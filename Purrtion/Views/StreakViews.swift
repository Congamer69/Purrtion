import SwiftUI
import SwiftData

/// Streak overview: count, freezes and the last five weeks.
struct StreakSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var ctx
    @Query private var entries: [FoodEntry]
    @State private var state = Streak.State()

    private let cal = Calendar.mondayFirst
    private var today: Date { Calendar.current.startOfDay(for: .now) }
    private var weekStart: Date { cal.dateInterval(of: .weekOfYear, for: today)!.start }
    private var gridStart: Date { cal.date(byAdding: .day, value: -28, to: weekStart)! }

    init() {
        let start = Calendar.mondayFirst.date(byAdding: .day, value: -28,
                                              to: Calendar.mondayFirst.dateInterval(of: .weekOfYear, for: .now)!.start)!
        _entries = Query(filter: #Predicate<FoodEntry> { $0.day >= start })
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Theme.Space.l) {
                    hero
                    freezeCard
                    calendarCard
                    Text("Eine Serie zählt jeden Tag, an dem du etwas einträgst. Fehlt ein Tag, rettet ein Streak-Freeze deine Serie automatisch. Der Tag zählt dann nicht mit, bricht sie aber nicht ab. Nach jeweils 7 Tagen in Folge bekommst du einen neuen Freeze, du kannst höchstens \(Streak.maxFreezes) sammeln.")
                        .font(Theme.font(12)).foregroundStyle(Theme.textSecondary)
                        .padding(.horizontal, Theme.Space.s)
                }
                .padding(Theme.Space.l)
            }
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle("Serie")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Fertig") { dismiss() } } }
            .task { state = Streak.refresh(ctx: ctx) }
        }
    }

    private var hero: some View {
        VStack(spacing: Theme.Space.s) {
            CatMascot(mood: state.loggedToday ? .proud : (state.count > 0 ? .idle : .sleeping), pixel: 5)
            HStack(spacing: 6) {
                Image(systemName: "flame.fill").font(.system(size: 30, weight: .bold))
                Text("\(state.count)").font(Theme.font(44, .heavy)).contentTransition(.numericText(value: Double(state.count)))
            }
            .foregroundStyle(state.loggedToday ? Theme.accent : Theme.textSecondary)
            Text(state.count == 1 ? "Tag in Folge" : "Tage in Folge").font(Theme.font(17, .bold)).foregroundStyle(Theme.textPrimary)
            Text(state.loggedToday ? "Heute ist erledigt." : (state.count > 0 ? "Trag heute etwas ein, um die Serie zu halten." : "Trag etwas ein, um eine neue Serie zu starten."))
                .font(Theme.font(14)).foregroundStyle(Theme.textSecondary).multilineTextAlignment(.center)
            if state.best > state.count {
                Text("Rekord: \(state.best) Tage").font(Theme.font(12, .bold)).foregroundStyle(Theme.accent)
                    .padding(.horizontal, 10).padding(.vertical, 4).background(Theme.accentSoft, in: Capsule())
            }
        }
        .frame(maxWidth: .infinity)
        .card(padding: Theme.Space.xl)
    }

    private var freezeCard: some View {
        HStack(spacing: Theme.Space.m) {
            HStack(spacing: Theme.Space.xs) {
                ForEach(0..<Streak.maxFreezes, id: \.self) { i in
                    Image(systemName: "snowflake").font(.system(size: 20, weight: .bold))
                        .foregroundStyle(i < state.freezes ? Theme.water : Theme.textSecondary.opacity(0.35))
                        .frame(width: 40, height: 40)
                        .background(i < state.freezes ? Theme.water.opacity(0.16) : Theme.cardAlt, in: Circle())
                }
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("Streak-Freeze").font(Theme.font(17, .bold)).foregroundStyle(Theme.textPrimary)
                Text(state.freezes == 0 ? "Keiner übrig, der nächste kommt nach 7 Tagen in Folge." : "\(state.freezes) von \(Streak.maxFreezes) bereit")
                    .font(Theme.font(12)).foregroundStyle(Theme.textSecondary)
            }
            Spacer(minLength: 0)
        }
        .card()
    }

    private var calendarCard: some View {
        let logged = Set(entries.map(\.day))
        return VStack(spacing: Theme.Space.s) {
            HStack {
                ForEach(["Mo", "Di", "Mi", "Do", "Fr", "Sa", "So"], id: \.self) {
                    Text($0).font(Theme.font(12)).foregroundStyle(Theme.textSecondary).frame(maxWidth: .infinity)
                }
            }
            ForEach(0..<5, id: \.self) { w in
                HStack(spacing: 6) {
                    ForEach(0..<7, id: \.self) { i in
                        let d = cal.date(byAdding: .day, value: w * 7 + i, to: gridStart)!
                        cell(d, logged: logged.contains(d))
                    }
                }
            }
            HStack(spacing: Theme.Space.l) {
                legend(Theme.accent, "eingetragen")
                legend(Theme.water, "Freeze")
            }
            .font(Theme.font(12)).foregroundStyle(Theme.textSecondary)
            .padding(.top, Theme.Space.xs)
        }
        .card()
    }

    private func cell(_ d: Date, logged: Bool) -> some View {
        let frozen = state.frozen.contains(d)
        let future = d > today
        let isToday = d == today
        return RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(logged ? Theme.accent : (frozen ? Theme.water.opacity(0.85) : Theme.cardAlt))
            .frame(height: 38)
            .overlay {
                if frozen && !logged {
                    Image(systemName: "snowflake").font(.system(size: 14, weight: .bold)).foregroundStyle(.white)
                } else {
                    Text("\(Calendar.current.component(.day, from: d))").font(Theme.font(12, .bold))
                        .foregroundStyle(logged ? Color.white : Theme.textSecondary)
                }
            }
            .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(isToday ? Theme.textPrimary : .clear, lineWidth: 2))
            .opacity(future ? 0.3 : 1)
            .frame(maxWidth: .infinity)
    }

    private func legend(_ color: Color, _ text: String) -> some View {
        HStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 3).fill(color).frame(width: 12, height: 12)
            Text(text)
        }
    }
}
