package de.purrtion.app.domain

import de.purrtion.app.App
import java.io.ByteArrayOutputStream
import java.time.Instant
import java.util.zip.Deflater
import java.util.zip.Inflater

/**
 * Backup on the server (Firestore), tied to the Google login. The JSON of [Backup] is compressed (raw deflate, same as on
 * iOS) and cut into parts of 700 KB (up to 10 MB in all). Two slots alternate, so a failed upload never damages the last backup: the
 * parts of the new slot are written first, then "backups/{uid}" points to them.
 */
object ServerBackup {
    private const val PART_SIZE = 700_000
    private const val MAX_PARTS = 15

    data class Meta(val updated: Long, val parts: Int, val entries: Int, val slot: String, val device: String)

    class Shrinks(val local: Int, val remote: Int) : Exception()

    private val uid: String get() = FirebaseAuth.uid ?: throw FirebaseException("Melde dich zuerst mit Google an.")

    suspend fun meta(): Meta? {
        val d = try { FirebaseREST.get("backups/$uid") } catch (e: FirebaseException) { if (e === FirebaseException.notFound) return null else throw e }
        val parts = (d["parts"] as? Double)?.toInt() ?: return null
        return Meta((d["updated"] as? Instant)?.toEpochMilli() ?: 0L, parts, (d["entries"] as? Double)?.toInt() ?: 0,
            d["slot"] as? String ?: "a", d["device"] as? String ?: "")
    }

    suspend fun upload(force: Boolean): Meta {
        val uid = uid
        val payload = Backup.makePayload()
        val old = meta()
        // A fresh install must not replace a good backup with its almost empty data.
        if (!force && old != null && old.entries > 0 && payload.entries.size < old.entries / 2) throw Shrinks(payload.entries.size, old.entries)
        val packed = deflate(Backup.encode(payload).toByteArray())
        val chunks = (packed.indices step PART_SIZE).map { packed.copyOfRange(it, minOf(it + PART_SIZE, packed.size)) }
        if (chunks.size > MAX_PARTS) throw FirebaseException("Das Backup ist größer als 10 MB und passt nicht auf den Server.")
        val slot = if (old?.slot == "a") "b" else "a"
        chunks.forEachIndexed { i, chunk -> FirebaseREST.set("backups/$uid/parts/$slot$i", mapOf("d" to chunk)) }
        val meta = Meta(System.currentTimeMillis(), chunks.size, payload.entries.size, slot, "Android")
        FirebaseREST.set("backups/$uid", mapOf("updated" to Instant.ofEpochMilli(meta.updated), "parts" to chunks.size,
            "entries" to meta.entries, "size" to packed.size, "slot" to slot, "device" to meta.device, "v" to 1))
        if (old != null) for (i in 0 until old.parts) runCatching { FirebaseREST.delete("backups/$uid/parts/${old.slot}$i") }
        return meta
    }

    suspend fun download(): String {
        val uid = uid
        val meta = meta() ?: throw FirebaseException.notFound
        val out = ByteArrayOutputStream()
        for (i in 0 until meta.parts) {
            val part = FirebaseREST.get("backups/$uid/parts/${meta.slot}$i")["d"] as? ByteArray ?: throw FirebaseException("Das Backup auf dem Server ist unvollständig.")
            out.write(part)
        }
        return String(inflate(out.toByteArray()))
    }

    suspend fun delete() {
        val uid = uid
        meta()?.let { m -> for (slot in listOf("a", "b")) for (i in 0 until maxOf(m.parts, MAX_PARTS)) runCatching { FirebaseREST.delete("backups/$uid/parts/$slot$i") } }
        FirebaseREST.delete("backups/$uid")
    }

    private fun deflate(data: ByteArray): ByteArray {
        val d = Deflater(Deflater.DEFAULT_COMPRESSION, true)
        d.setInput(data); d.finish()
        val out = ByteArrayOutputStream(); val buf = ByteArray(65536)
        while (!d.finished()) out.write(buf, 0, d.deflate(buf))
        d.end()
        return out.toByteArray()
    }

    private fun inflate(data: ByteArray): ByteArray {
        val i = Inflater(true)
        i.setInput(data + 0)
        val out = ByteArrayOutputStream(); val buf = ByteArray(65536)
        while (!i.finished()) {
            val n = i.inflate(buf)
            if (n == 0 && (i.needsInput() || i.needsDictionary())) break
            out.write(buf, 0, n)
        }
        i.end()
        return out.toByteArray()
    }
}
