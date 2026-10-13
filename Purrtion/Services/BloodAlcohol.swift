import Foundation

/// Blood alcohol estimate (‰) from the logged drinks.
///
/// Distribution volume from total body water (Watson formulas: sex, age, height, weight) instead of the flat
/// Widmark factor – more accurate for very light or heavy people. Each drink is absorbed linearly over
/// 45 minutes (≈10 % never reaches the blood), alcohol is broken down at a constant 0.15 ‰ per hour.
struct BloodAlcohol {
    struct Drink: Identifiable {
        let id: UUID
        let name: String
        let time: Date
        let grams: Double
    }

    struct Point: Identifiable {
        let time: Date
        let promille: Double
        var id: Date { time }
    }

    let drinks: [Drink]
    let points: [Point]
    let peak: Point?
    /// Body water in litres used for the calculation.
    let bodyWater: Double

    static let eliminationPerHour = 0.15
    static let absorptionMinutes = 45.0
    static let absorbedShare = 0.9

    init(drinks: [Drink], sex: Goals.Sex, age: Int, heightCM: Double, weightKG: Double) {
        self.drinks = drinks.sorted { $0.time < $1.time }
        let tbw: Double = sex == .male
            ? 2.447 - 0.09516 * Double(age) + 0.1074 * heightCM + 0.3362 * weightKG
            : -2.097 + 0.1069 * heightCM + 0.2466 * weightKG
        bodyWater = max(tbw, 15)
        guard let first = self.drinks.first else { points = []; peak = nil; return }
        // g alcohol → ‰: blood is ~80 % water, density 1.055 g/ml.
        let perGram = 0.8 / (bodyWater * 1.055)
        let step = 5.0 * 60
        var t = first.time
        var bac = 0.0
        var out: [Point] = [Point(time: t, promille: 0)]
        let lastDrink = self.drinks.last!.time
        // Simulate until everything is broken down (max. 36 h).
        while t < first.time.addingTimeInterval(36 * 3600) {
            let next = t.addingTimeInterval(step)
            var absorbed = 0.0
            for d in self.drinks {
                let a = d.time, b = d.time.addingTimeInterval(Self.absorptionMinutes * 60)
                let overlap = max(0, min(next, b).timeIntervalSince(max(t, a)))
                absorbed += d.grams * Self.absorbedShare * overlap / (Self.absorptionMinutes * 60)
            }
            bac += absorbed * perGram
            if bac > 0 { bac = max(0, bac - Self.eliminationPerHour * step / 3600) }
            t = next
            out.append(Point(time: t, promille: bac))
            if bac <= 0, t > lastDrink.addingTimeInterval(Self.absorptionMinutes * 60) { break }
        }
        points = out
        peak = out.max { $0.promille < $1.promille }
    }

    func value(at date: Date) -> Double {
        guard let first = points.first, date >= first.time else { return 0 }
        let i = Int(date.timeIntervalSince(first.time) / 300)
        guard i + 1 < points.count else { return 0 }
        let a = points[i], b = points[i + 1]
        let f = date.timeIntervalSince(a.time) / 300
        return a.promille + (b.promille - a.promille) * f
    }

    /// First moment after `date` at which the value falls below `limit`.
    func time(below limit: Double, after date: Date) -> Date? {
        guard value(at: date) >= limit else { return nil }
        return points.first { $0.time > date && $0.promille < limit && $0.time > (drinks.last?.time ?? date) }?.time
    }

    var totalGrams: Double { drinks.reduce(0) { $0 + $1.grams } }
    var isEmpty: Bool { drinks.isEmpty }

    /// Drinks of the entries (alcohol ≥ 1 g). Time = when the drink was logged (editable in the overview).
    static func drinks(from entries: [FoodEntry]) -> [Drink] {
        entries.compactMap { e in
            let g = e.nutrients[.alcohol] ?? 0
            return g >= 1 ? Drink(id: e.id, name: e.name, time: drinkTime(e), grams: g) : nil
        }
    }

    /// When the drink was had: the logging time, unless it was logged later for a past day (then 20:00 that day).
    static func drinkTime(_ e: FoodEntry) -> Date {
        let cal = Calendar.current
        let nextMorning = cal.date(byAdding: .hour, value: 30, to: e.day)!
        if e.createdAt >= e.day, e.createdAt < nextMorning { return e.createdAt }
        return cal.date(byAdding: .hour, value: 20, to: e.day)!
    }

    static func make(entries: [FoodEntry], goals: Goals, weight: Double?) -> BloodAlcohol {
        BloodAlcohol(drinks: drinks(from: entries), sex: goals.sex, age: goals.age, heightCM: goals.heightCM,
                     weightKG: weight ?? goals.weightKG)
    }
}

extension Double {
    /// "0,42 ‰"
    var promilleString: String { formatted(.number.precision(.fractionLength(2))) + " ‰" }
}
