import SwiftUI
import SwiftData

/// Friends: leaderboard over many metrics, week comparison, requests and invites.
struct FriendsView: View {
    @EnvironmentObject private var goals: Goals
    @Environment(\.modelContext) private var ctx
    @ObservedObject private var store = FriendsStore.shared
    @AppStorage(FriendsStore.nameKey) private var name = ""
    @AppStorage("catPalette") private var paletteID = CatPalette.ginger.id
    @AppStorage("friends.metric") private var metric: FriendMetric = .streak
    @State private var showCode = false
    @State private var showManage = false
    @State private var detail: FriendsStore.Person?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    if !store.isAvailable {
                        info("Nicht eingerichtet", "Für die Freunde-Seite fehlt in diesem Build die Firebase-Konfiguration (siehe backend/README.md).")
                    } else if !store.isSetUp {
                        FriendsSetupCard()
                    } else {
                        meCard
                        if !store.incoming.isEmpty { requestsCard }
                        if !store.outgoing.isEmpty { outgoingCard }
                        let myStats = FriendStats.compute(ctx: ctx, goals: goals, shareWeight: false)
                        if store.friends.isEmpty {
                            info("Noch keine Freunde", "Teile deinen Einladungslink oder gib den Code eines Freundes ein. Sobald ihr euch gegenseitig hinzugefügt habt, erscheint hier eure Rangliste.")
                        } else {
                            todayCard(myStats)
                            leaderboard(myStats)
                            weekCard(myStats)
                        }
                        footer
                    }
                }
                .padding(16)
            }
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle("Freunde")
            .toolbar {
                if store.isSetUp {
                    ToolbarItem(placement: .topBarLeading) {
                        Button { showManage = true } label: { Image(systemName: "person.2.badge.gearshape") }
                            .accessibilityLabel("Freunde verwalten")
                    }
                    ToolbarItem(placement: .primaryAction) {
                        Button { showCode = true } label: { Image(systemName: "person.badge.plus") }
                            .accessibilityLabel("Code eingeben")
                    }
                }
            }
            // Own task, so the request survives the end of the pull gesture.
            .refreshable { await Task { await store.refresh(ctx: ctx, goals: goals, force: true) }.value }
            .task { await store.refresh(ctx: ctx, goals: goals) }
            // While a request is open, look again every 30 seconds so an accepted request shows up by itself.
            .task(id: store.outgoing.count + store.incoming.count) {
                while !Task.isCancelled, !store.outgoing.isEmpty || !store.incoming.isEmpty {
                    try? await Task.sleep(for: .seconds(30))
                    guard !Task.isCancelled else { return }
                    await store.refresh(ctx: ctx, goals: goals)
                }
            }
            .sheet(isPresented: $showManage) { FriendsManageView() }
            .sheet(isPresented: $showCode) { CodeEntrySheet() }
            .sheet(item: $detail) { FriendDetailSheet(person: $0) }
            .sheet(item: $store.incomingCode) { CodeEntrySheet(prefill: $0) }
            .alert("Fehler", isPresented: Binding(get: { store.error != nil && !showCode && store.incomingCode == nil },
                                                  set: { if !$0 { store.error = nil } })) {
                Button("OK", role: .cancel) {}
            } message: { Text(store.error ?? "") }
        }
    }

    /// Me + friends with the chosen metric, best first.
    private func ranking(_ myStats: FriendStats) -> [(person: FriendsStore.Person, value: Double?, isMe: Bool)] {
        let mine = FriendsStore.Person(id: store.uid ?? "me", name: name, palette: paletteID, stats: myStats, updated: .now)
        let all = [(mine, metric.value(myStats), true)] + store.friends.map { ($0, metric.value($0.stats), false) }
        return all.sorted { ($0.1 ?? -1) > ($1.1 ?? -1) }.map { (person: $0.0, value: $0.1, isMe: $0.2) }
    }

    // MARK: Cards

    private var meCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 14) {
                CatMascot(mood: .happy, pixel: 3.4)
                VStack(alignment: .leading, spacing: 4) {
                    Text(name).font(Theme.font(20, .bold)).foregroundStyle(Theme.textPrimary)
                    HStack(spacing: 6) {
                        Text("Dein Code").font(Theme.font(12)).foregroundStyle(Theme.textSecondary)
                        Text(store.me?.code ?? "–").font(.system(size: 15, weight: .bold, design: .monospaced))
                            .foregroundStyle(Theme.accent).textSelection(.enabled)
                    }
                }
                Spacer(minLength: 0)
            }
            HStack(spacing: 10) {
                if let link = store.inviteLink {
                    ShareLink(item: link, subject: Text("Purrtion"),
                              message: Text("Lass uns auf Purrtion vergleichen! 🐾 Mein Code: \(store.me?.code ?? "")")) {
                        Label("Einladen", systemImage: "square.and.arrow.up").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(PillButtonStyle())
                }
                Button { showCode = true } label: {
                    Label("Code", systemImage: "keyboard").frame(maxWidth: .infinity)
                }
                .buttonStyle(PillButtonStyle(filled: false))
            }
        }
        .card()
    }

    private var requestsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Anfragen", systemImage: "person.crop.circle.badge.questionmark")
                .font(Theme.font(17, .bold)).foregroundStyle(Theme.textPrimary)
            ForEach(store.incoming) { p in
                HStack(spacing: 12) {
                    PersonCat(person: p, pixel: 2.4)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(p.name).font(Theme.font(16, .semibold)).foregroundStyle(Theme.textPrimary)
                        Text("möchte mit dir vergleichen").font(Theme.font(12)).foregroundStyle(Theme.textSecondary)
                    }
                    Spacer()
                    Button {
                        Haptics.tap()
                        Task { await store.decline(p.id, ctx: ctx, goals: goals) }
                    } label: {
                        Image(systemName: "xmark").font(.system(size: 14, weight: .bold)).foregroundStyle(Theme.textSecondary)
                            .frame(width: 38, height: 38).background(Theme.cardAlt, in: Circle())
                    }
                    Button {
                        Haptics.success()
                        Task { await store.accept(p.id, ctx: ctx, goals: goals) }
                    } label: {
                        Image(systemName: "checkmark").font(.system(size: 14, weight: .bold)).foregroundStyle(.white)
                            .frame(width: 38, height: 38).background(Theme.accent, in: Circle())
                    }
                }
                .buttonStyle(SquishButtonStyle())
            }
        }
        .card()
    }

    private var outgoingCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Gesendet").font(Theme.font(15, .bold)).foregroundStyle(Theme.textSecondary)
            Text("Sobald die Anfrage angenommen ist, erscheint ihr hier automatisch in der Rangliste.")
                .font(Theme.font(12)).foregroundStyle(Theme.textSecondary)
            ForEach(store.outgoing, id: \.id) { o in
                HStack {
                    Image(systemName: "hourglass").foregroundStyle(Theme.textSecondary)
                    Text(o.label).font(Theme.font(15)).foregroundStyle(Theme.textPrimary)
                    Text("wartet auf Bestätigung").font(Theme.font(12)).foregroundStyle(Theme.textSecondary)
                    Spacer()
                    Button("Zurückziehen") { Task { await store.remove(o.id, ctx: ctx, goals: goals) } }
                        .font(Theme.font(13, .semibold)).foregroundStyle(Theme.accent)
                }
            }
        }
        .card()
    }

    private func leaderboard(_ myStats: FriendStats) -> some View {
        let rows = ranking(myStats)
        let best = rows.compactMap(\.value).max() ?? 1
        let scale = metric.scale > 0 ? metric.scale : max(best, 1)
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Rangliste", systemImage: "trophy.fill").font(Theme.font(17, .bold)).foregroundStyle(Theme.textPrimary)
                Spacer()
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(FriendMetric.allCases) { m in
                        Button {
                            Haptics.select()
                            withAnimation(.snappy) { metric = m }
                        } label: {
                            Label(m.short, systemImage: m.icon).font(Theme.font(13, .semibold))
                                .foregroundStyle(metric == m ? .white : Theme.textSecondary)
                                .padding(.horizontal, 12).frame(height: 34)
                                .background(metric == m ? Theme.accent : Theme.cardAlt, in: Capsule())
                        }
                        .buttonStyle(SquishButtonStyle())
                    }
                }
            }
            Text(metric.explanation).font(Theme.font(12)).foregroundStyle(Theme.textSecondary)
            VStack(spacing: 10) {
                ForEach(Array(rows.enumerated()), id: \.element.person.id) { i, r in
                    Button {
                        if !r.isMe { detail = r.person }
                    } label: {
                        HStack(spacing: 10) {
                            // Same value = same place (1, 2, 2, 4).
                            let place = (rows.firstIndex { $0.value == r.value } ?? i)
                            Text(r.value == nil ? "–" : place < 3 ? ["🥇", "🥈", "🥉"][place] : "\(place + 1)")
                                .font(Theme.font(17, .bold)).foregroundStyle(Theme.textSecondary).frame(width: 30)
                            PersonCat(person: r.person, pixel: 2.2)
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(r.isMe ? "\(r.person.name) (du)" : r.person.name)
                                        .font(Theme.font(15, r.isMe ? .bold : .semibold)).foregroundStyle(Theme.textPrimary).lineLimit(1)
                                    Spacer()
                                    Text(r.value.map(metric.format) ?? "–").font(Theme.font(15, .bold))
                                        .foregroundStyle(r.isMe ? Theme.accent : Theme.textPrimary)
                                }
                                GeometryReader { g in
                                    ZStack(alignment: .leading) {
                                        Capsule().fill(Theme.cardAlt)
                                        Capsule().fill(r.isMe ? Theme.accent : Theme.fiber)
                                            .frame(width: max(4, g.size.width * min(1, (r.value ?? 0) / scale)))
                                    }
                                }
                                .frame(height: 6)
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .animation(.snappy, value: metric)
        }
        .card()
    }

    /// Everyone's day so far: eaten / goal.
    private func todayCard(_ myStats: FriendStats) -> some View {
        let me = FriendsStore.Person(id: store.uid ?? "me", name: name, palette: paletteID, stats: myStats, updated: .now)
        let rows = [(me, true)] + store.friends.map { ($0, false) }
        return VStack(alignment: .leading, spacing: 12) {
            Label("Heute", systemImage: "fork.knife").font(Theme.font(17, .bold)).foregroundStyle(Theme.textPrimary)
            ForEach(rows, id: \.0.id) { p, isMe in
                let s = p.stats
                let known = s.isToday && s.todayGoal > 0
                HStack(spacing: 10) {
                    PersonCat(person: p, pixel: 2)
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(alignment: .firstTextBaseline) {
                            Text(isMe ? "\(p.name) (du)" : p.name).font(Theme.font(15, isMe ? .bold : .semibold))
                                .foregroundStyle(Theme.textPrimary).lineLimit(1)
                            Spacer()
                            if known {
                                Text("\(s.todayKcal.kcalString)").font(Theme.font(15, .bold))
                                    .foregroundStyle(GoalStatus(kcal: s.todayKcal, goal: s.todayGoal).color)
                                + Text(" / \(s.todayGoal.kcalString) kcal").font(Theme.font(13)).foregroundStyle(Theme.textSecondary)
                            } else {
                                Text(s.isToday ? "–" : "heute noch nichts").font(Theme.font(13)).foregroundStyle(Theme.textSecondary)
                            }
                        }
                        GeometryReader { g in
                            ZStack(alignment: .leading) {
                                Capsule().fill(Theme.cardAlt)
                                if known {
                                    Capsule().fill(GoalStatus(kcal: s.todayKcal, goal: s.todayGoal).color)
                                        .frame(width: max(4, g.size.width * min(1, s.todayKcal / s.todayGoal)))
                                }
                            }
                        }
                        .frame(height: 6)
                    }
                }
            }
            Text("Ziel inklusive angerechneter Aktivität.").font(Theme.font(11)).foregroundStyle(Theme.textSecondary)
        }
        .card()
    }

    private func weekCard(_ myStats: FriendStats) -> some View {
        let rows: [(String, [Double])] = [("Du", myStats.week)] + store.friends.map { ($0.name, $0.stats.isToday ? $0.stats.week : shifted($0.stats)) }
        return VStack(alignment: .leading, spacing: 12) {
            Label("Diese Woche", systemImage: "calendar").font(Theme.font(17, .bold)).foregroundStyle(Theme.textPrimary)
            HStack(spacing: 0) {
                Text("").frame(width: 90, alignment: .leading)
                ForEach(0..<7, id: \.self) { i in
                    let d = Calendar.current.date(byAdding: .day, value: i - 6, to: .now)!
                    Text(d.formatted(.dateTime.weekday(.narrow))).font(Theme.font(11, .semibold))
                        .foregroundStyle(Theme.textSecondary).frame(maxWidth: .infinity)
                }
            }
            ForEach(Array(rows.enumerated()), id: \.offset) { _, r in
                HStack(spacing: 0) {
                    Text(r.0).font(Theme.font(14, .semibold)).foregroundStyle(Theme.textPrimary).lineLimit(1).frame(width: 90, alignment: .leading)
                    ForEach(0..<7, id: \.self) { i in
                        let v = i < r.1.count ? r.1[i] : 0
                        RoundedRectangle(cornerRadius: 5).fill(color(v)).frame(width: 22, height: 22).frame(maxWidth: .infinity)
                    }
                }
            }
            GoalLegend()
        }
        .card()
    }

    /// A friend who hasn't opened the app today: their week ends earlier – move it so the days line up.
    private func shifted(_ s: FriendStats) -> [Double] {
        guard let date = Self.dayFormatter.date(from: s.day) else { return s.week }
        let days = Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: date),
                                                   to: Calendar.current.startOfDay(for: .now)).day ?? 0
        guard days > 0 else { return s.week }
        return Array((s.week + Array(repeating: 0, count: min(days, 7))).suffix(7))
    }

    static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    private func color(_ v: Double) -> Color {
        switch Int(v) {
        case 1: GoalStatus.within.color
        case 2: GoalStatus.slightlyOver.color
        case 3: GoalStatus.over.color
        default: Theme.cardAlt
        }
    }

    private var footer: some View {
        VStack(spacing: 4) {
            Button { showManage = true } label: {
                Label("Freunde verwalten", systemImage: "person.2.badge.gearshape").frame(maxWidth: .infinity)
            }
            .buttonStyle(PillButtonStyle(filled: false))
            .padding(.bottom, 8)
            if store.busy { ProgressView().controlSize(.small) }
            if let r = store.lastRefresh {
                Text("Aktualisiert \(r.formatted(.relative(presentation: .named))) · zum Aktualisieren ziehen")
                    .font(Theme.font(11)).foregroundStyle(Theme.textSecondary)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func info(_ title: String, _ text: String) -> some View {
        VStack(spacing: 10) {
            CatMascot(mood: .idle, pixel: 4)
            Text(title).font(Theme.font(17, .bold)).foregroundStyle(Theme.textPrimary)
            Text(text).font(Theme.font(14)).foregroundStyle(Theme.textSecondary).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .card(padding: 22)
    }
}

/// A person's cat in their colour and today's mood (sleeping when they haven't been active today).
struct PersonCat: View {
    let person: FriendsStore.Person
    var pixel: CGFloat = 2.4

    var body: some View {
        let mood: CatMood = person.stats.isToday ? CatMood(key: person.stats.mood) : .sleeping
        AnimatedSprite(frames: mood.frames, fps: mood.fps, pixel: pixel, palette: CatPalette.byID(person.palette))
            .frame(width: 21 * pixel, height: 16 * pixel)
    }
}

/// Name + start (first visit of the page).
struct FriendsSetupCard: View {
    @EnvironmentObject private var goals: Goals
    @Environment(\.modelContext) private var ctx
    @ObservedObject private var store = FriendsStore.shared
    @AppStorage(FriendsStore.nameKey) private var name = ""
    @State private var draft = ""

    var body: some View {
        VStack(spacing: 14) {
            CatMascot(mood: .proud, pixel: 5)
            Text("Mit Freunden vergleichen").font(Theme.font(20, .bold)).foregroundStyle(Theme.textPrimary)
            Text("Wer hält die längste Serie, trinkt am meisten Wasser, isst am meisten Gemüse? Geteilt werden nur Kennzahlen wie Serie, Zieltreue, Health Score und deine Tageskalorien mit Ziel. Keine einzelnen Mahlzeiten und kein Gewicht.")
                .font(Theme.font(14)).foregroundStyle(Theme.textSecondary).multilineTextAlignment(.center)
            TextField("Dein Name", text: $draft)
                .font(Theme.font(17)).textInputAutocapitalization(.words)
                .padding(.horizontal, 14).frame(height: 50)
                .background(Theme.cardAlt, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            Button {
                name = String(draft.trimmingCharacters(in: .whitespaces).prefix(30))
                Task { await store.setUp(ctx: ctx, goals: goals) }
            } label: {
                HStack {
                    if store.busy { ProgressView().tint(.white) }
                    Text("Los geht’s")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(PillButtonStyle())
            .disabled(draft.trimmingCharacters(in: .whitespaces).isEmpty || store.busy)
            if let e = store.error { Text(e).font(Theme.font(13)).foregroundStyle(Theme.danger) }
        }
        .card(padding: 22)
        .onAppear { draft = name }
    }
}

/// Type or confirm an invite code.
struct CodeEntrySheet: View {
    var prefill: FriendsStore.IncomingCode? = nil
    @EnvironmentObject private var goals: Goals
    @Environment(\.modelContext) private var ctx
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var store = FriendsStore.shared
    @State private var code = ""
    @FocusState private var focused: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: 18) {
                CatMascot(mood: .happy, pixel: 4)
                Text(prefill?.name.map { "\($0) möchte mit dir vergleichen" } ?? "Freund hinzufügen")
                    .font(Theme.font(20, .bold)).foregroundStyle(Theme.textPrimary).multilineTextAlignment(.center)
                if !store.isSetUp {
                    Text("Lege zuerst deinen Namen auf der Freunde-Seite fest, dann kannst du die Anfrage senden.")
                        .font(Theme.font(14)).foregroundStyle(Theme.textSecondary).multilineTextAlignment(.center)
                    FriendsSetupCard()
                } else {
                    TextField("ABCD2345", text: $code)
                        .font(.system(size: 28, weight: .bold, design: .monospaced))
                        .multilineTextAlignment(.center)
                        .textInputAutocapitalization(.characters).autocorrectionDisabled()
                        .focused($focused)
                        .padding(.vertical, 12)
                        .background(Theme.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .onChange(of: code) { _, v in
                            let clean = String(v.uppercased().filter { $0.isLetter || $0.isNumber }.prefix(8))
                            if clean != v { code = clean }
                        }
                    Text("Den Code findet dein Freund auf seiner Freunde-Seite. Ihr seht euch, sobald ihr euch gegenseitig hinzugefügt habt.")
                        .font(Theme.font(13)).foregroundStyle(Theme.textSecondary).multilineTextAlignment(.center)
                    if let e = store.error { Text(e).font(Theme.font(13)).foregroundStyle(Theme.danger) }
                    Button {
                        Task {
                            if await store.addFriend(code: code, label: prefill?.name, ctx: ctx, goals: goals) {
                                Haptics.success()
                                dismiss()
                            }
                        }
                    } label: {
                        HStack {
                            if store.busy { ProgressView().tint(.white) }
                            Text("Anfrage senden")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(PillButtonStyle())
                    .disabled(code.count != 8 || store.busy)
                }
                Spacer()
            }
            .padding(20)
            .background(Theme.background.ignoresSafeArea())
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { dismiss() } } }
            .onAppear {
                store.error = nil
                if let prefill { code = prefill.code } else { focused = true }
            }
        }
        .presentationDetents([.large])
    }
}

/// One friend compared with me, metric by metric.
struct FriendDetailSheet: View {
    let person: FriendsStore.Person
    @EnvironmentObject private var goals: Goals
    @Environment(\.modelContext) private var ctx
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var store = FriendsStore.shared
    @State private var confirm = false

    var body: some View {
        let mine = FriendStats.compute(ctx: ctx, goals: goals, shareWeight: false)
        let theirs = person.stats
        let wins = FriendMetric.allCases.reduce((0, 0)) { acc, m in
            guard let a = m.value(mine), let b = m.value(theirs), a != b else { return acc }
            return a > b ? (acc.0 + 1, acc.1) : (acc.0, acc.1 + 1)
        }
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    HStack(spacing: 14) {
                        PersonCat(person: person, pixel: 3.6)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(person.name).font(Theme.font(22, .bold)).foregroundStyle(Theme.textPrimary)
                            if theirs.isToday, theirs.todayGoal > 0 {
                                Text("Heute \(theirs.todayKcal.kcalString) von \(theirs.todayGoal.kcalString) kcal · \(Int(theirs.todayEntries)) Einträge")
                                    .font(Theme.font(13)).foregroundStyle(Theme.textSecondary)
                            } else if theirs.isToday {
                                Text("Heute \(Int(theirs.todayPct)) % vom Ziel · \(Int(theirs.todayEntries)) Einträge")
                                    .font(Theme.font(13)).foregroundStyle(Theme.textSecondary)
                            } else {
                                Text("Heute noch nicht aktiv").font(Theme.font(13)).foregroundStyle(Theme.textSecondary)
                            }
                            if let u = person.updated {
                                Text("Stand \(u.formatted(.relative(presentation: .named)))").font(Theme.font(11)).foregroundStyle(Theme.textSecondary)
                            }
                        }
                        Spacer(minLength: 0)
                    }
                    .card()

                    HStack {
                        score("Du", wins.0, Theme.accent)
                        Text(":").font(Theme.font(28, .heavy)).foregroundStyle(Theme.textSecondary)
                        score(person.name, wins.1, Theme.fiber)
                    }
                    .card()

                    VStack(spacing: 14) {
                        ForEach(FriendMetric.allCases) { m in compare(m, mine: m.value(mine), theirs: m.value(theirs)) }
                        if let w = theirs.weightTrend {
                            HStack {
                                Label("Gewichtstrend", systemImage: "scalemass.fill").font(Theme.font(14, .semibold))
                                Spacer()
                                Text("\(w >= 0 ? "+" : "−")\(abs(w).formatted(.number.precision(.fractionLength(2)))) kg/Woche")
                                    .font(Theme.font(14, .bold))
                            }
                            .foregroundStyle(Theme.textPrimary)
                        }
                    }
                    .card()

                    Button(role: .destructive) { confirm = true } label: {
                        Label("Freund entfernen", systemImage: "person.badge.minus").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(PillButtonStyle(filled: false))
                }
                .padding(16)
            }
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle("Vergleich")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Fertig") { dismiss() } } }
            .confirmationDialog("\(person.name) entfernen?", isPresented: $confirm, titleVisibility: .visible) {
                Button("Entfernen", role: .destructive) {
                    Task {
                        await store.remove(person.id, ctx: ctx, goals: goals)
                        dismiss()
                    }
                }
            } message: { Text("Ihr seht eure Werte dann nicht mehr. Ihr könnt euch jederzeit neu einladen.") }
        }
        .presentationDetents([.large])
    }

    private func score(_ who: String, _ n: Int, _ color: Color) -> some View {
        VStack(spacing: 2) {
            Text("\(n)").font(Theme.font(34, .heavy)).foregroundStyle(color)
            Text(who).font(Theme.font(13, .semibold)).foregroundStyle(Theme.textSecondary).lineLimit(1)
        }
        .frame(maxWidth: .infinity)
    }

    private func compare(_ m: FriendMetric, mine: Double?, theirs: Double?) -> some View {
        let scale = m.scale > 0 ? m.scale : max(mine ?? 0, theirs ?? 0, 1)
        return VStack(alignment: .leading, spacing: 6) {
            Label(m.title, systemImage: m.icon).font(Theme.font(14, .semibold)).foregroundStyle(Theme.textPrimary)
            bar("Du", mine, scale, m, Theme.accent, win: (mine ?? -1) > (theirs ?? -1))
            bar(person.name, theirs, scale, m, Theme.fiber, win: (theirs ?? -1) > (mine ?? -1))
        }
    }

    private func bar(_ who: String, _ v: Double?, _ scale: Double, _ m: FriendMetric, _ color: Color, win: Bool) -> some View {
        HStack(spacing: 8) {
            Text(who).font(Theme.font(12)).foregroundStyle(Theme.textSecondary).frame(width: 70, alignment: .leading).lineLimit(1)
            GeometryReader { g in
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.cardAlt)
                    Capsule().fill(color).frame(width: max(4, g.size.width * min(1, (v ?? 0) / scale)))
                }
            }
            .frame(height: 8)
            Text(v.map(m.format) ?? "–").font(Theme.font(13, win ? .bold : .medium))
                .foregroundStyle(win ? color : Theme.textPrimary).frame(width: 74, alignment: .trailing)
            Image(systemName: "crown.fill").font(.system(size: 10)).foregroundStyle(Theme.carbs).opacity(win ? 1 : 0)
        }
    }
}

/// Settings: show/hide the page, name, weight trend, delete data.
struct FriendsSettingsSection: View {
    @EnvironmentObject private var goals: Goals
    @Environment(\.modelContext) private var ctx
    @ObservedObject private var store = FriendsStore.shared
    @AppStorage(FriendsStore.enabledKey) private var enabled = true
    @AppStorage(FriendsStore.nameKey) private var name = ""
    @AppStorage(FriendsStore.shareWeightKey) private var shareWeight = false
    @State private var draft = ""
    @State private var confirmDelete = false
    @State private var showManage = false

    var body: some View {
        if store.isAvailable {
            Section {
                Toggle(isOn: $enabled.animation()) { Label("Freunde-Seite anzeigen", systemImage: "person.2.fill") }
                if enabled {
                    HStack {
                        Text("Dein Name")
                        TextField("für Freunde sichtbar", text: $draft)
                            .multilineTextAlignment(.trailing)
                            .textInputAutocapitalization(.words)
                            .onSubmit(saveName)
                    }
                    Toggle("Gewichtstrend teilen", isOn: $shareWeight)
                        .onChange(of: shareWeight) { _, _ in push() }
                    if store.isSetUp {
                        Button { showManage = true } label: {
                            HStack {
                                Text("Freunde verwalten").foregroundStyle(Theme.textPrimary)
                                Spacer()
                                Text("\(store.friends.count)").foregroundStyle(Theme.textSecondary)
                                Image(systemName: "chevron.right").font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.textSecondary)
                            }
                        }
                        LabeledContent("Dein Code", value: store.me?.code ?? "–")
                        Button("Freunde-Daten löschen", role: .destructive) { confirmDelete = true }
                    }
                }
            } header: { Text("Freunde") } footer: {
                Text(enabled
                     ? "Freunde sehen nur Kennzahlen (Serie, Zieltreue, Score, Protein, Wasser, Aktivität, Obst & Gemüse) und deine Tageskalorien mit Ziel. Keine Mahlzeiten, kein Gewicht. Den Gewichtstrend (kg pro Woche) nur, wenn du ihn teilst."
                     : "Ausgeblendet. Die Seite verschwindet aus der Leiste unten. Deine Freunde bleiben erhalten.")
            }
            .listRowBackground(Theme.card)
            .sheet(isPresented: $showManage) { FriendsManageView() }
            .onAppear { draft = name }
            .onChange(of: draft) { _, _ in
                // Save shortly after typing stops.
                let current = draft
                Task {
                    try? await Task.sleep(for: .seconds(1.2))
                    if current == draft { saveName() }
                }
            }
            .confirmationDialog("Freunde-Daten löschen?", isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("Löschen", role: .destructive) { Task { await store.deleteAll() } }
            } message: {
                Text("Dein Profil und dein Code werden vom Server gelöscht, deine Freunde sehen dich nicht mehr. Deine Einträge in Purrtion bleiben.")
            }
        }
    }

    private func saveName() {
        let clean = String(draft.trimmingCharacters(in: .whitespaces).prefix(30))
        guard !clean.isEmpty, clean != name else { return }
        name = clean
        push()
    }

    private func push() {
        guard store.isSetUp else { return }
        Task { try? await store.upload(ctx: ctx, goals: goals, force: true) }
    }
}

/// Everyone in one place: friends (remove), sent requests (withdraw), received requests (accept / decline)
/// and people I declined or removed who still want to connect.
struct FriendsManageView: View {
    @EnvironmentObject private var goals: Goals
    @Environment(\.modelContext) private var ctx
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var store = FriendsStore.shared
    @State private var confirmRemove: FriendsStore.Person?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    if store.friends.isEmpty {
                        Text("Noch keine Freunde.").foregroundStyle(Theme.textSecondary)
                    }
                    ForEach(store.friends) { p in
                        HStack(spacing: 12) {
                            PersonCat(person: p, pixel: 2)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(p.name).font(Theme.font(16, .semibold)).foregroundStyle(Theme.textPrimary)
                                if let u = p.updated {
                                    Text("aktiv \(u.formatted(.relative(presentation: .named)))").font(Theme.font(12)).foregroundStyle(Theme.textSecondary)
                                }
                            }
                            Spacer()
                            Button("Entfernen", role: .destructive) { confirmRemove = p }
                                .font(Theme.font(14, .semibold)).buttonStyle(.borderless)
                        }
                    }
                } header: { Text("Freunde · \(store.friends.count)") } footer: {
                    Text("Entfernte Freunde sehen deine Werte nicht mehr. Ihr könnt euch jederzeit neu einladen.")
                }
                .listRowBackground(Theme.card)

                if !store.incoming.isEmpty {
                    Section("Erhaltene Anfragen") {
                        ForEach(store.incoming) { p in
                            HStack(spacing: 12) {
                                PersonCat(person: p, pixel: 2)
                                Text(p.name).font(Theme.font(16, .semibold)).foregroundStyle(Theme.textPrimary)
                                Spacer()
                                Button("Ablehnen") { Task { await store.decline(p.id, ctx: ctx, goals: goals) } }
                                    .font(Theme.font(14)).foregroundStyle(Theme.textSecondary).buttonStyle(.borderless)
                                Button("Annehmen") {
                                    Haptics.success()
                                    Task { await store.accept(p.id, ctx: ctx, goals: goals) }
                                }
                                .font(Theme.font(14, .bold)).buttonStyle(.borderless)
                            }
                        }
                    }
                    .listRowBackground(Theme.card)
                }

                if !store.outgoing.isEmpty {
                    Section {
                        ForEach(store.outgoing, id: \.id) { o in
                            HStack {
                                Image(systemName: "hourglass").foregroundStyle(Theme.textSecondary)
                                Text(o.label).font(Theme.font(16)).foregroundStyle(Theme.textPrimary).lineLimit(1)
                                Spacer()
                                Button("Zurückziehen") { Task { await store.remove(o.id, ctx: ctx, goals: goals) } }
                                    .font(Theme.font(14, .semibold)).buttonStyle(.borderless)
                            }
                        }
                    } header: { Text("Gesendete Anfragen") } footer: {
                        Text("Wartet, bis die andere Person annimmt. Danach steht sie oben bei den Freunden.")
                    }
                    .listRowBackground(Theme.card)
                }

                if !store.declined.isEmpty {
                    Section {
                        ForEach(store.declined) { p in
                            HStack(spacing: 12) {
                                PersonCat(person: p, pixel: 2)
                                Text(p.name).font(Theme.font(16)).foregroundStyle(Theme.textPrimary)
                                Spacer()
                                Button("Annehmen") { Task { await store.accept(p.id, ctx: ctx, goals: goals) } }
                                    .font(Theme.font(14, .semibold)).buttonStyle(.borderless)
                            }
                        }
                    } header: { Text("Abgelehnt oder entfernt") } footer: {
                        Text("Diese Personen möchten weiterhin mit dir vergleichen. Du siehst sie nur hier.")
                    }
                    .listRowBackground(Theme.card)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle("Freunde verwalten")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Fertig") { dismiss() } } }
            .refreshable { await Task { await store.refresh(ctx: ctx, goals: goals, force: true) }.value }
            .task { await store.refresh(ctx: ctx, goals: goals) }
            .confirmationDialog("\(confirmRemove?.name ?? "") entfernen?", isPresented: Binding(get: { confirmRemove != nil }, set: { if !$0 { confirmRemove = nil } }),
                                titleVisibility: .visible, presenting: confirmRemove) { p in
                Button("Entfernen", role: .destructive) { Task { await store.remove(p.id, ctx: ctx, goals: goals) } }
            } message: { _ in Text("Ihr seht eure Werte dann nicht mehr. Ihr könnt euch jederzeit neu einladen.") }
            .alert("Fehler", isPresented: Binding(get: { store.error != nil }, set: { if !$0 { store.error = nil } })) {
                Button("OK", role: .cancel) {}
            } message: { Text(store.error ?? "") }
        }
    }
}
