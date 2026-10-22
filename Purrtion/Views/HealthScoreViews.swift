import SwiftUI

extension HealthScore {
    var color: Color {
        switch score {
        case 80...: Theme.fiber
        case 60..<80: Theme.carbs
        default: Theme.accent
        }
    }
}

/// Compact score card on the Today screen.
struct HealthScoreCard: View {
    let score: HealthScore
    /// Score without the AI-added micronutrients – only passed when it differs.
    var baseline: HealthScore? = nil

    var body: some View {
        HStack(spacing: 14) {
            ScoreRing(value: Double(score.score) / 100, color: score.color, lineWidth: 6,
                      baseline: baseline.map { Double($0.score) / 100 }) {
                Text("\(score.score)").font(Theme.font(18, .heavy)).foregroundStyle(Theme.textPrimary)
                    .contentTransition(.numericText(value: Double(score.score)))
            }
            .frame(width: 54, height: 54)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text("Health Score").font(Theme.font(15, .bold)).foregroundStyle(Theme.textPrimary)
                    Text(score.isPreliminary ? "vorläufig" : score.rating)
                        .font(Theme.font(11, .bold))
                        .foregroundStyle(score.isPreliminary ? Theme.textSecondary : score.color)
                        .padding(.horizontal, 7).padding(.vertical, 2)
                        .background((score.isPreliminary ? Theme.textSecondary : score.color).opacity(0.15), in: Capsule())
                    if let baseline { AIDeltaBadge(delta: score.score - baseline.score) }
                }
                // mini bars for each component
                HStack(spacing: 3) {
                    ForEach(score.components) { c in
                        Capsule().fill(Theme.track(score.color))
                            .overlay(alignment: .leading) {
                                GeometryReader { g in Capsule().fill(score.color).frame(width: g.size.width * c.ratio) }
                            }
                            .frame(height: 5)
                    }
                }
                Text(score.components.compactMap(\.tip).first ?? "Super ausgewogen heute – weiter so!")
                    .font(Theme.font(12)).foregroundStyle(Theme.textSecondary).lineLimit(1)
            }
            Image(systemName: "chevron.right").font(.system(size: 12, weight: .bold)).foregroundStyle(Theme.textSecondary)
        }
        .card(padding: 14)
    }
}

struct ScoreRing<Label: View>: View {
    let value: Double
    let color: Color
    var lineWidth: CGFloat = 10
    /// Score without AI additions: the part between baseline and value is drawn lighter.
    var baseline: Double? = nil
    @ViewBuilder let label: () -> Label
    @State private var shown = 0.0

    var body: some View {
        ZStack {
            Circle().stroke(Theme.track(color), lineWidth: lineWidth)
            if let baseline, baseline < value {
                // AI gain: light segment on top of the solid "own data" part.
                Circle().trim(from: 0, to: shown)
                    .stroke(color.opacity(0.4), style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Circle().trim(from: 0, to: min(shown, baseline))
                    .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                    .rotationEffect(.degrees(-90))
            } else {
                Circle().trim(from: 0, to: shown)
                    .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                    .rotationEffect(.degrees(-90))
            }
            label()
        }
        .padding(lineWidth / 2)
        .onAppear { withAnimation(Motion.fill.delay(0.1)) { shown = value } }
        .onChange(of: value) { _, v in withAnimation(.spring) { shown = v } }
    }
}

/// Detailed breakdown sheet.
/// "+5 KI" – how much the AI-completed micronutrients changed the score.
struct AIDeltaBadge: View {
    let delta: Int

    var body: some View {
        HStack(spacing: 2) {
            Image(systemName: "sparkles").font(.system(size: 8, weight: .bold))
            Text("\(delta >= 0 ? "+" : "−")\(abs(delta)) KI").font(Theme.font(10, .bold))
        }
        .foregroundStyle(Theme.accent)
        .padding(.horizontal, 6).padding(.vertical, 2)
        .background(Theme.accentSoft, in: Capsule())
        .fixedSize()
        .accessibilityLabel("\(delta >= 0 ? "plus" : "minus") \(abs(delta)) Punkte durch KI-Ergänzung")
    }
}

struct HealthScoreView: View {
    let score: HealthScore
    var baseline: HealthScore? = nil
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    VStack(spacing: 10) {
                        ScoreRing(value: Double(score.score) / 100, color: score.color, lineWidth: 14,
                                  baseline: baseline.map { Double($0.score) / 100 }) {
                            VStack(spacing: 0) {
                                Text("\(score.score)").font(Theme.font(44, .heavy)).foregroundStyle(Theme.textPrimary)
                                Text("von 100").font(Theme.font(12, .medium)).foregroundStyle(Theme.textSecondary)
                            }
                        }
                        .frame(width: 150, height: 150)
                        Text(score.rating).font(Theme.font(20, .bold)).foregroundStyle(score.color)
                        if let baseline {
                            AIComparison(before: baseline.score, after: score.score, color: score.color)
                        }
                        if score.isPreliminary {
                            Label("Vorläufig – du hast erst \(Int(score.completeness * 100)) % deines Kalorienziels gegessen. Der Score wird im Laufe des Tages aussagekräftiger.",
                                  systemImage: "clock")
                                .font(Theme.font(13)).foregroundStyle(Theme.textSecondary).multilineTextAlignment(.center)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .card(padding: 20)

                    let tips = score.components.filter { $0.tip != nil }.sorted { $0.maxPoints - $0.points > $1.maxPoints - $1.points }
                    if let top = tips.first, let tip = top.tip {
                        HStack(alignment: .top, spacing: 12) {
                            CatMascot(mood: .idle, pixel: 2.6)
                            VStack(alignment: .leading, spacing: 3) {
                                Text("Größter Hebel heute: \(top.title)").font(Theme.font(14, .bold)).foregroundStyle(Theme.textPrimary)
                                Text(tip).font(Theme.font(13)).foregroundStyle(Theme.textSecondary)
                            }
                            Spacer(minLength: 0)
                        }
                        .card()
                    }

                    VStack(spacing: 16) {
                        ForEach(score.components) { c in
                            ComponentRow(c: c, color: score.color,
                                         before: baseline?.components.first { $0.id == c.id })
                        }
                    }
                    .card()

                    VStack(alignment: .leading, spacing: 6) {
                        Text("So wird der Score berechnet").font(Theme.font(15, .bold)).foregroundStyle(Theme.textPrimary)
                        Text("""
                        Acht Bereiche mit zusammen 100 Punkten, basierend auf:
                        • WHO „Healthy Diet“ (2020): Zucker < 10 % und gesättigte Fette < 10 % der Energie, Salz < 5 g, ≥ 400 g Obst & Gemüse
                        • DGE-Referenzwerte: ≥ 30 g Ballaststoffe, ausreichend Protein
                        • GBD 2017 Diet Collaborators (The Lancet, 2019): Salz, zu wenig Vollkorn/Ballaststoffe und Obst sind die größten ernährungsbedingten Risiken
                        • Reynolds et al. (The Lancet, 2019): Ballaststoffe und Herz-Kreislauf-Gesundheit
                        • EU-Referenzmengen (NRV) für 17 Vitamine & Mineralstoffe
                        Der Score ersetzt keine medizinische Beratung.
                        """)
                        .font(Theme.font(12)).foregroundStyle(Theme.textSecondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .card()
                }
                .padding(16)
            }
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle("Health Score")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Fertig") { dismiss() } } }
        }
    }

    private struct ComponentRow: View {
        let c: HealthScore.Component
        let color: Color
        var before: HealthScore.Component? = nil
        @State private var expanded = false

        private var delta: Int? {
            guard let before else { return nil }
            let d = Int(c.points.rounded()) - Int(before.points.rounded())
            return d == 0 ? nil : d
        }

        var body: some View {
            VStack(alignment: .leading, spacing: 6) {
                Button { withAnimation(Motion.quick) { expanded.toggle() } } label: {
                    HStack(spacing: 10) {
                        Image(systemName: c.icon).font(.system(size: 13, weight: .bold)).foregroundStyle(color)
                            .frame(width: 28, height: 28).background(color.opacity(0.15), in: RoundedRectangle(cornerRadius: 8))
                        VStack(alignment: .leading, spacing: 1) {
                            Text(c.title).font(Theme.font(15, .semibold)).foregroundStyle(Theme.textPrimary)
                            Text("\(c.valueText) · \(c.targetText)").font(Theme.font(12)).foregroundStyle(Theme.textSecondary)
                        }
                        Spacer()
                        if let delta { AIDeltaBadge(delta: delta) }
                        Text(c.pointsText).font(Theme.font(15, .bold)).foregroundStyle(c.isPenalty ? Theme.danger : Theme.textPrimary)
                        Image(systemName: "chevron.down").font(.system(size: 10, weight: .bold)).foregroundStyle(Theme.textSecondary)
                            .rotationEffect(.degrees(expanded ? 180 : 0))
                    }
                }
                .buttonStyle(.plain)
                GeometryReader { g in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Theme.track(color))
                        if let before, before.ratio < c.ratio {
                            Capsule().fill(color.opacity(0.4)).frame(width: max(4, g.size.width * c.ratio))
                            Capsule().fill(color).frame(width: max(4, g.size.width * before.ratio))
                        } else {
                            Capsule().fill(color).frame(width: max(4, g.size.width * c.ratio))
                        }
                    }
                }
                .frame(height: 6)
                if let before, delta != nil, expanded {
                    Text("Ohne KI-Ergänzung: \(Int(before.points.rounded()))/\(Int(c.maxPoints)) · \(before.valueText)")
                        .font(Theme.font(12)).foregroundStyle(Theme.textSecondary)
                }
                if expanded {
                    Text(c.explanation).font(Theme.font(12)).foregroundStyle(Theme.textSecondary)
                    if let tip = c.tip {
                        Label(tip, systemImage: "lightbulb.fill").font(Theme.font(12, .medium)).foregroundStyle(Theme.accent)
                    }
                }
            }
        }
    }
}

/// "Eigene Daten 82 → mit KI 87" under the big ring.
private struct AIComparison: View {
    let before: Int
    let after: Int
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 10) {
                stat("\(before)", "Eigene Daten", Theme.textPrimary)
                Image(systemName: "arrow.right").font(.system(size: 12, weight: .bold)).foregroundStyle(Theme.textSecondary)
                stat("\(after)", "Mit KI-Ergänzung", color)
            }
            HStack(spacing: 12) {
                legend(color, "aus deinen Daten")
                legend(color.opacity(0.4), "durch KI ergänzt")
            }
            .font(Theme.font(11, .medium))
            .foregroundStyle(Theme.textSecondary)
            Text("Fehlende Vitamine und Mineralstoffe wurden beim Abschließen des Tages von der KI geschätzt.")
                .font(Theme.font(12)).foregroundStyle(Theme.textSecondary).multilineTextAlignment(.center)
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .background(Theme.cardAlt, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func stat(_ value: String, _ label: String, _ c: Color) -> some View {
        VStack(spacing: 0) {
            Text(value).font(Theme.font(20, .heavy)).foregroundStyle(c)
            Text(label).font(Theme.font(11)).foregroundStyle(Theme.textSecondary)
        }
        .frame(minWidth: 90)
    }

    private func legend(_ c: Color, _ text: String) -> some View {
        HStack(spacing: 4) {
            Capsule().fill(c).frame(width: 14, height: 6)
            Text(text)
        }
    }
}
