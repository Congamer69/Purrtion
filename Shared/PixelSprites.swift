import SwiftUI

/// A pixel sprite described by rows of characters. Each character maps to a palette color, `.` is transparent.
struct PixelSprite: Hashable {
    let rows: [String]
    var width: Int { rows.map(\.count).max() ?? 0 }
    var height: Int { rows.count }

    init(_ rows: [String]) { self.rows = rows }

    var mirrored: PixelSprite { PixelSprite(rows.map { String($0.reversed()) }) }
}

/// Color palettes for the cats. Users can pick their favourite cat in the settings.
struct CatPalette: Hashable, Identifiable {
    let id: String
    let name: String
    let fur: Color
    let furLight: Color
    let stripe: Color

    static let ginger = CatPalette(id: "ginger", name: "Mochi", fur: Color(hex: 0xF6A25E), furLight: Color(hex: 0xFFE6CC), stripe: Color(hex: 0xE07B39))
    static let grey = CatPalette(id: "grey", name: "Nebel", fur: Color(hex: 0xA8A9B8), furLight: Color(hex: 0xECECF3), stripe: Color(hex: 0x82849A))
    static let black = CatPalette(id: "black", name: "Mitternacht", fur: Color(hex: 0x4A4453), furLight: Color(hex: 0x6E6779), stripe: Color(hex: 0x3A3542))
    static let cream = CatPalette(id: "cream", name: "Keks", fur: Color(hex: 0xF3DDBE), furLight: Color(hex: 0xFFF6EA), stripe: Color(hex: 0xD9B88E))

    /// The secret dog. Not part of `all`: it is unlocked by tapping the logo in the settings.
    static let dog = CatPalette(id: "dog", name: "Buddy", fur: Color(hex: 0xC98B4F), furLight: Color(hex: 0xF4E0BE), stripe: Color(hex: 0x8B5A33))

    // Fur colours from the streak shop.
    static let moon = CatPalette(id: "moon", name: "Mondschein", fur: Color(hex: 0xB9C6EC), furLight: Color(hex: 0xF3F6FF), stripe: Color(hex: 0x8D9CCF))
    static let cinnamon = CatPalette(id: "cinnamon", name: "Zimt", fur: Color(hex: 0xC4693B), furLight: Color(hex: 0xF5D5B7), stripe: Color(hex: 0x8F4626))
    static let sakura = CatPalette(id: "sakura", name: "Sakura", fur: Color(hex: 0xF5AACB), furLight: Color(hex: 0xFFEAF2), stripe: Color(hex: 0xD97BA3))
    static let mint = CatPalette(id: "mint", name: "Minze", fur: Color(hex: 0x86D9BC), furLight: Color(hex: 0xE6FBF3), stripe: Color(hex: 0x4FB08E))
    static let galaxy = CatPalette(id: "galaxy", name: "Galaxie", fur: Color(hex: 0x6F54D8), furLight: Color(hex: 0xCDBFFF), stripe: Color(hex: 0x4A34A3))
    static let shop: [CatPalette] = [.moon, .cinnamon, .sakura, .mint, .galaxy]

    static let all: [CatPalette] = [.ginger, .grey, .black, .cream]
    static func byID(_ id: String) -> CatPalette { (all + shop + [dog]).first { $0.id == id } ?? .ginger }
    var isDog: Bool { id == "dog" }

    func color(for c: Character) -> Color? {
        switch c {
        case "o": return Theme.pixelOutline
        case "w": return fur
        case "l": return furLight
        case "s": return stripe
        case "p": return Color(hex: 0xFF8FA3)
        case "e": return Color(hex: 0x2B2230)
        case "h": return .white
        case "c": return Color(hex: 0xFF9EAE, alpha: 0.85)
        // props
        case "r": return Color(hex: 0xFF5A5F)   // red
        case "R": return Color(hex: 0xC83C45)   // dark red
        case "g": return Color(hex: 0x6BCB77)   // green
        case "G": return Color(hex: 0x3E9E55)   // dark green
        case "b": return Color(hex: 0x6EC6FF)   // blue
        case "B": return Color(hex: 0x3D8FD1)   // dark blue
        case "y": return Color(hex: 0xFFC145)   // yellow
        case "n": return Color(hex: 0x9C6B4E)   // brown
        case "k": return Color(hex: 0xC9C2D0)   // light grey (plate / zzz)
        case "K": return Color(hex: 0x8F879A)   // grey
        case "W": return .white
        case "a": return Color(hex: 0xFF8A4A)   // orange
        case "A": return Color(hex: 0xD9662B)   // dark orange
        case "m": return Color(hex: 0xE08A6A)   // cooked meat
        case "M": return Color(hex: 0xB8583C)   // dark meat
        case "Y": return Color(hex: 0xE0A22E)   // dark yellow
        case "v": return Color(hex: 0x9B7BFF)   // violet
        case "V": return Color(hex: 0x6C4FD6)   // dark violet
        default: return nil
        }
    }
}

enum Sprites {
    // MARK: Sitting cat (front)
    static let sit = PixelSprite([
        "..o.......o.....",
        ".owo.....owo....",
        ".opwo...owpo....",
        ".opwwooowwpo....",
        "owwwswswswwwo...",
        "owwhewwwhewwo...",
        "owweewwweewwo...",
        "owcwwwpwwwcwo...",
        "owwwwowowwwwo...",
        ".owwllllllwo..o.",
        "..owllllllo..owo",
        ".owwllllllwo.owo",
        "owwwllllllwwoowo",
        "owwwllllllwwwwo.",
        "owwowwwwowwwwo..",
        ".ooooooooooooo..",
    ])

    static let sitBlink = PixelSprite([
        "..o.......o.....",
        ".owo.....owo....",
        ".opwo...owpo....",
        ".opwwooowwpo....",
        "owwwswswswwwo...",
        "owwwwwwwwwwwo...",
        "owwoowwwoowwo...",
        "owcwwwpwwwcwo...",
        "owwwwowowwwwo...",
        ".owwllllllwo..o.",
        "..owllllllo..owo",
        ".owwllllllwo.owo",
        "owwwllllllwwoowo",
        "owwwllllllwwwwo.",
        "owwowwwwowwwwo..",
        ".ooooooooooooo..",
    ])

    static let sitTail = PixelSprite([
        "..o.......o.....",
        ".owo.....owo....",
        ".opwo...owpo....",
        ".opwwooowwpo....",
        "owwwswswswwwo...",
        "owwhewwwhewwo...",
        "owweewwweewwo...",
        "owcwwwpwwwcwo...",
        "owwwwowowwwwo...",
        ".owwllllllwo....",
        "..owllllllo...o.",
        ".owwllllllwo.owo",
        "owwwllllllwwoowo",
        "owwwllllllwwwwo.",
        "owwowwwwowwwwo..",
        ".ooooooooooooo..",
    ])

    // happy: ^ ^ eyes, open smile
    static let happy = PixelSprite([
        "..o.......o.....",
        ".owo.....owo....",
        ".opwo...owpo....",
        ".opwwooowwpo....",
        "owwwswswswwwo...",
        "owwowwwwwowwo...",
        "owowowwwowowo...",
        "owcwwwpwwwcwo...",
        "owwwwowowwwwo...",
        ".owwllplllwo..o.",
        "..owllllllo..owo",
        ".owwllllllwo.owo",
        "owwwllllllwwoowo",
        "owwwllllllwwwwo.",
        "owwowwwwowwwwo..",
        ".ooooooooooooo..",
    ])

    // eating: mouth open
    static let eat1 = PixelSprite([
        "..o.......o.....",
        ".owo.....owo....",
        ".opwo...owpo....",
        ".opwwooowwpo....",
        "owwwswswswwwo...",
        "owwwwwwwwwwwo...",
        "owwoowwwoowwo...",
        "owcwwwpwwwcwo...",
        "owwwwoooowwwo...",
        ".owwwoppowwo..o.",
        "..owllooolo..owo",
        ".owwllllllwo.owo",
        "owwwllllllwwoowo",
        "owwwllllllwwwwo.",
        "owwowwwwowwwwo..",
        ".ooooooooooooo..",
    ])

    static let eat2 = PixelSprite([
        "..o.......o.....",
        ".owo.....owo....",
        ".opwo...owpo....",
        ".opwwooowwpo....",
        "owwwswswswwwo...",
        "owwwwwwwwwwwo...",
        "owwoowwwoowwo...",
        "owcwwwpwwwcwo...",
        "owwwwowowwwwo...",
        ".owwllllllwo..o.",
        "..owllllllo..owo",
        ".owwllllllwo.owo",
        "owwwllllllwwoowo",
        "owwwllllllwwwwo.",
        "owwowwwwowwwwo..",
        ".ooooooooooooo..",
    ])

    // worried / full: wide eyes, sweat drop
    static let full = PixelSprite([
        "..o.......o....b",
        ".owo.....owo..bb",
        ".opwo...owpo..bb",
        ".opwwooowwpo....",
        "owwwswswswwwo...",
        "owhewwwwwhewo...",
        "oweewwwwweewo...",
        "owcwwwpwwwcwo...",
        "owwwwoooowwwo...",
        ".owwllllllwwo.o.",
        "owwwllllllllwowo",
        "owwwllllllllwowo",
        "owwwllllllllwowo",
        "owwwllllllllwwo.",
        "owwowwwwwowwwo..",
        ".oooooooooooo...",
    ])

    // MARK: Sleeping (curled up loaf)
    static let sleep1 = PixelSprite([
        "....................",
        "....................",
        "..o...o.............",
        ".owo.owo............",
        ".owwowwooooooooo....",
        "owwwwwwwswswswwwo...",
        "owoowoowwwwwwwwwwo..",
        "owwcwpcwwwwwwwwwwwo.",
        ".owwwwwwlllllwwwwwo.",
        "..owwwwwllllllwwwwwo",
        "..oooowwwwwwwwwwwwwo",
        "......oooooooooooo..",
    ])

    static let sleep2 = PixelSprite([
        "....................",
        "....................",
        "..o...o.............",
        ".owo.owo............",
        ".owwowwooooooooo....",
        "owwwwwwwswswswwwo...",
        "owoowoowwwwwwwwwwo..",
        "owwcwpcwwwwwwwwwwwo.",
        ".owwwwwwlllllwwwwwwo",
        "..owwwwwllllllwwwwwo",
        "..oooowwwwwwwwwwwwwo",
        "......ooooooooooooo.",
    ])

    // MARK: Walking cat (side view, facing right)
    static let walk1 = PixelSprite([
        "...........o....o...",
        "..........owo..owo..",
        "..........owwoowwo..",
        ".........owwwwwwwwo.",
        ".........owwwwwhewo.",
        "o........owwwwweewpo",
        "ow.......owwwwwcwwo.",
        ".owoooooooowwwwwwo..",
        "..owswswswwwwwwwwo..",
        "..owwwwwwwwwwwwwo...",
        "..owwoooooooowwo....",
        "..ow.o......ow.o....",
        "..o..o......o..o....",
    ])

    static let walk2 = PixelSprite([
        "....................",
        "...........o....o...",
        "..........owo..owo..",
        "..........owwoowwo..",
        "o........owwwwwwwwo.",
        "ow.......owwwwwhewo.",
        ".ow......owwwwweewpo",
        "..ow.....owwwwwcwwo.",
        "..owoooooowwwwwwwo..",
        "..owswswswwwwwwwwo..",
        "..owwoooooooowwwo...",
        "...owo......owo.....",
        "...oo.......oo......",
    ])

    // MARK: Props
    static let heart = PixelSprite([
        ".rr.rr.",
        "rWrrrrr",
        "rrrrrrr",
        ".rrrrr.",
        "..rrr..",
        "...r...",
    ])

    static let apple = PixelSprite([
        "....G...",
        "...Gg...",
        ".rr.rrr.",
        "rWrrrrrr",
        "rrrrrrrr",
        "rrrrrrrR",
        ".rrrrrR.",
        "..rR.R..",
    ])

    static let fish = PixelSprite([
        "....bbb.....",
        "..bbbbbbb.bb",
        ".bbWbbbbbbbb",
        ".bbebbbbBbb.",
        "..bbbbbbbbbb",
        "....bbb...bb",
    ])

    static let drop = PixelSprite([
        "..b..",
        ".bbb.",
        "bbWbb",
        "bWbbb",
        "bbbbB",
        ".bBB.",
    ])

    static let star = PixelSprite([
        "...y...",
        "..yyy..",
        "yyyyyyy",
        ".yyyyy.",
        ".yy.yy.",
        "y.....y",
    ])

    static let z = PixelSprite([
        "KKKK",
        "..K.",
        ".K..",
        "KKKK",
    ])

    static let bowl = PixelSprite([
        "...n.n.n....",
        "..nynnynn...",
        "kkkkkkkkkkkk",
        "Kbbbbbbbbbbk",
        ".KbbWbbbbbk.",
        "..KKkkkkkK..",
    ])

    static let bread = PixelSprite([
        "..nnnn..",
        ".nyyyyn.",
        "nyyyyyyn",
        "nyyyYyyn",
        "nyyyyyyn",
        "nyYyyyyn",
        "nnnnnnnn",
    ])

    static let burger = PixelSprite([
        "..aaaa..",
        ".aaWaaa.",
        "aaaaaWaa",
        "gggggggg",
        "yyyyyyyy",
        "MMMMMMMM",
        ".AAAAAA.",
    ])

    static let fries = PixelSprite([
        "..y.y..",
        ".yyyyy.",
        ".yyyyy.",
        "rrrrrrr",
        ".rryrr.",
        ".rrrrr.",
        "..RRR..",
    ])

    static let carrot = PixelSprite([
        "......Gg",
        ".....gG.",
        "....aa..",
        "...aaA..",
        "..aaA...",
        ".aaA....",
        ".aA.....",
        "a.......",
    ])

    static let drumstick = PixelSprite([
        "..mmm...",
        ".mmmmm..",
        ".mmmmmm.",
        "..mmmmM.",
        "...MmM..",
        "....kW..",
        ".....kW.",
        "......W.",
    ])

    static let cheese = PixelSprite([
        "......yy",
        "....yyyy",
        "..yyYyyy",
        "yyyyyyyy",
        "yyYyyyYy",
        "yyyyyyyy",
    ])

    static let candy = PixelSprite([
        "r.....r",
        "rr.p.rr",
        "rrppprr",
        "rrpWprr",
        "rrppprr",
        "rr.p.rr",
        "r.....r",
    ])

    static let egg = PixelSprite([
        "..kkk..",
        ".kWWWk.",
        "kWWyWWk",
        "kWyyYWk",
        "kWWyWWk",
        ".kWWWk.",
        "..kkk..",
    ])

    static let paw = PixelSprite([
        ".p.p.",
        "p.p.p",
        ".....",
        ".ppp.",
        "ppppp",
        ".ppp.",
    ])

    static let glassEmpty = PixelSprite([
        "kkkkkkk",
        "k.....k",
        "k.....k",
        "k.....k",
        ".k...k.",
        ".k...k.",
        ".kkkkk.",
    ])

    static let glassFull = PixelSprite([
        "kkkkkkk",
        "kbbbbbk",
        "kbWbbbk",
        "kbbbbbk",
        ".kbbbk.",
        ".kbbBk.",
        ".kkkkk.",
    ])
}

// MARK: - More moods (built from the sitting cat: ears 0–4, face 5–8, body 9–15)

extension Sprites {
    private static let ears = [
        "..o.......o.....",
        ".owo.....owo....",
        ".opwo...owpo....",
        ".opwwooowwpo....",
        "owwwswswswwwo...",
    ]
    private static let body = [
        ".owwllllllwo..o.",
        "..owllllllo..owo",
        ".owwllllllwo.owo",
        "owwwllllllwwoowo",
        "owwwllllllwwwwo.",
        "owwowwwwowwwwo..",
        ".ooooooooooooo..",
    ]
    /// Rows 0–4 with something drawn into the free space right of the head (cols 13–15).
    private static func ears(_ extra: [String]) -> [String] {
        ears.enumerated().map { i, row in
            guard i < extra.count else { return row }
            return String(row.prefix(13)) + extra[i]
        }
    }

    // Morning, nothing eaten yet: sleepy eyes, then a big yawn.
    static let yawn1 = PixelSprite(ears + [
        "owwwwwwwwwwwo...",
        "owweewwweewwo...",
        "owcwwwpwwwcwo...",
        "owwwwowowwwwo...",
    ] + body)
    static let yawn2 = PixelSprite(ears + [
        "owwwwwwwwwwwo...",
        "owoowwwwwoowo...",
        "owcwwwpwwwcwo...",
        "owwwwoooowwwo...",
        ".owwwoppowwo..o.",
        "..owloppolo..owo",
        ".owwloooolwo.owo",
    ] + Array(body.suffix(4)))

    // Hungry: looks at its empty bowl and licks its lips.
    private static let hungryHead = [
        "..o.......o..........",
        ".owo.....owo.........",
        ".opwo...owpo.........",
        ".opwwooowwpo.........",
        "owwwswswswwwo........",
        "owwwhewwwhewo........",
        "owwweewwweewo........",
        "owcwwwpwwwcwo........",
        "owwwwowowwwwo........",
    ]
    private static let hungryBody = [
        "..owllllllo..........",
        ".owwllllllwo.........",
        "owwwllllllwwo.ooooooo",
        "owwwllllllwwo.okkkkko",
        "owwowwwwowwwo..oKKKo.",
        ".ooooooooooo....ooo..",
    ]
    static let hungry1 = PixelSprite(hungryHead + [".owwllplllwo........."] + hungryBody)
    static let hungry2 = PixelSprite(hungryHead + [".owwllllllwo........."] + hungryBody)

    // Tipsy: winking, blushing, hiccup bubbles.
    static let tipsy1 = PixelSprite(ears(["...", "...", ".b.", "bWb", ".b."]) + [
        "owwhewwwwwwwo...",
        "owweewwwoowwo...",
        "owccwwpwwccwo...",
        "owwwowowowwwo...",
    ] + body)
    static let tipsy2 = PixelSprite(ears([".b.", "bWb", ".b.", "...", "..."]) + [
        "owwwwwwwhewwo...",
        "owwoowwweewwo...",
        "owccwwpwwccwo...",
        "owwowowowwwwo...",
    ] + body)

    // Great day: heart eyes and a twinkle.
    private static let loveFace = [
        "owrwrwwwrwrwo...",
        "owrrrwwwrrrwo...",
        "owcrwwpwwrcwo...",
        "owwwwowowwwwo...",
    ]
    static let proud1 = PixelSprite(ears(["...", ".y.", "yWy", ".y.", "..."]) + loveFace + body)
    static let proud2 = PixelSprite(ears(["...", "...", "...", "..y", "..."]) + loveFace + body)

    // Goal reached: content, licking its lips.
    static let content1 = PixelSprite(ears + [
        "owowowwwowowo...",
        "owwowwwwwowwo...",
        "owcwwwpwwwcwo...",
        "owwwwowowwwwo...",
        ".owwlllpllwo..o.",
    ] + Array(body.suffix(6)))
    static let content2 = PixelSprite(ears + [
        "owowowwwowowo...",
        "owwowwwwwowwo...",
        "owcwwwpwwwcwo...",
        "owwwwowowwwwo...",
    ] + body)

    // Way too much: round belly, squeezed eyes, sweat.
    private static let stuffedBody = [
        ".owwllllllllwo..",
        "owwllllllllllwo.",
        "owllllllllllllwo",
        "owllllllllllllwo",
        "owllllllllllllwo",
        ".owwllllllllwwo.",
        "..oooooooooooo..",
    ]
    static let stuffed1 = PixelSprite(ears(["..b", ".bb", "...", "...", "..."]) + [
        "owowwwwwwwowo...",
        "owwowwwwwowwo...",
        "owowwwpwwwowo...",
        "owwwwwowwwwwo...",
    ] + stuffedBody)
    static let stuffed2 = PixelSprite(ears(["...", "..b", ".bb", "...", "..."]) + [
        "owowwwwwwwowo...",
        "owwowwwwwowwo...",
        "owowwwpwwwowo...",
        "owwwwwowwwwwo...",
    ] + stuffedBody)

    // Thirsty: dreams of a water drop.
    static let thirsty1 = PixelSprite(ears([".b.", "bbb", "bBb", ".b.", "..."]) + [
        "owwhewwwhewwo...",
        "owweewwweewwo...",
        "owcwwwpwwwcwo...",
        "owwwwwowwwwwo...",
    ] + body)
    static let thirsty2 = PixelSprite(ears(["...", ".b.", "bbb", "bBb", ".b."]) + [
        "owwhewwwhewwo...",
        "owweewwweewwo...",
        "owcwwwpwwwcwo...",
        "owwwwwowwwwwo...",
    ] + body)

    // Lots of activity: sweatband.
    private static let sportyEars = [
        "..o.......o.....",
        ".owo.....owo....",
        ".opwo...owpo....",
        ".opwwooowwpo....",
        "orrrrrrrrrrro...",
    ]
    static let sporty1 = PixelSprite(sportyEars + [
        "owwowwwwwowwo...",
        "owowowwwowowob..",
        "owcwwwpwwwcwo...",
        "owwwwowowwwwo...",
    ] + body)
    static let sporty2 = PixelSprite(sportyEars + [
        "owwowwwwwowwo...",
        "owowowwwowowo...",
        "owcwwwpwwwcwob..",
        "owwwwowowwwwo...",
    ] + body)
}

/// Wording for the chosen companion, so texts say "Hund" while the dog is active.
enum Pet {
    static let storageKey = "catPalette"
    static var isDog: Bool { UserDefaults.standard.string(forKey: storageKey) == CatPalette.dog.id }
    /// "die Katze" / "der Hund" (nominative).
    static var the: String { isDog ? "der Hund" : "die Katze" }
    /// "deine Katze" / "dein Hund".
    static var your: String { isDog ? "dein Hund" : "deine Katze" }
    static var yourUpper: String { isDog ? "Dein Hund" : "Deine Katze" }
    static var noun: String { isDog ? "Hund" : "Katze" }
}
