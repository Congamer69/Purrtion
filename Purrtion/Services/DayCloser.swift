import Foundation
import SwiftData
import FoundationModels

/// "Tag abschließen": the AI fills in missing micronutrients for every logged food (barcode products,
/// AI scans, own foods, recipe ingredients) and then writes a short verdict on the day.
/// Uses the same provider and key as the photo recognition.
@MainActor
enum DayCloser {
    /// A food counts as incomplete when fewer than this many of the health-score micronutrients are known.
    private static let completeThreshold = 10

    static func needsMicros(_ food: FoodItem) -> Bool {
        guard food.microsEstimated != true else { return false }
        return HealthScore.microKeys.filter { food.per100[$0] != nil }.count < completeThreshold
    }

    static func close(day: Date, goals: Goals, ctx: ModelContext) async throws -> DayReview {
        let d = Calendar.current.startOfDay(for: day)
        let entries = try ctx.fetch(FetchDescriptor<FoodEntry>(predicate: #Predicate { $0.day == d },
                                                               sortBy: [SortDescriptor(\.createdAt)]))
        guard !entries.isEmpty else { throw MealVision.VisionError.failed("Für diesen Tag gibt es noch keine Einträge.") }
        let provider = AITask.day.provider

        // 1) Fill in missing micronutrients.
        var missing: [String: FoodItem] = [:]
        for entry in entries {
            if entry.isComposite {
                for ing in entry.ingredients where needsMicros(ing.food) { missing[ing.food.id] = ing.food }
            } else if let food = entry.food, needsMicros(food) {
                missing[food.id] = food
            }
        }
        if !missing.isEmpty {
            let micros = try await estimateMicros(Array(missing.values), provider: provider)
            apply(micros, to: entries)
            try? ctx.save()
        }

        // 2) Verdict, based on the now complete numbers.
        let score = HealthScore(entries: entries, goalKcal: goals.kcal, goalProtein: goals.protein)
        let scoreBefore = HealthScore(entries: entries, goalKcal: goals.kcal, goalProtein: goals.protein, withoutAI: true)
        let verdict = try await judge(entries: entries, score: score, goals: goals, provider: provider)

        let existing = try ctx.fetch(FetchDescriptor<DayReview>(predicate: #Predicate { $0.day == d }))
        existing.dropFirst().forEach(ctx.delete)
        let review: DayReview
        if let first = existing.first {
            review = first
        } else {
            review = DayReview(day: d)
            ctx.insert(review)
        }
        review.createdAt = .now
        review.rating = verdict.rating
        review.tone = verdict.tone
        review.points = verdict.points
        review.signature = DayReview.signature(for: entries)
        review.enrichedCount = estimatedFoodCount(entries)
        review.providerName = provider == .apple ? provider.name : "\(provider.name) (\(AITask.day.model(for: provider)))"
        review.score = score.score
        review.scoreBefore = scoreBefore.score
        try ctx.save()
        WidgetBridge.update(ctx, goals: goals)
        return review
    }

    // MARK: Applying estimates

    /// Adds only values that are still missing – label and BLS data always win.
    private static func merge(_ food: FoodItem, _ micros: [String: Double]?) -> FoodItem? {
        guard let micros else { return nil }
        var f = food
        var added = Set(f.aiNutrientKeys ?? [])
        for (key, value) in micros where f.per100.extra[key] == nil && value.isFinite && value >= 0 {
            f.per100.extra[key] = value
            added.insert(key)
        }
        let before = Set(f.per100.extra.keys)
        f.per100.normalize()
        added.formUnion(Set(f.per100.extra.keys).subtracting(before))
        f.aiNutrientKeys = added.sorted()
        f.microsEstimated = true
        return f
    }

    private static func apply(_ micros: [String: [String: Double]], to entries: [FoodEntry]) {
        for entry in entries {
            if entry.isComposite {
                var changed = false
                let list = entry.ingredients.map { ing -> RecipeIngredient in
                    guard let food = merge(ing.food, micros[ing.food.id]) else { return ing }
                    changed = true
                    var updated = ing
                    updated.food = food
                    return updated
                }
                guard changed else { continue }
                entry.updateCompositeIngredients(list)
                if var meal = entry.food {
                    meal.microsEstimated = true
                    entry.foodData = try? JSONEncoder().encode(meal)
                }
            } else if let food = entry.food, let updated = merge(food, micros[food.id]) {
                entry.foodData = try? JSONEncoder().encode(updated)
            }
        }
    }

    private static func estimatedFoodCount(_ entries: [FoodEntry]) -> Int {
        entries.reduce(0) { count, entry in
            if entry.isComposite { return count + entry.ingredients.filter { $0.food.microsEstimated == true }.count }
            return count + (entry.food?.microsEstimated == true ? 1 : 0)
        }
    }

    // MARK: Micronutrient estimate

    private struct MicroPayload: Decodable {
        struct Item: Decodable {
            let id: String
            let micros: MicroList?
            enum CodingKeys: String, CodingKey { case id, micros = "micronutrients_per_100g" }
        }
        let items: [Item]
    }

    private static let microSchema: [String: Any] = [
        "type": "object",
        "properties": [
            "items": ["type": "array", "items": [
                "type": "object",
                "properties": [
                    "id": ["type": "string"],
                    "micronutrients_per_100g": CloudVision.micronutrientListSchema,
                ],
                "required": ["id", "micronutrients_per_100g"],
                "additionalProperties": false,
            ]],
        ],
        "required": ["items"],
        "additionalProperties": false,
    ]

    private static func describe(_ food: FoodItem) -> String {
        let n = food.per100
        var parts = [food.displayName]
        if let brand = food.brand, !brand.isEmpty { parts.append("Marke: \(brand)") }
        if let origin = food.origin, !origin.isEmpty, origin != food.displayName { parts.append(origin) }
        parts.append("pro 100 \(food.unit): \(Int(n.kcal)) kcal, Protein \(n.protein.clean) g, Kohlenhydrate \(n.carbs.clean) g, Fett \(n.fat.clean) g")
        let known = n.extra.filter { $0.value > 0 }.map { "\($0.key) \($0.value.clean)" }.sorted()
        if !known.isEmpty { parts.append("bereits bekannt: " + known.joined(separator: ", ")) }
        return parts.joined(separator: " | ")
    }

    /// Returns food id → micronutrients per 100 g.
    private static func estimateMicros(_ foods: [FoodItem], provider: VisionProvider) async throws -> [String: [String: Double]] {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-fakeAI") {
            try await Task.sleep(for: .seconds(2))
            return Dictionary(uniqueKeysWithValues: foods.map { ($0.id, ["vitaminC": 4, "magnesium": 60, "iron": 2.1, "zinc": 1.5,
                                                                          "vitaminE": 3, "vitaminB1": 0.2, "folate": 30, "potassium": 300]) })
        }
        #endif
        if provider == .apple { return try await AppleDayAI.estimateMicros(foods) }
        var result: [String: [String: Double]] = [:]
        // Short ids keep the prompt small; batches keep each answer well within the output limit.
        for batch in stride(from: 0, to: foods.count, by: 20).map({ Array(foods[$0..<min($0 + 20, foods.count)]) }) {
            var idMap: [String: String] = [:]
            var lines: [String] = []
            for (i, food) in batch.enumerated() {
                let short = "f\(i + 1)"
                idMap[short] = food.id
                lines.append("- id \(short): \(describe(food))")
            }
            let text = """
            Du bist Ernährungswissenschaftlerin. Für die folgenden Lebensmittel aus einem Ernährungstagebuch fehlen \
            Mikronährstoffangaben. Schätze für jedes Lebensmittel realistische Gehalte pro 100 g (bei Getränken pro 100 ml) \
            auf Basis typischer Nährwerttabellen wie dem Bundeslebensmittelschlüssel oder der USDA-Datenbank. \
            Nutze Name, Marke und Makronährstoffe, um das Lebensmittel genau einzuordnen (z. B. Vollkorn oder Weißmehl, \
            angereichert oder nicht). Bereits bekannte Werte musst du nicht wiederholen. Gib nur Werte an, die du plausibel \
            schätzen kannst; ist ein Lebensmittel nicht eindeutig erkennbar (z. B. "Schnell-Eintrag"), gib eine leere Liste zurück.
            Gültige Schlüssel mit Einheit: \(CloudVision.micronutrientHelp).
            Antworte ausschließlich mit JSON: {"items": [{"id": "f1", "micronutrients_per_100g": [{"key": "vitaminC", "value": 12}, {"key": "fiber", "value": 2.5}]}]}

            Lebensmittel:
            \(lines.joined(separator: "\n"))
            """
            let raw = try await CloudVision.request(provider: provider, model: AITask.day.model(for: provider), text: text, b64: nil, schema: microSchema)
            guard let payload = CloudVision.decode(MicroPayload.self, from: raw) else {
                throw MealVision.VisionError.failed("Antwort nicht lesbar")
            }
            let allowed = Set(NutrientKey.allCases.map(\.rawValue))
            for item in payload.items {
                guard let id = idMap[item.id] else { continue }
                result[id] = (item.micros?.values ?? [:]).filter { allowed.contains($0.key) && $0.value.isFinite && $0.value >= 0 }
            }
        }
        return result
    }

    // MARK: Verdict

    struct Verdict {
        var rating: String
        var tone: String
        var points: [String]
    }

    private struct VerdictPayload: Decodable {
        let rating: String
        let tone: String
        let points: [String]
    }

    private static let verdictSchema: [String: Any] = [
        "type": "object",
        "properties": [
            "rating": ["type": "string"],
            "tone": ["type": "string", "enum": ["positiv", "neutral", "kritisch"]],
            "points": ["type": "array", "items": ["type": "string"]],
        ],
        "required": ["rating", "tone", "points"],
        "additionalProperties": false,
    ]

    static func dayDescription(entries: [FoodEntry], score: HealthScore, goals: Goals) -> String {
        let total = entries.reduce(Nutrients()) { $0 + $1.nutrients }
        let foods = entries.map { e -> String in
            var line = "- \(e.name) (\(e.amountText)): \(Int(e.kcal)) kcal, P \(Int(e.protein)) g, K \(Int(e.carbs)) g, F \(Int(e.fat)) g"
            if e.isComposite { line += " – Zutaten: " + e.ingredients.map { "\($0.food.displayName) \(Int($0.grams)) g" }.joined(separator: ", ") }
            return line
        }
        let coverage = HealthScore.microKeys.compactMap { key -> (NutrientKey, Double)? in
            key.dailyValue.map { (key, (total[key] ?? 0) / $0) }
        }
        let low = coverage.filter { $0.1 < 0.5 }.map { "\($0.0.name) \(Int($0.1 * 100)) %" }
        let good = coverage.filter { $0.1 >= 1 }.map { $0.0.name }
        let components = score.components.map { "\($0.title): \(Int($0.points.rounded()))/\(Int($0.maxPoints)) (\($0.valueText))" }
        return """
        Ziele: \(Int(goals.kcal)) kcal, Protein \(Int(goals.protein)) g, Kohlenhydrate \(Int(goals.carbs)) g, Fett \(Int(goals.fat)) g.
        Gegessen:
        \(foods.joined(separator: "\n"))
        Summe: \(Int(total.kcal)) kcal, Protein \(Int(total.protein)) g, Kohlenhydrate \(Int(total.carbs)) g, Fett \(Int(total.fat)) g.
        Health Score: \(score.score)/100 – \(components.joined(separator: "; ")).
        Mikronährstoffe unter 50 % der EU-Referenzmenge: \(low.isEmpty ? "keine" : low.joined(separator: ", ")).
        Mindestens 100 % erreicht: \(good.isEmpty ? "keine" : good.joined(separator: ", ")).
        """
    }

    static let verdictInstructions = """
    Du bist eine freundliche, ehrliche Ernährungsberaterin und ordnest den Ernährungstag einer Person ein. \
    Beziehe dich auf die konkreten Lebensmittel und Zahlen. Duze die Person, bleib motivierend und stelle keine \
    medizinischen Diagnosen.
    rating: Einordnung in 1–2 Wörtern auf Deutsch, z. B. "Ausgewogen", "Sehr gut", "Proteinarm", "Zu süß", "Gemüsearm".
    tone: positiv, neutral oder kritisch.
    points: 3 bis 6 kurze Stichpunkte mit je höchstens 15 Wörtern – was gut lief, was gefehlt hat und ein bis zwei \
    konkrete Tipps für morgen.
    """

    private static func judge(entries: [FoodEntry], score: HealthScore, goals: Goals, provider: VisionProvider) async throws -> Verdict {
        let day = dayDescription(entries: entries, score: score, goals: goals)
        let verdict: Verdict
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-fakeAI") {
            try await Task.sleep(for: .seconds(1))
            return sanitize(Verdict(rating: "Ausgewogen", tone: "positiv", points: [
                "Viel Gemüse und Vollkorn – Ballaststoffziel erreicht.",
                "Lachs liefert Omega-3 und hochwertiges Protein.",
                "Protein mit 69 g noch deutlich unter deinem Ziel von 124 g.",
                "Tipp für morgen: Skyr oder Linsen als Snack einplanen.",
            ]))
        }
        #endif
        if provider == .apple {
            verdict = try await AppleDayAI.judge(day)
        } else {
            let text = verdictInstructions + "\nAntworte ausschließlich mit JSON: {\"rating\": \"…\", \"tone\": \"positiv|neutral|kritisch\", \"points\": [\"…\"]}\n\n" + day
            let raw = try await CloudVision.request(provider: provider, model: AITask.day.model(for: provider), text: text, b64: nil, schema: verdictSchema)
            guard let p = CloudVision.decode(VerdictPayload.self, from: raw) else {
                throw MealVision.VisionError.failed("Antwort nicht lesbar")
            }
            verdict = Verdict(rating: p.rating, tone: p.tone, points: p.points)
        }
        return sanitize(verdict)
    }

    private static func sanitize(_ v: Verdict) -> Verdict {
        let words = v.rating.trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters)).split(separator: " ")
        let tone = ["positiv", "neutral", "kritisch"].contains(v.tone.lowercased()) ? v.tone.lowercased() : "neutral"
        let points = v.points.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }.prefix(6)
        return Verdict(rating: words.prefix(3).joined(separator: " "), tone: tone, points: Array(points))
    }
}

/// On-device variant with Apple Intelligence – free, but with a smaller set of nutrients.
@MainActor
private enum AppleDayAI {
    @Generable
    struct MicroGuess {
        @Guide(description: "Ballaststoffe in g pro 100 g") var fiber: Double?
        @Guide(description: "Zucker in g pro 100 g") var sugar: Double?
        @Guide(description: "Gesättigte Fettsäuren in g pro 100 g") var saturatedFat: Double?
        @Guide(description: "Salz in g pro 100 g") var salt: Double?
        @Guide(description: "Kalium in mg pro 100 g") var potassium: Double?
        @Guide(description: "Calcium in mg pro 100 g") var calcium: Double?
        @Guide(description: "Magnesium in mg pro 100 g") var magnesium: Double?
        @Guide(description: "Eisen in mg pro 100 g") var iron: Double?
        @Guide(description: "Zink in mg pro 100 g") var zinc: Double?
        @Guide(description: "Jod in µg pro 100 g") var iodine: Double?
        @Guide(description: "Vitamin A in µg pro 100 g") var vitaminA: Double?
        @Guide(description: "Vitamin C in mg pro 100 g") var vitaminC: Double?
        @Guide(description: "Vitamin D in µg pro 100 g") var vitaminD: Double?
        @Guide(description: "Vitamin E in mg pro 100 g") var vitaminE: Double?
        @Guide(description: "Vitamin K in µg pro 100 g") var vitaminK: Double?
        @Guide(description: "Vitamin B1 in mg pro 100 g") var vitaminB1: Double?
        @Guide(description: "Vitamin B2 in mg pro 100 g") var vitaminB2: Double?
        @Guide(description: "Niacin (B3) in mg pro 100 g") var vitaminB3: Double?
        @Guide(description: "Vitamin B6 in mg pro 100 g") var vitaminB6: Double?
        @Guide(description: "Vitamin B12 in µg pro 100 g") var vitaminB12: Double?
        @Guide(description: "Folat in µg pro 100 g") var folate: Double?

        var values: [String: Double] {
            let pairs: [(NutrientKey, Double?)] = [
                (.fiber, fiber), (.sugar, sugar), (.saturatedFat, saturatedFat), (.salt, salt), (.potassium, potassium),
                (.calcium, calcium), (.magnesium, magnesium), (.iron, iron), (.zinc, zinc), (.iodine, iodine),
                (.vitaminA, vitaminA), (.vitaminC, vitaminC), (.vitaminD, vitaminD), (.vitaminE, vitaminE),
                (.vitaminK, vitaminK), (.vitaminB1, vitaminB1), (.vitaminB2, vitaminB2), (.vitaminB3, vitaminB3),
                (.vitaminB6, vitaminB6), (.vitaminB12, vitaminB12), (.folate, folate),
            ]
            return pairs.reduce(into: [:]) { out, pair in
                if let v = pair.1, v.isFinite, v >= 0 { out[pair.0.rawValue] = v }
            }
        }
    }

    @Generable
    struct VerdictGuess {
        @Guide(description: "Einordnung des Tages in 1–2 Wörtern, z. B. 'Ausgewogen' oder 'Proteinarm'") var rating: String
        @Guide(description: "Gesamteindruck", .anyOf(["positiv", "neutral", "kritisch"])) var tone: String
        @Guide(description: "3 bis 6 kurze Stichpunkte auf Deutsch", .maximumCount(6)) var points: [String]
    }

    static func model() throws -> SystemLanguageModel {
        let model = SystemLanguageModel.default
        guard model.isAvailable else {
            throw MealVision.VisionError.unavailable("Apple Intelligence ist gerade nicht verfügbar. Wähle unter Profil → KI-Modelle einen anderen Anbieter für die Tagesanalyse.")
        }
        return model
    }

    static func estimateMicros(_ foods: [FoodItem]) async throws -> [String: [String: Double]] {
        let model = try model()
        var result: [String: [String: Double]] = [:]
        for food in foods {
            let session = LanguageModelSession(model: model, instructions: """
            Du bist Ernährungswissenschaftlerin und schätzt Mikronährstoffe pro 100 g anhand typischer Nährwerttabellen. \
            Lass Werte weg, die du nicht plausibel schätzen kannst.
            """)
            let n = food.per100
            let prompt = "\(food.displayName)\(food.brand.map { " (\($0))" } ?? "") – pro 100 g: \(Int(n.kcal)) kcal, Protein \(n.protein.clean) g, Kohlenhydrate \(n.carbs.clean) g, Fett \(n.fat.clean) g."
            guard let guess = try? await session.respond(to: prompt, generating: MicroGuess.self).content else { continue }
            result[food.id] = guess.values
        }
        return result
    }

    static func judge(_ day: String) async throws -> DayCloser.Verdict {
        let session = LanguageModelSession(model: try model(), instructions: DayCloser.verdictInstructions)
        do {
            let guess = try await session.respond(to: day, generating: VerdictGuess.self).content
            return DayCloser.Verdict(rating: guess.rating, tone: guess.tone, points: guess.points)
        } catch {
            throw MealVision.VisionError.unavailable("Apple Intelligence konnte den Tag nicht bewerten (\(error.localizedDescription)). Mit Claude, Gemini oder OpenAI (Profil → KI-Modelle → Tagesanalyse) klappt es zuverlässiger.")
        }
    }
}
