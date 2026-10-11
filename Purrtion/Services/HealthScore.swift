import Foundation

/// Daily diet quality score 0–100, built from evidence-based targets:
/// - WHO Healthy Diet fact sheet (2020): free sugars < 10 % energy, saturated fat < 10 % energy,
///   salt < 5 g, ≥ 400 g fruit & vegetables per day.
/// - DGE reference values: dietary fibre ≥ 30 g/day, protein 0.8 g/kg (more for active people).
/// - GBD 2017 Diet Collaborators, The Lancet 2019: high sodium, low whole grains/fibre and low fruit
///   are the leading dietary risks for mortality.
/// - EU nutrient reference values (NRV) for vitamin & mineral coverage.
struct HealthScore: Equatable {
    static func == (a: HealthScore, b: HealthScore) -> Bool { a.score == b.score && a.completeness == b.completeness }

    struct Component: Identifiable {
        let id: String
        let title: String
        let icon: String
        let points: Double
        let maxPoints: Double
        let valueText: String
        let targetText: String
        let explanation: String
        let tip: String?

        var ratio: Double { points / maxPoints }
    }

    let components: [Component]
    /// Share of the calorie goal already eaten – below ~40 % the score is only an interim value.
    let completeness: Double

    var score: Int { Int(components.reduce(0) { $0 + $1.points }.rounded()) }
    var isPreliminary: Bool { completeness < 0.4 }

    var rating: String {
        switch score {
        case 85...: "Ausgezeichnet"
        case 70..<85: "Gut"
        case 50..<70: "Okay"
        default: "Ausbaufähig"
        }
    }

    /// The micronutrients used for the coverage part (NRV-based).
    static let microKeys: [NutrientKey] = [.vitaminA, .vitaminC, .vitaminD, .vitaminE, .vitaminK, .vitaminB1, .vitaminB2,
                                           .vitaminB3, .vitaminB6, .vitaminB12, .folate, .calcium, .magnesium, .iron,
                                           .zinc, .potassium, .iodine]

    /// `withoutAI`: score as it would be without the micronutrients the AI added on "Tag abschließen".
    init(entries: [FoodEntry], goalKcal: Double, goalProtein: Double, withoutAI: Bool = false) {
        var total = Nutrients()
        var fruitVeg = 0.0
        for e in entries {
            total = total + (withoutAI ? e.nutrientsWithoutAI : e.nutrients)
            if Self.isFruitOrVegetable(e.food) { fruitVeg += e.grams }
        }
        self.init(total: total, fruitVegGrams: fruitVeg, goalKcal: goalKcal, goalProtein: goalProtein)
    }

    init(total n: Nutrients, fruitVegGrams: Double, goalKcal: Double, goalProtein: Double) {
        completeness = n.kcal / max(goalKcal, 1)
        let kcal = max(n.kcal, 1)
        var c: [Component] = []

        // 1) Energy balance – 15
        let dev = abs(n.kcal - goalKcal) / max(goalKcal, 1)
        let energyPts = 15 * Self.falloff(dev, full: 0.10, zero: 0.40)
        c.append(Component(id: "energy", title: "Energiebilanz", icon: "flame.fill", points: energyPts, maxPoints: 15,
                           valueText: "\(Int(n.kcal)) kcal", targetText: "Ziel \(Int(goalKcal)) kcal ±10 %",
                           explanation: "Eine Energiezufuhr nahe deinem Bedarf ist die Grundlage für ein stabiles Gewicht.",
                           tip: n.kcal < goalKcal * 0.9 ? "Du liegst noch deutlich unter deinem Ziel." :
                                n.kcal > goalKcal * 1.1 ? "Heute deutlich über dem Ziel – morgen etwas leichter essen." : nil))

        // 2) Protein – 10
        let protRatio = n.protein / max(goalProtein, 1)
        let protPts = 10 * min(1, protRatio / 0.9)
        c.append(Component(id: "protein", title: "Protein", icon: "bolt.heart.fill", points: protPts, maxPoints: 10,
                           valueText: "\(Int(n.protein)) g", targetText: "≥ 90 % von \(Int(goalProtein)) g",
                           explanation: "Ausreichend Protein erhält Muskulatur und sättigt lange (DGE, ISSN-Positionspapier).",
                           tip: protRatio < 0.9 ? "Mehr Protein: Skyr, Hülsenfrüchte, Eier, Fisch oder Tofu." : nil))

        // 3) Fibre – 15
        let fiber = n[.fiber] ?? 0
        let fiberPts = 15 * min(1, fiber / 30)
        c.append(Component(id: "fiber", title: "Ballaststoffe", icon: "leaf.fill", points: fiberPts, maxPoints: 15,
                           valueText: "\(fiber.formatted(.number.precision(.fractionLength(0...1)))) g", targetText: "≥ 30 g (DGE)",
                           explanation: "Hohe Ballaststoffzufuhr senkt das Risiko für Herz-Kreislauf-Erkrankungen, Typ-2-Diabetes und Darmkrebs um 15–30 % (Reynolds et al., The Lancet 2019).",
                           tip: fiber < 30 ? "Vollkorn, Hülsenfrüchte, Gemüse, Nüsse und Haferflocken liefern viele Ballaststoffe." : nil))

        // 4) Fruit & vegetables – 10
        let fvPts = 10 * min(1, fruitVegGrams / 400)
        c.append(Component(id: "fruitveg", title: "Obst & Gemüse", icon: "carrot.fill", points: fvPts, maxPoints: 10,
                           valueText: "\(Int(fruitVegGrams)) g", targetText: "≥ 400 g (WHO, „5 am Tag“)",
                           explanation: "Mindestens 400 g Obst und Gemüse täglich sind mit geringerer Sterblichkeit verbunden (Aune et al., 2017). Gezählt werden Lebensmittel aus dem BLS.",
                           tip: fruitVegGrams < 400 ? "Noch \(Int(max(0, 400 - fruitVegGrams))) g Obst oder Gemüse bis zum Ziel." : nil))

        // 5) Sugar – 10
        let sugar = n[.sugar] ?? 0
        let sugarShare = sugar * 4 / kcal
        let sugarPts = 10 * Self.falloff(sugarShare, full: 0.10, zero: 0.25)
        c.append(Component(id: "sugar", title: "Zucker", icon: "cube.fill", points: sugarPts, maxPoints: 10,
                           valueText: "\(Int(sugar)) g · \(Int(sugarShare * 100)) %", targetText: "< 10 % der Energie (WHO)",
                           explanation: "Die WHO empfiehlt, weniger als 10 % der Energie aus Zucker aufzunehmen. Gezählt wird der Gesamtzucker – natürlicher Zucker aus Obst und Milch fließt also mit ein.",
                           tip: sugarShare > 0.10 ? "Süßgetränke und Süßigkeiten sind die größten Zuckerquellen." : nil))

        // 6) Saturated fat – 10
        let sat = n[.saturatedFat] ?? 0
        let satShare = sat * 9 / kcal
        let satPts = 10 * Self.falloff(satShare, full: 0.10, zero: 0.20)
        c.append(Component(id: "satfat", title: "Gesättigte Fette", icon: "drop.fill", points: satPts, maxPoints: 10,
                           valueText: "\(Int(sat)) g · \(Int(satShare * 100)) %", targetText: "< 10 % der Energie (WHO)",
                           explanation: "Weniger gesättigte Fette – ersetzt durch ungesättigte – senkt das Herz-Kreislauf-Risiko (Cochrane Review 2020).",
                           tip: satShare > 0.10 ? "Butter, Käse, Wurst und Gebäck durch Olivenöl, Nüsse oder Fisch ersetzen." : nil))

        // 7) Salt – 10
        let salt = n[.salt] ?? 0
        let saltPts = 10 * Self.falloff(salt, full: 5, zero: 10)
        c.append(Component(id: "salt", title: "Salz", icon: "aqi.low", points: saltPts, maxPoints: 10,
                           valueText: "\(salt.formatted(.number.precision(.fractionLength(0...1)))) g", targetText: "≤ 5 g (WHO), max. 6 g (DGE)",
                           explanation: "Zu viel Natrium ist laut GBD-Studie (The Lancet 2019) das größte ernährungsbedingte Gesundheitsrisiko weltweit.",
                           tip: salt > 5 ? "Fertiggerichte, Brot, Wurst und Käse enthalten viel verstecktes Salz." : nil))

        // 8) Micronutrients – 20
        let coverages = Self.microKeys.compactMap { key -> Double? in
            guard let dv = key.dailyValue else { return nil }
            return min(1, (n[key] ?? 0) / dv)
        }
        let avg = coverages.isEmpty ? 0 : coverages.reduce(0, +) / Double(coverages.count)
        let lowest = Self.microKeys.filter { key in
            guard let dv = key.dailyValue else { return false }
            return (n[key] ?? 0) / dv < 0.5
        }.prefix(3)
        c.append(Component(id: "micros", title: "Vitamine & Mineralstoffe", icon: "sparkles", points: 20 * avg, maxPoints: 20,
                           valueText: "Ø \(Int(avg * 100)) % abgedeckt", targetText: "17 Nährstoffe, EU-Referenzwerte",
                           explanation: "Durchschnittliche Abdeckung von Vitamin A, C, D, E, K, B-Vitaminen, Folat, Calcium, Magnesium, Eisen, Zink, Kalium und Jod (je max. 100 %). Markenprodukte liefern oft nur Pflichtangaben.",
                           tip: lowest.isEmpty ? nil : "Am niedrigsten: " + lowest.map { $0.name }.joined(separator: ", ")))

        components = c
    }

    /// 1 up to `full`, then linearly down to 0 at `zero`.
    private static func falloff(_ x: Double, full: Double, zero: Double) -> Double {
        if x <= full { return 1 }
        if x >= zero { return 0 }
        return 1 - (x - full) / (zero - full)
    }

    /// BLS groups F (fruit), G (vegetables), mushrooms (K7) and legumes (H7) – without juices and dried fruit.
    static func isFruitOrVegetable(_ food: FoodItem?) -> Bool {
        guard let food, food.source == .bls, food.id.hasPrefix("bls-") else { return false }
        let code = String(food.id.dropFirst(4))
        let name = (food.origin ?? food.name).lowercased()
        if name.contains("saft") || name.contains("nektar") || name.contains("getrocknet") || name.contains("konfitüre") { return false }
        return code.hasPrefix("F") || code.hasPrefix("G") || code.hasPrefix("K7") || code.hasPrefix("H7")
    }
}
