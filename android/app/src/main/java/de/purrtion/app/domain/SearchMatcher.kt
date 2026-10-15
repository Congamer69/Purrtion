package de.purrtion.app.domain

import java.text.Normalizer

/** "Käsespätzle" → "kasespatzle": lowercase, no diacritics, ß → ss. */
fun fold(s: String): String {
    val decomposed = Normalizer.normalize(s.lowercase(java.util.Locale.GERMANY), Normalizer.Form.NFD)
    return decomposed.replace(Regex("\\p{Mn}+"), "").replace("ß", "ss")
}

/** Words of a folded name. */
fun words(folded: String): List<String> = folded.split(Regex("[^\\p{L}\\p{N}]+")).filter { it.isNotEmpty() }

/**
 * Forgiving matching for German food names: word starts, compound parts ("milch" in "Vollmilch"),
 * split compounds ("käsespätzle" ↔ "Spätzle mit Käse"), simple plural endings and small typos.
 */
object SearchMatcher {
    /** Filler words of natural queries ("2 Scheiben Brot mit Butter") that say nothing about the food. */
    val stopwords = setOf(
        "mit", "und", "ohne", "ein", "eine", "einen", "einem", "einer", "der", "die", "das", "dem", "den", "des",
        "vom", "von", "aus", "zum", "zur", "im", "in", "auf", "a", "la", "al", "fur", "etwas", "bisschen",
        "g", "gr", "gramm", "ml", "l", "liter", "kg", "stuck", "stk", "portion", "portionen", "scheibe", "scheiben",
        "glas", "tasse", "teller", "schussel", "loffel", "el", "tl", "handvoll", "becher", "packung", "halbe", "halber",
        "grosse", "grosser", "grosses", "kleine", "kleiner", "kleines", "selbstgemacht", "hausgemacht", "restaurant",
    )

    /** Folded tokens of a query without numbers and filler words (falls back to all tokens). */
    fun tokens(folded: String): List<String> {
        val all = words(folded)
        val meaningful = all.filter { it !in stopwords && !it.all(Char::isDigit) && it.length > 1 }
        return meaningful.ifEmpty { all }
    }

    /** Strict: start of a word, or the last part of a compound ("vollmilch", "hafermilch"). */
    fun strict(word: String, token: String): Boolean =
        word.startsWith(token) || (word.length > token.length + 2 && word.endsWith(token))

    /** Relaxed: also plural/inflection endings and one typo for longer tokens. */
    fun relaxed(word: String, token: String): Boolean {
        if (strict(word, token)) return true
        val s = stem(token)
        if (s != token && s.length >= 3 && strict(word, s)) return true
        if (token.length >= 5 && word.length >= token.length - 1 && word.firstOrNull() == token.firstOrNull()) {
            for (len in listOf(token.length - 1, token.length, token.length + 1)) {
                if (word.length >= len && distance(word.take(len), token) <= 1) return true
            }
        }
        return false
    }

    /** "kasespatzle" → both parts ("kase", "spatzle") appear as words of `name`. */
    fun compound(token: String, name: String, words: List<String>): Boolean {
        if (token.length < 7) return false
        for (cut in 3..(token.length - 3)) {
            val a = token.substring(0, cut)
            val b = token.substring(cut)
            val bTrim = if (b.startsWith("s") && b.length > 4) b.drop(1) else b   // Fugen-s: "schweinsbraten"
            if (!name.contains(a) || !(name.contains(b) || name.contains(bTrim))) continue
            if (words.any { strict(it, a) } && words.any { strict(it, b) || strict(it, bTrim) }) return true
        }
        return false
    }

    /** Cheap check whether a name can match a token loosely at all (shares its start or end). */
    fun mayMatch(name: String, token: String): Boolean {
        if (token.length < 4) return name.contains(token.take(3))
        return name.contains(token.take(3)) || name.contains(token.takeLast(3))
    }

    fun stem(t: String): String {
        if (t.length <= 4) return t
        for (suffix in listOf("en", "er", "n", "e", "s")) if (t.endsWith(suffix)) return t.dropLast(suffix.length)
        return t
    }

    /** Levenshtein distance (small strings only). */
    fun distance(a: String, b: String): Int {
        if (a.isEmpty()) return b.length
        if (b.isEmpty()) return a.length
        var prev = IntArray(b.length + 1) { it }
        for (i in 1..a.length) {
            val cur = IntArray(b.length + 1)
            cur[0] = i
            for (j in 1..b.length) {
                cur[j] = minOf(prev[j] + 1, cur[j - 1] + 1, prev[j - 1] + if (a[i - 1] == b[j - 1]) 0 else 1)
            }
            prev = cur
        }
        return prev[b.length]
    }
}
