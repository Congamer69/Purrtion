import Foundation

/// Forgiving matching for German food names: word starts, compound parts ("milch" in "Vollmilch"),
/// split compounds ("käsespätzle" ↔ "Spätzle mit Käse"), simple plural endings and small typos.
enum SearchMatcher {
    /// Filler words of natural queries ("2 Scheiben Brot mit Butter") that say nothing about the food.
    static let stopwords: Set<String> = [
        "mit", "und", "ohne", "ein", "eine", "einen", "einem", "einer", "der", "die", "das", "dem", "den", "des",
        "vom", "von", "aus", "zum", "zur", "im", "in", "auf", "a", "la", "al", "fur", "etwas", "bisschen",
        "g", "gr", "gramm", "ml", "l", "liter", "kg", "stuck", "stk", "portion", "portionen", "scheibe", "scheiben",
        "glas", "tasse", "teller", "schussel", "loffel", "el", "tl", "handvoll", "becher", "packung", "halbe", "halber",
        "grosse", "grosser", "grosses", "kleine", "kleiner", "kleines", "selbstgemacht", "hausgemacht", "restaurant",
    ]

    /// Folded tokens of a query without numbers and filler words (falls back to all tokens).
    static func tokens(_ folded: String) -> [String] {
        let all = folded.split(whereSeparator: { !$0.isLetter && !$0.isNumber }).map(String.init)
        let meaningful = all.filter { !stopwords.contains($0) && !$0.allSatisfy(\.isNumber) && $0.count > 1 }
        return meaningful.isEmpty ? all : meaningful
    }

    /// Strict: start of a word, or the last part of a compound ("vollmilch", "hafermilch").
    static func strict(_ word: Substring, _ token: String) -> Bool {
        word.hasPrefix(token) || (word.count > token.count + 2 && word.hasSuffix(token))
    }

    /// Relaxed: also plural/inflection endings and one typo for longer tokens.
    static func relaxed(_ word: Substring, _ token: String) -> Bool {
        if strict(word, token) { return true }
        let s = stem(token)
        if s != token, s.count >= 3, strict(word, s) { return true }
        // Typos: only for longer tokens, and the word has to start alike (keeps this cheap).
        if token.count >= 5, word.count >= token.count - 1, word.first == token.first {
            for len in [token.count - 1, token.count, token.count + 1] where word.count >= len {
                if distance(String(word.prefix(len)), token) <= 1 { return true }
            }
        }
        return false
    }

    /// "kasespatzle" → both parts ("kase", "spatzle") appear as words of `name`.
    static func compound(_ token: String, name: String, words: [Substring]) -> Bool {
        guard token.count >= 7 else { return false }
        let chars = Array(token)
        for cut in 3...(chars.count - 3) {
            let a = String(chars[..<cut]), b = String(chars[cut...])
            let bTrim = b.hasPrefix("s") && b.count > 4 ? String(b.dropFirst()) : b   // Fugen-s: "schweinsbraten"
            guard name.contains(a), name.contains(b) || name.contains(bTrim) else { continue }
            if words.contains(where: { strict($0, a) }),
               words.contains(where: { strict($0, b) || strict($0, bTrim) }) { return true }
        }
        return false
    }

    /// Cheap check whether a name can match a token loosely at all (shares its start or end).
    static func mayMatch(_ name: String, _ token: String) -> Bool {
        guard token.count >= 4 else { return name.contains(token.prefix(3)) }
        return name.contains(token.prefix(3)) || name.contains(token.suffix(3))
    }

    static func stem(_ t: String) -> String {
        guard t.count > 4 else { return t }
        for suffix in ["en", "er", "n", "e", "s"] where t.hasSuffix(suffix) {
            return String(t.dropLast(suffix.count))
        }
        return t
    }

    /// Levenshtein distance (small strings only).
    static func distance(_ a: String, _ b: String) -> Int {
        let a = Array(a), b = Array(b)
        if a.isEmpty { return b.count }
        if b.isEmpty { return a.count }
        var prev = Array(0...b.count)
        for i in 1...a.count {
            var cur = [i] + Array(repeating: 0, count: b.count)
            for j in 1...b.count {
                cur[j] = min(prev[j] + 1, cur[j - 1] + 1, prev[j - 1] + (a[i - 1] == b[j - 1] ? 0 : 1))
            }
            prev = cur
        }
        return prev[b.count]
    }
}
