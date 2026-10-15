import Foundation
import SwiftData

/// The small snapshot of one user's stats that friends get to see. Everything is relative (percent, days, averages),
/// absolute weight is never shared – the weight trend only if switched on.
struct FriendStats: Codable, Equatable {
    var streak: Double = 0
    /// Days in goal of the last 7 finished days.
    var goal7: Double = 0
    /// % of the last 30 finished days in goal.
    var goal30: Double = 0
    var score7: Double = 0
    /// Ø share of the protein goal (%).
    var protein7: Double = 0
    /// Ø share of the water goal (%), -1 = not tracked.
    var water7: Double = -1
    /// Ø active kcal per day, -1 = unknown.
    var active7: Double = -1
    var fiber7: Double = 0
    var fruitveg7: Double = 0
    var logged30: Double = 0
    /// kg per week, only when shared.
    var weightTrend: Double? = nil
    /// Today: share of the goal eaten (%), score, number of entries – valid for `day`.
    var todayPct: Double = 0
    var todayScore: Double = -1
    var todayEntries: Double = 0
    /// kcal eaten today and today's goal (incl. activity bonus), -1 = unknown (older app version).
    var todayKcal: Double = -1
    var todayGoal: Double = -1
    /// Last 7 days incl. today: 0 nothing, 1 in goal, 2 up to +5 %, 3 over.
    var week: [Double] = []
    var mood: String = "idle"
    var day: String = ""

    static func dayKey(_ d: Date) -> String {
        let c = Calendar.current.dateComponents([.year, .month, .day], from: d)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    var isToday: Bool { day == Self.dayKey(.now) }

    // MARK: Firestore map

    var dictionary: [String: Any] {
        var d: [String: Any] = [
            "streak": streak, "goal7": goal7, "goal30": goal30, "score7": score7, "protein7": protein7,
            "water7": water7, "active7": active7, "fiber7": fiber7, "fruitveg7": fruitveg7, "logged30": logged30,
            "todayPct": todayPct, "todayScore": todayScore, "todayEntries": todayEntries,
            "todayKcal": todayKcal, "todayGoal": todayGoal,
            "week": week, "mood": mood, "day": day,
        ]
        if let weightTrend { d["weightTrend"] = weightTrend }
        return d
    }

    init() {}

    init(_ d: [String: Any]) {
        func n(_ k: String, _ def: Double = 0) -> Double { d[k] as? Double ?? def }
        streak = n("streak"); goal7 = n("goal7"); goal30 = n("goal30"); score7 = n("score7")
        protein7 = n("protein7"); water7 = n("water7", -1); active7 = n("active7", -1)
        fiber7 = n("fiber7"); fruitveg7 = n("fruitveg7"); logged30 = n("logged30")
        weightTrend = d["weightTrend"] as? Double
        todayPct = n("todayPct"); todayScore = n("todayScore", -1); todayEntries = n("todayEntries")
        todayKcal = n("todayKcal", -1); todayGoal = n("todayGoal", -1)
        week = d["week"] as? [Double] ?? []
        mood = d["mood"] as? String ?? "idle"
        day = d["day"] as? String ?? ""
    }

    // MARK: Computing my own

    @MainActor
    static func compute(ctx: ModelContext, goals: Goals, shareWeight: Bool, now: Date = .now) -> FriendStats {
        let cal = Calendar.current
        let today = cal.startOfDay(for: now)
        let start = cal.date(byAdding: .day, value: -30, to: today)!
        let entries = (try? ctx.fetch(FetchDescriptor<FoodEntry>(predicate: #Predicate { $0.day >= start }))) ?? []
        let byDay = Dictionary(grouping: entries, by: \.day)
        let water = (try? ctx.fetch(FetchDescriptor<WaterLog>(predicate: #Predicate { $0.day >= start }))) ?? []
        let waterByDay = Dictionary(grouping: water, by: \.day).mapValues { $0.reduce(0) { $0 + $1.ml } }
        func day(_ offset: Int) -> Date { cal.date(byAdding: .day, value: -offset, to: today)! }
        func status(_ d: Date) -> Double {
            let es = byDay[d] ?? []
            guard !es.isEmpty else { return 0 }
            switch GoalStatus(kcal: es.reduce(0) { $0 + $1.kcal }, goal: goals.target(for: d).kcal) {
            case .none: return 0
            case .within: return 1
            case .slightlyOver: return 2
            case .over: return 3
            }
        }

        var s = FriendStats()
        s.day = dayKey(today)
        // Streak: consecutive logged days up to today (or yesterday if today is still empty).
        var d = byDay[today] == nil ? day(1) : today
        var streakAll = 0
        let streakStart = cal.date(byAdding: .day, value: -400, to: today)!
        var streakFetch = FetchDescriptor<FoodEntry>(predicate: #Predicate { $0.day >= streakStart })
        streakFetch.propertiesToFetch = [\.day]
        let allDays = Set((try? ctx.fetch(streakFetch))?.map(\.day) ?? [])
        while allDays.contains(d) { streakAll += 1; d = cal.date(byAdding: .day, value: -1, to: d)! }
        s.streak = Double(streakAll)

        let last7 = (1...7).map(day)
        let last30 = (1...30).map(day)
        s.goal7 = Double(last7.filter { [1, 2].contains(status($0)) }.count)
        s.goal30 = (Double(last30.filter { [1, 2].contains(status($0)) }.count) / 30 * 100).rounded()
        s.logged30 = Double(last30.filter { byDay[$0] != nil }.count)

        let logged7 = last7.filter { byDay[$0] != nil }
        if !logged7.isEmpty {
            var score = 0.0, protein = 0.0, fiber = 0.0, fruitveg = 0.0
            for d in logged7 {
                let es = byDay[d] ?? []
                let t = goals.target(for: d)
                score += Double(HealthScore(entries: es, goalKcal: t.kcal, goalProtein: t.protein).score)
                let n = es.reduce(Nutrients()) { $0 + $1.nutrients }
                protein += min(150, n.protein / max(t.protein, 1) * 100)
                fiber += n[.fiber] ?? 0
                fruitveg += es.filter { HealthScore.isFruitOrVegetable($0.food) }.reduce(0) { $0 + $1.grams }
            }
            let c = Double(logged7.count)
            s.score7 = (score / c).rounded()
            s.protein7 = (protein / c).rounded()
            s.fiber7 = (fiber / c).rounded()
            s.fruitveg7 = (fruitveg / c).rounded()
        }
        if goals.waterEnabled {
            let pct = last7.map { min(150, Double(waterByDay[$0] ?? 0) / Double(max(goals.waterML, 1)) * 100) }
            s.water7 = (pct.reduce(0, +) / 7).rounded()
        }
        let actives = last7.map { (goals.activityEnabled ? ActivityStore.kcal(for: $0) : 0) + ActivityStore.manual(for: $0) }
        if goals.activityEnabled || actives.contains(where: { $0 > 0 }) {
            s.active7 = (actives.reduce(0, +) / 7).rounded()
        }
        if shareWeight {
            let wStart = cal.date(byAdding: .day, value: -28, to: today)!
            let weights = ((try? ctx.fetch(FetchDescriptor<WeightLog>(predicate: #Predicate { $0.date >= wStart }))) ?? [])
            let pts = weights.map { (x: $0.date.timeIntervalSince(wStart) / 86400, y: $0.kg) }
            if pts.count >= 3, let fit = Expenditure.robustSlope(pts) {
                s.weightTrend = (fit.slope * 7 * 100).rounded() / 100
            }
        }

        let todays = byDay[today] ?? []
        let t = goals.target(for: today)
        let kcal = todays.reduce(0) { $0 + $1.kcal }
        s.todayPct = (kcal / max(t.kcal, 1) * 100).rounded()
        s.todayKcal = kcal.rounded()
        s.todayGoal = t.kcal.rounded()
        s.todayEntries = Double(todays.count)
        if !todays.isEmpty {
            s.todayScore = Double(HealthScore(entries: todays, goalKcal: t.kcal, goalProtein: t.protein).score)
        }
        s.week = (0..<7).reversed().map { status(day($0)) }
        s.mood = CatMood.of(entries: todays, target: t, waterML: waterByDay[today] ?? 0, goals: goals, day: today,
                            promille: BloodAlcohol.make(entries: todays + (byDay[day(1)] ?? []), goals: goals, weight: nil).value(at: now)).key
        return s
    }
}

/// What can be compared on the friends page.
enum FriendMetric: String, CaseIterable, Identifiable {
    case streak, goal7, score7, protein7, water7, active7, fruitveg7, fiber7, goal30, logged30

    var id: String { rawValue }

    var title: String {
        switch self {
        case .streak: "Serie"
        case .goal7: "Im Ziel (7 Tage)"
        case .score7: "Health Score"
        case .protein7: "Protein"
        case .water7: "Wasser"
        case .active7: "Aktivität"
        case .fruitveg7: "Obst & Gemüse"
        case .fiber7: "Ballaststoffe"
        case .goal30: "Zieltreue (30 Tage)"
        case .logged30: "Fleiß (30 Tage)"
        }
    }

    var short: String {
        switch self {
        case .streak: "Serie"
        case .goal7: "Im Ziel"
        case .score7: "Score"
        case .protein7: "Protein"
        case .water7: "Wasser"
        case .active7: "Aktiv"
        case .fruitveg7: "Obst & Gemüse"
        case .fiber7: "Ballaststoffe"
        case .goal30: "Zieltreue"
        case .logged30: "Fleiß"
        }
    }

    var icon: String {
        switch self {
        case .streak: "flame.fill"
        case .goal7: "target"
        case .score7: "heart.text.square.fill"
        case .protein7: "bolt.heart.fill"
        case .water7: "drop.fill"
        case .active7: "figure.run"
        case .fruitveg7: "carrot.fill"
        case .fiber7: "leaf.fill"
        case .goal30: "calendar"
        case .logged30: "pencil.and.list.clipboard"
        }
    }

    var explanation: String {
        switch self {
        case .streak: "Tage in Folge, an denen etwas eingetragen wurde."
        case .goal7: "Tage der letzten Woche im Kalorienziel (bis +5 %)."
        case .score7: "Ø Health Score der letzten 7 Tage."
        case .protein7: "Ø Anteil des eigenen Proteinziels, letzte 7 Tage."
        case .water7: "Ø Anteil des eigenen Wasserziels, letzte 7 Tage."
        case .active7: "Ø Aktivitätskalorien pro Tag, letzte 7 Tage."
        case .fruitveg7: "Ø Gramm Obst & Gemüse pro Tag, letzte 7 Tage."
        case .fiber7: "Ø Gramm Ballaststoffe pro Tag, letzte 7 Tage."
        case .goal30: "Anteil der letzten 30 Tage im Kalorienziel."
        case .logged30: "Tage mit Einträgen in den letzten 30 Tagen."
        }
    }

    func value(_ s: FriendStats) -> Double? {
        switch self {
        case .streak: s.streak
        case .goal7: s.goal7
        case .score7: s.score7 > 0 ? s.score7 : nil
        case .protein7: s.protein7 > 0 ? s.protein7 : nil
        case .water7: s.water7 >= 0 ? s.water7 : nil
        case .active7: s.active7 >= 0 ? s.active7 : nil
        case .fruitveg7: s.fruitveg7
        case .fiber7: s.fiber7
        case .goal30: s.goal30
        case .logged30: s.logged30
        }
    }

    func format(_ v: Double) -> String {
        switch self {
        case .streak: "\(Int(v)) \(Int(v) == 1 ? "Tag" : "Tage")"
        case .goal7: "\(Int(v))/7"
        case .score7: "\(Int(v))"
        case .protein7, .water7, .goal30: "\(Int(v)) %"
        case .active7: "\(Int(v)) kcal"
        case .fruitveg7, .fiber7: "\(Int(v)) g"
        case .logged30: "\(Int(v))/30"
        }
    }

    /// Upper end of the bar.
    var scale: Double {
        switch self {
        case .goal7: 7
        case .score7, .protein7, .water7, .goal30: 100
        case .logged30: 30
        case .fiber7: 30
        case .fruitveg7: 400
        default: 0          // relative to the best value
        }
    }
}

extension CatMood {
    var key: String {
        switch self {
        case .idle: "idle"
        case .happy: "happy"
        case .eating: "eating"
        case .sleeping: "sleeping"
        case .full: "full"
        case .yawning: "yawning"
        case .hungry: "hungry"
        case .tipsy: "tipsy"
        case .proud: "proud"
        case .content: "content"
        case .stuffed: "stuffed"
        case .thirsty: "thirsty"
        case .sporty: "sporty"
        }
    }

    init(key: String) {
        let all: [CatMood] = [.idle, .happy, .eating, .sleeping, .full, .yawning, .hungry, .tipsy, .proud, .content,
                              .stuffed, .thirsty, .sporty]
        self = all.first { $0.key == key } ?? .idle
    }
}
