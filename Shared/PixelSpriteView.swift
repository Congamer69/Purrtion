import SwiftUI
import UIKit

/// Draws a `PixelSprite` crisp with a Canvas.
struct PixelSpriteView: View {
    let sprite: PixelSprite
    var pixel: CGFloat = 4
    var palette: CatPalette = .ginger
    /// Single-colour rendering (tinted / clear widgets): shades become opacity steps of white.
    var mono = false
    /// Hat, glasses and scarf from the streak shop (cat and dog).
    var outfit = Outfit()
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let sprite = palette.isDog ? Wardrobe.apply(outfit, to: DogSprites.convert(self.sprite), dog: true)
                                   : Wardrobe.apply(outfit, to: self.sprite)
        if !mono {
            return AnyView(
                Image(uiImage: bitmap(sprite)).resizable().interpolation(.none)
                    .frame(width: CGFloat(sprite.width) * pixel, height: CGFloat(sprite.height) * pixel)
                    .accessibilityHidden(true))
        }
        return AnyView(Canvas { ctx, _ in
            if mono {
                // Translucent pixels must not overlap, or the seams show up as a grid: draw each run of equal pixels once.
                for (y, row) in sprite.rows.enumerated() {
                    let chars = Array(row)
                    var x = 0
                    while x < chars.count {
                        var end = x + 1
                        while end < chars.count, chars[end] == chars[x] { end += 1 }
                        if let color = monoColor(for: chars[x]) {
                            ctx.fill(Path(CGRect(x: CGFloat(x) * pixel, y: CGFloat(y) * pixel,
                                                 width: CGFloat(end - x) * pixel, height: pixel)), with: .color(color))
                        }
                        x = end
                    }
                }
                return
            }
            for (y, row) in sprite.rows.enumerated() {
                for (x, ch) in row.enumerated() {
                    guard let color = palette.color(for: ch) else { continue }
                    ctx.fill(Path(CGRect(x: CGFloat(x) * pixel, y: CGFloat(y) * pixel,
                                         width: pixel + 0.4, height: pixel + 0.4)),
                             with: .color(color))
                }
            }
        }
        .frame(width: CGFloat(sprite.width) * pixel, height: CGFloat(sprite.height) * pixel)
        .accessibilityHidden(true))
    }

    /// The sprite as a ready-made bitmap (one pixel per cell, scaled up without smoothing). Drawing hundreds of little
    /// rectangles for every frame made long lists of sprites (the shop, the streak page) slow; a cached image is one draw.
    private func bitmap(_ shown: PixelSprite) -> UIImage {
        let dark = scheme == .dark
        let key = "\(shown.hashValue)|\(palette.id)|\(dark)" as NSString
        if let cached = SpriteBitmapCache.cache.object(forKey: key) { return cached }
        let traits = UITraitCollection(userInterfaceStyle: dark ? .dark : .light)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false
        let image = UIGraphicsImageRenderer(size: CGSize(width: max(shown.width, 1), height: max(shown.height, 1)), format: format).image { ctx in
            for (y, row) in shown.rows.enumerated() {
                for (x, ch) in row.enumerated() {
                    guard let color = palette.color(for: ch) else { continue }
                    UIColor(color).resolvedColor(with: traits).setFill()
                    ctx.fill(CGRect(x: x, y: y, width: 1, height: 1))
                }
            }
        }
        SpriteBitmapCache.cache.setObject(image, forKey: key)
        return image
    }

    /// Same look as the system's lock screen rendering: every pixel becomes white with an opacity
    /// following the brightness of its real colour (light belly, grey fur, dark outline and eyes).
    func monoColor(for c: Character) -> Color? {
        guard let color = palette.color(for: c) else { return nil }
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(color).resolvedColor(with: UITraitCollection(userInterfaceStyle: .light)).getRed(&r, green: &g, blue: &b, alpha: &a)
        let luminance = 0.2126 * r + 0.7152 * g + 0.0722 * b
        return Color.white.opacity(Double((0.12 + 0.88 * pow(luminance, 1.4)) * a))
    }
}

enum SpriteBitmapCache {
    static let cache: NSCache<NSString, UIImage> = {
        let c = NSCache<NSString, UIImage>()
        c.countLimit = 400
        return c
    }()
}
