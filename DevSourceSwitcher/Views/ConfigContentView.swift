import AppKit
import SwiftUI

struct ConfigContent: Codable, Hashable, Identifiable {
    let id: UUID
    let path: String
    let content: String

    init(path: String, content: String) {
        id = UUID()
        self.path = path
        self.content = content
    }
}

struct ConfigTextView: NSViewRepresentable {
    let content: String

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()

        guard let textView = scrollView.documentView as? NSTextView else {
            return scrollView
        }

        textView.isEditable = false
        textView.isSelectable = true
        textView.backgroundColor = .clear
        textView.textContainerInset = NSSize(width: 8, height: 8)
        textView.isHorizontallyResizable = true
        textView.isVerticallyResizable = true
        textView.textContainer?.widthTracksTextView = false
        textView.textContainer?.containerSize = NSSize(
            width: CGFloat.greatestFiniteMagnitude,
            height: CGFloat.greatestFiniteMagnitude)

        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder

        setText(textView, content: content)
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }
        setText(textView, content: content)
    }

    private func setText(_ textView: NSTextView, content: String) {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = 6

        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: 12, weight: .regular),
            .paragraphStyle: paragraphStyle,
            .foregroundColor: NSColor.labelColor
        ]

        textView.textStorage?.setAttributedString(
            NSAttributedString(string: content, attributes: attributes))
    }
}

struct ConfigContentView: View {
    let item: ConfigContent

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(item.path)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)

            Divider()

            ConfigTextView(content: item.content)
        }
        .frame(
            minWidth: 400, idealWidth: 500, maxWidth: .infinity,
            minHeight: 260, idealHeight: 320, maxHeight: .infinity)
    }
}
