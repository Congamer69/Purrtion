import UIKit

enum Haptics {
    static let enabledKey = "haptics"
    private static var on: Bool { UserDefaults.standard.object(forKey: enabledKey) as? Bool ?? true }

    static func tap() { if on { UIImpactFeedbackGenerator(style: .light).impactOccurred() } }
    static func success() { if on { UINotificationFeedbackGenerator().notificationOccurred(.success) } }
    /// Light tick when moving between values (chart scrubbing, pickers).
    static func select() { if on { UISelectionFeedbackGenerator().selectionChanged() } }
    static func warning() { if on { UINotificationFeedbackGenerator().notificationOccurred(.warning) } }
}
