import SwiftUI
import SwiftData

struct FoodDetailView: View {
    enum Mode {
        case add(day: Date)
        case edit(FoodEntry)
        /// One ingredient of a logged recipe / AI meal.
        case ingredient(FoodEntry, UUID)
        /// Returns the chosen amount instead of logging (recipe ingredients).
        case pick((FoodItem, Double, ServingOption) -> Void)
    }

    @State var food: FoodItem
    let mode: Mode
    var onDone: ((String) -> Void)? = nil
    /// Multi scan: logs the food and goes back to the scanner (gets the name of the logged food).
    var onAddAnother: ((String) -> Void)? = nil

    @Environment(\.modelContext) private var ctx
    @Environment(\.dismiss) private var dismiss
    @Query private var saved: [SavedFood]
    @State private var quantity: Double = 100
    @State private var serving: ServingOption = .base("g")
    @State private var quantityText = "100"
    @FocusState private var amountFocused: Bool

    init(food: FoodItem, mode: Mode, preset: (quantity: Double, serving: ServingOption)? = nil, onDone: ((String) -> Void)? = nil,
         onAddAnother: ((String) -> Void)? = nil) {
        _food = State(initialValue: food)
        self.mode = mode
        self.onDone = onDone
        self.onAddAnother = onAddAnother
        let key = food.id
        _saved = Query(filter: #Predicate<SavedFood> { $0.key == key })
        if case .edit(let entry) = mode {
            let s = food.allServings.first { $0.name == entry.servingName } ?? ServingOption(name: entry.servingName, grams: entry.servingGrams)
            _serving = State(initialValue: s)
            _quantity = State(initialValue: entry.quantity)
            _quantityText = State(initialValue: entry.quantity.clean)
        } else if case .ingredient(let entry, let id) = mode, let ing = entry.ingredients.first(where: { $0.id == id }) {
            _serving = State(initialValue: food.allServings.first { $0.name == ing.serving.name } ?? ing.serving)
            _quantity = State(initialValue: ing.quantity)
            _quantityText = State(initialValue: ing.quantity.clean)
        } else if let preset {
            _serving = State(initialValue: food.allServings.first { $0.name == preset.serving.name } ?? preset.serving)
            _quantity = State(initialValue: preset.quantity)
            _quantityText = State(initialValue: preset.quantity.clean)
        } else {
            _serving = State(initialValue: food.defaultServing)
            _quantity = State(initialValue: food.defaultQuantity)
            _quantityText = State(initialValue: food.defaultQuantity.clean)
        }
    }

    private var grams: Double { quantity * serving.grams }
    private var n: Nutrients { food.nutrients(grams: grams) }
    private var isFavorite: Bool { saved.first?.isFavorite ?? false }

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                header
                amountCard
                nutritionCard
                NutrientList(nutrients: n, compact: true)
                    .card()
                Text("Quelle: \(food.source.label)\(food.barcode.map { " · EAN \($0)" } ?? "")\(food.source == .bls ? " · Max Rubner-Institut, CC BY 4.0" : "")\(food.microsEstimated == true ? " · fehlende Mikronährstoffe KI-geschätzt" : "")")
                    .font(Theme.font(12)).foregroundStyle(Theme.textSecondary)
                    .padding(.bottom, 90)
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Theme.background.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { toggleFavorite() } label: {
                    Image(systemName: isFavorite ? "star.fill" : "star").foregroundStyle(isFavorite ? Theme.carbs : Theme.textSecondary)
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            // While typing: a compact "Fertig" bar right above the keyboard (content is inset, nothing overlaps).
            if amountFocused {
                HStack(spacing: 10) {
                    Button { amountFocused = false } label: {
                        Text("Fertig")
                            .font(Theme.font(15, .semibold))
                            .foregroundStyle(Theme.textPrimary)
                            .padding(.horizontal, 18).frame(height: 50)
                            .background(Theme.cardAlt, in: Capsule())
                    }
                    Spacer(minLength: 0)
                    Button {
                        amountFocused = false
                        commit()
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: quickIcon).font(.system(size: 15, weight: .bold))
                            VStack(alignment: .leading, spacing: 0) {
                                Text(quickTitle).font(Theme.font(15, .bold))
                                Text("\(grams.clean) \(food.unit) · \(n.kcal.kcalString) kcal")
                                    .font(Theme.font(11, .semibold)).opacity(0.85)
                            }
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 18).frame(height: 50)
                        .background(Theme.accent, in: Capsule())
                    }
                    .disabled(grams <= 0)
                }
                .buttonStyle(SquishButtonStyle())
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Theme.background)
            } else {
                HStack(spacing: 10) {
                    if onAddAnother != nil, case .add = mode {
                        Button { commit(scanAnother: true) } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "barcode.viewfinder")
                                Text("Weiteres scannen").lineLimit(1).minimumScaleFactor(0.7)
                            }
                        }
                        .buttonStyle(PillButtonStyle(color: Theme.accentText, filled: false))
                    }
                    Button { commit() } label: {
                        HStack {
                            Image(systemName: "pawprint.fill")
                            Text(onAddAnother != nil ? "Hinzufügen" : buttonTitle).lineLimit(1).minimumScaleFactor(0.7)
                        }
                    }
                    .buttonStyle(PillButtonStyle())
                }
                .disabled(grams <= 0)
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 8)
                .background(Theme.background)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(Motion.quick, value: amountFocused)
    }

    private var quickTitle: String {
        switch mode {
        case .add: "Direkt eintragen"
        case .edit, .ingredient: "Speichern"
        case .pick: "Hinzufügen"
        }
    }

    private var quickIcon: String {
        switch mode {
        case .edit, .ingredient: "checkmark"
        default: "pawprint.fill"
        }
    }

    private var buttonTitle: String {
        switch mode {
        case .add: "Eintragen · \(n.kcal.kcalString) kcal"
        case .edit, .ingredient: "Speichern"
        case .pick: "Als Zutat hinzufügen · \(n.kcal.kcalString) kcal"
        }
    }

    private var header: some View {
        HStack(spacing: 14) {
            FoodThumb(food: food, size: 64)
            VStack(alignment: .leading, spacing: 4) {
                Text(food.displayName).font(Theme.font(22, .bold)).foregroundStyle(Theme.textPrimary).lineLimit(3)
                if let b = food.brand ?? food.origin, !b.isEmpty {
                    Text(b).font(Theme.font(15)).foregroundStyle(Theme.textSecondary)
                }
                if let warning = food.warning {
                    Label(warning, systemImage: "exclamationmark.triangle.fill")
                        .font(Theme.font(13, .semibold)).foregroundStyle(Theme.carbs)
                }
            }
            Spacer(minLength: 0)
        }
    }

    private var amountCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                stepButton("minus") { setQuantity(quantity - step) }
                TextField("Menge", text: $quantityText)
                    .keyboardType(.decimalPad)
                    .focused($amountFocused)
                    .multilineTextAlignment(.center)
                    .font(Theme.font(30, .heavy))
                    .foregroundStyle(Theme.textPrimary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(Theme.cardAlt, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .onChange(of: quantityText) { _, t in
                        if let v = Double(t.replacingOccurrences(of: ",", with: ".")) { quantity = v }
                    }
                stepButton("plus") { setQuantity(quantity + step) }
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(food.allServings) { s in
                        let selected = s == serving
                        Button {
                            Haptics.tap()
                            withAnimation(Motion.quick) {
                                serving = s
                                setQuantity(s.grams == 1 ? (food.servings.first?.grams ?? 100).rounded() : 1)
                            }
                        } label: {
                            VStack(spacing: 1) {
                                Text(s.name).font(Theme.font(14, .semibold)).lineLimit(1)
                                if s.grams != 1 {
                                    Text("\(s.grams.clean) \(food.unit)").font(Theme.font(11)).opacity(0.75)
                                }
                            }
                            .padding(.horizontal, 14).padding(.vertical, 9)
                            .foregroundStyle(selected ? .white : Theme.textPrimary)
                            .background(selected ? Theme.accent : Theme.cardAlt, in: Capsule())
                        }
                        .buttonStyle(SquishButtonStyle())
                    }
                }
            }

            if serving.grams != 1 {
                HStack(spacing: 8) {
                    ForEach([0.5, 1, 1.5, 2, 3], id: \.self) { m in
                        Button { Haptics.tap(); setQuantity(m) } label: {
                            Text(m == 0.5 ? "½" : m == 1.5 ? "1½" : m.clean)
                                .font(Theme.font(15, .bold))
                                .frame(maxWidth: .infinity).frame(height: 36)
                                .foregroundStyle(quantity == m ? Theme.accent : Theme.textSecondary)
                                .background(quantity == m ? Theme.accentSoft : Color.clear, in: RoundedRectangle(cornerRadius: 10))
                        }
                        .buttonStyle(SquishButtonStyle())
                    }
                }
                Text("= \(grams.clean) \(food.unit)").font(Theme.font(14, .medium)).foregroundStyle(Theme.textSecondary)
            }
        }
        .card()
    }

    private var step: Double { serving.grams == 1 ? (food.unit == "ml" ? 50 : 10) : 0.5 }

    private func stepButton(_ icon: String, action: @escaping () -> Void) -> some View {
        Button { Haptics.tap(); action() } label: {
            Image(systemName: icon).font(.system(size: 18, weight: .bold)).foregroundStyle(Theme.accentText)
                .frame(width: 52, height: 56)
                .background(Theme.accentSoft, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(SquishButtonStyle())
    }

    private func setQuantity(_ v: Double) {
        quantity = max(0, (v * 100).rounded() / 100)
        quantityText = quantity.clean
    }

    private var nutritionCard: some View {
        HStack(spacing: 0) {
            bigStat(n.kcal.kcalString, "kcal", Theme.accent)
            bigStat("\(n.protein.clean) g", "Protein", Theme.protein)
            bigStat("\(n.carbs.clean) g", "Kohlenh.", Theme.carbs)
            bigStat("\(n.fat.clean) g", "Fett", Theme.fat)
        }
        .card(padding: 14)
    }

    private func bigStat(_ value: String, _ label: String, _ color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value).font(Theme.font(18, .heavy)).foregroundStyle(Theme.textPrimary)
                .contentTransition(.numericText()).animation(Motion.quick, value: value)
            HStack(spacing: 4) {
                Rectangle().fill(color).frame(width: 6, height: 6)
                Text(label).font(Theme.font(12, .medium)).foregroundStyle(Theme.textSecondary)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func commit(scanAnother: Bool = false) {
        switch mode {
        case .add(let day):
            ctx.log(food, quantity: quantity, serving: serving, day: day)
        case .edit(let entry):
            entry.foodData = try? JSONEncoder().encode(food)
            entry.update(quantity: quantity, serving: serving, food: food)
            try? ctx.save()
        case .ingredient(let entry, let id):
            entry.replaceIngredient(id, food: food, quantity: quantity, serving: serving)
            try? ctx.save()
        case .pick(let onPick):
            onPick(food, quantity, serving)
            return
        }
        Haptics.success()
        if scanAnother, let onAddAnother { onAddAnother(food.displayName); return }
        if let onDone { onDone(food.displayName) } else { dismiss() }
    }

    private func toggleFavorite() {
        Haptics.tap()
        if let s = saved.first {
            s.isFavorite.toggle()
        } else {
            let s = SavedFood(food: food)
            s.isFavorite = true
            s.lastQuantity = quantity
            s.lastServingName = serving.name
            ctx.insert(s)
        }
        try? ctx.save()
    }
}

struct EditEntryView: View {
    let entry: FoodEntry
    var body: some View {
        NavigationStack {
            if let food = entry.food {
                FoodDetailView(food: food, mode: .edit(entry))
                    .toolbar { ToolbarItem(placement: .cancellationAction) { CloseButton() } }
            } else {
                Text("Eintrag kann nicht bearbeitet werden.")
            }
        }
    }
}

/// Ingredients of a recipe or AI-scanned meal – behaves exactly like the "Gegessen" list:
/// tap to edit (same detail screen), swipe left to delete, swipe right for "Nochmal".
struct MealEntryDetailView: View {
    let entry: FoodEntry
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var ctx
    @State private var editing: UUID?
    @State private var addFromDatabase = false
    @State private var addManual = false

    var body: some View {
        let ingredients = entry.ingredients
        NavigationStack {
            List {
                MealSummaryCard(entry: entry)
                    .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)

                Section {
                    ForEach(ingredients) { ing in
                        Button { editing = ing.id } label: { IngredientRow(ingredient: ing) }
                            .buttonStyle(SquishButtonStyle())
                            .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                            .ingredientActions(entry: entry, id: ing.id, onLastRemoved: removeEntry)
                    }
                } header: {
                    HStack {
                        Text("Zutaten").font(Theme.font(18, .bold)).foregroundStyle(Theme.textPrimary)
                        Text("\(ingredients.count)").font(Theme.font(12, .bold)).foregroundStyle(Theme.textSecondary)
                            .padding(.horizontal, 7).padding(.vertical, 2).background(Theme.cardAlt, in: Capsule())
                        Spacer()
                        Menu {
                            Button { addFromDatabase = true } label: { Label("Zutat aus Datenbank", systemImage: "magnifyingglass") }
                            Button { addManual = true } label: { Label("Zutat selbst eintragen", systemImage: "square.and.pencil") }
                        } label: {
                            Image(systemName: "plus")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundStyle(Theme.accentText)
                                .frame(width: 34, height: 34)
                                .background(Theme.accentSoft, in: Circle())
                        }
                    }
                    .textCase(nil)
                    .padding(.top, 8)
                }
                .listSectionSeparator(.hidden)
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .animation(Motion.smooth, value: ingredients.map(\.id))
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle("Mahlzeit bearbeiten")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Fertig") { dismiss() } }
            }
            .navigationDestination(item: $editing) { id in
                if let ing = entry.ingredients.first(where: { $0.id == id }) {
                    FoodDetailView(food: ing.food, mode: .ingredient(entry, id))
                }
            }
            .sheet(isPresented: $addFromDatabase) {
                IngredientPicker { food, qty, serving in
                    entry.addIngredient(RecipeIngredient(food: food, quantity: qty, serving: serving))
                    try? ctx.save()
                }
            }
            .sheet(isPresented: $addManual) {
                ManualIngredientSheet { ing in
                    entry.addIngredient(ing)
                    try? ctx.save()
                }
            }
        }
    }

    private func removeEntry() {
        ctx.deleteTracked([entry])
        dismiss()
    }
}

/// Header of the meal editor: name, total kcal and macros.
private struct MealSummaryCard: View {
    let entry: FoodEntry

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Text(entry.name).font(Theme.font(20, .bold)).foregroundStyle(Theme.textPrimary).lineLimit(2)
                    if entry.food?.source == .ai { AIBadge() }
                }
                Text("\(entry.ingredients.count) Zutaten · \(entry.grams.clean) g")
                    .font(Theme.font(13)).foregroundStyle(Theme.textSecondary)
                HStack(spacing: 10) {
                    MacroDot(color: Theme.protein, value: entry.protein)
                    MacroDot(color: Theme.carbs, value: entry.carbs)
                    MacroDot(color: Theme.fat, value: entry.fat)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 0) {
                Text(entry.kcal.kcalString).font(Theme.font(26, .heavy)).foregroundStyle(Theme.textPrimary)
                    .contentTransition(.numericText(value: entry.kcal))
                Text("kcal").font(Theme.font(12, .medium)).foregroundStyle(Theme.textSecondary)
            }
        }
        .card(padding: 16)
        .animation(Motion.quick, value: entry.kcal)
    }
}

/// Edit sheet for a single ingredient (opened from the expanded meal on Today).
struct IngredientEditView: View {
    let entry: FoodEntry
    let id: UUID

    var body: some View {
        NavigationStack {
            if let ing = entry.ingredients.first(where: { $0.id == id }) {
                FoodDetailView(food: ing.food, mode: .ingredient(entry, id))
                    .toolbar { ToolbarItem(placement: .cancellationAction) { CloseButton() } }
            } else {
                Text("Zutat nicht gefunden.")
            }
        }
    }
}

extension View {
    /// The same swipe actions and context menu as a normal entry, applied to one meal ingredient.
    func ingredientActions(entry: FoodEntry, id: UUID, onLastRemoved: @escaping () -> Void) -> some View {
        modifier(IngredientActions(entry: entry, id: id, onLastRemoved: onLastRemoved))
    }
}

private struct IngredientActions: ViewModifier {
    let entry: FoodEntry
    let id: UUID
    let onLastRemoved: () -> Void
    @Environment(\.modelContext) private var ctx

    func body(content: Content) -> some View {
        content
            .swipeActions(edge: .trailing) {
                Button(role: .destructive) { delete() } label: { Label("Löschen", systemImage: "trash") }
            }
            .swipeActions(edge: .leading) {
                Button { duplicate() } label: { Label("Nochmal", systemImage: "plus.square.on.square") }
                    .tint(Theme.accent)
            }
            .contextMenu {
                Button { duplicate() } label: { Label("Nochmal hinzufügen", systemImage: "plus.square.on.square") }
                Button(role: .destructive) { delete() } label: { Label("Löschen", systemImage: "trash") }
            }
    }

    private func duplicate() {
        Haptics.tap()
        entry.duplicateIngredient(id)
        try? ctx.save()
    }

    private func delete() {
        Haptics.warning()
        UndoStore.shared.recordIngredientRemoval(of: entry)
        if entry.removeIngredient(id) { try? ctx.save() } else { UndoStore.shared.clear(); onLastRemoved() }
    }
}

struct CloseButton: View {
    @Environment(\.dismiss) private var dismiss
    var body: some View { Button("Abbrechen") { dismiss() } }
}

/// Lists all micronutrients grouped, with % of daily value.
struct NutrientList: View {
    let nutrients: Nutrients
    var compact = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            ForEach(NutrientKey.Group.allCases, id: \.self) { group in
                let keys = NutrientKey.allCases.filter { $0.group == group && nutrients[$0] != nil }
                if !keys.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(group.rawValue).font(Theme.font(15, .bold)).foregroundStyle(Theme.textPrimary)
                        ForEach(keys) { key in NutrientRow(key: key, value: nutrients[key] ?? 0) }
                    }
                }
            }
            if nutrients.extra.isEmpty {
                Text("Für dieses Lebensmittel sind keine weiteren Nährstoffe hinterlegt.")
                    .font(Theme.font(14)).foregroundStyle(Theme.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct NutrientRow: View {
    let key: NutrientKey
    let value: Double

    var body: some View {
        let pct = key.dailyValue.map { value / $0 }
        VStack(spacing: 4) {
            HStack {
                Text(key.name).font(Theme.font(14)).foregroundStyle(Theme.textPrimary)
                Spacer()
                Text("\(format(value)) \(key.unit)").font(Theme.font(14, .semibold)).foregroundStyle(Theme.textPrimary)
                if let pct {
                    Text("\(Int((pct * 100).rounded())) %")
                        .font(Theme.font(12, .semibold))
                        .foregroundStyle(Theme.textSecondary)
                        .frame(width: 46, alignment: .trailing)
                }
            }
            if let pct {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Theme.cardAlt)
                        Capsule().fill(barColor(pct)).frame(width: geo.size.width * min(pct, 1))
                    }
                }
                .frame(height: 4)
            }
        }
    }

    private func barColor(_ pct: Double) -> Color {
        if key.isLimit { return pct > 1 ? Theme.danger : Theme.carbs }
        return pct >= 1 ? Theme.fiber : Theme.fiber.opacity(0.7)
    }

    private func format(_ v: Double) -> String {
        v >= 10 ? v.rounded().clean : v.formatted(.number.precision(.fractionLength(0...2)))
    }
}

struct NutrientsDayView: View {
    let total: Nutrients
    let title: String

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                HStack(spacing: 0) {
                    stat(total.kcal.kcalString, "kcal")
                    stat("\(total.protein.rounded().clean) g", "Protein")
                    stat("\(total.carbs.rounded().clean) g", "Kohlenh.")
                    stat("\(total.fat.rounded().clean) g", "Fett")
                }
                .card(padding: 14)
                NutrientList(nutrients: total).card()
                Text("Prozentwerte beziehen sich auf die Referenzmengen der EU (NRV). Lebensmittel aus dem BLS liefern fast alle Mikronährstoffe, Markenprodukte oft nur die Pflichtangaben – die Summen sind daher Mindestwerte.")
                    .font(Theme.font(12)).foregroundStyle(Theme.textSecondary)
                    .padding(.horizontal, 6)
            }
            .padding(16)
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle(title)
    }

    private func stat(_ v: String, _ l: String) -> some View {
        VStack(spacing: 2) {
            Text(v).font(Theme.font(17, .heavy)).foregroundStyle(Theme.textPrimary)
            Text(l).font(Theme.font(12)).foregroundStyle(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }
}
