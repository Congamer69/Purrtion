import SwiftUI
import SwiftData

/// Log just calories (and optionally macros) in two taps.
struct QuickAddView: View {
    let day: Date
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var ctx
    @State private var name = ""
    @State private var kcal = ""
    @State private var protein = ""
    @State private var carbs = ""
    @State private var fat = ""
    @FocusState private var focus: Field?

    enum Field { case kcal, name, p, c, f }

    private func num(_ s: String) -> Double { Double(s.replacingOccurrences(of: ",", with: ".")) ?? 0 }

    private var kcalValue: Double {
        let k = num(kcal)
        return k > 0 ? k : num(protein) * 4 + num(carbs) * 4 + num(fat) * 9
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    HStack(alignment: .bottom) {
                        CatMascot(mood: .eating, pixel: 4)
                        Spacer()
                        VStack(alignment: .trailing) {
                            TextField("0", text: $kcal)
                                .keyboardType(.decimalPad)
                                .focused($focus, equals: .kcal)
                                .multilineTextAlignment(.trailing)
                                .font(Theme.font(52, .heavy))
                                .foregroundStyle(Theme.textPrimary)
                            Text("kcal").font(Theme.font(16, .semibold)).foregroundStyle(Theme.textSecondary)
                        }
                    }
                    .card(padding: 20)

                    VStack(spacing: 0) {
                        field("Name (optional)", text: $name, field: .name, keyboard: .default)
                        Divider().overlay(Theme.line)
                        field("Protein (g)", text: $protein, field: .p, color: Theme.protein)
                        Divider().overlay(Theme.line)
                        field("Kohlenhydrate (g)", text: $carbs, field: .c, color: Theme.carbs)
                        Divider().overlay(Theme.line)
                        field("Fett (g)", text: $fat, field: .f, color: Theme.fat)
                    }
                    .card(padding: 6)

                    if num(kcal) == 0, kcalValue > 0 {
                        Text("≈ \(kcalValue.kcalString) kcal aus den Makros berechnet")
                            .font(Theme.font(13)).foregroundStyle(Theme.textSecondary)
                    }
                }
                .padding(16)
            }
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle("Schnell eintragen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { dismiss() } } }
            .safeAreaInset(edge: .bottom) {
                Button(action: save) { Label("Eintragen", systemImage: "bolt.fill") }
                    .buttonStyle(PillButtonStyle())
                    .disabled(kcalValue <= 0)
                    .padding(16)
            }
            .onAppear { focus = .kcal }
        }
        .presentationDetents([.large])
    }

    private func field(_ title: String, text: Binding<String>, field: Field, keyboard: UIKeyboardType = .decimalPad, color: Color? = nil) -> some View {
        HStack(spacing: 10) {
            if let color { Rectangle().fill(color).frame(width: 8, height: 8) }
            TextField(title, text: text)
                .keyboardType(keyboard)
                .focused($focus, equals: field)
                .font(Theme.font(17))
        }
        .padding(.horizontal, 14)
        .frame(height: 52)
    }

    private func save() {
        // Store as a "custom" food with 1 portion = 100 units so the entry stays editable.
        var n = Nutrients(kcal: kcalValue, protein: num(protein), carbs: num(carbs), fat: num(fat))
        n.normalize()
        let title = name.trimmingCharacters(in: .whitespaces).isEmpty ? "Schnell-Eintrag" : name
        let food = FoodItem(id: "custom-\(UUID().uuidString)", name: title, source: .custom, per100: n,
                            servings: [ServingOption(name: "Portion", grams: 100)])
        ctx.log(food, quantity: 1, serving: food.servings[0], day: day)
        Haptics.success()
        dismiss()
    }
}
