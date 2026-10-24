import SwiftUI
import Combine

/// Targets valid from a certain day on – changing the goal never rewrites past days.
struct GoalPlan: Codable, Equatable {
    var from: Date
    var kcal: Double
    var protein: Double
    var carbs: Double
    var fat: Double
    /// Calendar weekday (1 = Sunday … 7 = Saturday) → own calorie goal.
    var weekdayKcal: [Int: Double] = [:]
    /// Share of the active energy from Apple Health that is added to the goal (0 = only shown).
    var activityPercent: Double = 0

    func sameTargets(as other: GoalPlan) -> Bool {
        kcal == other.kcal && protein == other.protein && carbs == other.carbs && fat == other.fat
            && weekdayKcal == other.weekdayKcal && activityPercent == other.activityPercent
    }
}

/// The resolved goal of one day (weekday goal + activity bonus applied).
struct DayTarget: Equatable {
    var kcal: Double
    var protein: Double
    var carbs: Double
    var fat: Double
    /// Goal before the activity bonus.
    var baseKcal: Double
    /// Apple Health + manually added activity.
    var activeKcal: Double
    var healthKcal: Double
    var manualKcal: Double
    var activityBonus: Double
    /// Share of Health activity credited on that day (the setting valid back then).
    var activityPercent: Double = 0
}

/// Daily targets + body profile, persisted in UserDefaults.
final class Goals: ObservableObject {
    @AppStorage("goal.kcal") var kcal: Double = 2000
    @AppStorage("goal.protein") var protein: Double = 120
    @AppStorage("goal.carbs") var carbs: Double = 220
    @AppStorage("goal.fat") var fat: Double = 70
    @AppStorage("goal.waterML") var waterML: Int = 2500
    @AppStorage("goal.waterStep") var waterStep: Int = 250
    @AppStorage("goal.waterEnabled") var waterEnabled = true
    @AppStorage("goal.healthScoreEnabled") var healthScoreEnabled = true

    /// Different calorie goals per weekday.
    @AppStorage("goal.weekdayEnabled") var weekdayEnabled = false
    /// Share of Apple Health active energy added to the goal (0 = only shown).
    @AppStorage("goal.activityPercent") var activityPercent: Double = 0
    /// Show active energy from Apple Health.
    @AppStorage("activity.enabled") var activityEnabled = false
    // Read and written straight through UserDefaults: a restored backup replaces these while the app runs, and a copy
    // held by the property wrapper kept the old value and wrote it back over the restored one.
    private static let weekdayKey = "goal.weekdayKcal"
    private static let historyKey = "goal.history"
    private var weekdayJSON: String {
        get { UserDefaults.standard.string(forKey: Self.weekdayKey) ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: Self.weekdayKey); objectWillChange.send() }
    }
    private var historyJSON: String {
        get { UserDefaults.standard.string(forKey: Self.historyKey) ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: Self.historyKey); objectWillChange.send() }
    }

    private var bag: Set<AnyCancellable> = []

    init() {
        if history.isEmpty { history = [currentPlan(from: .distantPast)] }
        // Record goal changes (debounced) so they apply from today on.
        objectWillChange
            .debounce(for: .milliseconds(700), scheduler: RunLoop.main)
            .sink { [weak self] _ in self?.recordPlan() }
            .store(in: &bag)
    }

    // MARK: Weekday goals

    var weekdayKcal: [Int: Double] {
        get {
            guard let data = weekdayJSON.data(using: .utf8),
                  let dict = try? JSONDecoder().decode([String: Double].self, from: data) else { return [:] }
            return Dictionary(uniqueKeysWithValues: dict.compactMap { k, v in Int(k).map { ($0, v) } })
        }
        set {
            let dict = Dictionary(uniqueKeysWithValues: newValue.map { ("\($0.key)", $0.value) })
            weekdayJSON = (try? JSONEncoder().encode(dict)).flatMap { String(data: $0, encoding: .utf8) } ?? ""
        }
    }

    func kcal(forWeekday wd: Int) -> Double { weekdayKcal[wd] ?? kcal }

    func setKcal(_ value: Double, forWeekday wd: Int) {
        var dict = weekdayKcal
        dict[wd] = value
        weekdayKcal = dict
    }

    // MARK: History

    private(set) var history: [GoalPlan] {
        get {
            guard let data = historyJSON.data(using: .utf8) else { return [] }
            let dec = JSONDecoder()
            dec.dateDecodingStrategy = .iso8601
            return (try? dec.decode([GoalPlan].self, from: data)) ?? []
        }
        set {
            let enc = JSONEncoder()
            enc.dateEncodingStrategy = .iso8601
            historyJSON = (try? enc.encode(newValue)).flatMap { String(data: $0, encoding: .utf8) } ?? ""
        }
    }

    private func currentPlan(from: Date) -> GoalPlan {
        GoalPlan(from: from, kcal: kcal, protein: protein, carbs: carbs, fat: fat,
                 weekdayKcal: weekdayEnabled ? weekdayKcal : [:], activityPercent: activityEnabled ? activityPercent : 0)
    }

    /// Stores the current targets as valid from today (same-day edits replace each other).
    func recordPlan() {
        let today = Calendar.current.startOfDay(for: .now)
        var h = history
        let plan = currentPlan(from: today)
        if let last = h.last, last.sameTargets(as: plan) { return }
        if let last = h.last, last.from >= today { h[h.count - 1] = plan } else { h.append(plan) }
        history = h
    }

    // MARK: Goal of a day

    func target(for day: Date) -> DayTarget {
        let cal = Calendar.current
        let d = cal.startOfDay(for: day)
        let plan: GoalPlan = d >= cal.startOfDay(for: .now)
            ? currentPlan(from: d)
            : (history.last { $0.from <= d } ?? history.first ?? currentPlan(from: d))
        let base = plan.weekdayKcal[cal.component(.weekday, from: d)] ?? plan.kcal
        let health = activityEnabled ? ActivityStore.kcal(for: d) : 0
        let manual = ActivityStore.manual(for: d)
        let active = health + manual
        // Manually added activity counts with the same share as Health activity. Without Health
        // there is no share to set, so it counts in full.
        let manualPercent = activityEnabled || plan.activityPercent > 0 ? plan.activityPercent : 100
        let bonus = (health * plan.activityPercent / 100 + manual * manualPercent / 100).rounded()
        let total = base + bonus
        // Protein stays; the extra/missing energy is shared by carbs and fat in their usual ratio.
        let delta = total - plan.kcal
        let carbE = plan.carbs * 4, fatE = plan.fat * 9
        let share = carbE + fatE > 0 ? carbE / (carbE + fatE) : 0.6
        return DayTarget(kcal: total, protein: plan.protein,
                         carbs: max(0, (plan.carbs + delta * share / 4).rounded()),
                         fat: max(0, (plan.fat + delta * (1 - share) / 9).rounded()),
                         baseKcal: base, activeKcal: active, healthKcal: health, manualKcal: manual, activityBonus: bonus,
                         activityPercent: plan.activityPercent)
    }

    /// Re-renders views after new activity data arrived.
    func activityUpdated() { objectWillChange.send() }

    /// Macros as fixed grams or as % of the calorie goal (always adds up to 100 %).
    @AppStorage("goal.macroMode") var macroMode: MacroMode = .percent
    @AppStorage("goal.proteinPct") var proteinPct: Double = 25
    @AppStorage("goal.fatPct") var fatPct: Double = 30
    var carbsPct: Double { max(0, 100 - proteinPct - fatPct) }

    enum MacroMode: String, CaseIterable, Identifiable {
        case percent, grams
        var id: String { rawValue }
        var label: String { self == .percent ? "Prozent" : "Gramm" }
    }

    /// Recomputes the gram targets from the percentages (percent mode only).
    func syncMacros() {
        guard macroMode == .percent else { return }
        protein = (kcal * proteinPct / 100 / 4).rounded()
        fat = (kcal * fatPct / 100 / 9).rounded()
        carbs = (kcal * carbsPct / 100 / 4).rounded()
    }

    /// Keeps percentages in sync when grams were edited directly.
    func syncPercentFromGrams() {
        let total = max(protein * 4 + carbs * 4 + fat * 9, 1)
        proteinPct = (protein * 4 / total * 100).rounded()
        fatPct = (fat * 9 / total * 100).rounded()
    }

    @AppStorage("profile.sex") var sex: Sex = .female
    @AppStorage("profile.age") var age: Int = 28
    @AppStorage("profile.height") var heightCM: Double = 170
    @AppStorage("profile.weight") var weightKG: Double = 68
    @AppStorage("profile.activity") var activity: Activity = .light
    @AppStorage("profile.target") var target: Target = .maintain
    @AppStorage("onboarded") var onboarded = false

    enum Sex: String, CaseIterable, Identifiable {
        case female, male
        var id: String { rawValue }
        var label: String { self == .female ? "Weiblich" : "Männlich" }
    }

    enum Activity: String, CaseIterable, Identifiable {
        case sedentary, light, moderate, active, veryActive
        var id: String { rawValue }
        var factor: Double {
            switch self { case .sedentary: 1.2; case .light: 1.375; case .moderate: 1.55; case .active: 1.725; case .veryActive: 1.9 }
        }
        var label: String {
            switch self {
            case .sedentary: "Kaum aktiv"
            case .light: "Leicht aktiv"
            case .moderate: "Mäßig aktiv"
            case .active: "Sehr aktiv"
            case .veryActive: "Extrem aktiv"
            }
        }
        var detail: String {
            switch self {
            case .sedentary: "Bürojob, wenig Bewegung"
            case .light: "1–3× Sport pro Woche"
            case .moderate: "3–5× Sport pro Woche"
            case .active: "6–7× Sport pro Woche"
            case .veryActive: "Körperliche Arbeit + Sport"
            }
        }
    }

    enum Target: String, CaseIterable, Identifiable {
        case lose, loseSlow, maintain, gain
        var id: String { rawValue }
        var delta: Double {
            switch self { case .lose: -500; case .loseSlow: -250; case .maintain: 0; case .gain: 300 }
        }
        var label: String {
            switch self {
            case .lose: "Abnehmen"
            case .loseSlow: "Sanft abnehmen"
            case .maintain: "Gewicht halten"
            case .gain: "Zunehmen"
            }
        }
    }

    /// Mifflin-St Jeor
    var bmr: Double {
        10 * weightKG + 6.25 * heightCM - 5 * Double(age) + (sex == .male ? 5 : -161)
    }

    var tdee: Double { bmr * activity.factor }

    var suggestedKcal: Double { (max(1200, tdee + target.delta) / 10).rounded() * 10 }

    func applySuggestion() {
        kcal = suggestedKcal
        // protein ~1.8 g/kg (max 35 %), fat 28 %, rest carbs
        let p = min(weightKG * 1.8 * 4 / kcal * 100, 35)
        proteinPct = p.rounded()
        fatPct = 28
        let mode = macroMode
        macroMode = .percent
        syncMacros()
        macroMode = mode
        waterML = Int((weightKG * 35 / 250).rounded() * 250)
    }
}
