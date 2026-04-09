import SwiftUI
import AppKit

struct CodeEditorView: NSViewRepresentable {
    @Binding var text: String
    var isEditable: Bool = true
    var fontSize: CGFloat = 12

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false
        scrollView.scrollerStyle = .overlay

        let textView = scrollView.documentView as! NSTextView
        let font = NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)
        textView.font = font
        textView.isEditable = isEditable
        textView.isSelectable = true
        textView.isRichText = false
        textView.usesFindBar = true
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.isAutomaticTextCompletionEnabled = false
        textView.drawsBackground = false
        textView.textColor = .labelColor
        textView.insertionPointColor = .labelColor
        textView.textContainerInset = NSSize(width: 4, height: 6)

        // Disable line wrapping — allow horizontal scroll
        textView.isHorizontallyResizable = true
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.textContainer?.widthTracksTextView = false
        textView.textContainer?.containerSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)

        // Line numbers
        let rulerView = LineNumberRulerView(textView: textView, font: font)
        scrollView.verticalRulerView = rulerView
        scrollView.hasVerticalRuler = true
        scrollView.rulersVisible = true

        textView.delegate = context.coordinator
        textView.string = text

        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let textView = nsView.documentView as? NSTextView else { return }
        if textView.string != text && !context.coordinator.isUpdating {
            textView.string = text
            nsView.verticalRulerView?.needsDisplay = true
        }
        textView.isEditable = isEditable
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: CodeEditorView
        var isUpdating = false

        init(_ parent: CodeEditorView) { self.parent = parent }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            isUpdating = true
            parent.text = textView.string
            isUpdating = false
        }
    }
}

// MARK: - Line Number Ruler

private final class LineNumberRulerView: NSRulerView {
    private weak var textView: NSTextView?
    private let lineFont: NSFont

    init(textView: NSTextView, font: NSFont) {
        self.textView = textView
        self.lineFont = NSFont.monospacedSystemFont(ofSize: font.pointSize - 1, weight: .regular)
        super.init(scrollView: textView.enclosingScrollView!, orientation: .verticalRuler)
        self.clientView = textView
        self.ruleThickness = 36

        NotificationCenter.default.addObserver(self, selector: #selector(needsRedisplay), name: NSText.didChangeNotification, object: textView)
        NotificationCenter.default.addObserver(self, selector: #selector(needsRedisplay), name: NSView.boundsDidChangeNotification, object: textView.enclosingScrollView?.contentView)
    }

    required init(coder: NSCoder) { fatalError() }

    @objc private func needsRedisplay(_ n: Notification) { needsDisplay = true }

    override func drawHashMarksAndLabels(in rect: NSRect) {
        guard let textView, let lm = textView.layoutManager, let tc = textView.textContainer else { return }

        // Draw gutter background
        let bg = NSColor.windowBackgroundColor.withAlphaComponent(0.6)
        bg.setFill()
        rect.fill()

        let visibleRect = textView.visibleRect
        let glyphRange = lm.glyphRange(forBoundingRect: visibleRect, in: tc)
        let charRange = lm.characterRange(forGlyphRange: glyphRange, actualGlyphRange: nil)
        let content = textView.string as NSString
        let yOffset = textView.textContainerInset.height

        // Count lines before visible area
        var lineNum = 1
        if charRange.location > 0 {
            let before = NSRange(location: 0, length: min(charRange.location, content.length))
            content.enumerateSubstrings(in: before, options: [.byLines, .substringNotRequired]) { _, _, _, _ in
                lineNum += 1
            }
        }

        let attrs: [NSAttributedString.Key: Any] = [
            .font: lineFont,
            .foregroundColor: NSColor.secondaryLabelColor,
        ]

        let drawRange = NSRange(location: charRange.location, length: min(charRange.length, content.length - charRange.location))
        guard drawRange.length > 0 else { return }

        content.enumerateSubstrings(in: drawRange, options: [.byLines, .substringNotRequired]) { _, range, _, _ in
            let gRange = lm.glyphRange(forCharacterRange: range, actualCharacterRange: nil)
            let lineRect = lm.boundingRect(forGlyphRange: gRange, in: tc)
            let y = lineRect.minY + yOffset - visibleRect.minY
            let str = "\(lineNum)" as NSString
            let size = str.size(withAttributes: attrs)
            str.draw(at: NSPoint(x: self.ruleThickness - size.width - 8, y: y + (lineRect.height - size.height) / 2), withAttributes: attrs)
            lineNum += 1
        }
    }
}
