import Foundation

/// "Was passt noch?" – ranks favourites, recipes and own foods by how well they fit the rest of the day.
///
/// For every candidate a few amounts are tried (½, 1, 1½, 2 × the usual portion). Each amount is scored by
/// - how well its macro mix matches what is still missing (cosine of the energy vectors protein / carbs / fat),
/// - how much of the missing protein it covers,
/// - how close it gets to the calories that fit right now (rest of the budget split over the meals still to come),
/// and amounts that would go over the budget are dropped (nothing at all once the goal is reached). The usual portion gets a small bonus.
enum MealSuggestions {
    struct Candidate {
        let food: FoodItem
        let quantity: Double
        let serving: ServingOption
        let kind: Kind
    }

    enum Kind: Hashable { case favorite, recipe, own
        var label: String { self == .favorite ? "Favorit" : self == .recipe ? "Rezept" : "Eigenes" }
        var icon: String { self == .favorite ? "star.fill" : self == .recipe ? "book.fill" : "person.fill" }
    }

    struct Suggestion: Identifiable, Hashable {
        static func == (a: Suggestion, b: Suggestion) -> Bool { a.id == b.id && a.quantity == b.quantity }
        func hash(into h: inout Hasher) { h.combine(id); h.combine(quantity) }

        let food: FoodItem
        let quantity: Double
        let serving: ServingOption
        let kind: Kind
        let nutrients: Nutrients
        let score: Double
        let reason: String
        var id: String { food.id }

        var amountText: String {
            if serving.grams == 1 { return "\(quantity.clean) \(serving.name)" }
            let single = serving.name.hasPrefix("1 ") ? String(serving.name.dropFirst(2)) : serving.name
            let amount = quantity == 1 ? serving.name : "\(quantity.clean) × \(single)"
            return "\(amount) · \((quantity * serving.grams).clean) \(food.unit)"
        }
    }

    struct Gap {
        var kcal: Double
        var protein: Double
        var carbs: Double
        var fat: Double
        /// Meals still to come today (incl. the next one).
        var mealsLeft: Int
    }

    static func gap(total: Nutrients, target: DayTarget, now: Date = .now, isToday: Bool) -> Gap {
        let hour = Calendar.current.component(.hour, from: now)
        let meals = !isToday ? 1 : hour < 10 ? 3 : hour < 15 ? 2 : 1
        return Gap(kcal: target.kcal - total.kcal, protein: max(0, target.protein - total.protein),
                   carbs: max(0, target.carbs - total.carbs), fat: max(0, target.fat - total.fat), mealsLeft: meals)
    }

    static func rank(_ candidates: [Candidate], gap: Gap, limit: Int = 30) -> [Suggestion] {
        let budget = max(gap.kcal, 0)
        guard budget >= 20 else { return [] }
        // With almost nothing left, only light snacks make sense.
        let ideal = budget < 150 ? min(budget, 120) : budget / Double(gap.mealsLeft)
        let gapVec = [gap.protein * 4, gap.carbs * 4, gap.fat * 9]
        var best: [String: Suggestion] = [:]
        for c in candidates {
            let factors: [Double] = [0.5, 1, 1.5, 2]
            for f in factors {
                let q = c.quantity * f
                let n = c.food.nutrients(grams: q * c.serving.grams)
                guard n.kcal >= 20 else { continue }
                // Only what really fits: a few kcal of tolerance, never over the goal.
                if n.kcal > budget * 1.03 + 10 { continue }
                let vec = [n.protein * 4, n.carbs * 4, n.fat * 9]
                let macroFit = cosine(vec, gapVec)
                let proteinCover = gap.protein > 5 ? min(n.protein / gap.protein, 1) : 0.5
                let fill = ideal > 0 ? 1 - min(abs(n.kcal - ideal) / ideal, 1) : 0
                var score = 0.42 * macroFit + 0.28 * proteinCover + 0.30 * fill
                if f != 1 { score -= 0.06 }                                    // prefer the usual amount
                if c.kind == .favorite { score += 0.02 }
                let reason = Self.reason(n: n, gap: gap, fill: fill, macroFit: macroFit, ideal: ideal)
                let s = Suggestion(food: c.food, quantity: q, serving: c.serving, kind: c.kind, nutrients: n, score: score, reason: reason)
                if (best[c.food.id]?.score ?? -1) < score { best[c.food.id] = s }
            }
        }
        return best.values.sorted { $0.score > $1.score }.prefix(limit).map { $0 }
    }

    private static func reason(n: Nutrients, gap: Gap, fill: Double, macroFit: Double, ideal: Double) -> String {
        if gap.protein > 15, n.protein >= gap.protein * 0.45 { return "Viel Protein" }
        if fill > 0.85, gap.mealsLeft == 1 { return "Füllt den Rest" }
        if fill > 0.85 { return "Passende Größe" }
        if n.kcal < ideal * 0.5 { return "Leichter Snack" }
        if macroFit > 0.95 { return "Passende Makros" }
        return "Passt ins Budget"
    }

    private static func cosine(_ a: [Double], _ b: [Double]) -> Double {
        let dot = zip(a, b).reduce(0) { $0 + $1.0 * $1.1 }
        let na = sqrt(a.reduce(0) { $0 + $1 * $1 }), nb = sqrt(b.reduce(0) { $0 + $1 * $1 })
        guard na > 0, nb > 0 else { return 0.5 }
        return dot / (na * nb)
    }
}
