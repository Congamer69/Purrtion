import Foundation

/// Schweizer Nährwertdatenbank (BLV) – ~1,200 generic foods incl. ~150 ready dishes (burgers, kebab,
/// pizzas, gratins …). Free for diary apps with source attribution. Bundled, works offline.
final class SwissDatabase: @unchecked Sendable {
    static let shared = SwissDatabase()
    static let attribution = "Schweizer Nährwertdatenbank V 7.1, Bundesamt für Lebensmittelsicherheit und Veterinärwesen BLV, naehrwertdaten.ch"

    private struct Entry {
        let code: String
        let name: String
        let folded: String
        let words: [Substring]
        let category: String
        let synonyms: String
        let values: [Double?]
    }

    private var entries: [Entry] = []
    private var keys: [String] = []
    private var indexByCode: [String: Int] = [:]
    private let lock = NSLock()
    private var loaded = false

    func preload() {
        DispatchQueue.global(qos: .utility).async { self.loadIfNeeded() }
    }

    private func loadIfNeeded() {
        lock.lock(); defer { lock.unlock() }
        guard !loaded else { return }
        loaded = true
        guard let url = DatabaseUpdater.fileURL(.swiss),
              let data = try? Data(contentsOf: url),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let keys = json["keys"] as? [String],
              let foods = json["foods"] as? [[Any]] else { return }
        self.keys = keys
        for f in foods {
            guard f.count >= 5, let code = f[0] as? String, let name = f[1] as? String, let vals = f[2] as? [Any] else { continue }
            let synonyms = (f[4] as? String ?? "").replacingOccurrences(of: ";", with: " ")
            let folded = BLSDatabase.fold(name + " " + synonyms)
            indexByCode[code] = entries.count
            entries.append(Entry(code: code, name: name, folded: folded,
                                 words: folded.split(whereSeparator: { !$0.isLetter && !$0.isNumber }),
                                 category: f[3] as? String ?? "", synonyms: synonyms,
                                 values: vals.map { ($0 as? NSNumber)?.doubleValue }))
        }
    }

    func reload() {
        lock.lock()
        entries = []; keys = []; indexByCode = [:]
        loaded = false
        lock.unlock()
        preload()
    }

    func food(code: String) -> FoodItem? {
        loadIfNeeded()
        return indexByCode[code].map { food(entries[$0]) }
    }

    func category(code: String) -> String? {
        loadIfNeeded()
        return indexByCode[code].map { entries[$0].category }
    }

    private func food(_ e: Entry) -> FoodItem {
        var n = Nutrients()
        for (k, key) in keys.enumerated() {
            guard k < e.values.count, let v = e.values[k] else { continue }
            switch key {
            case "kcal": n.kcal = v
            case "protein": n.protein = v
            case "carbs": n.carbs = v
            case "fat": n.fat = v
            default: n.extra[key] = v
            }
        }
        let drink = e.category.hasPrefix("Alkoholfreie Getränke") || e.category.hasPrefix("Alkoholhaltige Getränke")
            || e.name.lowercased().hasPrefix("milch")
        let unit = drink ? "ml" : "g"
        // Name without trailing preparation details: "Fleischlasagne, zubereitet" → "Fleischlasagne"
        var display = e.name.trimmingCharacters(in: .whitespaces)
        for suffix in [", zubereitet", ", gebacken", ", hausgemacht"] where display.hasSuffix(suffix) {
            display = String(display.dropLast(suffix.count))
        }
        return FoodItem(id: "ch-\(e.code)", name: display, brand: nil, source: .swiss, per100: n, unit: unit,
                        servings: Self.servings(category: e.category, name: e.name, unit: unit),
                        origin: display != e.name ? e.name : nil)
    }

    func search(_ query: String, limit: Int = 25) -> [FoodItem] {
        loadIfNeeded()
        let q = BLSDatabase.fold(query).trimmingCharacters(in: .whitespacesAndNewlines)
        let tokens = SearchMatcher.tokens(q)
        guard !tokens.isEmpty else { return [] }
        var scored: [(Int, Int)] = []
        for (i, e) in entries.enumerated() {
            var score = 0
            if tokens.allSatisfy({ t in e.words.contains { SearchMatcher.strict($0, t) } }) {
                if let first = e.words.first, first.hasPrefix(tokens[0]) { score += 300 }
                for t in tokens where e.words.contains(where: { $0 == t }) { score += 60 }
                if e.category.hasPrefix("Gerichte") { score += 40 }
            } else if tokens.allSatisfy({ SearchMatcher.mayMatch(e.folded, $0) }),
                      tokens.allSatisfy({ t in e.words.contains { SearchMatcher.relaxed($0, t) } || SearchMatcher.compound(t, name: e.folded, words: e.words) }) {
                score -= 400
            } else { continue }
            score -= e.name.count * 2
            scored.append((i, score))
        }
        return scored.sorted { $0.1 > $1.1 }.prefix(limit).map { food(entries[$0.0]) }
    }

    /// Fruit and vegetables for the health score (no juices, dried fruit or jam).
    static func isFruitOrVegetable(category: String, name: String) -> Bool {
        let n = name.lowercased()
        if n.contains("saft") || n.contains("getrocknet") || n.contains("konfitüre") || n.contains("sirup") { return false }
        return category.hasPrefix("Früchte") || category.hasPrefix("Gemüse")
    }

    private static func servings(category: String, name: String, unit: String) -> [ServingOption] {
        let n = name.lowercased()
        func s(_ list: [(String, Double)]) -> [ServingOption] { list.map { ServingOption(name: $0.0, grams: $0.1) } }
        if unit == "ml" {
            if category.hasPrefix("Alkoholhaltige") { return n.contains("bier") ? s([("1 Flasche", 330), ("1 Stange", 300)]) : s([("1 Glas", 150)]) }
            return s([("1 Glas", 200), ("1 Tasse", 150)])
        }
        switch true {
        case category.hasPrefix("Gerichte"):
            if n.contains("burger") || n.contains("kebab") || n.contains("hot dog") || n.contains("sandwich") {
                return s([("1 Stück", n.contains("doppelt") ? 260 : 200)])
            }
            if n.contains("pizza") { return s([("1 Pizza", 400), ("1 Stück", 100)]) }
            if n.contains("suppe") || n.contains("bouillon") || n.contains("minestrone") || n.contains("gazpacho") {
                return s([("1 Teller", 300), ("1 Tasse", 200)])
            }
            if n.contains("crêpe") || n.contains("omelette") { return s([("1 Stück", 120), ("1 Portion", 250)]) }
            return s([("1 Portion", 350), ("1 kleine Portion", 250)])
        case category.hasPrefix("Brote"): return s([("1 Scheibe", 50), ("1 Portion", 60)])
        case category.hasPrefix("Früchte"): return s([("1 Stück", 150), ("1 Handvoll", 80)])
        case category.hasPrefix("Gemüse"): return s([("1 Portion", 150)])
        case category.hasPrefix("Fleisch"), category.hasPrefix("Fisch"): return s([("1 Portion", 150)])
        case category.hasPrefix("Milch"):
            if n.contains("käse") { return s([("1 Scheibe", 25), ("1 Portion", 40)]) }
            return s([("1 Becher", 150)])
        case category.hasPrefix("Süssigkeiten"): return s([("1 Stück", 30), ("1 Portion", 60)])
        case category.hasPrefix("Fette"): return s([("1 TL", 5), ("1 EL", 12)])
        case category.hasPrefix("Nüsse"), category.hasPrefix("Salzige Snacks"): return s([("1 Handvoll", 30)])
        default: return s([("1 Portion", 100)])
        }
    }
}
