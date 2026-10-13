import SwiftUI
import SwiftData

/// Log just calories (and optionally macros, alcohol and any micronutrient) in two taps.
struct QuickAddView: View {
    let day: Date
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var ctx
    @State private var name = ""
    @State private var kcal = ""
    @State private var protein = ""
    @State private var carbs = ""
    @State private var fat = ""
    @State private var showMore = false
    @State private var alcoholML = ""
    @State private var alcoholVol = ""
    @State private var alcoholGrams = ""
    @State private var time = Date()
    @State private var extras: [NutrientKey: String] = [:]
    @FocusState private var focus: Field?

    enum Field: Hashable { case kcal, name, p, c, f, ml, vol, alc, extra(NutrientKey) }

    private func num(_ s: String) -> Double { Double(s.replacingOccurrences(of: ",", with: ".")) ?? 0 }

    /// Grams of alcohol: typed directly or from amount × % vol (density 0.789 g/ml).
    private var alcohol: Double {
        let g = num(alcoholGrams)
        if g > 0 { return g }
        return num(alcoholML) * num(alcoholVol) / 100 * 0.789
    }

    private var kcalValue: Double {
        let k = num(kcal)
        return k > 0 ? k : num(protein) * 4 + num(carbs) * 4 + num(fat) * 9 + alcohol * 7
    }

    private var extraCount: Int { extras.values.filter { num($0) > 0 }.count + (alcohol > 0 ? 1 : 0) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    HStack(alignment: .bottom) {
                        CatMascot(mood: alcohol > 0 ? .tipsy : .eating, pixel: 4)
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
                        Text("≈ \(kcalValue.kcalString) kcal aus \(alcohol > 0 ? "Makros und Alkohol" : "den Makros") berechnet")
                            .font(Theme.font(13)).foregroundStyle(Theme.textSecondary)
                    }

                    Button {
                        Haptics.tap()
                        focus = nil
                        withAnimation(.snappy) { showMore.toggle() }
                    } label: {
                        HStack {
                            Label("Alkohol & Mikronährstoffe", systemImage: "list.bullet.rectangle")
                                .font(Theme.font(15, .semibold)).foregroundStyle(Theme.textPrimary)
                            if extraCount > 0 {
                                Text("\(extraCount)").font(Theme.font(12, .bold)).foregroundStyle(.white)
                                    .padding(.horizontal, 7).padding(.vertical, 2).background(Theme.accent, in: Capsule())
                            }
                            Spacer()
                            Image(systemName: "chevron.down").font(.system(size: 13, weight: .bold)).foregroundStyle(Theme.textSecondary)
                                .rotationEffect(.degrees(showMore ? 180 : 0))
                        }
                        .padding(.horizontal, 16).frame(height: 52)
                        .background(Theme.card, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                    }
                    .buttonStyle(SquishButtonStyle())

                    if showMore {
                        alcoholCard
                            .transition(.opacity.combined(with: .move(edge: .top)))
                        ForEach(NutrientKey.Group.allCases, id: \.self) { group in
                            let keys = NutrientKey.allCases.filter { $0.group == group && $0 != .alcohol }
                            VStack(alignment: .leading, spacing: 0) {
                                Text(group.rawValue).font(Theme.font(13, .bold)).foregroundStyle(Theme.textSecondary)
                                    .padding(.horizontal, 14).padding(.top, 8).padding(.bottom, 2)
                                ForEach(Array(keys.enumerated()), id: \.element) { i, key in
                                    if i > 0 { Divider().overlay(Theme.line) }
                                    extraField(key)
                                }
                            }
                            .card(padding: 6)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                        }
                    }
                }
                .padding(16)
            }
            .scrollDismissesKeyboard(.interactively)
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

    private var alcoholCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Alkohol").font(Theme.font(13, .bold)).foregroundStyle(Theme.textSecondary)
                Spacer()
                if alcohol > 0 {
                    Text("\(alcohol.formatted(.number.precision(.fractionLength(0...1)))) g · \((alcohol * 7).kcalString) kcal")
                        .font(Theme.font(12, .semibold)).foregroundStyle(Theme.accent)
                }
            }
            .padding(.horizontal, 14).padding(.top, 8).padding(.bottom, 2)
            HStack(spacing: 0) {
                field("Menge (ml)", text: $alcoholML, field: .ml)
                Divider().frame(height: 30).overlay(Theme.line)
                field("Vol-%", text: $alcoholVol, field: .vol)
            }
            Divider().overlay(Theme.line)
            field("oder Alkohol direkt (g)", text: $alcoholGrams, field: .alc)
            Divider().overlay(Theme.line)
            HStack {
                Text("Getrunken um").font(Theme.font(17)).foregroundStyle(Theme.textPrimary)
                Spacer()
                DatePicker("", selection: $time, displayedComponents: .hourAndMinute).labelsHidden()
            }
            .padding(.horizontal, 14).frame(height: 52)
            HStack(spacing: 8) {
                ForEach(Self.presets, id: \.0) { p in
                    Button {
                        Haptics.tap()
                        alcoholML = p.1.clean; alcoholVol = p.2.clean; alcoholGrams = ""
                        if name.isEmpty { name = p.0 }
                    } label: {
                        Text(p.0).font(Theme.font(12, .semibold)).foregroundStyle(Theme.accent)
                            .padding(.horizontal, 10).frame(height: 30).background(Theme.accentSoft, in: Capsule())
                    }
                    .buttonStyle(SquishButtonStyle())
                }
            }
            .padding(.horizontal, 14).padding(.bottom, 10)
            Text("Wird für die Promille-Schätzung in der Tagesübersicht genutzt.")
                .font(Theme.font(12)).foregroundStyle(Theme.textSecondary)
                .padding(.horizontal, 14).padding(.bottom, 8)
        }
        .card(padding: 6)
    }

    static let presets: [(String, Double, Double)] = [("Bier 0,5", 500, 5), ("Wein", 200, 12), ("Sekt", 100, 11), ("Shot", 20, 40)]

    private func extraField(_ key: NutrientKey) -> some View {
        HStack(spacing: 10) {
            Text(key.name).font(Theme.font(16)).foregroundStyle(Theme.textPrimary).lineLimit(1)
            Spacer(minLength: 8)
            TextField("–", text: Binding(get: { extras[key] ?? "" }, set: { extras[key] = $0 }))
                .keyboardType(.decimalPad)
                .focused($focus, equals: .extra(key))
                .multilineTextAlignment(.trailing)
                .font(Theme.font(16, .semibold))
                .frame(width: 90)
            Text(key.unit).font(Theme.font(13)).foregroundStyle(Theme.textSecondary).frame(width: 24, alignment: .leading)
        }
        .padding(.horizontal, 14)
        .frame(height: 44)
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
        for (key, text) in extras where num(text) > 0 { n[key] = num(text) }
        if alcohol > 0 { n[.alcohol] = (alcohol * 10).rounded() / 10 }
        n.normalize()
        let title = name.trimmingCharacters(in: .whitespaces).isEmpty ? (alcohol > 0 ? "Getränk" : "Schnell-Eintrag") : name
        let food = FoodItem(id: "custom-\(UUID().uuidString)", name: title, source: .custom, per100: n,
                            servings: [ServingOption(name: "Portion", grams: 100)])
        let entry = FoodEntry(food: food, quantity: 1, serving: food.servings[0], day: day)
        if alcohol > 0 { entry.createdAt = Self.combine(day: day, time: time) }
        ctx.insert(entry)
        ctx.remember(food, quantity: 1, serving: food.servings[0])
        try? ctx.save()
        Haptics.success()
        dismiss()
    }

    /// The chosen clock time on the logged day; early-morning times after an evening count as the night after.
    static func combine(day: Date, time: Date) -> Date {
        let cal = Calendar.current
        let c = cal.dateComponents([.hour, .minute], from: time)
        var d = cal.date(bySettingHour: c.hour ?? 0, minute: c.minute ?? 0, second: 0, of: cal.startOfDay(for: day)) ?? day
        if (c.hour ?? 12) < 6, d.addingTimeInterval(86400) <= .now, !cal.isDateInToday(day) { d = d.addingTimeInterval(86400) }
        return d
    }
}
