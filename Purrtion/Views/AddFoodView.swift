import SwiftUI
import SwiftData

struct AddFoodView: View {
    let day: Date
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var ctx
    @StateObject private var search = FoodSearch()
    @FocusState private var focused: Bool
    @Query(sort: \SavedFood.lastUsed, order: .reverse) private var saved: [SavedFood]
    @Query(sort: \CustomFood.name) private var customFoods: [CustomFood]
    @State private var newRecipe = false
    @AppStorage("search.tab") private var tab: ListTab = .recent
    @Namespace private var tabNS
    @State private var newFood = false
    @State private var path: [FoodItem] = []
    @State private var showBarcode = false
    @State private var addedName: String?
    /// The last logged drink went to the night before (logged after midnight).
    @State private var addedToNight = false
    @State private var aiQuery: AIQuery?
    @State private var showSuggestions = false
    @AppStorage(SearchSource.ai.storageKey) private var aiEnabled = true

    struct AIQuery: Identifiable { let text: String; var id: String { text } }

    private var trimmedQuery: String { search.query.trimmingCharacters(in: .whitespacesAndNewlines) }
    /// Natural sentences ("2 Eier und ein Toast") go to the AI first, single words below the database hits.
    private var looksLikeSentence: Bool {
        let words = trimmedQuery.split(separator: " ")
        return words.count >= 3 || trimmedQuery.contains(where: \.isNumber) || trimmedQuery.contains(",")
            || words.contains { ["und", "mit", "dazu", "plus"].contains($0.lowercased()) }
    }

    private var favorites: [SavedFood] { saved.filter(\.isFavorite) }
    private var recents: [SavedFood] { Array(saved.prefix(25)) }

    var body: some View {
        NavigationStack(path: $path) {
            List {
                if search.query.trimmingCharacters(in: .whitespaces).isEmpty {
                    emptyQueryContent
                } else {
                    resultsContent
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .scrollDismissesKeyboard(.immediately)
            .background(Theme.background.ignoresSafeArea())
            .safeAreaInset(edge: .top, spacing: 0) { searchBar }
            .overlay(alignment: .top) { addedToast }
            .navigationTitle("Essen hinzufügen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Fertig") { dismiss() } }
                ToolbarItem(placement: .primaryAction) {
                    Button { showBarcode = true } label: { Image(systemName: "barcode.viewfinder") }
                }
            }
            .navigationDestination(for: FoodItem.self) { food in
                FoodDetailView(food: food, mode: .add(day: day)) { name in
                    path.removeAll()
                    flashAdded(name)
                }
            }
            .sheet(isPresented: $showSuggestions) {
                SuggestionsSheet(day: day) { name in flashAdded(name) }
            }
            .sheet(isPresented: $showBarcode) {
                BarcodeFlowView(day: day)
            }
            .sheet(item: $aiQuery) { q in
                MealPhotoView(day: day, textQuery: q.text) { name in
                    aiQuery = nil
                    flashAdded(name)
                }
            }
            .sheet(isPresented: $newRecipe) { RecipeEditor(existing: nil) }
            .sheet(isPresented: $newFood) { CustomFoodEditor(existing: nil) }
        }
        .onAppear {
            focused = true
            #if DEBUG
            if let q = UserDefaults.standard.string(forKey: "debugSearch"), search.query.isEmpty {
                search.query = q
                search.queryChanged()
            }
            #endif
        }
    }

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass").foregroundStyle(Theme.textSecondary)
            TextField(aiEnabled ? "z. B. Skyr oder „2 Eier und ein Toast“" : "z. B. Apfel, Skyr, Pizza …", text: $search.query)
                .font(Theme.font(17))
                .focused($focused)
                .submitLabel(.search)
                .autocorrectionDisabled()
                .onSubmit {
                    // Enter on a sentence or without hits → let the AI estimate it.
                    if aiEnabled, trimmedQuery.count >= 2, looksLikeSentence || search.isEmpty { aiQuery = AIQuery(text: trimmedQuery) }
                }
                .onChange(of: search.query) { _, _ in search.queryChanged() }
            if search.isLoading {
                ProgressView().controlSize(.small)
            } else if !search.query.isEmpty {
                Button { search.query = "" } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(Theme.textSecondary) }
            }
        }
        .padding(.horizontal, 16)
        .frame(height: 50)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Theme.background)
    }

    private var createButtons: some View {
        HStack(spacing: 10) {
            Button { newRecipe = true } label: { Label("Rezept", systemImage: "frying.pan.fill") }
            Button { newFood = true } label: { Label("Eigenes", systemImage: "plus.circle.fill") }
        }
        .buttonStyle(PillButtonStyle(filled: false))
        .plainRow()
        .listRowSeparator(.hidden)
    }

    private var matchingCustom: [CustomFood] {
        let q = BLSDatabase.fold(search.query.trimmingCharacters(in: .whitespaces))
        guard !q.isEmpty else { return customFoods }
        return customFoods.filter { BLSDatabase.fold($0.name).contains(q) }
    }

    enum ListTab: String, CaseIterable, Identifiable {
        case recent, favorites, mine
        var id: String { rawValue }
        var title: String {
            switch self { case .recent: "Zuletzt"; case .favorites: "Favoriten"; case .mine: "Meine" }
        }
        var icon: String {
            switch self { case .recent: "clock.fill"; case .favorites: "star.fill"; case .mine: "fork.knife" }
        }
    }

    private var tabBar: some View {
        HStack(spacing: 6) {
            ForEach(ListTab.allCases) { t in
                let on = tab == t
                Button {
                    Haptics.tap()
                    withAnimation(.snappy) { tab = t }
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: t.icon).font(.system(size: 12, weight: .bold))
                        Text(t.title).font(Theme.font(14, .semibold))
                        Text("\(count(t))").font(Theme.font(11, .bold)).opacity(0.7)
                    }
                    .foregroundStyle(on ? .white : Theme.textSecondary)
                    .frame(maxWidth: .infinity).frame(height: 38)
                    .background {
                        if on { Capsule().fill(Theme.accent).matchedGeometryEffect(id: "tab", in: tabNS) }
                    }
                }
                .buttonStyle(SquishButtonStyle())
            }
        }
        .padding(4)
        .background(Theme.card, in: Capsule())
        .plainRow()
        .listRowSeparator(.hidden)
    }

    private func count(_ t: ListTab) -> Int {
        switch t { case .recent: recents.count; case .favorites: favorites.count; case .mine: customFoods.count }
    }

    @ViewBuilder
    private var emptyQueryContent: some View {
        Button {
            focused = false
            showSuggestions = true
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "wand.and.stars").font(.system(size: 16, weight: .bold)).foregroundStyle(Theme.accent)
                    .frame(width: 34, height: 34).background(Theme.accentSoft, in: Circle())
                VStack(alignment: .leading, spacing: 1) {
                    Text("Was passt noch?").font(Theme.font(15, .bold)).foregroundStyle(Theme.textPrimary)
                    Text("Vorschläge aus Favoriten & Rezepten").font(Theme.font(12)).foregroundStyle(Theme.textSecondary)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.system(size: 13, weight: .bold)).foregroundStyle(Theme.textSecondary)
            }
            .padding(.horizontal, 12).padding(.vertical, 10)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(SquishButtonStyle())
        .plainRow()
        .listRowSeparator(.hidden)
        tabBar
        switch tab {
        case .recent:
            if recents.isEmpty {
                VStack(spacing: 12) {
                    CatMascot(mood: .idle, pixel: 5)
                    Text("Wonach hast du Hunger?").font(Theme.font(17, .semibold)).foregroundStyle(Theme.textPrimary)
                    Text("Über 8.000 Lebensmittel und Gerichte aus dem Bundeslebensmittelschlüssel und der Schweizer Nährwertdatenbank – offline – plus Millionen Produkte von Open Food Facts. Alles andere schätzt die KI.")
                        .font(Theme.font(14)).foregroundStyle(Theme.textSecondary).multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
                .plainRow()
            } else {
                ForEach(recents) { savedRow($0) }
            }
        case .favorites:
            if favorites.isEmpty {
                tabHint(Sprites.star, "Noch keine Favoriten", "Tippe in der Detailansicht auf den Stern oder wische in „Zuletzt“ nach links.")
            } else {
                ForEach(favorites) { savedRow($0) }
            }
        case .mine:
            createButtons
            if customFoods.isEmpty {
                tabHint(Sprites.bowl, "Noch nichts Eigenes", "Lege Rezepte (z. B. Meal Prep) oder eigene Lebensmittel an.")
            } else {
                ForEach(customFoods) { foodRow($0.food) }
            }
        }
    }

    private func tabHint(_ sprite: PixelSprite, _ title: String, _ text: String) -> some View {
        VStack(spacing: 10) {
            PixelSpriteView(sprite: sprite, pixel: 4)
            Text(title).font(Theme.font(16, .semibold)).foregroundStyle(Theme.textPrimary)
            Text(text).font(Theme.font(14)).foregroundStyle(Theme.textSecondary).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 30)
        .plainRow()
    }

    private var aiRow: some View {
        Button { aiQuery = AIQuery(text: trimmedQuery) } label: {
            HStack(spacing: 12) {
                Image(systemName: "sparkles").font(.system(size: 17, weight: .bold)).foregroundStyle(Theme.accent)
                    .frame(width: 44, height: 44).background(Theme.accentSoft, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    Text("„\(trimmedQuery)“ mit KI schätzen").font(Theme.font(16, .semibold)).foregroundStyle(Theme.textPrimary).lineLimit(2)
                    Text(looksLikeSentence ? "Erkennt alle genannten Lebensmittel und Mengen" : "Für Restaurant- und Imbissgerichte ohne Datenbankeintrag")
                        .font(Theme.font(13)).foregroundStyle(Theme.textSecondary).lineLimit(1)
                }
                Spacer(minLength: 4)
                Image(systemName: "chevron.right").font(.system(size: 12, weight: .bold)).foregroundStyle(Theme.accent)
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
        .plainRow()
    }

    @ViewBuilder
    private var resultsContent: some View {
        if aiEnabled, trimmedQuery.count >= 2, looksLikeSentence { aiRow }
        if !matchingCustom.isEmpty {
            Section { ForEach(matchingCustom) { foodRow($0.food) } } header: { SectionTitle("Meine", icon: "fork.knife") }
        }
        // A chain in the query ("mcdonalds pommes") puts its products first.
        let chainsFirst = RestaurantDatabase.mentionsChain(trimmedQuery)
        if chainsFirst { restaurantSection }
        if !search.foods.isEmpty {
            Section { ForEach(search.foods) { foodRow($0) } } header: { SectionTitle("Lebensmittel · BLS", icon: "leaf.fill") }
        }
        if !search.swiss.isEmpty {
            Section { ForEach(search.swiss) { foodRow($0) } } header: { SectionTitle("Lebensmittel & Gerichte · Schweiz", icon: "mountain.2.fill") }
        }
        if !chainsFirst { restaurantSection }
        if !search.products.isEmpty {
            Section { ForEach(search.products) { foodRow($0) } } header: { SectionTitle("Produkte · Open Food Facts", icon: "cart.fill") }
        }
        if aiEnabled, trimmedQuery.count >= 2, !looksLikeSentence, !search.isLoading || !search.isEmpty {
            Section { aiRow } header: { SectionTitle("Nicht dabei?", icon: "sparkles") }
        }
        if search.isLoading && search.products.isEmpty {
            WalkingCatLoader(pixel: 2.5, width: 200, text: "Suche Produkte …")
                .frame(maxWidth: .infinity).padding(.vertical, 30).plainRow()
        } else if let error = search.error {
            Label(error, systemImage: "wifi.slash")
                .font(Theme.font(13)).foregroundStyle(Theme.textSecondary).plainRow()
        } else if !search.isLoading && search.isEmpty {
            VStack(spacing: 10) {
                PixelSpriteView(sprite: Sprites.fish, pixel: 4)
                Text("Nichts gefunden").font(Theme.font(16, .semibold)).foregroundStyle(Theme.textPrimary)
                Text(aiEnabled ? "Lass es oben von der KI schätzen oder trag es über ⚡ schnell selbst ein." : "Probier einen anderen Begriff oder trag es über ⚡ schnell selbst ein.")
                    .font(Theme.font(14)).foregroundStyle(Theme.textSecondary).multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity).padding(.vertical, 30).plainRow()
        }
    }

    @ViewBuilder
    private var restaurantSection: some View {
        if !search.restaurants.isEmpty {
            Section { ForEach(search.restaurants) { foodRow($0) } } header: { SectionTitle("Restaurantketten", icon: "takeoutbag.and.cup.and.straw.fill") }
        }
    }

    private func foodRow(_ food: FoodItem) -> some View {
        NavigationLink(value: food) { FoodRow(food: food) }
            .plainRow()
    }

    private func savedRow(_ s: SavedFood) -> some View {
        HStack(spacing: 8) {
            if let food = s.food {
                NavigationLink(value: food) { FoodRow(food: food, subtitle: lastUsedText(s), amountGrams: lastGrams(s, food)) }
                Button {
                    let serving = s.lastServing ?? food.defaultServing
                    ctx.log(food, quantity: s.lastQuantity, serving: serving, day: day)
                    flashAdded(food.displayName)
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 34, height: 34)
                        .background(Theme.accent, in: Circle())
                }
                .buttonStyle(SquishButtonStyle())
            }
        }
        .plainRow()
        .swipeActions {
            Button { s.isFavorite.toggle() } label: { Label("Favorit", systemImage: s.isFavorite ? "star.slash" : "star") }
                .tint(Theme.carbs)
            Button(role: .destructive) { ctx.delete(s) } label: { Label("Entfernen", systemImage: "trash") }
        }
    }

    /// Amount that the "+" button logs, in g/ml.
    private func lastGrams(_ s: SavedFood, _ food: FoodItem) -> Double {
        s.lastQuantity * (s.lastServing?.grams ?? (s.lastServingName == food.unit ? 1 : food.defaultServing.grams))
    }

    private func lastUsedText(_ s: SavedFood) -> String {
        let serving = s.lastServing
        if let serving, serving.grams != 1 {
            if s.lastQuantity == 1 { return serving.name }
            let single = serving.name.hasPrefix("1 ") ? String(serving.name.dropFirst(2)) : serving.name
            return "\(s.lastQuantity.clean) × \(single)"
        }
        return "\(s.lastQuantity.clean) \(s.lastServingName)"
    }

    @ViewBuilder
    private var addedToast: some View {
        if let addedName {
            HStack(spacing: 10) {
                PixelSpriteView(sprite: Sprites.heart, pixel: 3)
                VStack(alignment: .leading, spacing: 1) {
                    Text("\(addedName) eingetragen").font(Theme.font(15, .semibold)).lineLimit(1)
                    if addedToNight {
                        Text("🌙 zählt zur Nacht von gestern").font(Theme.font(12, .medium)).opacity(0.75)
                    }
                }
            }
            .foregroundStyle(Theme.background)
            .padding(.horizontal, 18).padding(.vertical, 12)
            .background(Theme.textPrimary, in: Capsule())
            .padding(.top, 70)
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }

    private func flashAdded(_ name: String) {
        Haptics.success()
        addedToNight = BloodAlcohol.lastMovedToNight
        BloodAlcohol.lastMovedToNight = false
        withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) { addedName = name }
        DispatchQueue.main.asyncAfter(deadline: .now() + (addedToNight ? 2.6 : 1.6)) {
            withAnimation(.easeOut) { if addedName == name { addedName = nil } }
        }
    }
}

struct FoodRow: View {
    let food: FoodItem
    var subtitle: String? = nil
    /// When set (recents/favourites), the big number is what actually gets logged.
    var amountGrams: Double? = nil

    var body: some View {
        HStack(spacing: 12) {
            FoodThumb(food: food)
            VStack(alignment: .leading, spacing: 2) {
                Text(food.displayName).font(Theme.font(16, .semibold)).foregroundStyle(Theme.textPrimary).lineLimit(2)
                if let warning = food.warning, subtitle == nil {
                    Label(warning, systemImage: "exclamationmark.triangle.fill")
                        .font(Theme.font(12, .medium)).foregroundStyle(Theme.carbs).lineLimit(1)
                } else {
                    Text(subtitle ?? detail).font(Theme.font(13)).foregroundStyle(Theme.textSecondary).lineLimit(1)
                }
            }
            Spacer(minLength: 4)
            VStack(alignment: .trailing, spacing: 0) {
                if let amountGrams {
                    Text(food.nutrients(grams: amountGrams).kcal.kcalString).font(Theme.font(16, .bold)).foregroundStyle(Theme.textPrimary)
                    Text("kcal").font(Theme.font(10, .medium)).foregroundStyle(Theme.textSecondary)
                    Text("\(food.per100.kcal.kcalString)/100\(food.unit)").font(Theme.font(9, .medium)).foregroundStyle(Theme.textSecondary.opacity(0.8))
                } else {
                    Text(food.per100.kcal.kcalString).font(Theme.font(16, .bold)).foregroundStyle(Theme.textPrimary)
                    Text("kcal/100\(food.unit)").font(Theme.font(10, .medium)).foregroundStyle(Theme.textSecondary)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private var detail: String {
        var parts: [String] = []
        if let b = food.brand, !b.isEmpty { parts.append(b) }
        if let s = food.servings.first { parts.append(s.name) }
        parts.append("P \(food.per100.protein.rounded().clean) · K \(food.per100.carbs.rounded().clean) · F \(food.per100.fat.rounded().clean)")
        return parts.joined(separator: " · ")
    }
}

struct FoodThumb: View {
    let food: FoodItem
    var size: CGFloat = 44

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Theme.cardAlt)
            if let url = food.imageURL {
                AsyncImage(url: url) { img in
                    img.resizable().scaledToFill()
                } placeholder: {
                    PixelSpriteView(sprite: Sprites.paw, pixel: 3).opacity(0.5)
                }
                .frame(width: size, height: size)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            } else {
                PixelSpriteView(sprite: sprite, pixel: size / 14)
            }
        }
        .frame(width: size, height: size)
    }

    private var sprite: PixelSprite {
        switch food.source {
        case .ai: return Sprites.star
        case .custom: return Sprites.paw
        case .restaurant:
            if food.unit == "ml" { return Sprites.drop }
            let name = food.name.lowercased(), category = (food.origin ?? "").lowercased()
            if name.contains("pommes") || name.contains("fries") || name.contains("potato") || name.contains("wedges") { return Sprites.fries }
            if category.contains("dessert") || name.contains("sundae") || name.contains("mcflurry") || name.contains("shake") { return Sprites.candy }
            if name.contains("salat") || name.contains("salad") { return Sprites.carrot }
            if name.contains("nugget") || name.contains("wings") || name.contains("chicken box") { return Sprites.drumstick }
            return Sprites.burger
        case .swiss:
            let category = SwissDatabase.shared.category(code: String(food.id.dropFirst(3))) ?? ""
            if food.unit == "ml" { return Sprites.drop }
            if category.hasPrefix("Gerichte") { return Sprites.bowl }
            if category.hasPrefix("Brote") || category.hasPrefix("Getreide") { return Sprites.bread }
            if category.hasPrefix("Gemüse") { return Sprites.carrot }
            if category.hasPrefix("Milch") { return Sprites.cheese }
            if category.hasPrefix("Süss") { return Sprites.candy }
            if category.hasPrefix("Fisch") { return Sprites.fish }
            if category.hasPrefix("Fleisch") { return Sprites.drumstick }
            if category.hasPrefix("Eier") { return Sprites.egg }
            return Sprites.apple
        default: break
        }
        if food.unit == "ml" { return Sprites.drop }
        guard food.source == .bls, let group = food.id.dropFirst(4).first else { return Sprites.apple }
        let name = (food.origin ?? food.name).lowercased()
        switch group {
        case "B", "C", "D": return Sprites.bread
        case "E": return name.contains("ei") && !name.contains("teig") ? Sprites.egg : Sprites.bread
        case "G", "K": return Sprites.carrot
        case "M": return Sprites.cheese
        case "S": return Sprites.candy
        case "T": return Sprites.fish
        case "U", "V", "W": return Sprites.drumstick
        case "X", "Y": return Sprites.bowl
        default: return Sprites.apple
        }
    }
}

struct SectionTitle: View {
    let title: String
    let icon: String
    init(_ title: String, icon: String) { self.title = title; self.icon = icon }
    var body: some View {
        Label(title, systemImage: icon)
            .font(Theme.font(14, .bold))
            .foregroundStyle(Theme.textSecondary)
            .textCase(nil)
    }
}

extension View {
    func plainRow() -> some View {
        self.listRowBackground(Color.clear)
            .listRowSeparatorTint(Theme.line)
    }
}
