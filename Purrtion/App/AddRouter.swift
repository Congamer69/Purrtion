import SwiftUI

/// The quick-add buttons live in the tab view's bottom accessory (RootView); Today opens the sheet they ask for.
@MainActor
final class AddRouter: ObservableObject {
    static let shared = AddRouter()
    @Published var request: AddSheet?
    func open(_ sheet: AddSheet) { request = sheet }
}
