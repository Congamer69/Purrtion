package de.purrtion.app.domain

import android.util.Base64
import java.security.SecureRandom
import java.text.Normalizer
import javax.crypto.Cipher
import javax.crypto.SecretKeyFactory
import javax.crypto.spec.GCMParameterSpec
import javax.crypto.spec.PBEKeySpec
import javax.crypto.spec.SecretKeySpec
import org.json.JSONObject

/**
 * Keeps the friends login (uid + refresh token) in a backup, encrypted with a password only you know. Same format as the iPhone app.
 *
 * The token gives access to the friends profile, so it is never written in plain text:
 * - key: PBKDF2-HMAC-SHA256 (210 000 rounds, random 16 byte salt) from the password (Unicode NFC)
 * - cipher: AES-256-GCM with a random 12 byte nonce, the label below as authenticated data
 * - stored as `p1:` + base64(salt ‖ nonce ‖ ciphertext ‖ tag)
 * The password stays on this device (encrypted by the Keystore, see [Secrets]) so daily backups can encrypt without asking. It is never part of a backup.
 */
object BackupVault {
    const val PASSWORD_KEY = "backup.password"
    const val MINIMUM_LENGTH = 8
    private const val PREFIX = "p1:"
    private const val ROUNDS = 210_000
    private val label = "purrtion-friends-v1".toByteArray()

    class WrongPassword : Exception("Das Passwort stimmt nicht.")

    data class Account(val uid: String, val refresh: String)

    /** The password set on this device (null = the friends login is not backed up). */
    var password: String?
        get() = Secrets.get(PASSWORD_KEY)?.takeIf { it.isNotEmpty() }
        set(value) = Secrets.set(PASSWORD_KEY, value)

    fun seal(account: Account, password: String): String {
        val salt = ByteArray(16).also { SecureRandom().nextBytes(it) }
        val nonce = ByteArray(12).also { SecureRandom().nextBytes(it) }
        val cipher = Cipher.getInstance("AES/GCM/NoPadding").apply {
            init(Cipher.ENCRYPT_MODE, key(password, salt), GCMParameterSpec(128, nonce))
            updateAAD(label)
        }
        val plain = JSONObject().put("uid", account.uid).put("refresh", account.refresh).toString().toByteArray()
        return PREFIX + Base64.encodeToString(salt + nonce + cipher.doFinal(plain), Base64.NO_WRAP)
    }

    /** Throws [WrongPassword] for a wrong password or a changed file. */
    fun open(text: String, password: String): Account {
        val blob = runCatching { Base64.decode(text.removePrefix(PREFIX), Base64.DEFAULT) }.getOrNull()
        if (!text.startsWith(PREFIX) || blob == null || blob.size < 16 + 12 + 16) throw WrongPassword()
        return try {
            val salt = blob.copyOfRange(0, 16)
            val cipher = Cipher.getInstance("AES/GCM/NoPadding").apply {
                init(Cipher.DECRYPT_MODE, key(password, salt), GCMParameterSpec(128, blob.copyOfRange(16, 28)))
                updateAAD(label)
            }
            val json = JSONObject(String(cipher.doFinal(blob, 28, blob.size - 28)))
            Account(json.getString("uid"), json.getString("refresh"))
        } catch (e: Exception) { throw WrongPassword() }
    }

    private fun key(password: String, salt: ByteArray): SecretKeySpec {
        val spec = PBEKeySpec(Normalizer.normalize(password, Normalizer.Form.NFC).toCharArray(), salt, ROUNDS, 256)
        return SecretKeySpec(SecretKeyFactory.getInstance("PBKDF2WithHmacSHA256").generateSecret(spec).encoded, "AES")
    }
}
