import Foundation
import SwiftUI

/// Searches the bundled BLS and Swiss database instantly and Open Food Facts (products) over the network.
@MainActor
final class FoodSearch: ObservableObject {
    @Published var query = ""
    @Published private(set) var foods: [FoodItem] = []
    @Published private(set) var swiss: [FoodItem] = []
    @Published private(set) var products: [FoodItem] = []
    @Published private(set) var isLoading = false
    @Published private(set) var error: String?

    private var task: Task<Void, Never>?

    var isEmpty: Bool { foods.isEmpty && swiss.isEmpty && products.isEmpty }

    /// Products are searched with the meaningful words only ("2 Eier und ein Toast" → "Eier Toast").
    static func productQuery(_ q: String) -> String {
        let words = q.split(whereSeparator: { $0 == " " || $0 == "," })
        let kept = words.filter { w in
            let f = BLSDatabase.fold(String(w))
            return !SearchMatcher.stopwords.contains(f) && !f.allSatisfy(\.isNumber) && f.count > 1
        }
        return kept.isEmpty ? q : kept.joined(separator: " ")
    }

    func queryChanged() {
        task?.cancel()
        let q = query.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else {
            foods = []; swiss = []; products = []; isLoading = false; error = nil
            return
        }
        isLoading = q.count >= 2
        task = Task {
            let useBLS = SearchSource.bls.isEnabled, useSwiss = SearchSource.swiss.isEnabled
            let (local, ch) = await Task.detached(priority: .userInitiated) {
                #if DEBUG
                let t0 = Date()
                defer { print("search '\(q)' took \(Int(Date().timeIntervalSince(t0) * 1000)) ms") }
                #endif
                return (useBLS ? BLSDatabase.shared.search(q) : [], useSwiss ? SwissDatabase.shared.search(q) : [])
            }.value
            guard !Task.isCancelled else { return }
            foods = local
            swiss = ch
            guard q.count >= 2, SearchSource.openFoodFacts.isEnabled else { products = []; isLoading = false; return }
            try? await Task.sleep(for: .milliseconds(350))   // debounce network
            guard !Task.isCancelled else { return }
            do {
                let result = try await OpenFoodFacts.search(Self.productQuery(q))
                guard !Task.isCancelled else { return }
                products = result
                error = nil
            } catch {
                guard !Task.isCancelled else { return }
                products = []
                self.error = "Produktsuche offline – Lebensmittel funktionieren trotzdem."
            }
            isLoading = false
        }
    }
}
