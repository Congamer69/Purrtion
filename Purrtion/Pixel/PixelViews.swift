import SwiftUI


/// Cycles through frames using a timeline.
struct AnimatedSprite: View {
    let frames: [PixelSprite]
    var fps: Double = 4
    var pixel: CGFloat = 4
    var palette: CatPalette = .ginger

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1 / fps)) { ctx in
            let i = Int(ctx.date.timeIntervalSinceReferenceDate * fps) % max(frames.count, 1)
            PixelSpriteView(sprite: frames[i], pixel: pixel, palette: palette)
        }
    }
}

enum CatMood: Equatable {
    case idle, happy, eating, sleeping, full

    var frames: [PixelSprite] {
        switch self {
        // long sequence so blinks / tail flicks feel random-ish
        case .idle: return [Sprites.sit, .init(Sprites.sit.rows), Sprites.sitTail, Sprites.sit, Sprites.sit,
                            Sprites.sitBlink, Sprites.sit, Sprites.sitTail, Sprites.sit, Sprites.sit, Sprites.sit, Sprites.sitBlink]
        case .happy: return [Sprites.happy, Sprites.happy, Sprites.sitTail, Sprites.happy, Sprites.sitBlink]
        case .eating: return [Sprites.eat1, Sprites.eat2]
        case .sleeping: return [Sprites.sleep1, Sprites.sleep1, Sprites.sleep2, Sprites.sleep2]
        case .full: return [Sprites.full, Sprites.full, Sprites.full, Sprites.sitBlink]
        }
    }

    var fps: Double {
        switch self {
        case .eating: return 6
        case .sleeping: return 1.5
        default: return 3
        }
    }
}

/// The mascot: a pixel cat that reacts to your day.
struct CatMascot: View {
    var mood: CatMood
    var pixel: CGFloat = 5
    @AppStorage("catPalette") private var paletteID = CatPalette.ginger.id
    @State private var bounce = false

    var body: some View {
        ZStack(alignment: .topTrailing) {
            AnimatedSprite(frames: mood.frames, fps: mood.fps, pixel: pixel, palette: CatPalette.byID(paletteID))
                .offset(y: bounce ? -pixel * 2 : 0)
            if mood == .sleeping { FloatingZs(pixel: pixel * 0.6).offset(x: pixel * 2, y: -pixel * 4) }
        }
        .onChange(of: mood) { _, new in
            guard new == .eating || new == .happy else { return }
            withAnimation(.spring(response: 0.22, dampingFraction: 0.4)) { bounce = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) { bounce = false }
            }
        }
    }
}

struct FloatingZs: View {
    var pixel: CGFloat = 3
    var body: some View {
        TimelineView(.animation) { ctx in
            let t = ctx.date.timeIntervalSinceReferenceDate
            ZStack {
                ForEach(0..<3, id: \.self) { i in
                    let p = (t / 2.4 + Double(i) / 3).truncatingRemainder(dividingBy: 1)
                    PixelSpriteView(sprite: Sprites.z, pixel: pixel * (0.6 + p * 0.6))
                        .offset(x: CGFloat(p) * pixel * 6, y: -CGFloat(p) * pixel * 14)
                        .opacity(p < 0.8 ? 1 : (1 - p) * 5)
                }
            }
        }
    }
}

/// Little cat walking back and forth - used as loading indicator.
struct WalkingCatLoader: View {
    var pixel: CGFloat = 3
    var width: CGFloat = 200
    var text: String? = nil
    @AppStorage("catPalette") private var paletteID = CatPalette.ginger.id

    var body: some View {
        VStack(spacing: 10) {
            TimelineView(.animation) { ctx in
                let t = ctx.date.timeIntervalSinceReferenceDate
                let period = 3.2
                let phase = (t / period).truncatingRemainder(dividingBy: 1)
                let forward = phase < 0.5
                let p = forward ? phase * 2 : (1 - phase) * 2
                let spriteW = CGFloat(Sprites.walk1.width) * pixel
                let frame = Int(t * 7) % 2 == 0 ? Sprites.walk1 : Sprites.walk2
                PixelSpriteView(sprite: forward ? frame : frame.mirrored, pixel: pixel, palette: CatPalette.byID(paletteID))
                    .offset(x: (width - spriteW) * CGFloat(p) - (width - spriteW) / 2)
            }
            .frame(width: width, height: CGFloat(Sprites.walk1.height) * pixel)
            PixelDashes(width: width)
            if let text {
                Text(text)
                    .font(Theme.font(14, .medium))
                    .foregroundStyle(Theme.textSecondary)
            }
        }
    }
}

struct PixelDashes: View {
    var width: CGFloat
    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<Int(width / 10), id: \.self) { _ in
                Rectangle().fill(Theme.line).frame(width: 6, height: 3)
            }
        }
        .frame(width: width)
    }
}

/// Pixel hearts bursting from a point, used when food is added.
struct HeartBurst: View {
    var trigger: Int
    @State private var particles: [Particle] = []

    struct Particle: Identifiable {
        let id = UUID()
        let dx: CGFloat
        let dy: CGFloat
        let sprite: PixelSprite
        var on = false
    }

    var body: some View {
        ZStack {
            ForEach(particles) { p in
                PixelSpriteView(sprite: p.sprite, pixel: 3)
                    .offset(x: p.on ? p.dx : 0, y: p.on ? p.dy : 0)
                    .opacity(p.on ? 0 : 1)
                    .scaleEffect(p.on ? 1.2 : 0.4)
            }
        }
        .allowsHitTesting(false)
        .onChange(of: trigger) { _, _ in burst() }
    }

    private func burst() {
        let sprites = [Sprites.heart, Sprites.star, Sprites.heart, Sprites.paw]
        let new = (0..<8).map { i -> Particle in
            let angle = Double(i) / 8 * 2 * .pi + .random(in: -0.3...0.3)
            let r = CGFloat.random(in: 60...100)
            return Particle(dx: cos(angle) * r, dy: sin(angle) * r - 30, sprite: sprites[i % sprites.count])
        }
        particles = new
        withAnimation(.easeOut(duration: 0.9)) {
            for i in particles.indices { particles[i].on = true }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { particles.removeAll() }
    }
}

// MARK: - Pixel font (5x5) for the logo

enum PixelFont {
    static let glyphs: [Character: [String]] = [
        "P": ["xxxx.", "x...x", "xxxx.", "x....", "x...."],
        "U": ["x...x", "x...x", "x...x", "x...x", ".xxx."],
        "R": ["xxxx.", "x...x", "xxxx.", "x..x.", "x...x"],
        "T": ["xxxxx", "..x..", "..x..", "..x..", "..x.."],
        "I": ["xxx", ".x.", ".x.", ".x.", "xxx"],
        "O": [".xxx.", "x...x", "x...x", "x...x", ".xxx."],
        "N": ["x...x", "xx..x", "x.x.x", "x..xx", "x...x"],
        " ": ["..", "..", "..", "..", ".."],
    ]
}

struct PixelText: View {
    let text: String
    var pixel: CGFloat = 4
    var color: Color = Theme.textPrimary

    var body: some View {
        HStack(alignment: .top, spacing: pixel) {
            ForEach(Array(text.uppercased().enumerated()), id: \.offset) { _, ch in
                let g = PixelFont.glyphs[ch] ?? PixelFont.glyphs[" "]!
                Canvas { ctx, _ in
                    for (y, row) in g.enumerated() {
                        for (x, c) in row.enumerated() where c == "x" {
                            ctx.fill(Path(CGRect(x: CGFloat(x) * pixel, y: CGFloat(y) * pixel, width: pixel, height: pixel)),
                                     with: .color(color))
                        }
                    }
                }
                .frame(width: CGFloat(g[0].count) * pixel, height: 5 * pixel)
            }
        }
        .accessibilityLabel(text)
    }
}
