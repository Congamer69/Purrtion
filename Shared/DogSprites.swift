import Foundation

/// The secret dog: every cat sprite is turned into a dog by swapping the pointy ears for floppy ones,
/// adding a light muzzle with a black nose and a tongue. Props (food, hearts …) stay as they are.
enum DogSprites {
    private static var cache: [PixelSprite: PixelSprite] = [:]
    private static let lock = NSLock()

    static func convert(_ sprite: PixelSprite) -> PixelSprite {
        lock.lock(); defer { lock.unlock() }
        if let hit = cache[sprite] { return hit }
        let result = build(sprite)
        cache[sprite] = result
        return result
    }

    private static func build(_ sprite: PixelSprite) -> PixelSprite {
        var rows = sprite.rows.map { Array($0) }
        guard rows.count >= 12 else { return sprite }

        if rows.count >= 14, sprite.rows[0].hasPrefix("..o.......o") {
            sit(&rows)
        } else if rows.count == 12, sprite.rows[2].hasPrefix("..o...o") {
            sleep(&rows)
        } else if rows.count == 13, sprite.rows[0].hasPrefix("...........o....o") || sprite.rows[1].hasPrefix("...........o....o") {
            walk(&rows)
        } else {
            return sprite
        }
        return PixelSprite(rows.map { String($0) })
    }

    /// No tabby stripes on a dog; `s` is the ear colour here.
    private static func stripesOff(_ rows: inout [[Character]]) {
        for y in rows.indices { for x in rows[y].indices where rows[y][x] == "s" { rows[y][x] = "w" } }
    }

    private static func ear(_ rows: inout [[Character]], y: Int, cols: [Int]) {
        guard rows.indices.contains(y) else { return }
        for x in cols where rows[y].indices.contains(x) && rows[y][x] == "w" { rows[y][x] = "s" }
    }

    /// Replaces the first columns of a row, keeping whatever the cat drew to the right of it (sweat, sparkles …).
    private static func head(_ rows: inout [[Character]], y: Int, _ new: String) {
        let n = Array(new)
        for (x, c) in n.enumerated() where rows[y].indices.contains(x) { rows[y][x] = c }
    }

    private static func sit(_ rows: inout [[Character]]) {
        stripesOff(&rows)
        head(&rows, y: 0, "..ooooooooo..")
        head(&rows, y: 1, ".owwwwwwwwwo.")
        head(&rows, y: 2, ".osswwwwwsso.")
        head(&rows, y: 3, "ossswwwwwssso")
        for y in 4...7 { ear(&rows, y: y, cols: [1, 2, 10, 11]) }
        // Tongue between the mouth lines, light muzzle, black nose.
        if rows[8].count > 7, rows[8][5] == "o", rows[8][6] == "w", rows[8][7] == "o" { rows[8][6] = "p" }
        for y in 7...8 { for x in 4...8 where rows[y][x] == "w" { rows[y][x] = "l" } }
        if rows[7][6] == "p" { rows[7][6] = "e" }
    }

    private static func sleep(_ rows: inout [[Character]]) {
        stripesOff(&rows)
        head(&rows, y: 2, "..ooo")
        head(&rows, y: 3, ".ossswo")
        head(&rows, y: 4, ".ossswwo")
        for y in 5...7 { ear(&rows, y: y, cols: [1, 2]) }
        if rows[7][5] == "p" { rows[7][5] = "e" }
    }

    private static func walk(_ rows: inout [[Character]]) {
        stripesOff(&rows)
        let f = rows[0].contains("o") ? 0 : 1
        let blank = [Character](repeating: ".", count: rows[0].count)
        rows[f] = blank
        rows[f + 1] = Array("..........oooooooo..")
        rows[f + 2] = Array(".........owwwwwwwwo.")
        for y in (f + 3)...(f + 6) {
            ear(&rows, y: y, cols: [10, 11])
            for x in rows[y].indices where rows[y][x] == "p" { rows[y][x] = "e" }
        }
    }
}
