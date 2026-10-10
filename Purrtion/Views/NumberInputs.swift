import SwiftUI

/// A value you can either drag with a slider or tap and type directly.
struct SliderField: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    var step: Double = 1
    var unit: String = ""
    var decimals: Int = 0
    var tint: Color = Theme.accent

    @State private var text = ""
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(title).font(Theme.font(16)).foregroundStyle(Theme.textPrimary)
                Spacer()
                TextField("", text: $text)
                    .keyboardType(decimals > 0 ? .decimalPad : .numberPad)
                    .multilineTextAlignment(.trailing)
                    .font(Theme.font(20, .bold))
                    .foregroundStyle(tint)
                    .focused($focused)
                    .fixedSize()
                    .onSubmit(commit)
                    .onChange(of: focused) { _, f in if !f { commit() } }
                if !unit.isEmpty {
                    Text(unit).font(Theme.font(15, .medium)).foregroundStyle(Theme.textSecondary)
                }
            }
            Slider(value: Binding(get: { min(max(value, range.lowerBound), range.upperBound) },
                                  set: { value = ($0 / step).rounded() * step }),
                   in: range)
                .tint(tint)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture { focused = true }
        .onAppear { text = format(value) }
        .onChange(of: value) { _, v in if !focused { text = format(v) } }
    }

    private func format(_ v: Double) -> String {
        v.formatted(.number.precision(.fractionLength(0...decimals)).grouping(.never))
    }

    private func commit() {
        let cleaned = text.replacingOccurrences(of: ",", with: ".").filter { $0.isNumber || $0 == "." }
        if let v = Double(cleaned) { value = min(max(v, range.lowerBound * 0.5), range.upperBound * 2) }
        text = format(value)
    }
}

extension Binding where Value == Int {
    /// Lets Int settings use the Double-based SliderField.
    var asDouble: Binding<Double> {
        Binding<Double>(get: { Double(wrappedValue) }, set: { wrappedValue = Int($0.rounded()) })
    }
}

/// Global "Fertig" button above number keyboards.
struct KeyboardDoneToolbar: ViewModifier {
    func body(content: Content) -> some View {
        content.toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Fertig") {
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                }
                .fontWeight(.semibold)
            }
        }
    }
}

extension View {
    func keyboardDoneButton() -> some View { modifier(KeyboardDoneToolbar()) }
}
