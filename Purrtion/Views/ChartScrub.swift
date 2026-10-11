import SwiftUI
import Charts
import UIKit

/// Long press, then slide over a chart to inspect single values – like Apple Health / Fitness.
/// A UIKit long press is used so normal scrolling keeps working: moving before the press is
/// recognised scrolls the page, holding first starts scrubbing.
private struct LongPressScrub: UIGestureRecognizerRepresentable {
    let onChange: (CGPoint?) -> Void

    func makeUIGestureRecognizer(context: Context) -> UILongPressGestureRecognizer {
        let g = UILongPressGestureRecognizer()
        g.minimumPressDuration = 0.28
        g.allowableMovement = 12
        return g
    }

    func handleUIGestureRecognizerAction(_ g: UILongPressGestureRecognizer, context: Context) {
        switch g.state {
        case .began, .changed: onChange(context.converter.localLocation)
        default: onChange(nil)
        }
    }
}

extension View {
    /// Adds scrubbing to a `Chart`. `snap` maps the raw x value under the finger to a data point (or nil).
    func chartScrub<X: Plottable & Equatable>(_ selection: Binding<X?>, snap: @escaping (X) -> X?) -> some View {
        chartOverlay { proxy in
            GeometryReader { geo in
                Rectangle().fill(.clear).contentShape(Rectangle())
                    .gesture(LongPressScrub { point in
                        guard let point, let frame = proxy.plotFrame.map({ geo[$0] }) else {
                            if selection.wrappedValue != nil { selection.wrappedValue = nil }
                            return
                        }
                        let x = min(max(point.x - frame.minX, 0), frame.width - 1)
                        guard let raw: X = proxy.value(atX: x), let snapped = snap(raw) else { return }
                        if selection.wrappedValue != snapped {
                            if selection.wrappedValue == nil { Haptics.tap() } else { Haptics.select() }
                            selection.wrappedValue = snapped
                        }
                    })
            }
        }
    }
}

/// Header shown while scrubbing: date + a few labelled values, replacing the card title.
struct ScrubHeader: View {
    struct Item: Identifiable {
        let label: String
        let value: String
        var color: Color = Theme.textPrimary
        var id: String { label }
    }
    let title: String
    let items: [Item]

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(Theme.font(13, .semibold)).foregroundStyle(Theme.textSecondary)
            HStack(alignment: .firstTextBaseline, spacing: 14) {
                ForEach(items) { item in
                    VStack(alignment: .leading, spacing: 0) {
                        Text(item.value).font(Theme.font(17, .heavy)).foregroundStyle(item.color)
                            .contentTransition(.numericText())
                        Text(item.label).font(Theme.font(11, .medium)).foregroundStyle(Theme.textSecondary)
                    }
                    .lineLimit(1).fixedSize()
                }
                Spacer(minLength: 0)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12).padding(.vertical, 8)
        .background(Theme.cardAlt, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .shadow(color: .black.opacity(0.18), radius: 8, y: 3)
        .padding(.top, -10)
        .transition(.opacity)
    }
}
