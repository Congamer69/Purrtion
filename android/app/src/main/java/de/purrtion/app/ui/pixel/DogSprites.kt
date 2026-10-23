package de.purrtion.app.ui.pixel

/**
 * The secret dog: every cat sprite is turned into a dog by swapping the pointy ears for floppy ones,
 * adding a light muzzle with a black nose and a tongue. Props (food, hearts …) stay as they are.
 * Same transformation as `Shared/DogSprites.swift` on iOS.
 */
object DogSprites {
    private val cache = HashMap<PixelSprite, PixelSprite>()

    @Synchronized
    fun convert(sprite: PixelSprite): PixelSprite = cache.getOrPut(sprite) { build(sprite) }

    private fun build(sprite: PixelSprite): PixelSprite {
        val rows = sprite.rows.map { it.toCharArray() }.toMutableList()
        if (rows.size < 12) return sprite
        val r = sprite.rows
        when {
            rows.size >= 14 && r[0].startsWith("..o.......o") -> sit(rows)
            rows.size == 12 && r[2].startsWith("..o...o") -> sleep(rows)
            rows.size == 13 && (r[0].startsWith("...........o....o") || r[1].startsWith("...........o....o")) -> walk(rows)
            else -> return sprite
        }
        return PixelSprite(rows.map { String(it) })
    }

    /** No tabby stripes on a dog; `s` is the ear colour here. */
    private fun stripesOff(rows: List<CharArray>) {
        for (row in rows) for (x in row.indices) if (row[x] == 's') row[x] = 'w'
    }

    private fun ear(rows: List<CharArray>, y: Int, cols: List<Int>) {
        if (y !in rows.indices) return
        for (x in cols) if (x in rows[y].indices && rows[y][x] == 'w') rows[y][x] = 's'
    }

    /** Replaces the first columns of a row, keeping whatever the cat drew to the right of it (sweat, sparkles …). */
    private fun head(rows: List<CharArray>, y: Int, new: String) {
        for ((x, c) in new.withIndex()) if (x in rows[y].indices) rows[y][x] = c
    }

    private fun sit(rows: List<CharArray>) {
        stripesOff(rows)
        head(rows, 0, "..ooooooooo..")
        head(rows, 1, ".owwwwwwwwwo.")
        head(rows, 2, ".osswwwwwsso.")
        head(rows, 3, "ossswwwwwssso")
        for (y in 4..7) ear(rows, y, listOf(1, 2, 10, 11))
        // Tongue between the mouth lines, light muzzle, black nose.
        if (rows[8].size > 7 && rows[8][5] == 'o' && rows[8][6] == 'w' && rows[8][7] == 'o') rows[8][6] = 'p'
        for (y in 7..8) for (x in 4..8) if (rows[y][x] == 'w') rows[y][x] = 'l'
        if (rows[7][6] == 'p') rows[7][6] = 'e'
    }

    private fun sleep(rows: List<CharArray>) {
        stripesOff(rows)
        head(rows, 2, "..ooo")
        head(rows, 3, ".ossswo")
        head(rows, 4, ".ossswwo")
        for (y in 5..7) ear(rows, y, listOf(1, 2))
        if (rows[7][5] == 'p') rows[7][5] = 'e'
    }

    private fun walk(rows: MutableList<CharArray>) {
        stripesOff(rows)
        val f = if ('o' in rows[0]) 0 else 1
        rows[f] = CharArray(rows[0].size) { '.' }
        rows[f + 1] = "..........oooooooo..".toCharArray()
        rows[f + 2] = ".........owwwwwwwwo.".toCharArray()
        for (y in (f + 3)..(f + 6)) {
            ear(rows, y, listOf(10, 11))
            for (x in rows[y].indices) if (rows[y][x] == 'p') rows[y][x] = 'e'
        }
    }
}
