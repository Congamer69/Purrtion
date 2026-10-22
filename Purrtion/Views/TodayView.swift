import SwiftUI
import SwiftData

enum AddSheet: Identifiable {
    case search, barcode, photo, quick
    case edit(FoodEntry)
    case meal(FoodEntry)
    case ingredient(FoodEntry, UUID)
    case nutrients(Nutrients)
    case score(HealthScore, baseline: HealthScore?)
    case review(DayReview)
    case overview
    case suggestions
    case calendar
    /// Pick the day to copy entries from.
    case copyFromDay
    /// Choose which entries of `source` to copy onto the shown day.
    case copyPicker(source: Date)
    /// Pick the target day for the currently selected entries.
    case copySelectionTo

    var id: String {
        switch self {
        case .search: "search"
        case .barcode: "barcode"
        case .photo: "photo"
        case .quick: "quick"
        case .edit(let e): "edit-\(e.id)"
        case .meal(let e): "meal-\(e.id)"
        case .ingredient(let e, let id): "ingredient-\(e.id)-\(id)"
        case .nutrients: "nutrients"
        case .score: "score"
        case .review(let r): "review-\(r.day.timeIntervalSince1970)"
        case .overview: "overview"
        case .suggestions: "suggestions"
        case .calendar: "calendar"
        case .copyFromDay: "copyFromDay"
        case .copyPicker(let d): "copyPicker-\(d.timeIntervalSince1970)"
        case .copySelectionTo: "copySelectionTo"
        }
    }
}

struct TodayView: View {
    @State private var day = Calendar.current.startOfDay(for: .now)
    /// The calendar day the app last considered "today" – used to follow midnight.
    @State private var todayAnchor = Calendar.current.startOfDay(for: .now)
    @Environment(\.scenePhase) private var scenePhase
    @ObservedObject private var router = NotificationRouter.shared
    @State private var sheet: AddSheet?
    /// Non-nil while selecting entries (multi-delete, copy, save as recipe).
    @State private var selection: Set<UUID>?
    @State private var nextSheet: AddSheet?
    @State private var recipeName = ""
    @State private var askRecipeName = false
    @State private var recipeFromSelection = false
    @Environment(\.modelContext) private var ctx

    var body: some View {
        NavigationStack {
            DayContent(day: day, sheet: $sheet, selection: $selection, onSaveRecipe: { fromSelection in
                recipeFromSelection = fromSelection
                recipeName = "Mahlzeit \(day.formatted(.dateTime.day().month(.abbreviated)))"
                askRecipeName = true
            })
                .id(day)
                .background(Theme.background.ignoresSafeArea())
                .safeAreaInset(edge: .top, spacing: 0) {
                    DayHeader(day: $day, onCalendar: { sheet = .calendar }, onToday: {
                        withAnimation(.snappy) { day = Calendar.current.startOfDay(for: .now) }
                    })
                }
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    if let selection {
                        SelectionBar(count: selection.count,
                                     onDelete: deleteSelected,
                                     onCopy: { sheet = .copySelectionTo },
                                     onRecipe: { recipeFromSelection = true; recipeName = "Meine Mahlzeit"; askRecipeName = true },
                                     onDone: { withAnimation(.snappy) { self.selection = nil } })
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    } else {
                        QuickAddDock(sheet: $sheet)
                    }
                }
                .toolbar(.hidden, for: .navigationBar)
                .gesture(DragGesture(minimumDistance: 30).onEnded { v in
                    guard selection == nil, abs(v.translation.width) > abs(v.translation.height) * 1.5 else { return }
                    let delta = v.translation.width < 0 ? 1 : -1
                    let next = Calendar.current.date(byAdding: .day, value: delta, to: day)!
                    guard next <= Calendar.current.startOfDay(for: .now) else { return }
                    Haptics.tap()
                    withAnimation(.snappy) { day = next }
                })
                .onChange(of: day) { _, _ in selection = nil }
                .onReceive(NotificationCenter.default.publisher(for: .NSCalendarDayChanged).receive(on: RunLoop.main)) { _ in
                    followMidnight()
                }
                .onChange(of: scenePhase) { _, phase in if phase == .active { followMidnight() } }
                #if DEBUG
                .task {
                    if UserDefaults.standard.string(forKey: "debugSearch") != nil {
                        try? await Task.sleep(for: .seconds(1.6))
                        sheet = .search
                    }
                }
                #endif
                // Notification tap: open that day's verdict once the splash is gone (also on a cold start).
                .onChange(of: router.reviewDay, initial: true) { _, _ in handleReviewTap() }
                .onChange(of: router.appReady) { _, _ in handleReviewTap() }
        }
        .sheet(item: $sheet, onDismiss: {
            // chain: calendar → entry picker
            if let next = nextSheet { nextSheet = nil; DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { sheet = next } }
        }) { s in
            switch s {
            case .search: AddFoodView(day: day)
            case .barcode: BarcodeFlowView(day: day)
            case .photo: MealPhotoView(day: day)
            case .quick: QuickAddView(day: day)
            case .edit(let entry): EditEntryView(entry: entry)
            case .meal(let entry): MealEntryDetailView(entry: entry)
            case .ingredient(let entry, let id): IngredientEditView(entry: entry, id: id)
            case .nutrients(let total):
                NavigationStack { NutrientsDayView(total: total, title: "Nährstoffe") }
                    .presentationDetents([.medium, .large])
            case .score(let score, let baseline):
                HealthScoreView(score: score, baseline: baseline).presentationDetents([.large])
            case .review(let review):
                DayReviewSheet(review: review)
            case .overview:
                DayOverviewSheet(day: day)
            case .suggestions:
                SuggestionsSheet(day: day)
            case .calendar:
                CalendarSheet(title: "Tag wählen") { picked in day = picked }
            case .copyFromDay:
                CalendarSheet(title: "Übernehmen von …") { picked in nextSheet = .copyPicker(source: picked) }
            case .copyPicker(let source):
                CopyPickerSheet(source: source, target: day)
            case .copySelectionTo:
                CalendarSheet(title: "Kopieren nach …", allowFuture: true) { picked in copySelected(to: picked) }
            }
        }
        .alert("Als Rezept speichern", isPresented: $askRecipeName) {
            TextField("Name", text: $recipeName)
            Button("Abbrechen", role: .cancel) {}
            Button("Speichern") { saveRecipe() }
        } message: {
            Text(recipeFromSelection ? "Die ausgewählten Einträge werden zu einem Rezept." : "Alle Einträge dieses Tages werden zu einem Rezept.")
        }
    }

    private func handleReviewTap() {
        guard router.appReady, let target = router.reviewDay else { return }
        router.reviewDay = nil
        sheet = nil
        openReview(for: target)
    }

    /// Notification tap: show that day and its verdict.
    private func openReview(for target: Date) {
        let d = Calendar.current.startOfDay(for: target)
        withAnimation(.snappy) { day = d }
        if let review = try? ctx.fetch(FetchDescriptor<DayReview>(predicate: #Predicate { $0.day == d })).first {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { sheet = .review(review) }
        }
    }

    /// At midnight "Heute" moves on to the new day (unless another day is being looked at on purpose).
    private func followMidnight() {
        let now = Calendar.current.startOfDay(for: .now)
        guard now != todayAnchor else { return }
        if day == todayAnchor { withAnimation(.snappy) { day = now } }
        todayAnchor = now
    }

    private func selectedEntries() -> [FoodEntry] {
        guard let ids = selection, !ids.isEmpty else { return [] }
        let d = day
        let all = (try? ctx.fetch(FetchDescriptor<FoodEntry>(predicate: #Predicate { $0.day == d }))) ?? []
        return all.filter { ids.contains($0.id) }
    }

    private func deleteSelected() {
        let list = selectedEntries()
        guard !list.isEmpty else { return }
        Haptics.warning()
        withAnimation { list.forEach(ctx.delete) }
        try? ctx.save()
        selection = nil
    }

    private func copySelected(to target: Date) {
        let t = Calendar.current.startOfDay(for: target)
        for e in selectedEntries() {
            guard let food = e.food else { continue }
            ctx.insert(FoodEntry(food: food, quantity: e.quantity, serving: ServingOption(name: e.servingName, grams: e.servingGrams), day: t))
        }
        try? ctx.save()
        Haptics.success()
        selection = nil
    }

    private func saveRecipe() {
        let entries: [FoodEntry]
        if recipeFromSelection {
            entries = selectedEntries()
        } else {
            let d = day
            entries = (try? ctx.fetch(FetchDescriptor<FoodEntry>(predicate: #Predicate { $0.day == d }))) ?? []
        }
        let ingredients = entries.compactMap { e in
            e.food.map { RecipeIngredient(food: $0, quantity: e.quantity, serving: ServingOption(name: e.servingName, grams: e.servingGrams)) }
        }
        guard !ingredients.isEmpty else { return }
        let name = recipeName.trimmingCharacters(in: .whitespaces)
        ctx.insert(CustomFood(recipeName: name.isEmpty ? "Meine Mahlzeit" : name, ingredients: ingredients, portions: 1))
        try? ctx.save()
        Haptics.success()
        selection = nil
    }
}

/// Bottom bar while selecting entries.
struct SelectionBar: View {
    let count: Int
    let onDelete: () -> Void
    let onCopy: () -> Void
    let onRecipe: () -> Void
    let onDone: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Button(action: onDone) {
                Text("Fertig").font(Theme.font(15, .bold)).foregroundStyle(Theme.textPrimary)
                    .padding(.horizontal, 16).frame(height: 50)
                    .background(Theme.cardAlt, in: Capsule())
            }
            Spacer(minLength: 0)
            Text("\(count) ausgewählt").font(Theme.font(13, .semibold)).foregroundStyle(Theme.textSecondary)
            Spacer(minLength: 0)
            actionButton("doc.on.doc.fill", Theme.accent, onCopy)
            actionButton("frying.pan.fill", Theme.fiber, onRecipe)
            actionButton("trash.fill", Theme.danger, onDelete)
        }
        .buttonStyle(SquishButtonStyle())
        .disabled(count == 0)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Theme.background.opacity(0.97))
    }

    private func actionButton(_ icon: String, _ color: Color, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon).font(.system(size: 17, weight: .bold)).foregroundStyle(count == 0 ? Theme.textSecondary : color)
                .frame(width: 50, height: 50)
                .background((count == 0 ? Theme.cardAlt : color.opacity(0.15)), in: Circle())
        }
    }
}

/// Lists the entries of another day; deselect what you don't want, then add.
struct CopyPickerSheet: View {
    let source: Date
    let target: Date
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var ctx
    @Query private var entries: [FoodEntry]
    @State private var selected: Set<UUID> = []
    @State private var didInit = false

    init(source: Date, target: Date) {
        self.source = Calendar.current.startOfDay(for: source)
        self.target = target
        let d = Calendar.current.startOfDay(for: source)
        _entries = Query(filter: #Predicate<FoodEntry> { $0.day == d }, sort: \FoodEntry.createdAt)
    }

    private var allSelected: Bool { !entries.isEmpty && selected.count == entries.count }
    private var chosen: [FoodEntry] { entries.filter { selected.contains($0.id) } }

    var body: some View {
        NavigationStack {
            List {
                if entries.isEmpty {
                    VStack(spacing: 10) {
                        CatMascot(mood: .sleeping, pixel: 4)
                        Text("An diesem Tag gibt es keine Einträge.").font(Theme.font(15)).foregroundStyle(Theme.textSecondary)
                    }
                    .frame(maxWidth: .infinity).padding(.vertical, 30)
                    .listRowBackground(Color.clear)
                } else {
                    Section {
                        Button {
                            Haptics.tap()
                            withAnimation(.snappy) { selected = allSelected ? [] : Set(entries.map(\.id)) }
                        } label: {
                            HStack {
                                CheckCircle(on: allSelected)
                                Text(allSelected ? "Alle abwählen" : "Alle auswählen").font(Theme.font(16, .semibold)).foregroundStyle(Theme.textPrimary)
                                Spacer()
                                Text("\(selected.count)/\(entries.count)").font(Theme.font(14)).foregroundStyle(Theme.textSecondary)
                            }
                        }
                    }
                    .listRowBackground(Theme.card)
                    Section {
                        ForEach(entries) { e in
                            Button {
                                Haptics.tap()
                                withAnimation(.snappy) {
                                    if selected.contains(e.id) { selected.remove(e.id) } else { selected.insert(e.id) }
                                }
                            } label: {
                                HStack(spacing: 12) {
                                    CheckCircle(on: selected.contains(e.id))
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(e.name).font(Theme.font(15, .semibold)).foregroundStyle(Theme.textPrimary)
                                        Text(e.amountText).font(Theme.font(12)).foregroundStyle(Theme.textSecondary)
                                    }
                                    Spacer()
                                    Text("\(e.kcal.kcalString) kcal").font(Theme.font(14, .semibold)).foregroundStyle(Theme.textPrimary)
                                }
                            }
                        }
                    } header: { Text(source.formatted(.dateTime.weekday(.wide).day().month(.wide))) }
                    .listRowBackground(Theme.card)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle("Übernehmen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { dismiss() } } }
            .safeAreaInset(edge: .bottom) {
                if !entries.isEmpty {
                    Button {
                        for e in chosen {
                            guard let food = e.food else { continue }
                            ctx.insert(FoodEntry(food: food, quantity: e.quantity,
                                                 serving: ServingOption(name: e.servingName, grams: e.servingGrams), day: target))
                        }
                        try? ctx.save()
                        dismiss()
                    } label: {
                        Label("\(chosen.count) Einträge hinzufügen · \(chosen.reduce(0) { $0 + $1.kcal }.kcalString) kcal",
                              systemImage: "plus.circle.fill")
                    }
                    .buttonStyle(PillButtonStyle())
                    .disabled(chosen.isEmpty)
                    .opacity(chosen.isEmpty ? 0.5 : 1)
                    .padding(16)
                    .background(Theme.background)
                }
            }
            .onAppear {
                guard !didInit else { return }
                didInit = true
                selected = Set(entries.map(\.id))
            }
        }
    }
}

struct CheckCircle: View {
    let on: Bool
    var body: some View {
        Image(systemName: on ? "checkmark.circle.fill" : "circle")
            .font(.system(size: 22))
            .foregroundStyle(on ? Theme.accent : Theme.textSecondary.opacity(0.6))
            .contentTransition(.symbolEffect(.replace))
    }
}

// MARK: - Header

struct DayHeader: View {
    @Binding var day: Date
    var onCalendar: () -> Void = {}
    var onToday: () -> Void = {}
    @EnvironmentObject private var goals: Goals
    @Environment(\.modelContext) private var ctx
    @Query private var week: [FoodEntry]
    @State private var streak = 0
    private let cal = Calendar.mondayFirst
    private var isToday: Bool { Calendar.current.isDateInToday(day) }

    init(day: Binding<Date>, onCalendar: @escaping () -> Void = {}, onToday: @escaping () -> Void = {}) {
        _day = day
        self.onCalendar = onCalendar
        self.onToday = onToday
        let c = Calendar.mondayFirst
        let monday = c.dateInterval(of: .weekOfYear, for: day.wrappedValue)!.start
        let sunday = c.date(byAdding: .day, value: 6, to: monday)!
        _week = Query(filter: #Predicate<FoodEntry> { $0.day >= monday && $0.day <= sunday })
    }

    var title: String {
        if isToday { return "Heute" }
        if Calendar.current.isDateInYesterday(day) { return "Gestern" }
        return day.formatted(.dateTime.weekday(.wide))
    }

    private var weekDays: [Date] {
        let monday = cal.dateInterval(of: .weekOfYear, for: day)!.start
        return (0..<7).map { cal.date(byAdding: .day, value: $0, to: monday)! }
    }

    var body: some View {
        VStack(spacing: Theme.Space.m) {
            HStack(alignment: .center, spacing: Theme.Space.s) {
                VStack(alignment: .leading, spacing: 0) {
                    Text(title).font(Theme.font(22, .bold)).foregroundStyle(Theme.textPrimary)
                    Text(day.formatted(.dateTime.day().month(.wide).year())).font(Theme.font(13)).foregroundStyle(Theme.textSecondary)
                }
                .contentTransition(.numericText())
                Spacer(minLength: 0)
                if !isToday {
                    Button(action: onToday) {
                        Label("Zu Heute", systemImage: "arrow.uturn.forward").font(Theme.font(12, .bold))
                            .foregroundStyle(Theme.accent)
                            .padding(.horizontal, 10).frame(height: 34)
                            .background(Theme.accentSoft, in: Capsule())
                    }
                    .transition(.scale.combined(with: .opacity))
                }
                if streak > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "flame.fill").font(.system(size: 11, weight: .bold))
                        Text("\(streak)").font(Theme.font(13, .bold)).contentTransition(.numericText(value: Double(streak)))
                    }
                    .foregroundStyle(Theme.accent)
                    .padding(.horizontal, 10).frame(height: 34)
                    .background(Theme.accentSoft, in: Capsule())
                    .accessibilityLabel("\(streak) Tage in Folge")
                }
                Button(action: onCalendar) {
                    Image(systemName: "calendar").font(.system(size: 15, weight: .bold)).foregroundStyle(Theme.accent)
                        .frame(width: 34, height: 34).background(Theme.accentSoft, in: Circle())
                }
                .accessibilityLabel("Kalender")
            }
            HStack(spacing: 6) {
                let kcalByDay = Dictionary(grouping: week, by: \.day).mapValues { $0.reduce(0) { $0 + $1.kcal } }
                ForEach(weekDays, id: \.self) { d in cell(d, kcal: kcalByDay[d] ?? 0) }
            }
        }
        .buttonStyle(SquishButtonStyle())
        .padding(.horizontal, Theme.Space.l)
        .padding(.top, Theme.Space.s)
        .padding(.bottom, Theme.Space.s)
        .background(Theme.background)
        .animation(.snappy, value: isToday)
        .task { refreshStreak() }
        .onChange(of: week.count) { _, _ in refreshStreak() }
    }

    private func cell(_ d: Date, kcal: Double) -> some View {
        let future = d > Calendar.current.startOfDay(for: .now)
        let status = GoalStatus(kcal: kcal, goal: goals.target(for: d).kcal)
        let selected = Calendar.current.isDate(d, inSameDayAs: day)
        let label = String(d.formatted(.dateTime.weekday(.abbreviated)).prefix(2))
        return Button {
            guard !future else { return }
            Haptics.tap()
            withAnimation(.snappy) { day = d }
        } label: {
            VStack(spacing: 4) {
                Text(label).font(Theme.font(12, selected ? .bold : .regular))
                    .foregroundStyle(selected ? Theme.textPrimary : Theme.textSecondary)
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(status.color)
                    .frame(height: 32)
                    .overlay(Text("\(Calendar.current.component(.day, from: d))").font(Theme.font(12, .bold))
                        .foregroundStyle(kcal > 0 ? Color.white : Theme.textSecondary))
                    .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(selected ? Theme.textPrimary : .clear, lineWidth: 2).padding(-3))
            }
            .frame(maxWidth: .infinity)
            .opacity(future ? 0.35 : 1)
        }
        .disabled(future)
        .accessibilityLabel(d.formatted(.dateTime.weekday(.wide).day().month(.wide)))
    }

    /// Consecutive logged days up to today (or yesterday while today is still empty).
    private func refreshStreak() {
        let today = Calendar.current.startOfDay(for: .now)
        let from = Calendar.current.date(byAdding: .day, value: -400, to: today)!
        var fetch = FetchDescriptor<FoodEntry>(predicate: #Predicate { $0.day >= from })
        fetch.propertiesToFetch = [\.day]
        let days = Set((try? ctx.fetch(fetch))?.map(\.day) ?? [])
        var d = days.contains(today) ? today : Calendar.current.date(byAdding: .day, value: -1, to: today)!
        var n = 0
        while days.contains(d) { n += 1; d = Calendar.current.date(byAdding: .day, value: -1, to: d)! }
        if n != streak { withAnimation(.snappy) { streak = n } }
    }
}

// MARK: - Day content

struct DayContent: View {
    let day: Date
    @Binding var sheet: AddSheet?
    @Binding var selection: Set<UUID>?
    var onSaveRecipe: (Bool) -> Void
    @EnvironmentObject private var goals: Goals
    @Environment(\.modelContext) private var ctx
    /// The day before: last night's drinks may still be in the blood (cat mood).
    @Query private var previous: [FoodEntry]
    @Query private var entries: [FoodEntry]
    @Query private var water: [WaterLog]
    @State private var justAte = false
    @State private var burst = 0
    @State private var pendingCelebration = false
    @State private var expandedMeals: Set<UUID> = []
    @Query private var reviews: [DayReview]
    @State private var closing = false
    @State private var closeError: String?

    init(day: Date, sheet: Binding<AddSheet?>, selection: Binding<Set<UUID>?>, onSaveRecipe: @escaping (Bool) -> Void) {
        self.day = day
        self._sheet = sheet
        self._selection = selection
        self.onSaveRecipe = onSaveRecipe
        let d = day
        _entries = Query(filter: #Predicate<FoodEntry> { $0.day == d }, sort: \FoodEntry.createdAt, order: .reverse)
        let prev = Calendar.current.date(byAdding: .day, value: -1, to: d)!
        _previous = Query(filter: #Predicate<FoodEntry> { $0.day == prev })
        _water = Query(filter: #Predicate<WaterLog> { $0.day == d })
        _reviews = Query(filter: #Predicate<DayReview> { $0.day == d })
    }

    /// Score without AI-added micronutrients – nil when the AI did not change anything.
    private func aiBaseline(_ score: HealthScore) -> HealthScore? {
        guard entries.contains(where: { e in
            e.isComposite ? e.ingredients.contains { !($0.food.aiNutrientKeys ?? []).isEmpty } : !(e.food?.aiNutrientKeys ?? []).isEmpty
        }) else { return nil }
        let before = HealthScore(entries: entries, goalKcal: target.kcal, goalProtein: target.protein, withoutAI: true)
        return before.score == score.score ? nil : before
    }

    private var reviewOutdated: Bool {
        guard let review = reviews.first else { return false }
        return review.signature != DayReview.signature(for: entries)
    }

    private func closeDay() {
        Haptics.tap()
        withAnimation(.snappy) { closing = true }
        Task {
            do {
                _ = try await DayCloser.close(day: day, goals: goals, ctx: ctx)
                Haptics.success()
            } catch {
                closeError = error.localizedDescription
            }
            withAnimation(.snappy) { closing = false }
        }
    }

    private var total: Nutrients { entries.reduce(Nutrients()) { $0 + $1.nutrients } }
    private var selecting: Bool { selection != nil }
    /// Changes whenever something Apple Health should know about changes (entries, amounts, times, water).
    private var healthSignature: String {
        entries.map { "\($0.id):\(Int($0.kcal * 10)):\(Int($0.createdAt.timeIntervalSince1970))" }.joined(separator: "|")
            + "#\(water.reduce(0) { $0 + $1.ml })"
    }
    /// Goal of the shown day (weekday goal, activity bonus, goal valid at that time).
    private var target: DayTarget { goals.target(for: day) }

    private var mood: CatMood {
        if justAte { return .eating }
        let promille = Calendar.current.isDateInToday(day)
            ? BloodAlcohol.make(entries: entries + previous, goals: goals, weight: nil).value(at: .now) : 0
        return CatMood.of(entries: entries, target: target, waterML: water.reduce(0) { $0 + $1.ml }, goals: goals,
                          day: day, promille: promille)
    }

    var body: some View {
        List {
            Group {
                VStack(spacing: Theme.Space.l) {
                    Button { sheet = .overview } label: { SummaryCard(total: total, mood: mood, burst: burst, target: target) }
                        .buttonStyle(SquishButtonStyle())
                    Divider().overlay(Theme.line)
                    Button { sheet = .nutrients(total) } label: { MacroRow(total: total, target: target) }
                        .buttonStyle(SquishButtonStyle())
                }
                .card(padding: 18)
                if goals.healthScoreEnabled, !entries.isEmpty {
                    let score = HealthScore(entries: entries, goalKcal: target.kcal, goalProtein: target.protein)
                    let baseline = aiBaseline(score)
                    Button { sheet = .score(score, baseline: baseline) } label: { HealthScoreCard(score: score, baseline: baseline) }
                        .buttonStyle(SquishButtonStyle())
                }
                if let review = reviews.first, !entries.isEmpty {
                    Button { sheet = .review(review) } label: { DayReviewCard(review: review, outdated: reviewOutdated) }
                        .buttonStyle(SquishButtonStyle())
                        .transition(.scale(scale: 0.95).combined(with: .opacity))
                }
                if goals.waterEnabled {
                    WaterCard(day: day, logs: water)
                }
            }
            .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)

            Section {
                if entries.isEmpty {
                    EmptyDayView()
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                } else {
                    ForEach(entries) { entry in
                        let expanded = entry.isComposite && expandedMeals.contains(entry.id) && !selecting
                        Group {
                            if selecting {
                                // While selecting, the whole row (circle included) is one plain tap target: no button
                                // press state, no context menu and no inner buttons that could swallow quick taps.
                                HStack(spacing: 10) {
                                    CheckCircle(on: selection?.contains(entry.id) ?? false)
                                        .transition(.move(edge: .leading).combined(with: .opacity))
                                    EntryRow(entry: entry, expanded: nil, onToggle: {})
                                        .allowsHitTesting(false)
                                }
                                .contentShape(Rectangle())
                                .onTapGesture { tap(entry) }
                            } else {
                                Button { tap(entry) } label: {
                                    EntryRow(entry: entry, expanded: entry.isComposite ? expanded : nil, onToggle: { toggle(entry) })
                                }
                                .buttonStyle(SquishButtonStyle())
                                .contextMenu {
                                    Button { duplicate(entry) } label: { Label("Nochmal eintragen", systemImage: "plus.square.on.square") }
                                    Button { withAnimation(.snappy) { selection = [entry.id] } } label: { Label("Auswählen", systemImage: "checkmark.circle") }
                                    Button(role: .destructive) { delete(entry) } label: { Label("Löschen", systemImage: "trash") }
                                }
                            }
                        }
                        .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .swipeActions(edge: .trailing) {
                            if !selecting {
                                Button(role: .destructive) { delete(entry) } label: { Label("Löschen", systemImage: "trash") }
                            }
                        }
                        .swipeActions(edge: .leading) {
                            if !selecting {
                                Button { duplicate(entry) } label: { Label("Nochmal", systemImage: "plus.square.on.square") }
                                    .tint(Theme.accent)
                            }
                        }
                        .transition(.asymmetric(insertion: .scale(scale: 0.9).combined(with: .opacity), removal: .opacity))

                        // Ingredients as their own rows: same look, tap & swipe as entries, joined by a rail.
                        if expanded {
                            let ingredients = entry.ingredients
                            ForEach(Array(ingredients.enumerated()), id: \.element.id) { index, ing in
                                Button { sheet = .ingredient(entry, ing.id) } label: {
                                    IngredientRow(ingredient: ing, compact: true)
                                }
                                .buttonStyle(SquishButtonStyle())
                                .padding(.leading, 24)
                                .background(alignment: .leading) {
                                    IngredientRail(isLast: index == ingredients.count - 1)
                                }
                                .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                                .ingredientActions(entry: entry, id: ing.id) { delete(entry) }
                                .transition(.opacity.combined(with: .offset(y: -12)))
                            }
                        }
                    }
                    if !selecting {
                        DayCloseRow(hasReview: !reviews.isEmpty, outdated: reviewOutdated, running: closing, action: closeDay)
                            .listRowInsets(EdgeInsets(top: 10, leading: 16, bottom: 4, trailing: 16))
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                    }
                }
            } header: {
                HStack {
                    Text("Gegessen").font(Theme.font(18, .bold)).foregroundStyle(Theme.textPrimary)
                    if !entries.isEmpty {
                        Text("\(entries.count)").font(Theme.font(12, .bold)).foregroundStyle(Theme.textSecondary)
                            .padding(.horizontal, 7).padding(.vertical, 2).background(Theme.cardAlt, in: Capsule())
                    }
                    Spacer()
                    if selecting {
                        Button(allSelected ? "Keine" : "Alle") {
                            Haptics.tap()
                            withAnimation(.snappy) { selection = allSelected ? [] : Set(entries.map(\.id)) }
                        }
                        .font(Theme.font(14, .semibold))
                        .foregroundStyle(Theme.accent)
                    } else {
                        optionsMenu
                    }
                }
                .textCase(nil)
                .padding(.top, 0)
            }
            .listSectionSeparator(.hidden)

            Color.clear.frame(height: 20).listRowBackground(Color.clear).listRowSeparator(.hidden)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: entries.count)
        .animation(.snappy, value: selecting)
        .animation(.snappy, value: reviews.first?.createdAt)
        .alert("Tag abschließen fehlgeschlagen", isPresented: Binding(get: { closeError != nil }, set: { if !$0 { closeError = nil } })) {
            Button("OK", role: .cancel) {}
        } message: { Text(closeError ?? "") }
        .onChange(of: entries.map(\.kcal)) { _, _ in WidgetBridge.update(ctx, goals: goals) }
        .onChange(of: water.map(\.ml)) { _, _ in WidgetBridge.update(ctx, goals: goals) }
        .onChange(of: healthSignature) { _, _ in NutritionSync.schedule(day, container: PurrtionApp.container) }
        .onChange(of: entries.count) { old, new in
            guard new > old else { return }
            // Celebrate once the add sheet is gone so the user actually sees it.
            if sheet == nil { celebrate() } else { pendingCelebration = true }
        }
        .onChange(of: sheet?.id) { _, id in
            guard id == nil, pendingCelebration else { return }
            pendingCelebration = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { celebrate() }
        }
    }

    private var allSelected: Bool { !entries.isEmpty && selection?.count == entries.count }

    private var optionsMenu: some View {
        Menu {
            Button { sheet = .suggestions } label: { Label("Was passt noch?", systemImage: "wand.and.stars") }
            Section("Übernehmen") {
                Button { sheet = .copyPicker(source: Calendar.current.date(byAdding: .day, value: -1, to: day)!) } label: {
                    Label("Von gestern …", systemImage: "arrow.uturn.down")
                }
                Button { sheet = .copyFromDay } label: { Label("Von anderem Tag …", systemImage: "calendar") }
            }
            if !entries.isEmpty {
                Section("Einträge") {
                    Button { withAnimation(.snappy) { selection = [] } } label: {
                        Label("Auswählen …", systemImage: "checkmark.circle")
                    }
                    Button { onSaveRecipe(false) } label: { Label("Tag als Rezept speichern", systemImage: "frying.pan") }
                    Button { favoriteAll() } label: { Label("Alle zu Favoriten", systemImage: "star") }
                    Button { sheet = .nutrients(total) } label: { Label("Nährstoffe des Tages", systemImage: "chart.bar.doc.horizontal") }
                }
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(Theme.accent)
                .frame(width: 34, height: 34)
                .background(Theme.accentSoft, in: Circle())
        }
    }

    private func toggle(_ entry: FoodEntry) {
        Haptics.tap()
        withAnimation(.smooth(duration: 0.32)) {
            if expandedMeals.contains(entry.id) { expandedMeals.remove(entry.id) } else { expandedMeals.insert(entry.id) }
        }
    }

    private func tap(_ entry: FoodEntry) {
        if selecting {
            Haptics.tap()
            // No animation: an animated list update still running would swallow the next quick tap.
            if selection?.contains(entry.id) == true { selection?.remove(entry.id) } else { selection?.insert(entry.id) }
        } else {
            sheet = entry.isComposite ? .meal(entry) : .edit(entry)
        }
    }

    private func celebrate() {
        Haptics.success()
        burst += 1
        justAte = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) { justAte = false }
    }

    private func delete(_ e: FoodEntry) {
        Haptics.warning()
        ctx.delete(e)
        try? ctx.save()
    }

    private func favoriteAll() {
        for e in entries {
            guard let food = e.food else { continue }
            ctx.remember(food, quantity: e.quantity, serving: ServingOption(name: e.servingName, grams: e.servingGrams))
            let key = food.id
            if let saved = try? ctx.fetch(FetchDescriptor<SavedFood>(predicate: #Predicate { $0.key == key })).first {
                saved.isFavorite = true
            }
        }
        try? ctx.save()
        Haptics.success()
    }

    private func duplicate(_ e: FoodEntry) {
        guard let food = e.food else { return }
        ctx.log(food, quantity: e.quantity, serving: ServingOption(name: e.servingName, grams: e.servingGrams), day: day)
    }
}

// MARK: - Cards

struct SummaryCard: View {
    let total: Nutrients
    let mood: CatMood
    let burst: Int
    let target: DayTarget
    @EnvironmentObject private var goals: Goals

    var body: some View {
        let remaining = target.kcal - total.kcal
        let progress = total.kcal / max(target.kcal, 1)
        HStack(spacing: 18) {
            ZStack {
                CalorieRing(progress: progress, lineWidth: 14)
                CatMascot(mood: mood, pixel: 4.2).offset(y: mood == .sleeping ? 4 : 2)
                HeartBurst(trigger: burst)
            }
            .frame(width: 136, height: 136)

            VStack(alignment: .leading, spacing: 10) {
                VStack(alignment: .leading, spacing: 0) {
                    Text(remaining >= 0 ? "Übrig" : "Drüber")
                        .font(Theme.font(14, .medium)).foregroundStyle(Theme.textSecondary)
                    Text(abs(remaining).kcalString)
                        .font(Theme.font(38, .heavy))
                        .foregroundStyle(remaining >= 0 ? Theme.textPrimary : Theme.danger)
                        .contentTransition(.numericText(value: remaining))
                        .animation(.snappy, value: remaining)
                    HStack(spacing: 6) {
                        Text("kcal").font(Theme.font(13, .semibold)).foregroundStyle(Theme.textSecondary)
                        if target.activityBonus > 0 {
                            // The activity bonus lives here, next to what it changes – always visible, never truncated.
                            HStack(spacing: 3) {
                                Image(systemName: "flame.fill").font(.system(size: 9, weight: .bold))
                                Text("+\(target.activityBonus.kcalString) durch Aktivität").font(Theme.font(11, .bold))
                            }
                            .foregroundStyle(Theme.accent)
                            .padding(.horizontal, 7).padding(.vertical, 3)
                            .background(Theme.accentSoft, in: Capsule())
                            .lineLimit(1).fixedSize()
                        }
                    }
                }
                HStack(spacing: 12) {
                    stat("Gegessen", total.kcal)
                    stat("Ziel", target.kcal)
                    if goals.activityEnabled || target.manualKcal > 0 {
                        VStack(alignment: .leading, spacing: 1) {
                            HStack(spacing: 2) {
                                Image(systemName: "flame.fill").font(.system(size: 11, weight: .bold)).foregroundStyle(Theme.accent)
                                Text(target.activeKcal.kcalString).font(Theme.font(16, .bold)).foregroundStyle(Theme.textPrimary)
                                    .contentTransition(.numericText(value: target.activeKcal))
                            }
                            HStack(spacing: 3) {
                                Text("Aktiv").font(Theme.font(12)).foregroundStyle(Theme.textSecondary)
                                if target.activityPercent > 0, target.activeKcal > 0 {
                                    Text("\(Int(target.activityPercent)) %").font(Theme.font(11, .bold)).foregroundStyle(Theme.accent)
                                }
                            }
                        }
                        .lineLimit(1).fixedSize()
                    }
                }
            }
            Spacer(minLength: 0)
        }
    }

    private func stat(_ title: String, _ value: Double) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(value.kcalString).font(Theme.font(16, .bold)).foregroundStyle(Theme.textPrimary)
                .contentTransition(.numericText(value: value))
            Text(title).font(Theme.font(12)).foregroundStyle(Theme.textSecondary)
        }
        .lineLimit(1).fixedSize()
    }
}

struct CalorieRing: View {
    var progress: Double
    var lineWidth: CGFloat = 12
    @State private var shown: Double = 0

    var body: some View {
        ZStack {
            Circle().stroke(Theme.accentSoft, lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: min(shown, 1))
                .stroke(Theme.accent, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
            if shown > 1 {
                Circle()
                    .trim(from: 0, to: min(shown - 1, 1))
                    .stroke(Theme.danger, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                    .rotationEffect(.degrees(-90))
            }
        }
        .padding(lineWidth / 2)
        .onAppear { withAnimation(.spring(response: 1, dampingFraction: 0.8).delay(0.1)) { shown = progress } }
        .onChange(of: progress) { _, p in withAnimation(.spring(response: 0.8, dampingFraction: 0.75)) { shown = p } }
    }
}

/// Protein / carbs / fat bars; lives inside the hero card on Today.
struct MacroRow: View {
    let total: Nutrients
    let target: DayTarget

    var body: some View {
        HStack(spacing: 14) {
            MacroBar(name: "Protein", value: total.protein, goal: target.protein, color: Theme.protein)
            MacroBar(name: "Kohlenh.", value: total.carbs, goal: target.carbs, color: Theme.carbs)
            MacroBar(name: "Fett", value: total.fat, goal: target.fat, color: Theme.fat)
        }
    }
}

struct MacroBar: View {
    let name: String
    let value: Double
    let goal: Double
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(name).font(Theme.font(13, .semibold)).foregroundStyle(Theme.textSecondary)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.track(color))
                    Capsule().fill(color)
                        .frame(width: max(8, geo.size.width * min(value / max(goal, 1), 1)))
                        .animation(.spring(response: 0.7, dampingFraction: 0.75), value: value)
                }
            }
            .frame(height: 8)
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value.rounded().clean).font(Theme.font(16, .bold)).foregroundStyle(Theme.textPrimary)
                    .contentTransition(.numericText(value: value))
                Text("/ \(goal.clean) g").font(Theme.font(12)).foregroundStyle(Theme.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct WaterCard: View {
    let day: Date
    let logs: [WaterLog]
    @EnvironmentObject private var goals: Goals
    @Environment(\.modelContext) private var ctx

    private var ml: Int { logs.reduce(0) { $0 + $1.ml } }

    var body: some View {
        let glasses = max(1, goals.waterML / max(goals.waterStep, 1))
        let filled = ml / max(goals.waterStep, 1)
        let total = Text("\(Double(ml) / 1000, format: .number.precision(.fractionLength(0...2))) / \(Double(goals.waterML) / 1000, format: .number.precision(.fractionLength(0...1))) l")
        let label = VStack(alignment: .leading, spacing: 0) {
            Text("Wasser").font(Theme.font(12)).foregroundStyle(Theme.textSecondary)
            total.font(Theme.font(14, .bold)).foregroundStyle(Theme.water)
                .contentTransition(.numericText(value: Double(ml)))
        }
        .fixedSize()
        let glassRow = HStack(spacing: 4) {
            ForEach(0..<min(glasses, 12), id: \.self) { i in
                Button {
                    Haptics.tap()
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                        if i < filled { add(-goals.waterStep) } else { add(goals.waterStep) }
                    }
                } label: {
                    PixelSpriteView(sprite: i < filled ? Sprites.glassFull : Sprites.glassEmpty, pixel: 2.6)
                        .scaleEffect(i < filled ? 1 : 0.92)
                }
                .buttonStyle(SquishButtonStyle())
            }
        }
        // One row when it fits, otherwise the glasses wrap below the label.
        return ViewThatFits(in: .horizontal) {
            HStack(spacing: Theme.Space.m) { label; Spacer(minLength: 0); glassRow }
            VStack(alignment: .leading, spacing: Theme.Space.s) { label; glassRow }
        }
        .card(padding: 14)
    }

    private func add(_ amount: Int) {
        if let log = logs.first {
            log.ml = max(0, log.ml + amount)
        } else if amount > 0 {
            ctx.insert(WaterLog(day: day, ml: amount))
        }
        try? ctx.save()
    }
}

struct EntryRow: View {
    let entry: FoodEntry
    /// Non-nil for recipes / AI meals: shows the expand chevron inside the card.
    var expanded: Bool? = nil
    var onToggle: () -> Void = {}

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(entry.name).font(Theme.font(16, .semibold)).foregroundStyle(Theme.textPrimary).lineLimit(1)
                    if entry.food?.source == .ai { AIBadge() }
                }
                HStack(spacing: 6) {
                    if let brand = entry.brand, !brand.isEmpty {
                        Text(brand).lineLimit(1)
                        Text("·")
                    }
                    Text(entry.amountText).lineLimit(1)
                    Text("·")
                    Text(entry.createdAt.formatted(date: .omitted, time: .shortened)).lineLimit(1)
                }
                .font(Theme.font(13)).foregroundStyle(Theme.textSecondary)
                HStack(spacing: 8) {
                    MacroDot(color: Theme.protein, value: entry.protein)
                    MacroDot(color: Theme.carbs, value: entry.carbs)
                    MacroDot(color: Theme.fat, value: entry.fat)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 0) {
                Text(entry.kcal.kcalString).font(Theme.font(18, .bold)).foregroundStyle(Theme.textPrimary)
                Text("kcal").font(Theme.font(11, .medium)).foregroundStyle(Theme.textSecondary)
            }
            if let expanded {
                Image(systemName: "chevron.down")
                    .font(.system(size: 12, weight: .heavy))
                    .foregroundStyle(expanded ? .white : Theme.accent)
                    .rotationEffect(.degrees(expanded ? 180 : 0))
                    .frame(width: 30, height: 30)
                    .background(expanded ? Theme.accent : Theme.accentSoft, in: Circle())
                    .padding(8)
                    .contentShape(Rectangle())
                    .highPriorityGesture(TapGesture().onEnded { onToggle() })
                    .padding(-8)
                    .accessibilityLabel(expanded ? "Zutaten einklappen" : "Zutaten ausklappen")
                    .accessibilityAddTraits(.isButton)
            }
        }
        .padding(14)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.radiusSmall + 4, style: .continuous))
        .contentShape(Rectangle())
    }
}

struct AIBadge: View {
    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: "sparkles").font(.system(size: 9, weight: .bold))
            Text("KI").font(Theme.font(10, .bold))
        }
        .foregroundStyle(Theme.accent)
        .padding(.horizontal, 6).padding(.vertical, 3)
        .background(Theme.accentSoft, in: Capsule())
        .fixedSize()
    }
}

/// One ingredient of a meal, styled like an entry (slightly more compact when nested on Today).
struct IngredientRow: View {
    let ingredient: RecipeIngredient
    var compact = false

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: compact ? 2 : 3) {
                HStack(spacing: 5) {
                    Text(ingredient.food.displayName).font(Theme.font(compact ? 15 : 16, .semibold))
                        .foregroundStyle(Theme.textPrimary).lineLimit(1)
                    if ingredient.food.source == .ai {
                        Image(systemName: "sparkles").font(.system(size: 10, weight: .bold)).foregroundStyle(Theme.accent)
                    }
                }
                Text(ingredient.amountText).font(Theme.font(compact ? 12 : 13)).foregroundStyle(Theme.textSecondary).lineLimit(1)
                HStack(spacing: 8) {
                    MacroDot(color: Theme.protein, value: ingredient.nutrients.protein)
                    MacroDot(color: Theme.carbs, value: ingredient.nutrients.carbs)
                    MacroDot(color: Theme.fat, value: ingredient.nutrients.fat)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 0) {
                Text(ingredient.nutrients.kcal.kcalString).font(Theme.font(compact ? 16 : 18, .bold)).foregroundStyle(Theme.textPrimary)
                Text("kcal").font(Theme.font(11, .medium)).foregroundStyle(Theme.textSecondary)
            }
        }
        .padding(compact ? 12 : 14)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.radiusSmall + 4, style: .continuous))
        .contentShape(Rectangle())
    }
}

/// Accent line + branch connecting nested ingredient rows to their meal above.
struct IngredientRail: View {
    let isLast: Bool

    var body: some View {
        GeometryReader { g in
            let x: CGFloat = 10
            Path { p in
                p.move(to: CGPoint(x: x, y: -8))
                p.addLine(to: CGPoint(x: x, y: isLast ? g.size.height / 2 - 8 : g.size.height + 8))
                if isLast {
                    p.addQuadCurve(to: CGPoint(x: x + 8, y: g.size.height / 2), control: CGPoint(x: x, y: g.size.height / 2))
                } else {
                    p.move(to: CGPoint(x: x, y: g.size.height / 2))
                }
                p.addLine(to: CGPoint(x: 22, y: g.size.height / 2))
            }
            .stroke(Color(light: 0xFFC6A3, dark: 0x6B4634), style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
        }
        .frame(width: 24)
    }
}

struct MacroDot: View {
    let color: Color
    let value: Double
    var body: some View {
        HStack(spacing: 3) {
            Rectangle().fill(color).frame(width: 6, height: 6)
            Text("\(value.rounded().clean) g").font(Theme.font(12, .medium)).foregroundStyle(Theme.textSecondary)
        }
    }
}

struct EmptyDayView: View {
    var body: some View {
        VStack(spacing: Theme.Space.m) {
            AnimatedSprite(frames: [Sprites.bowl], pixel: 4)
            Text("Der Napf ist noch leer").font(Theme.font(17, .bold)).foregroundStyle(Theme.textPrimary)
            Text("Tippe unten auf eine Option, um dein erstes Essen einzutragen.")
                .font(Theme.font(14)).foregroundStyle(Theme.textSecondary).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Theme.Space.xl)
    }
}

// MARK: - Quick add dock

/// The four ways to log food, always one tap away: a floating glass dock above the tab bar.
struct QuickAddDock: View {
    @Binding var sheet: AddSheet?

    var body: some View {
        HStack(spacing: Theme.Space.xs) {
            action("magnifyingglass", "Suchen", .search, primary: true)
            action("barcode.viewfinder", "Barcode", .barcode)
            action("camera.fill", "Foto", .photo)
            action("bolt.fill", "Schnell", .quick)
        }
        .padding(Theme.Space.xs)
        // Mostly opaque so list rows scrolling underneath don't bleed through the labels.
        .background(Theme.card.opacity(0.9), in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .shadow(color: Theme.cardShadow, radius: 14, y: 6)
        .padding(.horizontal, Theme.Space.l)
        .padding(.vertical, Theme.Space.s)
    }

    private func action(_ icon: String, _ title: String, _ s: AddSheet, primary: Bool = false) -> some View {
        Button { Haptics.tap(); sheet = s } label: {
            VStack(spacing: 3) {
                Image(systemName: icon).font(.system(size: 20, weight: .bold)).frame(height: 24)
                Text(title).font(Theme.font(12, .bold))
            }
            .foregroundStyle(primary ? Color.white : Theme.accent)
            .frame(maxWidth: .infinity).frame(height: 58)
            .background {
                if primary { RoundedRectangle(cornerRadius: 24, style: .continuous).fill(Theme.accent) }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(SquishButtonStyle())
        .accessibilityLabel(title)
    }
}
