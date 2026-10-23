import SwiftUI

/// The cards of the Verlauf tab. Order and visibility are the user's choice.
enum StatsCardID: String, CaseIterable, Codable, Identifiable {
    case kcal, overview, expenditure, goal, score, weight, activity, macro, weekday, topFoods, micro
    var id: String { rawValue }

    var title: String {
        switch self {
        case .kcal: "Kalorien"
        case .overview: "Serie & Zieltreue"
        case .expenditure: "Echter Verbrauch"
        case .goal: "Ziel eingehalten"
        case .score: "Health Score"
        case .weight: "Gewicht"
        case .activity: "Aktivität"
        case .macro: "Makros"
        case .weekday: "Wochentage"
        case .topFoods: "Häufigste Lebensmittel"
        case .micro: "Mikronährstoffe"
        }
    }

    var icon: String {
        switch self {
        case .kcal: "flame.fill"
        case .overview: "pawprint.fill"
        case .expenditure: "bolt.heart.fill"
        case .goal: "target"
        case .score: "heart.text.square.fill"
        case .weight: "scalemass.fill"
        case .activity: "figure.walk"
        case .macro: "chart.pie.fill"
        case .weekday: "calendar"
        case .topFoods: "fork.knife"
        case .micro: "pills.fill"
        }
    }

    /// Shown out of the box; the rest is one tap away in "Anpassen".
    var defaultVisible: Bool {
        switch self {
        case .kcal, .overview, .expenditure, .goal, .score, .weight: true
        default: false
        }
    }
}

struct StatsLayout: Codable, Equatable {
    var order: [StatsCardID] = StatsCardID.allCases
    var hidden: Set<StatsCardID> = Set(StatsCardID.allCases.filter { !$0.defaultVisible })

    static let storageKey = "stats.layout"

    init() {}

    init(json: String) {
        if let data = json.data(using: .utf8), let decoded = try? JSONDecoder().decode(StatsLayout.self, from: data) {
            self = decoded
            // Cards added in later versions show up at the end, hidden or not by their default.
            for c in StatsCardID.allCases where !order.contains(c) {
                order.append(c)
                if !c.defaultVisible { hidden.insert(c) }
            }
        }
    }

    var json: String { (try? JSONEncoder().encode(self)).flatMap { String(data: $0, encoding: .utf8) } ?? "" }
    var visible: [StatsCardID] { order.filter { !hidden.contains($0) } }
}

/// Verlauf → "Anpassen": drag to reorder, tap the eye to show or hide.
struct StatsLayoutEditor: View {
    @Binding var layout: StatsLayout
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(layout.order) { card in
                        let shown = !layout.hidden.contains(card)
                        HStack(spacing: 12) {
                            Image(systemName: card.icon).font(.system(size: 14, weight: .bold))
                                .foregroundStyle(shown ? Theme.accent : Theme.textSecondary)
                                .frame(width: 32, height: 32)
                                .background(shown ? Theme.accentSoft : Theme.cardAlt, in: RoundedRectangle(cornerRadius: 9))
                            Text(card.title).font(Theme.font(15, .semibold))
                                .foregroundStyle(shown ? Theme.textPrimary : Theme.textSecondary)
                            Spacer()
                            Button {
                                Haptics.tap()
                                withAnimation(Motion.quick) {
                                    if shown { layout.hidden.insert(card) } else { layout.hidden.remove(card) }
                                }
                            } label: {
                                Image(systemName: shown ? "eye.fill" : "eye.slash")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(shown ? Theme.accent : Theme.textSecondary)
                                    .frame(width: 36, height: 36)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(shown ? "\(card.title) ausblenden" : "\(card.title) einblenden")
                        }
                    }
                    .onMove { layout.order.move(fromOffsets: $0, toOffset: $1) }
                } header: { Text("Karten") } footer: {
                    Text("Ziehe an den Griffen, um die Reihenfolge zu ändern. Mit dem Auge blendest du Karten ein oder aus. Manche Karten erscheinen nur, wenn es Daten dafür gibt.")
                }
                .listRowBackground(Theme.card)

                Section {
                    Button("Auf Standard zurücksetzen") { withAnimation(Motion.quick) { layout = StatsLayout() } }
                }
                .listRowBackground(Theme.card)
            }
            .environment(\.editMode, .constant(.active))
            .scrollContentBackground(.hidden)
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle("Verlauf anpassen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Fertig") { dismiss() } } }
        }
    }
}
