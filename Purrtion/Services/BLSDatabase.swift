import Foundation

/// Bundeslebensmittelschlüssel 4.0 (Max Rubner-Institut, CC BY 4.0) – the official German nutrient
/// database: ~7,100 foods with up to 138 lab-analysed nutrients. Bundled with the app, works offline.
final class BLSDatabase: @unchecked Sendable {
    static let shared = BLSDatabase()
    static let attribution = "Max Rubner-Institut (2025): Bundeslebensmittelschlüssel (BLS), Version 4.0 – Deutsche Nährstoffdatenbank. Karlsruhe. DOI: 10.25826/Data20251217-134202-0 · Lizenz CC BY 4.0"

    private var codes: [String] = []
    private var names: [String] = []
    private var folded: [String] = []
    private var values: [[Double?]] = []
    private var keys: [String] = []
    private var indexByCode: [String: Int] = [:]
    private let lock = NSLock()
    private var loaded = false

    /// Call early (e.g. on app start) so the first search is instant.
    func preload() {
        DispatchQueue.global(qos: .userInitiated).async { self.loadIfNeeded() }
    }

    private func loadIfNeeded() {
        lock.lock(); defer { lock.unlock() }
        guard !loaded else { return }
        loaded = true
        guard let url = DatabaseUpdater.fileURL(.bls),
              let data = try? Data(contentsOf: url),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let keys = json["keys"] as? [String],
              let foods = json["foods"] as? [[Any]] else { return }
        self.keys = keys
        codes.reserveCapacity(foods.count)
        for f in foods {
            guard f.count == 3, let code = f[0] as? String, let name = f[1] as? String, let vals = f[2] as? [Any] else { continue }
            indexByCode[code] = codes.count
            codes.append(code)
            names.append(name)
            folded.append(Self.fold(name))
            values.append(vals.map { ($0 as? NSNumber)?.doubleValue })
        }
    }

    /// Drops the loaded data so the next search reads the (updated) file again.
    func reload() {
        lock.lock()
        codes = []; names = []; folded = []; values = []; keys = []; indexByCode = [:]
        loaded = false
        lock.unlock()
        preload()
    }

    static func fold(_ s: String) -> String {
        s.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "de_DE"))
            .replacingOccurrences(of: "ß", with: "ss")
    }

    // MARK: Lookup

    func food(code: String) -> FoodItem? {
        loadIfNeeded()
        return indexByCode[code].map(food(at:))
    }

    private func food(at i: Int) -> FoodItem {
        let code = codes[i]
        var n = Nutrients()
        for (k, key) in keys.enumerated() {
            guard let v = values[i][k] else { continue }
            switch key {
            case "kcal": n.kcal = v
            case "protein": n.protein = v
            case "carbs": n.carbs = v
            case "fat": n.fat = v
            default: n.extra[key] = v
            }
        }
        let popular = PopularFoods.byCode[code]
        let unit = popular?.unit ?? Self.unit(code: code, name: names[i])
        return FoodItem(id: "bls-\(code)", name: popular?.name ?? names[i], brand: nil,
                        source: .bls, per100: n, unit: unit,
                        servings: popular?.servings ?? Self.defaultServings(code: code, name: names[i], unit: unit),
                        origin: popular != nil ? names[i] : nil)
    }

    // MARK: Search

    func search(_ query: String, limit: Int = 40) -> [FoodItem] {
        loadIfNeeded()
        let q = Self.fold(query).trimmingCharacters(in: .whitespacesAndNewlines)
        let tokens = SearchMatcher.tokens(q)
        guard !tokens.isEmpty else { return [] }
        let phrase = tokens.joined(separator: " ")

        var scored: [(Int, Int)] = []
        var strictHits = Set<Int>()
        for i in folded.indices {
            let name = folded[i]
            let popular = PopularFoods.byCode[codes[i]]
            let haystack = popular.map { name + " " + $0.searchText } ?? name
            guard tokens.allSatisfy({ haystack.contains($0) }) else { continue }

            var score = 0
            let words = name.split(whereSeparator: { !$0.isLetter && !$0.isNumber })
            let popularWords = popular?.searchTerms.flatMap { $0.split(separator: " ") } ?? []
            let allWords = words + popularWords
            // A token must start a word or a part of a German compound ("milch" in "Vollmilch"),
            // not hide inside a syllable ("latte" in "Blätterteig").
            guard tokens.allSatisfy({ t in allWords.contains { SearchMatcher.strict($0, t) } }) else { continue }
            let prefixHit = tokens.allSatisfy { t in allWords.contains { $0.hasPrefix(t) } }
            if !prefixHit { score -= 150 }
            if let popular, prefixHit {
                score += 600
                if popular.searchTerms.contains(phrase) { score += 2000 }
                else if popular.searchTerms.contains(where: { $0.hasPrefix(phrase) }) { score += 800 }
            }
            if let first = words.first, first.hasPrefix(tokens[0]) { score += 300 }
            if name.hasPrefix(phrase) { score += 150 }
            for t in tokens where words.contains(where: { $0 == t }) { score += 60 }
            if name.contains(" roh") { score += 25 }
            if let c = codes[i].first, "XY".contains(c), tokens.count == 1 { score -= 30 }
            score -= name.count * 2
            scored.append((i, score))
            strictHits.insert(i)
        }

        // Second, forgiving pass: typos, plurals and split compounds ("Käsespätzle" → "Spätzle mit Käse").
        if scored.count < 8 {
            for i in folded.indices where !strictHits.contains(i) {
                let name = folded[i]
                guard tokens.allSatisfy({ SearchMatcher.mayMatch(name, $0) }) else { continue }
                let words = name.split(whereSeparator: { !$0.isLetter && !$0.isNumber })
                guard tokens.allSatisfy({ t in words.contains { SearchMatcher.relaxed($0, t) } || SearchMatcher.compound(t, name: name, words: words) })
                else { continue }
                scored.append((i, -400 - folded[i].count * 2))
            }
        }
        return scored.sorted { $0.1 > $1.1 }.prefix(limit).map { food(at: $0.0) }
    }

    // MARK: Units & portions

    private static func unit(code: String, name: String) -> String {
        let n = name.lowercased()
        guard let c = code.first else { return "g" }
        if c == "N" || c == "P" { return "ml" }  // drinks, alcoholic drinks
        if n.contains("saft") || n.contains("nektar") || n.contains("smoothie") || n.hasSuffix("drink")
            || n.contains("drink ") || n.contains("schorle") { return "ml" }
        if code.hasPrefix("M11") || code.hasPrefix("M13") || code.hasPrefix("M12") { return "ml" }  // milk, kefir
        if code.hasPrefix("Q1") || code.hasPrefix("Q2") || code.hasPrefix("Q3") { return "ml" }  // oils
        return "g"
    }

    /// Sensible default portions by BLS food group when no curated portion exists.
    private static func defaultServings(code: String, name: String, unit: String) -> [ServingOption] {
        let n = name.lowercased()
        func s(_ list: [(String, Double)]) -> [ServingOption] { list.map { ServingOption(name: $0.0, grams: $0.1) } }
        if unit == "ml" {
            if code.hasPrefix("P2") || code.hasPrefix("P3") { return s([("1 Glas", 200), ("1 kleines Glas", 125)]) }
            if code.hasPrefix("P1") { return s([("1 Flasche", 500), ("1 kleine Flasche", 330)]) }
            if code.hasPrefix("P") { return s([("1 Glas", 40), ("1 Schnapsglas", 20)]) }
            if code.hasPrefix("N4") || code.hasPrefix("N5") || code.hasPrefix("N6") || code.hasPrefix("N7") {
                return s([("1 Tasse", 150), ("1 Becher", 250)])
            }
            if code.hasPrefix("Q") { return s([("1 EL", 10), ("1 TL", 4)]) }
            return s([("1 Glas", 200), ("1 Flasche", 500)])
        }
        switch code.first {
        case "B":
            if n.contains("brötchen") || n.contains("semmel") || n.contains("laugen") || n.contains("baguette-brötchen") {
                return s([("1 Stück", 60)])
            }
            if n.contains("toast") { return s([("1 Scheibe", 25)]) }
            if n.contains("knäcke") { return s([("1 Scheibe", 10)]) }
            return s([("1 Scheibe", 45), ("1 dicke Scheibe", 60)])
        case "C":
            if n.contains("gekocht") { return s([("1 Portion", 180)]) }
            if n.contains("flocken") || n.contains("müsli") { return s([("1 Portion", 50), ("1 EL", 10)]) }
            return s([("1 Portion", 70), ("1 EL", 12)])
        case "D": return s([("1 Stück", 100), ("1 Keks", 10)])
        case "E":
            if n.contains("hühnerei") { return s([("1 Ei (M)", 58), ("1 Ei (L)", 65)]) }
            if n.contains("gekocht") { return s([("1 Portion", 250)]) }
            return s([("1 Portion", 100)])
        case "F":
            if n.contains("getrocknet") { return s([("1 Handvoll", 30)]) }
            return s([("1 Portion", 125), ("1 Handvoll", 80)])
        case "G": return s([("1 Portion", 150), ("1 Handvoll", 40)])
        case "H":
            if n.contains("tofu") { return s([("1 Portion", 150)]) }
            if n.contains("mus") || n.contains("creme") { return s([("1 EL", 15), ("1 TL", 6)]) }
            if n.contains("gekocht") || n.contains("konserve") { return s([("1 Portion", 150)]) }
            return s([("1 Handvoll", 30), ("1 EL", 10)])
        case "K":
            if n.contains("chips") { return s([("1 Handvoll", 25), ("1 Tüte", 175)]) }
            if n.contains("pilz") || n.contains("champignon") { return s([("1 Portion", 150)]) }
            return s([("1 Portion", 200), ("1 Stück", 80)])
        case "M":
            if n.contains("joghurt") || n.contains("quark") || n.contains("skyr") || n.contains("frischkäse") {
                return s([("1 Becher", 150), ("1 EL", 20)])
            }
            if n.contains("sahne") || n.contains("rahm") || n.contains("schmand") { return s([("1 EL", 15), ("1 Becher", 200)]) }
            return s([("1 Scheibe", 25), ("1 Portion", 30)])
        case "Q": return s([("1 TL", 5), ("1 EL", 12)])
        case "R": return s([("1 TL", 5), ("1 EL", 15)])
        case "S":
            if n.contains("schokolade") { return s([("1 Riegel", 25), ("1 Tafel", 100)]) }
            if n.contains("eis") { return s([("1 Kugel", 60)]) }
            if n.contains("honig") || n.contains("konfitüre") || n.contains("creme") { return s([("1 TL", 8), ("1 EL", 20)]) }
            return s([("1 Stück", 10), ("1 Handvoll", 25)])
        case "T": return s([("1 Filet", 125), ("1 Portion", 150)])
        case "U", "V": return s([("1 Portion", 150), ("1 kleine Portion", 100)])
        case "W":
            if n.contains("würstchen") || n.contains("wurst") && (n.contains("brat") || n.contains("bock") || n.contains("wiener")) {
                return s([("1 Stück", 100)])
            }
            return s([("1 Scheibe", 15), ("1 Portion", 50)])
        case "X", "Y":
            if n.contains("suppe") || n.contains("eintopf") { return s([("1 Teller", 300), ("1 Tasse", 150)]) }
            if n.contains("sauce") || n.contains("dressing") || n.contains("dip") { return s([("1 EL", 15), ("1 Portion", 60)]) }
            return s([("1 Portion", 300), ("1 kleine Portion", 200)])
        default: return []
        }
    }
}
