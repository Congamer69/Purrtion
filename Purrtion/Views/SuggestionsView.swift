import SwiftUI
import SwiftData

/// "Was passt noch?" – favourites, recipes and own foods ranked by how well they fit the rest of the day.
struct SuggestionsList: View {
    let day: Date
    /// Called after logging (name of the food). Default: pop back.
    var onLogged: ((String) -> Void)? = nil
    @EnvironmentObject private var goals: Goals
    @Environment(\.modelContext) private var ctx
    @Environment(\.dismiss) private var dismiss
    @Query private var entries: [FoodEntry]
    @Query private var saved: [SavedFood]
    @Query private var custom: [CustomFood]
    @State private var filter: Filter = .all
    /// Detail is built only for the tapped row (building one per row made SwiftUI re-render in a loop).
    @State private var selected: MealSuggestions.Suggestion?

    enum Filter: String, CaseIterable, Identifiable {
        case all, favorites, recipes
        var id: String { rawValue }
        var title: String { self == .all ? "Alle" : self == .favorites ? "Favoriten" : "Rezepte & Eigene" }
    }

    init(day: Date, onLogged: ((String) -> Void)? = nil) {
        let d = Calendar.current.startOfDay(for: day)
        self.day = d
        self.onLogged = onLogged
        _entries = Query(filter: #Predicate<FoodEntry> { $0.day == d })
        _saved = Query(filter: #Predicate<SavedFood> { $0.isFavorite })
    }

    private var total: Nutrients { entries.reduce(Nutrients()) { $0 + $1.nutrients } }
    private var target: DayTarget { goals.target(for: day) }
    private var gap: MealSuggestions.Gap {
        MealSuggestions.gap(total: total, target: target, isToday: Calendar.current.isDateInToday(day))
    }

    private var candidates: [MealSuggestions.Candidate] {
        var out: [MealSuggestions.Candidate] = []
        if filter != .recipes {
            for s in saved {
                guard let f = s.food else { continue }
                out.append(.init(food: f, quantity: s.lastQuantity, serving: s.lastServing ?? f.defaultServing, kind: .favorite))
            }
        }
        if filter != .favorites {
            for c in custom {
                let f = c.food
                if c.isRecipe {
                    out.append(.init(food: f, quantity: 1, serving: f.servings.first ?? f.defaultServing, kind: .recipe))
                } else {
                    out.append(.init(food: f, quantity: f.defaultQuantity, serving: f.defaultServing, kind: .own))
                }
            }
        }
        return out
    }

    var body: some View {
        let g = gap
        let list = MealSuggestions.rank(candidates, gap: g)
        List {
            Group {
                header(g)
                Picker("Filter", selection: $filter) {
                    ForEach(Filter.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
            }
            .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)

            if saved.isEmpty && custom.isEmpty {
                empty("Noch keine Favoriten oder Rezepte",
                      "Markiere Lebensmittel mit dem Stern als Favorit oder lege Rezepte an – dann schlägt \(Pet.the) hier vor, was noch passt.")
            } else if list.isEmpty {
                empty(g.kcal <= 0 ? "Tagesziel erreicht" : "Nichts passt mehr ganz",
                      g.kcal <= 0 ? "Für heute ist das Kalorienziel erreicht. Alles Weitere wäre drüber, deshalb schlägt \(Pet.the) nichts mehr vor."
                                  : "Alle Favoriten und Rezepte wären selbst in kleiner Menge zu viel.")
            } else {
                Section {
                    ForEach(list) { s in
                        Button { selected = s } label: {
                            HStack(spacing: 6) {
                                row(s)
                                Image(systemName: "chevron.right").font(.system(size: 12, weight: .bold)).foregroundStyle(Theme.textSecondary)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .listRowBackground(Theme.card)
                        .swipeActions(edge: .leading) {
                            Button { log(s) } label: { Label("Eintragen", systemImage: "plus") }.tint(Theme.accent)
                        }
                    }
                } footer: {
                    Text("Sortiert danach, wie gut Menge, Kalorien und Makros zum Rest des Tages passen\(Calendar.current.isDateInToday(day) ? " – bei noch \(g.mealsLeft) \(g.mealsLeft == 1 ? "Mahlzeit" : "Mahlzeiten") heute" : ""). Nach rechts wischen trägt direkt ein.")
                        .font(Theme.font(12))
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle("Was passt noch?")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(item: $selected) { s in
            FoodDetailView(food: s.food, mode: .add(day: day), preset: (s.quantity, s.serving)) { name in
                selected = nil
                finish(name)
            }
        }
    }

    private func header(_ g: MealSuggestions.Gap) -> some View {
        HStack(spacing: 14) {
            CatMascot(mood: g.kcal <= 0 ? .full : .hungry, pixel: 3.4)
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(abs(g.kcal).kcalString).font(Theme.font(28, .heavy))
                        .foregroundStyle(g.kcal >= 0 ? Theme.textPrimary : Theme.danger)
                    Text(g.kcal >= 0 ? "kcal übrig" : "kcal drüber").font(Theme.font(14, .semibold)).foregroundStyle(Theme.textSecondary)
                }
                HStack(spacing: 10) {
                    chip("P", g.protein, Theme.protein)
                    chip("K", g.carbs, Theme.carbs)
                    chip("F", g.fat, Theme.fat)
                }
            }
            Spacer(minLength: 0)
        }
        .card()
    }

    private func chip(_ label: String, _ value: Double, _ color: Color) -> some View {
        HStack(spacing: 4) {
            Rectangle().fill(color).frame(width: 7, height: 7)
            Text("\(label) \(Int(value.rounded())) g").font(Theme.font(12, .semibold)).foregroundStyle(Theme.textSecondary)
        }
        .lineLimit(1).fixedSize()
    }

    private func row(_ s: MealSuggestions.Suggestion) -> some View {
        HStack(spacing: 12) {
            FoodThumb(food: s.food, size: 40)
            VStack(alignment: .leading, spacing: 3) {
                Text(s.food.displayName).font(Theme.font(15, .semibold)).foregroundStyle(Theme.textPrimary).lineLimit(1)
                Text(s.amountText).font(Theme.font(12)).foregroundStyle(Theme.textSecondary).lineLimit(1)
                HStack(spacing: 6) {
                    Text(s.reason).font(Theme.font(11, .bold)).foregroundStyle(Theme.accentText)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Theme.accentSoft, in: Capsule())
                    Label(s.kind.label, systemImage: s.kind.icon).font(Theme.font(11, .medium)).foregroundStyle(Theme.textSecondary)
                        .labelStyle(.titleAndIcon)
                }
                .lineLimit(1)
            }
            Spacer(minLength: 4)
            VStack(alignment: .trailing, spacing: 1) {
                Text(s.nutrients.kcal.kcalString).font(Theme.font(16, .bold)).foregroundStyle(Theme.textPrimary)
                Text("kcal").font(Theme.font(10, .medium)).foregroundStyle(Theme.textSecondary)
                Text("\(Int(s.nutrients.protein.rounded())) g P").font(Theme.font(10, .semibold)).foregroundStyle(Theme.protein)
            }
        }
        .padding(.vertical, 2)
    }

    private func empty(_ title: String, _ text: String) -> some View {
        VStack(spacing: 10) {
            CatMascot(mood: .sleeping, pixel: 4)
            Text(title).font(Theme.font(17, .bold)).foregroundStyle(Theme.textPrimary)
            Text(text).font(Theme.font(14)).foregroundStyle(Theme.textSecondary).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 30)
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
    }

    private func log(_ s: MealSuggestions.Suggestion) {
        ctx.log(s.food, quantity: s.quantity, serving: s.serving, day: day)
        Haptics.success()
        finish(s.food.displayName)
    }

    private func finish(_ name: String) {
        if let onLogged { onLogged(name) } else { dismiss() }
    }
}

/// Stand-alone sheet version (options menu).
struct SuggestionsSheet: View {
    let day: Date
    var onLogged: ((String) -> Void)? = nil
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            SuggestionsList(day: day) { name in
                dismiss()
                onLogged?(name)
            }
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Fertig") { dismiss() } } }
        }
        .presentationDetents([.large])
    }
}
