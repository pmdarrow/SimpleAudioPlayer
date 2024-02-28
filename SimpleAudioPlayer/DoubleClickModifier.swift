import SwiftUI

// From https://gist.github.com/joelekstrom/91dad79ebdba409556dce663d28e8297

extension View {
    /// Adds a double click handler this view (macOS only)
    ///
    /// Example
    /// ```
    /// Text("Hello")
    ///     .onDoubleClick { print("Double click detected") }
    /// ```
    /// - Parameters:
    ///   - handler: Block invoked when a double click is detected
    func onDoubleClick(handler: @escaping () -> Void) -> some View {
        modifier(DoubleClickHandler(handler: handler))
    }
}

struct DoubleClickHandler: ViewModifier {
    let handler: () -> Void
    func body(content: Content) -> some View {
        content.overlay {
            DoubleClickListeningViewRepresentable(handler: handler)
        }
    }
}

struct DoubleClickListeningViewRepresentable: NSViewRepresentable {
    let handler: () -> Void
    func makeNSView(context _: Context) -> DoubleClickListeningView {
        DoubleClickListeningView(handler: handler)
    }

    func updateNSView(_: DoubleClickListeningView, context _: Context) {}
}

class DoubleClickListeningView: NSView {
    let handler: () -> Void
    init(handler: @escaping () -> Void) {
        self.handler = handler
        super.init(frame: .zero)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func mouseDown(with event: NSEvent) {
        super.mouseDown(with: event)
        if event.clickCount == 2 {
            handler()
        }
    }
}
