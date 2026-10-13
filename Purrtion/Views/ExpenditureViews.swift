import SwiftUI

/// "Echter Verbrauch" in the history: measured daily expenditure split into resting, digestion and movement.
struct ExpenditureCard: View {
    let estimate: ExpenditureEstimate

    var body: some View {
        let e = estimate
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Label("Echter Verbrauch", systemImage: "scalemass.fill").font(Theme.font(17, .bold)).foregroundStyle(Theme.textPrimary)
                Spacer()
                Image(systemName: "chevron.right").font(.system(size: 12, weight: .bold)).foregroundStyle(Theme.textSecondary)
            }
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("Ø \(e.total.kcalString)").font(Theme.font(30, .heavy)).foregroundStyle(Theme.textPrimary)
                Text("kcal/Tag").font(Theme.font(14, .semibold)).foregroundStyle(Theme.textSecondary)
                Spacer()
                ConfidencePill(estimate: e)
            }
            ExpenditureBar(estimate: e)
            if !e.isMeasured {
                Text("Noch eine Schätzung – für den gemessenen Wert fehlen: \(e.missing.joined(separator: ", ")).")
                    .font(Theme.font(12)).foregroundStyle(Theme.textSecondary)
            } else if let f = e.trackerFactor, abs(f - 1) > 0.1 {
                Text(f < 1 ? "Deine Aktivität laut Apple Health ist rund \(Int(((1 - f) * 100).rounded())) % höher als das, was dein Gewicht zeigt."
                           : "Du bewegst dich rund \(Int(((f - 1) * 100).rounded())) % mehr, als Apple Health misst (z. B. Alltag ohne Uhr).")
                    .font(Theme.font(12)).foregroundStyle(Theme.textSecondary)
            }
        }
        .card()
    }
}

struct ExpenditureBar: View {
    let estimate: ExpenditureEstimate
    var showLegend = true

    var body: some View {
        let e = estimate
        let parts: [(String, Double, Color)] = [
            ("Grundumsatz", e.basal, Theme.protein),
            ("Verdauung", e.digestion, Theme.carbs),
            ("Bewegung", e.movement, Theme.accent),
        ]
        VStack(alignment: .leading, spacing: 8) {
            GeometryReader { g in
                HStack(spacing: 2) {
                    ForEach(parts, id: \.0) { p in
                        if p.1 > 0 {
                            Rectangle().fill(p.2).frame(width: max(4, (g.size.width - 4) * p.1 / max(e.total, 1)))
                        }
                    }
                }
                .clipShape(Capsule())
            }
            .frame(height: 12)
            if showLegend {
                HStack(spacing: 12) {
                    ForEach(parts, id: \.0) { p in
                        VStack(alignment: .leading, spacing: 1) {
                            HStack(spacing: 4) {
                                RoundedRectangle(cornerRadius: 2).fill(p.2).frame(width: 8, height: 8)
                                Text(p.1.kcalString).font(Theme.font(14, .bold)).foregroundStyle(Theme.textPrimary)
                            }
                            Text(p.0).font(Theme.font(11)).foregroundStyle(Theme.textSecondary)
                        }
                        .lineLimit(1).fixedSize()
                    }
                    Spacer(minLength: 0)
                }
            }
        }
    }
}

struct ConfidencePill: View {
    let estimate: ExpenditureEstimate
    var body: some View {
        let measured = estimate.isMeasured
        Text(measured ? "Genauigkeit \(estimate.confidence.label)" : "Schätzung")
            .font(Theme.font(11, .bold))
            .foregroundStyle(measured ? Theme.fiber : Theme.textSecondary)
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background((measured ? Theme.fiber : Theme.textSecondary).opacity(0.14), in: Capsule())
            .lineLimit(1).fixedSize()
    }
}

struct ExpenditureSheet: View {
    let estimate: ExpenditureEstimate
    @EnvironmentObject private var goals: Goals
    @Environment(\.dismiss) private var dismiss
    @State private var applied = false

    private var suggestedGoal: Double { (max(1200, estimate.total + goals.target.delta) / 10).rounded() * 10 }

    var body: some View {
        let e = estimate
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            Text(e.total.kcalString).font(Theme.font(40, .heavy)).foregroundStyle(Theme.textPrimary)
                            Text("kcal pro Tag").font(Theme.font(15, .semibold)).foregroundStyle(Theme.textSecondary)
                            Spacer()
                            ConfidencePill(estimate: e)
                        }
                        Text(e.isMeasured
                             ? "± \(Int(e.uncertainty.rounded())) kcal · gemessen aus \(e.loggedDays) Tagen Essen und \(e.weighIns) Wiegungen der letzten \(e.windowDays) Tage"
                             : "Vorläufige Schätzung aus \(e.basalFromHealth ? "Apple Health" : "deinem Profil")")
                            .font(Theme.font(13)).foregroundStyle(Theme.textSecondary)
                        ExpenditureBar(estimate: e)
                    }
                    .card()

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Woraus er besteht").font(Theme.font(17, .bold)).foregroundStyle(Theme.textPrimary)
                        row("Grundumsatz", e.basal, Theme.protein,
                            e.basalFromHealth ? "Ruheenergie laut Apple Health" : "Mifflin-St Jeor bei \(weightText(e.trendWeight))")
                        row("Verdauung", e.digestion, Theme.carbs, "≈ 10 % von dem, was du isst")
                        row("Bewegung", e.movement, Theme.accent, "Training, Schritte und Alltag – der Rest")
                        if e.trackedActive > 0 {
                            Divider()
                            row("Aktivität laut Apple Health", e.trackedActive, Theme.textSecondary, "inkl. selbst eingetragener Aktivität")
                            if let f = e.trackerFactor, e.isMeasured {
                                Text("Dein Körper bestätigt \(Int((f * 100).rounded())) % davon.")
                                    .font(Theme.font(13, .semibold)).foregroundStyle(f < 0.9 ? Theme.carbs : Theme.fiber)
                            }
                        }
                    }
                    .card()

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Grundlage").font(Theme.font(17, .bold)).foregroundStyle(Theme.textPrimary)
                        fact("Ø gegessen", e.intake > 0 ? "\(e.intake.kcalString) kcal" : "–")
                        fact("Gewichtstrend", e.weightPerWeek.map { (($0 >= 0 ? "+" : "−") + abs($0).formatted(.number.precision(.fractionLength(2))) + " kg/Woche") } ?? "–")
                        if let t = e.trendWeight { fact("Trendgewicht", weightText(t)) }
                        fact("Energie je kg", "\(Int(e.energyDensity.rounded()).formatted()) kcal")
                        if let m = e.measured {
                            fact("Aus der Energiebilanz", "\(m.kcalString) kcal")
                            fact("Vorab-Schätzung", "\(e.prior.kcalString) kcal")
                            fact("Gewicht der Messung", "\(Int((e.measuredWeight * 100).rounded())) %")
                        }
                        if !e.missing.isEmpty {
                            Text("Noch nötig: \(e.missing.joined(separator: ", ")).")
                                .font(Theme.font(13, .semibold)).foregroundStyle(Theme.accent)
                        }
                    }
                    .card()

                    VStack(alignment: .leading, spacing: 10) {
                        Text("So wird gerechnet").font(Theme.font(17, .bold)).foregroundStyle(Theme.textPrimary)
                        Text("Verbrauch = was du isst − was dein Körper speichert. Der Gewichtstrend kommt aus einer robusten Regression über alle Wiegungen – einzelne Ausreißer durch Wasser oder Salz zählen kaum. Wie viele kcal ein Kilo ausmacht, hängt vom Körperfett ab (Forbes/Hall-Modell, ca. 6.000–8.000 kcal). Tage ohne Einträge zählen mit deinem Durchschnitt, unvollständige Tage werden ignoriert. Solange wenig Daten da sind, stützt sich der Wert auf Apple Health bzw. dein Profil; mit jeder Woche zählt die Messung mehr.")
                            .font(Theme.font(13)).foregroundStyle(Theme.textSecondary)
                        Text("Am genauesten wird es, wenn du dich mehrmals pro Woche morgens wiegst und an den meisten Tagen alles einträgst.")
                            .font(Theme.font(13, .semibold)).foregroundStyle(Theme.textSecondary)
                    }
                    .card()

                    if e.isMeasured, abs(suggestedGoal - goals.kcal) >= 50 {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Passendes Ziel für „\(goals.target.label)“: \(suggestedGoal.kcalString) kcal")
                                .font(Theme.font(15, .bold)).foregroundStyle(Theme.textPrimary)
                            Text("Aktuell \(goals.kcal.kcalString) kcal. Gilt ab heute, vergangene Tage behalten ihr Ziel.")
                                .font(Theme.font(13)).foregroundStyle(Theme.textSecondary)
                            Button {
                                Haptics.success()
                                goals.kcal = suggestedGoal
                                goals.syncMacros()
                                applied = true
                            } label: {
                                Label(applied ? "Übernommen" : "Ziel übernehmen", systemImage: applied ? "checkmark" : "target")
                            }
                            .buttonStyle(PillButtonStyle())
                            .disabled(applied)
                        }
                        .card()
                    }
                }
                .padding(16)
            }
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle("Echter Verbrauch")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Fertig") { dismiss() } } }
        }
        .presentationDetents([.large])
    }

    private func weightText(_ kg: Double?) -> String {
        guard let kg else { return "deinem Gewicht" }
        return kg.formatted(.number.precision(.fractionLength(1))) + " kg"
    }

    private func row(_ title: String, _ value: Double, _ color: Color, _ note: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            RoundedRectangle(cornerRadius: 2).fill(color).frame(width: 10, height: 10)
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(Theme.font(15, .semibold)).foregroundStyle(Theme.textPrimary)
                Text(note).font(Theme.font(12)).foregroundStyle(Theme.textSecondary)
            }
            Spacer()
            Text("\(value.kcalString) kcal").font(Theme.font(15, .bold)).foregroundStyle(Theme.textPrimary)
        }
    }

    private func fact(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title).font(Theme.font(14)).foregroundStyle(Theme.textSecondary)
            Spacer()
            Text(value).font(Theme.font(14, .semibold)).foregroundStyle(Theme.textPrimary)
        }
    }
}
