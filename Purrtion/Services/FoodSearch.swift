import Foundation
import SwiftUI

/// Searches the bundled BLS instantly and Open Food Facts (products) over the network.
@MainActor
final class FoodSearch: ObservableObject {
    @Published var query = ""
    @Published private(set) var foods: [FoodItem] = []
    @Published private(set) var products: [FoodItem] = []
    @Published private(set) var isLoading = false
    @Published private(set) var error: String?

    private var task: Task<Void, Never>?

    var isEmpty: Bool { foods.isEmpty && products.isEmpty }

    func queryChanged() {
        task?.cancel()
        let q = query.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else {
            foods = []; products = []; isLoading = false; error = nil
            return
        }
        isLoading = q.count >= 2
        task = Task {
            let local = await Task.detached(priority: .userInitiated) { BLSDatabase.shared.search(q) }.value
            guard !Task.isCancelled else { return }
            foods = local
            guard q.count >= 2 else { products = []; return }
            try? await Task.sleep(for: .milliseconds(350))   // debounce network
            guard !Task.isCancelled else { return }
            do {
                let result = try await OpenFoodFacts.search(q)
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
