import Foundation

/// What the cat wears (hat, glasses, scarf), picked in the streak shop. Drawn into the sprite's pixel rows, so it moves with
/// every frame. Only the upright poses carry clothes; lying and walking poses stay bare.
struct Outfit: Equatable {
    var hat = ""
    var glasses = ""
    var scarf = ""
    var isEmpty: Bool { hat.isEmpty && glasses.isEmpty && scarf.isEmpty }

    /// "hat,glasses,scarf" as sent to friends (nil/empty = nothing worn).
    var encoded: String? { isEmpty ? nil : [hat, glasses, scarf].joined(separator: ",") }

    init(hat: String = "", glasses: String = "", scarf: String = "") { self.hat = hat; self.glasses = glasses; self.scarf = scarf }

    init(encoded: String?) {
        let p = (encoded ?? "").split(separator: ",", omittingEmptySubsequences: false).map(String.init)
        self.init(hat: p.count > 0 ? p[0] : "", glasses: p.count > 1 ? p[1] : "", scarf: p.count > 2 ? p[2] : "")
    }
}

enum Wardrobe {
    /// Hats fill the gap between the ears: columns 3–9 of rows 0–2. They only paint onto empty cells.
    private static let hats: [String: [String]] = [
        "hat.party":  ["...y...", "..rWr..", ".rWrWr."],
        "hat.beanie": ["...W...", "..bbb..", "..BbB.."],
        "hat.top":    ["..eee..", "..eRe..", "..eee.."],
        "hat.crown":  [".y.y.y.", ".yyyyy.", "..yYy.."],
        "hat.wizard": ["...B...", "..ByB..", ".BvBvB."],
    ]
    /// Scarf colours: light and dark stripe.
    private static let scarves: [String: (Character, Character)] = [
        "scarf.red": ("r", "R"), "scarf.blue": ("b", "B"), "scarf.green": ("g", "G"), "scarf.gold": ("y", "Y"), "scarf.violet": ("v", "V"),
    ]

    static func apply(_ outfit: Outfit, to sprite: PixelSprite) -> PixelSprite {
        guard !outfit.isEmpty, sprite.rows.count == 16, sprite.rows[0].hasPrefix("..o.......o.."), sprite.rows[4].hasPrefix("owwwswswswwwo") else { return sprite }
        var grid = sprite.rows.map { Array($0) }
        func put(_ row: Int, _ col: Int, _ ch: Character, onlyEmpty: Bool = false) {
            guard ch != ".", row < grid.count, col < grid[row].count else { return }
            if onlyEmpty && grid[row][col] != "." { return }
            grid[row][col] = ch
        }
        if let hat = hats[outfit.hat] {
            for (r, line) in hat.enumerated() { for (i, ch) in line.enumerated() { put(r, 3 + i, ch, onlyEmpty: true) } }
        }
        if outfit.glasses == "glasses.round" || outfit.glasses == "glasses.sun" {
            let frame: Character = outfit.glasses == "glasses.sun" ? "e" : "B"
            for start in [2, 7] {
                for c in start...(start + 3) { put(4, c, frame); put(7, c, frame) }
                for r in 5...6 { put(r, start, frame); put(r, start + 3, frame) }
                if outfit.glasses == "glasses.sun" { for r in 5...6 { put(r, start + 1, "e"); put(r, start + 2, "e") } }
            }
            put(5, 6, frame)
        }
        if let (a, b) = scarves[outfit.scarf] {
            for (i, c) in (2...10).enumerated() { put(9, c, i % 2 == 0 ? a : b) }
            put(10, 5, a); put(10, 6, b); put(11, 5, b)
        }
        return PixelSprite(grid.map { String($0) })
    }
}
