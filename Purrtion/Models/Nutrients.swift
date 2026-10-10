import Foundation

/// All nutrients beyond energy + the three macros. Amounts are stored in the nutrient's `unit`.
enum NutrientKey: String, CaseIterable, Codable, Identifiable {
    case sugar, fiber, saturatedFat, monoFat, polyFat, omega3, transFat, cholesterol, salt, sodium
    case potassium, calcium, magnesium, iron, zinc, phosphorus, iodine, selenium, copper, manganese
    case vitaminA, vitaminC, vitaminD, vitaminE, vitaminK
    case vitaminB1, vitaminB2, vitaminB3, vitaminB5, vitaminB6, biotin, vitaminB12, folate
    case caffeine, alcohol

    var id: String { rawValue }

    enum Group: String, CaseIterable { case details = "Details", minerals = "Mineralstoffe", vitamins = "Vitamine", other = "Sonstiges" }

    var group: Group {
        switch self {
        case .sugar, .fiber, .saturatedFat, .monoFat, .polyFat, .omega3, .transFat, .cholesterol, .salt, .sodium: return .details
        case .potassium, .calcium, .magnesium, .iron, .zinc, .phosphorus, .iodine, .selenium, .copper, .manganese: return .minerals
        case .vitaminA, .vitaminC, .vitaminD, .vitaminE, .vitaminK, .vitaminB1, .vitaminB2, .vitaminB3, .vitaminB5,
             .vitaminB6, .biotin, .vitaminB12, .folate: return .vitamins
        case .caffeine, .alcohol: return .other
        }
    }

    var name: String {
        switch self {
        case .sugar: "Zucker"
        case .fiber: "Ballaststoffe"
        case .saturatedFat: "Gesättigte Fette"
        case .monoFat: "Einfach unges. Fette"
        case .polyFat: "Mehrfach unges. Fette"
        case .omega3: "Omega-3-Fettsäuren"
        case .transFat: "Transfette"
        case .cholesterol: "Cholesterin"
        case .salt: "Salz"
        case .sodium: "Natrium"
        case .potassium: "Kalium"
        case .calcium: "Calcium"
        case .magnesium: "Magnesium"
        case .iron: "Eisen"
        case .zinc: "Zink"
        case .phosphorus: "Phosphor"
        case .iodine: "Jod"
        case .selenium: "Selen"
        case .copper: "Kupfer"
        case .manganese: "Mangan"
        case .vitaminA: "Vitamin A"
        case .vitaminC: "Vitamin C"
        case .vitaminD: "Vitamin D"
        case .vitaminE: "Vitamin E"
        case .vitaminK: "Vitamin K"
        case .vitaminB1: "Vitamin B1"
        case .vitaminB2: "Vitamin B2"
        case .vitaminB3: "Niacin (B3)"
        case .vitaminB5: "Pantothensäure (B5)"
        case .biotin: "Biotin (B7)"
        case .vitaminB6: "Vitamin B6"
        case .vitaminB12: "Vitamin B12"
        case .folate: "Folat"
        case .caffeine: "Koffein"
        case .alcohol: "Alkohol"
        }
    }

    var unit: String {
        switch self {
        case .sugar, .fiber, .saturatedFat, .monoFat, .polyFat, .omega3, .transFat, .salt, .alcohol: "g"
        case .cholesterol, .sodium, .potassium, .calcium, .magnesium, .iron, .zinc, .phosphorus, .copper, .manganese,
             .vitaminC, .vitaminE, .vitaminB1, .vitaminB2, .vitaminB3, .vitaminB5, .vitaminB6, .caffeine: "mg"
        case .iodine, .selenium, .vitaminA, .vitaminD, .vitaminK, .biotin, .vitaminB12, .folate: "µg"
        }
    }

    /// EU reference intake (NRV, Regulation 1169/2011) or common guidance. `nil` = no daily target shown.
    var dailyValue: Double? {
        switch self {
        case .sugar: 90
        case .fiber: 30
        case .saturatedFat: 20
        case .salt: 6
        case .sodium: 2400
        case .potassium: 2000
        case .calcium: 800
        case .magnesium: 375
        case .iron: 14
        case .zinc: 10
        case .phosphorus: 700
        case .iodine: 150
        case .selenium: 55
        case .copper: 1
        case .manganese: 2
        case .vitaminB5: 6
        case .biotin: 50
        case .vitaminA: 800
        case .vitaminC: 80
        case .vitaminD: 20
        case .vitaminE: 12
        case .vitaminK: 75
        case .vitaminB1: 1.1
        case .vitaminB2: 1.4
        case .vitaminB3: 16
        case .vitaminB6: 1.4
        case .vitaminB12: 2.5
        case .folate: 200
        case .cholesterol: 300
        case .caffeine: 400
        default: nil
        }
    }

    /// For these, staying *below* the daily value is the goal.
    var isLimit: Bool { [.sugar, .saturatedFat, .salt, .sodium, .cholesterol, .caffeine, .transFat].contains(self) }
}

struct Nutrients: Codable, Hashable {
    var kcal: Double = 0
    var protein: Double = 0
    var carbs: Double = 0
    var fat: Double = 0
    var extra: [String: Double] = [:]

    subscript(key: NutrientKey) -> Double? {
        get { extra[key.rawValue] }
        set { extra[key.rawValue] = newValue }
    }

    func scaled(_ factor: Double) -> Nutrients {
        Nutrients(kcal: kcal * factor, protein: protein * factor, carbs: carbs * factor, fat: fat * factor,
                  extra: extra.mapValues { $0 * factor })
    }

    static func + (a: Nutrients, b: Nutrients) -> Nutrients {
        Nutrients(kcal: a.kcal + b.kcal, protein: a.protein + b.protein, carbs: a.carbs + b.carbs, fat: a.fat + b.fat,
                  extra: a.extra.merging(b.extra, uniquingKeysWith: +))
    }

    /// Fill in salt/sodium from each other and kcal from macros when missing.
    mutating func normalize() {
        if self[.salt] == nil, let na = self[.sodium] { self[.salt] = na * 2.5 / 1000 }
        if self[.sodium] == nil, let s = self[.salt] { self[.sodium] = s / 2.5 * 1000 }
        if kcal == 0, protein + carbs + fat > 0 { kcal = protein * 4 + carbs * 4 + fat * 9 + (self[.alcohol] ?? 0) * 7 }
    }
}
