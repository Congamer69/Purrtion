import SwiftUI
import PhotosUI
import SwiftData

/// Photo of a meal → AI estimates components and nutrients directly → user adjusts or replaces → log.
struct MealPhotoView: View {
    let day: Date
    /// Text mode: estimate from a description ("Käsespätzle vom Restaurant") instead of a photo.
    var textQuery: String? = nil
    /// Called after logging in text mode (the search sheet stays open).
    var onLogged: ((String) -> Void)? = nil
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var ctx
    @State private var image: UIImage?
    @State private var pickerItem: PhotosPickerItem?
    @State private var showCamera = false
    @State private var hint = ""
    @State private var phase: Phase = .idle
    @State private var items: [EditableItem] = []
    @State private var dish = ""
    @State private var replacementTarget: ReplacementTarget?
    @State private var showIngredientPicker = false

    enum Phase: Equatable { case idle, analyzing, result, failed(String) }

    struct EditableItem: Identifiable {
        let id = UUID()
        var recognized: String
        var food: FoodItem
        var grams: Double
        var include = true
        var confidence: String
        var isAIEstimate: Bool
        /// Added through the normal food flow; its amount was selected in FoodDetailView.
        var isDatabaseAddition = false
        /// Fixed upper end of the amount slider – chosen once, so dragging can never grow the range.
        var sliderMax: Double = 0

        static let maxGrams: Double = 5000

        mutating func fixSliderRange() {
            grams = min(max(0, grams), Self.maxGrams)
            if sliderMax <= 0 { sliderMax = min(Self.maxGrams, max(600, (grams * 2.5 / 50).rounded(.up) * 50)) }
        }

        var kcal: Double { food.nutrients(grams: grams).kcal }
    }

    struct ReplacementTarget: Identifiable {
        let id: UUID
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    if let textQuery { textCard(textQuery) } else { photoCard }
                    switch phase {
                    case .idle: idleContent
                    case .analyzing:
                        WalkingCatLoader(pixel: 3, width: 220, text: "\(Pet.yourUpper) schnuppert am Essen …").padding(.vertical, 20)
                    case .failed(let msg):
                        VStack(spacing: 10) {
                            CatMascot(mood: .full, pixel: 4)
                            Text(msg).font(Theme.font(15)).foregroundStyle(Theme.textPrimary).multilineTextAlignment(.center)
                            Button("Nochmal versuchen") { analyze() }.buttonStyle(PillButtonStyle(filled: false))
                        }
                        .card()
                    case .result: resultContent
                    }
                }
                .padding(16)
                .padding(.bottom, 80)
            }
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle(textQuery == nil ? "Gericht scannen" : "KI-Schätzung")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Schließen") { dismiss() } } }
            .task { if textQuery != nil, phase == .idle { analyze() } }
            .safeAreaInset(edge: .bottom) { bottomButton }
            .fullScreenCover(isPresented: $showCamera) {
                CameraPicker(image: $image).ignoresSafeArea()
            }
            .sheet(item: $replacementTarget) { target in
                FoodReplacementPicker { food in
                    replaceItem(id: target.id, with: food)
                }
            }
            .sheet(isPresented: $showIngredientPicker) {
                IngredientPicker { food, quantity, serving in
                    items.append(EditableItem(recognized: food.displayName, food: food, grams: quantity * serving.grams,
                                              confidence: "Datenbank", isAIEstimate: false, isDatabaseAddition: true))
                }
            }
            .onChange(of: pickerItem) { _, item in
                Task {
                    if let data = try? await item?.loadTransferable(type: Data.self), let img = UIImage(data: data) {
                        image = img
                    }
                }
            }
            .onChange(of: image) { _, img in if img != nil { analyze() } }
        }
    }

    private func textCard(_ text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "sparkles").font(.system(size: 18, weight: .bold)).foregroundStyle(Theme.accentText)
                .frame(width: 44, height: 44).background(Theme.accentSoft, in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text("„\(text)“").font(Theme.font(17, .semibold)).foregroundStyle(Theme.textPrimary)
                Text("Schätzung mit \(AITask.photo.provider.name)").font(Theme.font(12)).foregroundStyle(Theme.textSecondary)
            }
            Spacer(minLength: 0)
        }
        .card(padding: 14)
    }

    private var photoCard: some View {
        ZStack {
            if let image {
                Image(uiImage: image).resizable().scaledToFill()
                    .frame(height: 240).frame(maxWidth: .infinity).clipped()
                    .clipShape(RoundedRectangle(cornerRadius: Theme.radius, style: .continuous))
            } else {
                VStack(spacing: 14) {
                    HStack(alignment: .bottom, spacing: 10) {
                        CatMascot(mood: .idle, pixel: 4)
                        PixelSpriteView(sprite: Sprites.bowl, pixel: 4)
                    }
                    Text("Fotografiere dein Essen – ich erkenne die Bestandteile und schätze Mengen und Nährwerte.")
                        .font(Theme.font(14)).foregroundStyle(Theme.textSecondary).multilineTextAlignment(.center)
                }
                .padding(20)
                .frame(height: 240).frame(maxWidth: .infinity)
                .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.radius, style: .continuous))
            }
        }
    }

    @ViewBuilder
    private var idleContent: some View {
        HStack(spacing: 10) {
            Button { showCamera = true } label: { Label("Kamera", systemImage: "camera.fill") }
                .buttonStyle(PillButtonStyle())
                .disabled(!UIImagePickerController.isSourceTypeAvailable(.camera))
            PhotosPicker(selection: $pickerItem, matching: .images) {
                Label("Foto wählen", systemImage: "photo.on.rectangle")
            }
            .buttonStyle(PillButtonStyle(filled: false))
        }
        TextField("Optional: Hinweis, z. B. „mit Sahnesoße“", text: $hint)
            .font(Theme.font(15))
            .padding(.horizontal, 16).frame(height: 48)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var resultContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(dish).font(Theme.font(20, .bold)).foregroundStyle(Theme.textPrimary)
                    Text("\(totalKcal.kcalString) kcal · Mengen geschätzt").font(Theme.font(13)).foregroundStyle(Theme.textSecondary)
                    HStack(spacing: 10) {
                        MacroDot(color: Theme.protein, value: totalNutrients.protein)
                        MacroDot(color: Theme.carbs, value: totalNutrients.carbs)
                        MacroDot(color: Theme.fat, value: totalNutrients.fat)
                    }
                }
                Spacer()
                CatMascot(mood: .happy, pixel: 3)
            }
            ForEach($items) { $item in
                ItemEditor(item: $item) { replacementTarget = ReplacementTarget(id: item.id) }
            }
            Button { showIngredientPicker = true } label: {
                Label("Zutat hinzufügen", systemImage: "plus.circle.fill")
            }
            .buttonStyle(PillButtonStyle(filled: false))
            Text("Die KI-Nährwerte sind Schätzungen. Über „Ersetzen durch“ kannst du jeden Eintrag aus den Lebensmitteldatenbanken auswählen; die Menge bleibt erhalten.")
                .font(Theme.font(12)).foregroundStyle(Theme.textSecondary)
            if textQuery == nil {
                Button {
                    phase = .idle; image = nil; items = []; pickerItem = nil
                } label: { Label("Neues Foto", systemImage: "arrow.counterclockwise") }
                    .font(Theme.font(15, .semibold))
            }
        }
    }

    private var selectedItems: [EditableItem] { items.filter(\.include) }
    private var totalNutrients: Nutrients {
        selectedItems.reduce(Nutrients()) { total, item in
            total + item.food.nutrients(grams: item.grams)
        }
    }
    private var totalKcal: Double { totalNutrients.kcal }

    @ViewBuilder
    private var bottomButton: some View {
        if phase == .result {
            Button {
                let ingredients = selectedItems.map {
                    RecipeIngredient(food: $0.food, quantity: $0.grams, serving: .base($0.food.unit))
                }
                let mealName = dish.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "KI-Mahlzeit" : dish
                if selectedItems.count == 1, let only = selectedItems.first {
                    // A single dish is logged like any other food and keeps its estimated portion for next time.
                    var food = only.food
                    food.servings = [ServingOption(name: "1 Portion", grams: only.grams)]
                    ctx.log(food, quantity: only.grams, serving: .base(food.unit), day: day)
                } else {
                    ctx.insert(FoodEntry(mealName: mealName, ingredients: ingredients, source: .ai, day: day))
                    try? ctx.save()
                }
                Haptics.success()
                if let onLogged { onLogged(selectedItems.count == 1 ? selectedItems[0].food.displayName : mealName) } else { dismiss() }
            } label: {
                Label(selectedItems.count == 1 ? "Eintragen · \(totalKcal.kcalString) kcal" : "\(selectedItems.count) Einträge · \(totalKcal.kcalString) kcal", systemImage: "pawprint.fill")
            }
            .buttonStyle(PillButtonStyle())
            .disabled(selectedItems.isEmpty)
            .padding(.horizontal, 16).padding(.bottom, 8)
            .background(Theme.background.opacity(0.95))
        }
    }

    private func analyze() {
        guard image != nil || textQuery != nil else { return }
        withAnimation { phase = .analyzing }
        Task {
            do {
                let result: MealVision.Result
                if let textQuery { result = try await MealVision.analyze(text: textQuery) }
                else { result = try await MealVision.analyze(image: image!, hint: hint) }
                dish = result.dish
                items = result.items.map {
                    var item = EditableItem(recognized: $0.name, food: $0.food, grams: $0.grams.rounded(),
                                            confidence: $0.confidence, isAIEstimate: $0.isAIEstimate)
                    item.fixSliderRange()
                    return item
                }
                Haptics.success()
                withAnimation(.spring) { phase = .result }
            } catch {
                Haptics.warning()
                withAnimation { phase = .failed(error.localizedDescription) }
            }
        }
    }

    private func replaceItem(id: UUID, with food: FoodItem) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        items[index].recognized = food.displayName
        items[index].food = food
        items[index].isAIEstimate = false
        items[index].isDatabaseAddition = false
        items[index].include = true
        Haptics.success()
    }

    struct ItemEditor: View {
        @Binding var item: EditableItem
        let onReplace: () -> Void

        var body: some View {
            let n = item.food.nutrients(grams: item.grams)
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top) {
                    Button { withAnimation(Motion.quick) { item.include.toggle() } } label: {
                        Image(systemName: item.include ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 22)).foregroundStyle(item.include ? Theme.accent : Theme.textSecondary)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.recognized).font(Theme.font(16, .semibold)).foregroundStyle(Theme.textPrimary)
                        Text(item.isAIEstimate
                             ? "KI-Schätzung · \(item.food.per100.kcal.kcalString) kcal / 100 \(item.food.unit)"
                             : "\(item.food.source.label) · \(item.food.per100.kcal.kcalString) kcal / 100 \(item.food.unit)")
                            .font(Theme.font(12, .medium)).foregroundStyle(Theme.accentText).lineLimit(1)
                        Text("Sicherheit: \(item.confidence)").font(Theme.font(11)).foregroundStyle(Theme.textSecondary)
                    }
                    Spacer()
                    Text("\(item.kcal.kcalString) kcal").font(Theme.font(16, .bold)).foregroundStyle(Theme.textPrimary)
                }
                if item.isDatabaseAddition {
                    Text("\(item.grams.clean) \(item.food.unit) · über Lebensmittelsuche hinzugefügt")
                        .font(Theme.font(13, .medium)).foregroundStyle(Theme.textSecondary)
                } else {
                    Button(action: onReplace) {
                        Label("Ersetzen durch", systemImage: "magnifyingglass")
                            .font(Theme.font(13, .semibold))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(Theme.accentText)
                    HStack(spacing: 10) {
                        Button { item.grams = max(0, item.grams - 10) } label: { Image(systemName: "minus") }
                        Slider(value: Binding(get: { min(item.grams, item.sliderMax) },
                                              set: { item.grams = min(max(0, $0), item.sliderMax) }),
                               in: 0...max(item.sliderMax, 10), step: 5)
                        Button {
                            item.grams = min(item.grams + 10, EditableItem.maxGrams)
                            // "+" may go beyond the slider; then the slider grows once, in fixed steps.
                            if item.grams > item.sliderMax { item.sliderMax = min(EditableItem.maxGrams, item.sliderMax * 2) }
                        } label: { Image(systemName: "plus") }
                        Text("\(item.grams.clean) \(item.food.unit)").font(Theme.font(14, .semibold)).frame(width: 64, alignment: .trailing)
                    }
                    .font(.system(size: 14, weight: .bold))
                }
                HStack(spacing: 10) {
                    MacroDot(color: Theme.protein, value: n.protein)
                    MacroDot(color: Theme.carbs, value: n.carbs)
                    MacroDot(color: Theme.fat, value: n.fat)
                }
            }
            .opacity(item.include ? 1 : 0.5)
            .card(padding: 14)
            .onAppear { item.fixSliderRange() }
        }
    }
}

/// Search BLS and Open Food Facts exactly as in "Essen hinzufügen", but selecting a row
/// replaces only the food data. The scanned amount intentionally never changes.
struct FoodReplacementPicker: View {
    let title: String
    let hint: String
    let onPick: (FoodItem) -> Void
    @Environment(\.dismiss) private var dismiss
    @StateObject private var search = FoodSearch()
    @Query(sort: \CustomFood.name) private var customFoods: [CustomFood]
    @FocusState private var focused: Bool

    init(title: String = "Ersetzen durch",
         hint: String = "Der gewählte Eintrag ersetzt die KI-Schätzung. Die Grammzahl bleibt unverändert.",
         onPick: @escaping (FoodItem) -> Void) {
        self.title = title
        self.hint = hint
        self.onPick = onPick
    }

    var body: some View {
        NavigationStack {
            List {
                if search.query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    ContentUnavailableView("Lebensmittel suchen", systemImage: "magnifyingglass",
                                           description: Text(hint))
                        .listRowBackground(Color.clear)
                } else {
                    results
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(Theme.background.ignoresSafeArea())
            .safeAreaInset(edge: .top) { searchBar }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { dismiss() } } }
            .onAppear { focused = true }
        }
    }

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass").foregroundStyle(Theme.textSecondary)
            TextField("Lebensmittel suchen", text: $search.query)
                .font(Theme.font(17)).focused($focused).autocorrectionDisabled()
                .onChange(of: search.query) { _, _ in search.queryChanged() }
            if search.isLoading { ProgressView().controlSize(.small) }
        }
        .padding(.horizontal, 16).frame(height: 50)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .padding(.horizontal, 16).padding(.vertical, 8)
        .background(Theme.background)
    }

    @ViewBuilder
    private var results: some View {
        if !matchingCustom.isEmpty {
            Section { ForEach(matchingCustom) { row($0.food) } } header: { SectionTitle("Meine", icon: "fork.knife") }
        }
        if !search.foods.isEmpty {
            Section { ForEach(search.foods) { row($0) } } header: { SectionTitle("Lebensmittel · BLS", icon: "leaf.fill") }
        }
        if !search.products.isEmpty {
            Section { ForEach(search.products) { row($0) } } header: { SectionTitle("Produkte · Open Food Facts", icon: "cart.fill") }
        }
        if search.isLoading && search.products.isEmpty {
            WalkingCatLoader(pixel: 2.5, width: 200, text: "Suche Lebensmittel …")
                .frame(maxWidth: .infinity).padding(.vertical, 30).plainRow()
        } else if !search.isLoading && search.isEmpty && matchingCustom.isEmpty {
            Text("Nichts gefunden").font(Theme.font(15)).foregroundStyle(Theme.textSecondary).plainRow()
        }
    }

    private var matchingCustom: [CustomFood] {
        let q = BLSDatabase.fold(search.query.trimmingCharacters(in: .whitespacesAndNewlines))
        return customFoods.filter { BLSDatabase.fold($0.name).contains(q) }
    }

    private func row(_ food: FoodItem) -> some View {
        Button {
            onPick(food)
            dismiss()
        } label: {
            FoodRow(food: food)
        }
        .buttonStyle(.plain)
        .plainRow()
    }
}

struct CameraPicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let p = UIImagePickerController()
        p.sourceType = .camera
        p.delegate = context.coordinator
        return p
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraPicker
        init(_ p: CameraPicker) { parent = p }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            parent.image = info[.originalImage] as? UIImage
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) { parent.dismiss() }
    }
}
