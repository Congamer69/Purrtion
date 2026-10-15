import Foundation

/// Large restaurant chains (McDonald's, Burger King …) with the chains' own published nutrition values.
/// Built by tools/restaurants/build_restaurants.py, bundled, works offline and is updated like BLS and the Swiss database.
final class RestaurantDatabase: @unchecked Sendable {
    static let shared = RestaurantDatabase()
    static let attribution = "Restaurantketten: offizielle Nährwertangaben von McDonald's Deutschland und Burger King Deutschland."

    struct Chain {
        let id: String
        let name: String
        let source: String
    }

    private struct Entry {
        let code: String
        let chain: String
        let name: String
        let category: String
        let serving: Double
        let unit: String
        let words: [Substring]
        let values: [Double?]
    }

    /// Ways people write the chain names in a search ("mcdonalds", "mäcces", "bk" …), already folded.
    private static let aliases: [String: [String]] = [
        "mcdonalds": ["mcdonalds", "mcdonald", "mcd", "mces", "maces", "macces", "mecces", "mcdoof"],
        "burgerking": ["burgerking", "bk"],
    ]

    private var entries: [Entry] = []
    private var keys: [String] = []
    private(set) var chains: [String: Chain] = [:]
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
        guard let url = DatabaseUpdater.fileURL(.restaurants),
              let data = try? Data(contentsOf: url),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let keys = json["keys"] as? [String],
              let foods = json["foods"] as? [[Any]] else { return }
        self.keys = keys
        for (id, c) in json["chains"] as? [String: [String: String]] ?? [:] {
            chains[id] = Chain(id: id, name: c["name"] ?? id, source: c["source"] ?? "")
        }
        for f in foods {
            guard f.count >= 7, let code = f[0] as? String, let chain = f[1] as? String, let name = f[2] as? String,
                  let vals = f[6] as? [Any] else { continue }
            let folded = Self.normalize(name)
            indexByCode[code] = entries.count
            entries.append(Entry(code: code, chain: chain, name: name, category: f[3] as? String ?? "",
                                 serving: (f[4] as? NSNumber)?.doubleValue ?? 100, unit: f[5] as? String ?? "g",
                                 words: folded.split(whereSeparator: { !$0.isLetter && !$0.isNumber }),
                                 values: vals.map { ($0 as? NSNumber)?.doubleValue }))
        }
    }

    func reload() {
        lock.lock()
        entries = []; keys = []; chains = [:]; indexByCode = [:]
        loaded = false
        lock.unlock()
        preload()
    }

    /// Folded text without apostrophes and with the chain names written together ("McDonald's" → "mcdonalds").
    private static func normalize(_ s: String) -> String {
        BLSDatabase.fold(s)
            .replacingOccurrences(of: "'", with: "").replacingOccurrences(of: "’", with: "").replacingOccurrences(of: "®", with: " ")
            .replacingOccurrences(of: "mc donald", with: "mcdonald").replacingOccurrences(of: "burger king", with: "burgerking")
    }

    func food(code: String) -> FoodItem? {
        loadIfNeeded()
        return indexByCode[code].map { food(entries[$0]) }
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
        let portion = e.unit == "ml" ? "1 Getränk" : "1 Portion"
        return FoodItem(id: "rk-\(e.code)", name: e.name, brand: chains[e.chain]?.name, source: .restaurant, per100: n, unit: e.unit,
                        servings: [ServingOption(name: portion, grams: e.serving)], origin: e.category.isEmpty ? nil : e.category)
    }

    /// Products of the chains. A chain name in the query ("mcdonalds pommes", "bk") narrows the results to that chain;
    /// the chain name alone lists its whole menu.
    func search(_ query: String, limit: Int = 25) -> [FoodItem] {
        loadIfNeeded()
        let q = Self.normalize(query).trimmingCharacters(in: .whitespacesAndNewlines)
        var tokens = SearchMatcher.tokens(q)
        guard !tokens.isEmpty else { return [] }
        var chain: String?
        tokens.removeAll { t in
            guard let c = Self.aliases.first(where: { $0.value.contains(t) })?.key else { return false }
            chain = c
            return true
        }
        let pool = entries.indices.filter { chain == nil || entries[$0].chain == chain }
        if tokens.isEmpty {
            guard chain != nil else { return [] }
            // Whole menu: burgers first, then other dishes, sides, desserts and drinks.
            func rank(_ e: Entry) -> Int {
                if e.unit == "ml" { return 4 }
                let c = e.category.lowercased()
                if ["burger", "beef", "chicken", "mccrispy", "mcwrap", "neu"].contains(where: c.hasPrefix) { return 0 }
                if c.contains("beilage") || c.contains("dip") || c.contains("snack") { return 2 }
                if c.contains("dessert") || c.contains("frühstück") || c.contains("mccafé") { return 3 }
                return 1
            }
            return pool.sorted { (rank(entries[$0]), entries[$0].name) < (rank(entries[$1]), entries[$1].name) }
                .prefix(200).map { food(entries[$0]) }
        }
        var scored: [(Int, Int)] = []
        for i in pool {
            let e = entries[i]
            var score = 0
            if tokens.allSatisfy({ t in e.words.contains { SearchMatcher.strict($0, t) } }) {
                if let first = e.words.first, first.hasPrefix(tokens[0]) { score += 300 }
                for t in tokens where e.words.contains(where: { $0 == t }) { score += 60 }
            } else if tokens.allSatisfy({ t in e.words.contains { SearchMatcher.relaxed($0, t) } }) {
                score -= 400
            } else { continue }
            score -= e.name.count * 2
            scored.append((i, score))
        }
        return scored.sorted { $0.1 > $1.1 }.prefix(limit).map { food(entries[$0.0]) }
    }

    /// True when the query names a chain, so its results belong at the top.
    static func mentionsChain(_ query: String) -> Bool {
        let tokens = normalize(query).split(whereSeparator: { !$0.isLetter && !$0.isNumber }).map(String.init)
        return tokens.contains { t in aliases.values.contains { $0.contains(t) } }
    }
}
