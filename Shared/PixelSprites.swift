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

    static let all: [CatPalette] = [.ginger, .grey, .black, .cream]
    static func byID(_ id: String) -> CatPalette { all.first { $0.id == id } ?? .ginger }

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
