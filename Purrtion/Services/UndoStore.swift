import SwiftUI
import SwiftData

/// Remembers the last deletion for a short while so a false swipe can be taken back.
@MainActor
final class UndoStore: ObservableObject {
    static let shared = UndoStore()
    /// How long the undo button stays around.
    static let window: Duration = .seconds(10)

    private enum Change {
        case entries([FoodEntry])
        case ingredients(entryID: UUID, previous: [RecipeIngredient])
    }

    @Published private(set) var label: String?
    private var change: Change?
    private var expiry: Task<Void, Never>?

    var canUndo: Bool { change != nil }

    /// Call before deleting: keeps detached copies of the entries.
    func recordDeletion(of entries: [FoodEntry]) {
        guard !entries.isEmpty else { return }
        let copies = entries.map { FoodEntry(copying: $0) }
        arm(.entries(copies), label: entries.count == 1 ? "Eintrag" : "\(entries.count) Einträge")
    }

    /// Call before removing an ingredient from a meal.
    func recordIngredientRemoval(of entry: FoodEntry) {
        arm(.ingredients(entryID: entry.id, previous: entry.ingredients), label: "Zutat")
    }

    func undo(ctx: ModelContext) {
        guard let change else { return }
        switch change {
        case .entries(let list):
            list.forEach(ctx.insert)
        case .ingredients(let id, let previous):
            let found = try? ctx.fetch(FetchDescriptor<FoodEntry>(predicate: #Predicate { $0.id == id })).first
            found?.updateCompositeIngredients(previous)
        }
        try? ctx.save()
        Haptics.success()
        clear()
    }

    func clear() {
        expiry?.cancel()
        withAnimation(Motion.quick) { change = nil; label = nil }
    }

    private func arm(_ new: Change, label: String) {
        expiry?.cancel()
        withAnimation(Motion.quick) { change = new; self.label = label }
        expiry = Task { [weak self] in
            try? await Task.sleep(for: Self.window)
            guard !Task.isCancelled else { return }
            self?.clear()
        }
    }
}

extension ModelContext {
    /// Deletes entries and offers to take it back.
    @MainActor func deleteTracked(_ entries: [FoodEntry]) {
        UndoStore.shared.recordDeletion(of: entries)
        entries.forEach(delete)
        try? save()
    }
}

/// Sits next to the "…" menu while something can still be restored.
struct UndoButton: View {
    @ObservedObject private var store = UndoStore.shared
    @Environment(\.modelContext) private var ctx

    var body: some View {
        if let label = store.label {
            Button { store.undo(ctx: ctx) } label: {
                HStack(spacing: 5) {
                    Image(systemName: "arrow.uturn.backward").font(.system(size: 12, weight: .bold))
                    Text("\(label) zurück").font(Theme.font(12, .bold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 12).frame(height: 34)
                .background(Theme.accent, in: Capsule())
            }
            .buttonStyle(SquishButtonStyle())
            .transition(.scale(scale: 0.8, anchor: .trailing).combined(with: .opacity))
            .accessibilityLabel("\(label) wiederherstellen")
        }
    }
}
