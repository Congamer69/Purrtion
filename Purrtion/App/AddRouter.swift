import SwiftUI

/// The "+" tab in the tab bar never shows a screen of its own: it jumps to Heute and asks it to open the add sheet.
@MainActor
final class AddRouter: ObservableObject {
    static let shared = AddRouter()
    @Published var request = 0
    func open() { request += 1 }
}
