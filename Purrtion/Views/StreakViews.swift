import SwiftUI
import SwiftData

/// Streak overview: count, freezes and the last five weeks.
struct StreakSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var ctx
    @Query private var entries: [FoodEntry]
    @EnvironmentObject private var goals: Goals
    @State private var state = Streak.State()
    @AppStorage(Extras.shopKey) private var shopOn = true

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
                    statsRow
                    if shopOn { StreakShopCard(bestStreak: max(state.best, state.count)) { state = Streak.refresh(ctx: ctx) } }
                    milestonesCard
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

    private var active: Bool { state.loggedToday }

    private var hero: some View {
        VStack(spacing: Theme.Space.m) {
            CatMascot(mood: state.loggedToday ? .proud : (state.count > 0 ? .idle : .sleeping), pixel: 5)
            // Flame and count side by side; the glow is a small soft halo behind the flame only.
            HStack(spacing: 10) {
                ZStack {
                    TimelineView(.animation(paused: !active)) { ctx in
                        let t = ctx.date.timeIntervalSinceReferenceDate
                        let pulse = active ? (sin(t * 2.2) + 1) / 2 : 0
                        Circle()
                            .fill(RadialGradient(colors: [Theme.accent.opacity(active ? 0.30 : 0), .clear], center: .center, startRadius: 2, endRadius: 34))
                            .frame(width: 68, height: 68)
                            .scaleEffect(1 + pulse * 0.12)
                    }
                    Image(systemName: "flame.fill")
                        .font(.system(size: 40, weight: .bold))
                        .foregroundStyle(active ? AnyShapeStyle(LinearGradient(colors: [Color(hex: 0xFFC145), Theme.accent], startPoint: .top, endPoint: .bottom)) : AnyShapeStyle(Theme.textSecondary.opacity(0.5)))
                        .symbolEffect(.pulse, isActive: active)
                }
                .frame(width: 56, height: 68)
                Text("\(state.count)").font(Theme.font(56, .heavy)).foregroundStyle(Theme.textPrimary)
                    .contentTransition(.numericText(value: Double(state.count)))
            }
            VStack(spacing: 4) {
                Text(state.count == 1 ? "Tag in Folge" : "Tage in Folge").font(Theme.font(17, .bold)).foregroundStyle(Theme.textPrimary)
                Text(state.loggedToday ? "Heute ist erledigt." : (state.count > 0 ? "Trag heute etwas ein, um die Serie zu halten." : "Trag etwas ein, um eine neue Serie zu starten."))
                    .font(Theme.font(14)).foregroundStyle(Theme.textSecondary).multilineTextAlignment(.center)
            }
            nextFreezeBar
        }
        .frame(maxWidth: .infinity)
        .card(padding: Theme.Space.xl)
    }

    /// Progress to the next freeze: the current run modulo 7.
    private var nextFreezeBar: some View {
        let full = state.freezes >= Streak.maxFreezes
        let into = state.count % Streak.daysPerFreeze
        let progress = full ? 1 : Double(into) / Double(Streak.daysPerFreeze)
        return VStack(spacing: 6) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.track(Theme.water))
                    Capsule().fill(LinearGradient(colors: [Theme.water, Theme.accent], startPoint: .leading, endPoint: .trailing))
                        .frame(width: max(10, geo.size.width * progress))
                }
            }
            .frame(height: 10)
            HStack(spacing: 4) {
                Image(systemName: "snowflake").font(.system(size: 11, weight: .bold))
                Text(full ? "Alle Freezes gefüllt" : "Noch \(Streak.daysPerFreeze - into) \(Streak.daysPerFreeze - into == 1 ? "Tag" : "Tage") bis zum nächsten Freeze")
            }
            .font(Theme.font(12, .bold)).foregroundStyle(Theme.water)
        }
        .padding(.top, Theme.Space.xs)
    }

    private var statsRow: some View {
        let logged = Set(entries.map(\.day))
        let activeDays = logged.filter { $0 <= today }.count
        return HStack(spacing: Theme.Space.m) {
            statTile("trophy.fill", "\(max(state.best, state.count))", "Rekord", Color(hex: 0xFFC145))
            statTile("calendar", "\(activeDays)", "Tage in 5 Wochen", Theme.accent)
            statTile("snowflake", "\(state.frozen.count)", "Freezes genutzt", Theme.water)
        }
    }

    private func statTile(_ icon: String, _ value: String, _ label: String, _ tint: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon).font(.system(size: 15, weight: .bold)).foregroundStyle(tint)
                .frame(width: 34, height: 34).background(tint.opacity(0.16), in: Circle())
            Text(value).font(Theme.font(22, .bold)).foregroundStyle(Theme.textPrimary).contentTransition(.numericText())
            Text(label).font(Theme.font(12)).foregroundStyle(Theme.textSecondary).multilineTextAlignment(.center).lineLimit(2)
        }
        .frame(maxWidth: .infinity)
        .card(padding: Theme.Space.m)
    }

    private static let milestones = [3, 7, 14, 30, 60, 100, 200, 365]

    /// Badges for streak lengths: reached ones glow in the accent, the next one shows how far you are.
    private var milestonesCard: some View {
        let reached = max(state.best, state.count)
        let next = Self.milestones.first { $0 > state.count }
        return VStack(alignment: .leading, spacing: Theme.Space.m) {
            Text("Meilensteine").font(Theme.font(17, .bold)).foregroundStyle(Theme.textPrimary)
            // Two rows of four so every badge stays inside the card.
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: Theme.Space.s), count: 4), spacing: Theme.Space.m) {
                ForEach(Self.milestones, id: \.self) { m in
                    let done = reached >= m
                    let isNext = m == next
                    VStack(spacing: 6) {
                        ZStack {
                            Circle().fill(done ? AnyShapeStyle(LinearGradient(colors: [Color(hex: 0xFFC145), Theme.accent], startPoint: .top, endPoint: .bottom)) : AnyShapeStyle(Theme.cardAlt))
                            if isNext {
                                Circle().trim(from: 0, to: Double(state.count) / Double(m))
                                    .stroke(Theme.accent, style: StrokeStyle(lineWidth: 3.5, lineCap: .round))
                                    .rotationEffect(.degrees(-90))
                                    .padding(-4)
                            }
                            Image(systemName: done ? "flame.fill" : "lock.fill")
                                .font(.system(size: done ? 22 : 15, weight: .bold))
                                .foregroundStyle(done ? Color.white : Theme.textSecondary.opacity(0.6))
                        }
                        .frame(width: 52, height: 52)
                        .padding(4)
                        Text("\(m)").font(Theme.font(14, .bold)).foregroundStyle(done ? Theme.textPrimary : Theme.textSecondary)
                    }
                }
            }
            if let next {
                Text("Noch \(next - state.count) \(next - state.count == 1 ? "Tag" : "Tage") bis \(next) in Folge.")
                    .font(Theme.font(12)).foregroundStyle(Theme.textSecondary)
            } else {
                Text("Alle Meilensteine erreicht.").font(Theme.font(12)).foregroundStyle(Theme.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
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

    /// Last five weeks as a chain: neighbouring logged days are joined, so a streak reads as one run.
    private var calendarCard: some View {
        let logged = Set(entries.map(\.day))
        return VStack(spacing: Theme.Space.s) {
            HStack {
                ForEach(["Mo", "Di", "Mi", "Do", "Fr", "Sa", "So"], id: \.self) {
                    Text($0).font(Theme.font(12)).foregroundStyle(Theme.textSecondary).frame(maxWidth: .infinity)
                }
            }
            ForEach(0..<5, id: \.self) { w in
                HStack(spacing: 0) {
                    ForEach(0..<7, id: \.self) { i in
                        let d = cal.date(byAdding: .day, value: w * 7 + i, to: gridStart)!
                        let prev = cal.date(byAdding: .day, value: -1, to: d)!
                        let next = cal.date(byAdding: .day, value: 1, to: d)!
                        let on = counts(d, logged)
                        cell(d, logged: logged.contains(d),
                             joinLeft: i > 0 && on && counts(prev, logged),
                             joinRight: i < 6 && on && counts(next, logged))
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

    private func counts(_ d: Date, _ logged: Set<Date>) -> Bool { logged.contains(d) || state.frozen.contains(d) }

    private func cell(_ d: Date, logged: Bool, joinLeft: Bool, joinRight: Bool) -> some View {
        let frozen = state.frozen.contains(d) && !logged
        let future = d > today
        let isToday = d == today
        let tint = frozen ? Theme.water : Theme.accent
        return ZStack {
            // Bridge to the neighbouring days of the run.
            HStack(spacing: 0) {
                Rectangle().fill(tint.opacity(0.32)).opacity(joinLeft ? 1 : 0)
                Rectangle().fill(tint.opacity(0.32)).opacity(joinRight ? 1 : 0)
            }
            .frame(height: 22)
            Circle()
                .fill(logged || frozen ? tint : Theme.cardAlt)
                .frame(width: 36, height: 36)
                .overlay {
                    if frozen {
                        Image(systemName: "snowflake").font(.system(size: 14, weight: .bold)).foregroundStyle(.white)
                    } else if logged && isToday {
                        Image(systemName: "flame.fill").font(.system(size: 15, weight: .bold)).foregroundStyle(.white)
                    } else {
                        Text("\(Calendar.current.component(.day, from: d))").font(Theme.font(12, .bold))
                            .foregroundStyle(logged ? Color.white : Theme.textSecondary)
                    }
                }
                .overlay(Circle().stroke(isToday ? Theme.textPrimary : .clear, lineWidth: 2).padding(-3))
        }
        .opacity(future ? 0.3 : 1)
        .frame(maxWidth: .infinity, minHeight: 42)
    }

    private func legend(_ color: Color, _ text: String) -> some View {
        HStack(spacing: 6) {
            Circle().fill(color).frame(width: 12, height: 12)
            Text(text)
        }
    }
}

/// The streak shop. Its own view with its own state, so buying and switching categories does not redraw the whole streak page.
struct StreakShopCard: View {
    let bestStreak: Int
    var onFreezeBought: () -> Void = {}
    @Environment(\.modelContext) private var ctx
    @EnvironmentObject private var goals: Goals
    @State private var points = 0
    @State private var kind = ShopItem.Kind.fur
    @State private var shopTick = 0
    @State private var toast: String?

    private var balance: Int { Shop.balance(earned: points) }

    var body: some View {
        let items = Shop.items.filter { $0.kind == kind }
        return VStack(alignment: .leading, spacing: Theme.Space.m) {
            HStack {
                Text("Shop").font(Theme.font(17, .bold)).foregroundStyle(Theme.textPrimary)
                Spacer()
                HStack(spacing: 5) {
                    PixelSpriteView(sprite: Sprites.paw, pixel: 2)
                    Text("\(balance)").font(Theme.font(15, .heavy)).foregroundStyle(Theme.textPrimary).contentTransition(.numericText(value: Double(balance)))
                }
                .padding(.horizontal, 10).padding(.vertical, 5).background(Theme.accentSoft, in: Capsule())
            }
            Text("Punkte gibt es für jeden eingetragenen Tag (5), für Tage nahe am Ziel (+10) und für Meilensteine.")
                .font(Theme.font(12)).foregroundStyle(Theme.textSecondary)
            Picker("Kategorie", selection: $kind) {
                ForEach(ShopItem.Kind.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: Theme.Space.s), count: 3), spacing: Theme.Space.s) {
                ForEach(items) { shopTile($0) }
            }
            if !(UserDefaults.standard.string(forKey: "shop.hat") ?? "").isEmpty || !(UserDefaults.standard.string(forKey: "shop.glasses") ?? "").isEmpty
                || !(UserDefaults.standard.string(forKey: "shop.scarf") ?? "").isEmpty {
                Button("Alles ausziehen") { Shop.takeOffAll(); shopTick += 1; Haptics.tap() }.font(Theme.font(14, .semibold))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
        .task(id: bestStreak) { points = Shop.earned(ctx: ctx, goals: goals, bestStreak: bestStreak) }
        .overlay(alignment: .bottom) {
            if let toast {
                Text(toast).font(Theme.font(14, .bold)).foregroundStyle(.white)
                    .padding(.horizontal, 16).padding(.vertical, 10).background(Theme.accent, in: Capsule())
                    .offset(y: 18).transition(.scale(scale: 0.85).combined(with: .opacity))
            }
        }
    }

    private func preview(_ item: ShopItem) -> some View {
        var outfit = Outfit()
        var palette = CatPalette.byID(UserDefaults.standard.string(forKey: "catPalette") ?? CatPalette.ginger.id)
        switch item.kind {
        case .fur: palette = CatPalette.byID(item.id)
        case .hat: outfit.hat = item.id
        case .glasses: outfit.glasses = item.id
        case .scarf: outfit.scarf = item.id
        case .extra: break
        }
        return Group {
            if item.kind == .extra {
                Image(systemName: "snowflake").font(.system(size: 30, weight: .bold)).foregroundStyle(Theme.water).frame(width: 56, height: 56)
            } else {
                PixelSpriteView(sprite: Sprites.sit, pixel: 3.4, palette: palette, outfit: outfit)
            }
        }
    }

    private func shopTile(_ item: ShopItem) -> some View {
        _ = shopTick
        let owned = Shop.owned.contains(item.id)
        let worn = Shop.isWorn(item)
        let affordable = balance >= item.price
        let freezeFull = item.kind == .extra && (UserDefaults.standard.object(forKey: "streak.freezes") as? Int ?? 1) >= Streak.maxFreezes
        return Button {
            if owned {
                Shop.equip(item); Haptics.tap()
            } else if freezeFull {
                flash("Du hast schon alle Freezes.")
            } else if Shop.buy(item, balance: balance) {
                Haptics.success()
                onFreezeBought()
                flash(item.kind == .extra ? "Freeze gekauft" : "\(item.name) gekauft")
            } else {
                Haptics.warning()
                flash("Dir fehlen \(item.price - balance) Punkte.")
            }
            shopTick += 1
        } label: {
            VStack(spacing: 6) {
                preview(item).frame(height: 58)
                Text(item.name).font(Theme.font(12, .bold)).foregroundStyle(Theme.textPrimary).lineLimit(1).minimumScaleFactor(0.8)
                Group {
                    if worn { Text("Getragen").foregroundStyle(Theme.accentText) }
                    else if owned { Text("Anziehen").foregroundStyle(Theme.textSecondary) }
                    else { Text("\(item.price)").foregroundStyle(affordable && !freezeFull ? Theme.textPrimary : Theme.textSecondary.opacity(0.7)) }
                }
                .font(Theme.font(12, .heavy))
            }
            .frame(maxWidth: .infinity).padding(.vertical, 10)
            .background(worn ? Theme.accentSoft : Theme.cardAlt, in: RoundedRectangle(cornerRadius: Theme.radiusSmall, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Theme.radiusSmall, style: .continuous).stroke(worn ? Theme.accent : .clear, lineWidth: 2))
            .opacity(owned || affordable ? 1 : 0.7)
        }
        .buttonStyle(SquishButtonStyle())
    }

    private func flash(_ text: String) {
        withAnimation(Motion.quick) { toast = text }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) { withAnimation(Motion.quick) { toast = nil } }
    }
}
