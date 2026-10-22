import SwiftUI
import SwiftData

extension Calendar {
    /// Gregorian calendar with weeks always running Monday → Sunday, independent of the region setting.
    static var mondayFirst: Calendar {
        var c = Calendar.current
        c.firstWeekday = 2
        return c
    }
}

/// Goal status of a logged day: green = within, orange = up to 5 % over, red = more.
enum GoalStatus {
    case none, within, slightlyOver, over

    init(kcal: Double, goal: Double) {
        if kcal <= 0 { self = .none }
        else if kcal <= goal { self = .within }
        else if kcal <= goal * 1.05 { self = .slightlyOver }
        else { self = .over }
    }

    var color: Color {
        switch self {
        case .none: Theme.cardAlt
        case .within: Theme.fiber
        case .slightlyOver: Color(hex: 0xFF9F43)   // status colours stay fixed, whatever accent is chosen
        case .over: Theme.danger
        }
    }
}

/// Legend shared by the calendar and the history grid.
struct GoalLegend: View {
    var body: some View {
        HStack(spacing: 12) {
            item(GoalStatus.within.color, "im Ziel")
            item(GoalStatus.slightlyOver.color, "bis +5 %")
            item(GoalStatus.over.color, "drüber")
            item(GoalStatus.none.color, "leer")
        }
        .font(Theme.font(11, .medium))
        .foregroundStyle(Theme.textSecondary)
    }

    private func item(_ color: Color, _ text: String) -> some View {
        HStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 3).fill(color).frame(width: 10, height: 10)
            Text(text)
        }
    }
}

/// Month grid: green = within the calorie goal, orange = up to 5 % over, red = more, grey = nothing logged.
struct CalendarMonthView: View {
    @Binding var month: Date
    var selected: Date? = nil
    var allowFuture = false
    var onSelect: (Date) -> Void
    @EnvironmentObject private var goals: Goals
    @Query private var entries: [FoodEntry]

    private var cal: Calendar { .mondayFirst }

    private var kcalByDay: [Date: Double] {
        var d: [Date: Double] = [:]
        for e in entries { d[e.day, default: 0] += e.kcal }
        return d
    }

    private var days: [Date?] {
        let start = cal.date(from: cal.dateComponents([.year, .month], from: month))!
        let count = cal.range(of: .day, in: .month, for: start)!.count
        let weekday = cal.component(.weekday, from: start)
        let offset = (weekday - cal.firstWeekday + 7) % 7
        return Array(repeating: nil, count: offset) + (0..<count).map { cal.date(byAdding: .day, value: $0, to: start)! }
    }

    var body: some View {
        let stats = kcalByDay
        VStack(spacing: 12) {
            HStack {
                Button { shift(-1) } label: { Image(systemName: "chevron.left") }
                Spacer()
                Text(month.formatted(.dateTime.month(.wide).year())).font(Theme.font(17, .bold)).foregroundStyle(Theme.textPrimary)
                Spacer()
                let atCurrent = !allowFuture && cal.isDate(month, equalTo: .now, toGranularity: .month)
                Button { shift(1) } label: { Image(systemName: "chevron.right") }
                    .disabled(atCurrent)
                    .opacity(atCurrent ? 0.3 : 1)
            }
            .font(.system(size: 15, weight: .bold))
            .foregroundStyle(Theme.textPrimary)
            .buttonStyle(SquishButtonStyle())

            let symbols = cal.veryShortStandaloneWeekdaySymbols
            let ordered = Array(symbols[(cal.firstWeekday - 1)...] + symbols[..<(cal.firstWeekday - 1)])
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 7), spacing: 6) {
                ForEach(Array(ordered.enumerated()), id: \.offset) { _, s in
                    Text(s).font(Theme.font(11, .semibold)).foregroundStyle(Theme.textSecondary)
                }
                ForEach(Array(days.enumerated()), id: \.offset) { _, day in
                    if let day { cell(day, kcal: stats[day]) } else { Color.clear.frame(height: 38) }
                }
            }

            GoalLegend()
        }
    }

    private func cell(_ day: Date, kcal: Double?) -> some View {
        let future = !allowFuture && day > cal.startOfDay(for: .now)
        let color = GoalStatus(kcal: kcal ?? 0, goal: goals.target(for: day).kcal).color
        let isSelected = selected.map { cal.isDate($0, inSameDayAs: day) } ?? false
        return Button { if !future { Haptics.tap(); onSelect(day) } } label: {
            Text("\(cal.component(.day, from: day))")
                .font(Theme.font(14, cal.isDateInToday(day) ? .heavy : .semibold))
                .foregroundStyle(kcal ?? 0 > 0 ? .white : Theme.textPrimary)
                .frame(maxWidth: .infinity)
                .frame(height: 38)
                .background(color.opacity(kcal ?? 0 > 0 ? 0.9 : 1), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(isSelected ? Theme.accent : (cal.isDateInToday(day) ? Theme.textSecondary : .clear), lineWidth: 2))
                .opacity(future ? 0.35 : 1)
        }
        .buttonStyle(SquishButtonStyle())
    }

    private func shift(_ d: Int) {
        Haptics.tap()
        withAnimation(Motion.quick) { month = cal.date(byAdding: .month, value: d, to: month)! }
    }
}

/// Calendar in a sheet to pick a day.
struct CalendarSheet: View {
    let title: String
    var allowFuture = false
    let onPick: (Date) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var month = Date()

    var body: some View {
        NavigationStack {
            CalendarMonthView(month: $month, allowFuture: allowFuture) { day in
                onPick(day)
                dismiss()
            }
            .card()
            .padding(16)
            .frame(maxHeight: .infinity, alignment: .top)
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { dismiss() } } }
        }
        .presentationDetents([.medium, .large])
    }
}

/// Summary of a single past day (from the history calendar).
struct DaySummarySheet: View {
    let day: Date
    @EnvironmentObject private var goals: Goals
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var ctx
    @Query private var entries: [FoodEntry]

    init(day: Date) {
        self.day = day
        let d = day
        _entries = Query(filter: #Predicate<FoodEntry> { $0.day == d }, sort: \FoodEntry.createdAt)
    }

    var body: some View {
        NavigationStack {
            List {
                let total = entries.reduce(Nutrients()) { $0 + $1.nutrients }
                let target = goals.target(for: day)
                Section {
                    HStack {
                        VStack(alignment: .leading) {
                            Text("\(total.kcal.kcalString) kcal").font(Theme.font(26, .heavy))
                            let status = GoalStatus(kcal: total.kcal, goal: target.kcal)
                            Text(total.kcal <= target.kcal ? "Im Ziel (\(target.kcal.kcalString))" : "\((total.kcal - target.kcal).kcalString) kcal über dem Ziel")
                                .font(Theme.font(13)).foregroundStyle(status == .none ? Theme.fiber : status.color)
                        }
                        Spacer()
                        if goals.healthScoreEnabled, !entries.isEmpty {
                            let score = HealthScore(entries: entries, goalKcal: target.kcal, goalProtein: target.protein)
                            VStack(spacing: 0) {
                                Text("\(score.score)").font(Theme.font(22, .heavy)).foregroundStyle(score.color)
                                Text("Score").font(Theme.font(11)).foregroundStyle(Theme.textSecondary)
                            }
                        }
                    }
                    HStack(spacing: 12) {
                        MacroDot(color: Theme.protein, value: total.protein)
                        MacroDot(color: Theme.carbs, value: total.carbs)
                        MacroDot(color: Theme.fat, value: total.fat)
                    }
                }
                .listRowBackground(Theme.card)
                Section("Einträge") {
                    ForEach(entries) { e in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(e.name).font(Theme.font(15, .semibold))
                                Text(e.amountText).font(Theme.font(12)).foregroundStyle(Theme.textSecondary)
                            }
                            Spacer()
                            Text("\(e.kcal.kcalString) kcal").font(Theme.font(14, .semibold))
                        }
                    }
                    .onDelete { idx in
                        idx.map { entries[$0] }.forEach(ctx.delete)
                        try? ctx.save()
                    }
                    if entries.isEmpty { Text("Keine Einträge").foregroundStyle(Theme.textSecondary) }
                }
                .listRowBackground(Theme.card)
            }
            .scrollContentBackground(.hidden)
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle(day.formatted(.dateTime.weekday(.wide).day().month(.wide)))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Fertig") { dismiss() } } }
        }
        .presentationDetents([.medium, .large])
    }
}
