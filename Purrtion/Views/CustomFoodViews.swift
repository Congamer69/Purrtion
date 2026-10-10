import SwiftUI
import SwiftData

/// Manage own foods & recipes.
struct MyFoodsView: View {
    @Environment(\.modelContext) private var ctx
    @Query(sort: \CustomFood.createdAt, order: .reverse) private var foods: [CustomFood]
    @State private var editingFood: CustomFood?
    @State private var editingRecipe: CustomFood?
    @State private var newFood = false
    @State private var newRecipe = false

    var body: some View {
        List {
            Section {
                Button { newRecipe = true } label: { Label("Neues Rezept", systemImage: "frying.pan.fill") }
                Button { newFood = true } label: { Label("Neues Lebensmittel", systemImage: "plus.circle.fill") }
            }
            .listRowBackground(Theme.card)

            let recipes = foods.filter(\.isRecipe)
            if !recipes.isEmpty {
                Section("Rezepte") {
                    ForEach(recipes) { r in
                        Button { editingRecipe = r } label: { CustomRow(item: r) }
                    }
                    .onDelete { idx in idx.map { recipes[$0] }.forEach(ctx.delete) }
                }
                .listRowBackground(Theme.card)
            }
            let simple = foods.filter { !$0.isRecipe }
            if !simple.isEmpty {
                Section("Lebensmittel") {
                    ForEach(simple) { f in
                        Button { editingFood = f } label: { CustomRow(item: f) }
                    }
                    .onDelete { idx in idx.map { simple[$0] }.forEach(ctx.delete) }
                }
                .listRowBackground(Theme.card)
            }
            if foods.isEmpty {
                VStack(spacing: 10) {
                    PixelSpriteView(sprite: Sprites.bowl, pixel: 4)
                    Text("Lege eigene Lebensmittel oder ganze Rezepte an – z. B. für Meal Prep.")
                        .font(Theme.font(14)).foregroundStyle(Theme.textSecondary).multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity).padding(.vertical, 24)
                .listRowBackground(Color.clear)
            }
        }
        .scrollContentBackground(.hidden)
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle("Eigene Lebensmittel")
        .sheet(isPresented: $newFood) { CustomFoodEditor(existing: nil) }
        .sheet(item: $editingFood) { CustomFoodEditor(existing: $0) }
        .sheet(isPresented: $newRecipe) { RecipeEditor(existing: nil) }
        .sheet(item: $editingRecipe) { RecipeEditor(existing: $0) }
    }
}

private struct CustomRow: View {
    let item: CustomFood
    var body: some View {
        let food = item.food
        HStack {
            FoodThumb(food: food, size: 40)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.name).font(Theme.font(16, .semibold)).foregroundStyle(Theme.textPrimary)
                Text(item.isRecipe ? "\(item.ingredients.count) Zutaten · \(item.portions) Portionen · \(food.nutrients(grams: food.defaultServing.grams).kcal.kcalString) kcal/Portion"
                                   : "\(food.per100.kcal.kcalString) kcal / 100 \(food.unit)")
                    .font(Theme.font(12)).foregroundStyle(Theme.textSecondary)
            }
        }
    }
}

/// Simple custom food (e.g. something from the bakery around the corner).
struct CustomFoodEditor: View {
    let existing: CustomFood?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var ctx

    @State private var name = ""
    @State private var brand = ""
    @State private var unit = "g"
    @State private var kcal = ""
    @State private var protein = ""
    @State private var carbs = ""
    @State private var fat = ""
    @State private var sugar = ""
    @State private var fiber = ""
    @State private var salt = ""
    @State private var servingName = "1 Portion"
    @State private var servingGrams = ""

    private func num(_ s: String) -> Double? { Double(s.replacingOccurrences(of: ",", with: ".")) }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name", text: $name)
                    TextField("Marke / Herkunft (optional)", text: $brand)
                    Picker("Einheit", selection: $unit) {
                        Text("Gramm").tag("g"); Text("Milliliter").tag("ml")
                    }
                    .pickerStyle(.segmented)
                }
                .listRowBackground(Theme.card)
                Section {
                    field("Kalorien", $kcal, "kcal")
                    field("Protein", $protein, "g")
                    field("Kohlenhydrate", $carbs, "g")
                    field("davon Zucker", $sugar, "g")
                    field("Fett", $fat, "g")
                    field("Ballaststoffe", $fiber, "g")
                    field("Salz", $salt, "g")
                } header: { Text("Nährwerte pro 100 \(unit)") }
                .listRowBackground(Theme.card)
                Section {
                    TextField("Bezeichnung", text: $servingName)
                    field("Menge", $servingGrams, unit)
                } header: { Text("Portion (optional)") }
                .listRowBackground(Theme.card)
            }
            .scrollContentBackground(.hidden)
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle(existing == nil ? "Neues Lebensmittel" : "Bearbeiten")
            .navigationBarTitleDisplayMode(.inline)
            .keyboardDoneButton()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Sichern", action: save).disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || num(kcal) == nil)
                }
            }
            .onAppear(perform: load)
        }
    }

    private func field(_ title: String, _ text: Binding<String>, _ unit: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            TextField("0", text: text).keyboardType(.decimalPad).multilineTextAlignment(.trailing).frame(width: 90)
            Text(unit).foregroundStyle(Theme.textSecondary).frame(width: 34, alignment: .leading)
        }
    }

    private func load() {
        guard let existing, let data = existing.foodData, let f = try? JSONDecoder().decode(FoodItem.self, from: data) else { return }
        name = existing.name; brand = existing.brand ?? ""; unit = f.unit
        func s(_ v: Double?) -> String { v.map { $0.clean } ?? "" }
        kcal = s(f.per100.kcal); protein = s(f.per100.protein); carbs = s(f.per100.carbs); fat = s(f.per100.fat)
        sugar = s(f.per100[.sugar]); fiber = s(f.per100[.fiber]); salt = s(f.per100[.salt])
        if let sv = f.servings.first { servingName = sv.name; servingGrams = sv.grams.clean }
    }

    private func save() {
        var n = Nutrients(kcal: num(kcal) ?? 0, protein: num(protein) ?? 0, carbs: num(carbs) ?? 0, fat: num(fat) ?? 0)
        n[.sugar] = num(sugar); n[.fiber] = num(fiber); n[.salt] = num(salt)
        n.normalize()
        var servings: [ServingOption] = []
        if let g = num(servingGrams), g > 0 { servings.append(ServingOption(name: servingName.isEmpty ? "1 Portion" : servingName, grams: g)) }
        let trimmedBrand = brand.trimmingCharacters(in: .whitespaces)
        let food = FoodItem(id: "custom", name: name, brand: trimmedBrand.isEmpty ? nil : trimmedBrand, source: .custom,
                            per100: n, unit: unit, servings: servings)
        if let existing {
            existing.name = name
            existing.brand = food.brand
            existing.foodData = try? JSONEncoder().encode(food)
        } else {
            ctx.insert(CustomFood(name: name, food: food))
        }
        try? ctx.save()
        Haptics.success()
        dismiss()
    }
}

/// Recipe / meal prep: ingredients from the normal search, split into portions.
struct RecipeEditor: View {
    let existing: CustomFood?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var ctx
    @State private var name = ""
    @State private var portions = 4
    @State private var ingredients: [RecipeIngredient] = []
    @State private var addIngredient = false
    @State private var addManual = false

    private var total: Nutrients { ingredients.reduce(Nutrients()) { $0 + $1.nutrients } }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name, z. B. Chili sin Carne", text: $name)
                    Stepper(value: $portions, in: 1...30) {
                        HStack {
                            Text("Portionen")
                            Spacer()
                            Text("\(portions)").font(Theme.font(18, .bold)).foregroundStyle(Theme.accent)
                        }
                    }
                }
                .listRowBackground(Theme.card)

                Section {
                    ForEach(ingredients) { ing in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(ing.food.displayName).font(Theme.font(15, .semibold))
                                Text("\(ing.grams.clean) \(ing.food.unit)").font(Theme.font(12)).foregroundStyle(Theme.textSecondary)
                            }
                            Spacer()
                            Text("\(ing.nutrients.kcal.kcalString) kcal").font(Theme.font(14, .semibold))
                        }
                    }
                    .onDelete { ingredients.remove(atOffsets: $0) }
                    Button { addIngredient = true } label: { Label("Zutat aus Datenbank", systemImage: "magnifyingglass") }
                    Button { addManual = true } label: { Label("Zutat selbst eintragen", systemImage: "square.and.pencil") }
                } header: { Text("Zutaten") }
                .listRowBackground(Theme.card)

                if !ingredients.isEmpty {
                    Section {
                        summary("Ganzes Rezept", total, grams: ingredients.reduce(0) { $0 + $1.grams })
                        summary("Pro Portion", total.scaled(1 / Double(portions)), grams: ingredients.reduce(0) { $0 + $1.grams } / Double(portions))
                    } header: { Text("Nährwerte") }
                    .listRowBackground(Theme.card)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle(existing == nil ? "Neues Rezept" : "Rezept bearbeiten")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Sichern", action: save).disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || ingredients.isEmpty)
                }
            }
            .sheet(isPresented: $addManual) {
                ManualIngredientSheet { ingredients.append($0) }
            }
            .sheet(isPresented: $addIngredient) {
                IngredientPicker { food, qty, serving in
                    ingredients.append(RecipeIngredient(food: food, quantity: qty, serving: serving))
                }
            }
            .onAppear {
                guard let existing, name.isEmpty else { return }
                name = existing.name; portions = existing.portions; ingredients = existing.ingredients
            }
        }
    }

    private func summary(_ title: String, _ n: Nutrients, grams: Double) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title).font(Theme.font(15, .semibold))
                Spacer()
                Text("\(n.kcal.kcalString) kcal · \(grams.rounded().clean) g").font(Theme.font(15, .bold))
            }
            HStack(spacing: 10) {
                MacroDot(color: Theme.protein, value: n.protein)
                MacroDot(color: Theme.carbs, value: n.carbs)
                MacroDot(color: Theme.fat, value: n.fat)
            }
        }
    }

    private func save() {
        if let existing {
            existing.name = name
            existing.portions = portions
            existing.ingredients = ingredients
        } else {
            ctx.insert(CustomFood(recipeName: name, ingredients: ingredients, portions: portions))
        }
        try? ctx.save()
        Haptics.success()
        dismiss()
    }
}

/// Search + amount picker that returns an ingredient instead of logging it.
struct IngredientPicker: View {
    let onPick: (FoodItem, Double, ServingOption) -> Void
    @Environment(\.dismiss) private var dismiss
    @StateObject private var search = FoodSearch()
    @State private var path: [FoodItem] = []
    @FocusState private var focused: Bool

    var body: some View {
        NavigationStack(path: $path) {
            List {
                ForEach(search.foods + search.products) { food in
                    NavigationLink(value: food) { FoodRow(food: food) }.plainRow()
                }
                if search.isLoading {
                    WalkingCatLoader(pixel: 2.5, width: 200, text: "Suche …").frame(maxWidth: .infinity).plainRow()
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(Theme.background.ignoresSafeArea())
            .safeAreaInset(edge: .top) {
                TextField("Zutat suchen", text: $search.query)
                    .focused($focused)
                    .autocorrectionDisabled()
                    .onChange(of: search.query) { _, _ in search.queryChanged() }
                    .padding(.horizontal, 16).frame(height: 48)
                    .background(Theme.card, in: RoundedRectangle(cornerRadius: 14))
                    .padding(.horizontal, 16).padding(.vertical, 8)
                    .background(Theme.background)
            }
            .navigationTitle("Zutat")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { dismiss() } } }
            .navigationDestination(for: FoodItem.self) { food in
                FoodDetailView(food: food, mode: .pick { f, q, s in
                    onPick(f, q, s)
                    dismiss()
                })
            }
            .onAppear { focused = true }
        }
    }
}

/// Free-form ingredient: name, amount and nutrients for exactly that amount.
struct ManualIngredientSheet: View {
    let onAdd: (RecipeIngredient) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var amount = ""
    @State private var unit = "g"
    @State private var kcal = ""
    @State private var protein = ""
    @State private var carbs = ""
    @State private var fat = ""
    @FocusState private var nameFocused: Bool

    private func num(_ s: String) -> Double? { Double(s.replacingOccurrences(of: ",", with: ".")) }
    private var valid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && (num(amount) ?? 0) > 0 && num(kcal) != nil
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name, z. B. Omas Tomatensoße", text: $name).focused($nameFocused)
                    HStack {
                        Text("Menge")
                        Spacer()
                        TextField("0", text: $amount).keyboardType(.decimalPad).multilineTextAlignment(.trailing).frame(width: 90)
                        Picker("", selection: $unit) { Text("g").tag("g"); Text("ml").tag("ml") }
                            .pickerStyle(.segmented).frame(width: 90)
                    }
                }
                .listRowBackground(Theme.card)
                Section {
                    row("Kalorien", $kcal, "kcal")
                    row("Protein", $protein, "g")
                    row("Kohlenhydrate", $carbs, "g")
                    row("Fett", $fat, "g")
                } header: { Text("Nährwerte für diese Menge") } footer: {
                    Text("Trag die Werte für die gesamte Menge ein – z. B. von der Packung oder grob geschätzt.")
                }
                .listRowBackground(Theme.card)
            }
            .scrollContentBackground(.hidden)
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle("Eigene Zutat")
            .navigationBarTitleDisplayMode(.inline)
            .keyboardDoneButton()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Hinzufügen", action: add).disabled(!valid) }
            }
            .onAppear { nameFocused = true }
        }
        .presentationDetents([.large])
    }

    private func row(_ title: String, _ text: Binding<String>, _ unit: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            TextField("0", text: text).keyboardType(.decimalPad).multilineTextAlignment(.trailing).frame(width: 90)
            Text(unit).foregroundStyle(Theme.textSecondary).frame(width: 34, alignment: .leading)
        }
    }

    private func add() {
        let grams = num(amount) ?? 0
        guard grams > 0 else { return }
        let f = 100 / grams
        var n = Nutrients(kcal: (num(kcal) ?? 0) * f, protein: (num(protein) ?? 0) * f,
                          carbs: (num(carbs) ?? 0) * f, fat: (num(fat) ?? 0) * f)
        n.normalize()
        let food = FoodItem(id: "manual-\(UUID().uuidString)", name: name.trimmingCharacters(in: .whitespaces),
                            source: .custom, per100: n, unit: unit)
        onAdd(RecipeIngredient(food: food, quantity: grams, serving: .base(unit)))
        Haptics.success()
        dismiss()
    }
}
