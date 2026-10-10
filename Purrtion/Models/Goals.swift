import SwiftUI

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
