import SwiftUI
import UniformTypeIdentifiers
#if os(macOS)
import AppKit
#elseif os(iOS)
import UIKit
#endif

struct ComposerView: View {
    @Binding var draft: String
    let attachments: [ChatImageAttachment]
    let isSending: Bool
    let canSend: Bool
    let unavailableReason: String?
    let attachmentErrorMessage: String?
    let onAttachImages: ([URL]) -> Void
    let onRemoveAttachment: (ChatImageAttachment) -> Void
    let onSend: () -> Void

    @FocusState private var isComposerFocused: Bool
    @State private var isShowingImageImporter = false
    @State private var isDropTargeted = false

    private var trimmedDraft: String {
        draft.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var payload: ChatPromptPayload {
        ChatPromptPayload(text: draft, attachments: attachments)
    }

    private var canSubmit: Bool {
        payload.canSubmit && canSend && isSending == false
    }

    private var sendButtonColor: Color {
        canSubmit ? .accentColor : .secondary.opacity(0.5)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let unavailableReason {
                Text(unavailableReason)
                    .font(.caption)
                    .foregroundStyle(.orange)
            }

            if let attachmentErrorMessage {
                Text(attachmentErrorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            if attachments.isEmpty == false {
                ChatImageAttachmentStrip(
                    attachments: attachments,
                    thumbnailSize: 64,
                    onRemove: onRemoveAttachment
                )
            }

            HStack(alignment: .center, spacing: 8) {
                Button {
                    isShowingImageImporter = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Attach image")
                .accessibilityLabel("Attach image")

                ComposerInputTextView(
                    text: $draft,
                    placeholder: "Message",
                    accessibilityLabel: "Message",
                    accessibilityHint: "Type a prompt for the selected model",
                    onAttachImages: onAttachImages,
                    onSubmit: submitIfPossible
                )
                .focused($isComposerFocused)

                Button(action: submitIfPossible) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 26))
                        .foregroundStyle(sendButtonColor)
                        .contentTransition(.symbolEffect(.replace))
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.return, modifiers: .command)
                .disabled(canSubmit == false)
                .help("Send message")
                .accessibilityLabel("Send message")
                .accessibilityHint("Sends the message to the selected model")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color.platformTextBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(
                        composerBorderColor,
                        lineWidth: isDropTargeted ? 1.5 : 1
                    )
            )
        }
        .fileImporter(
            isPresented: $isShowingImageImporter,
            allowedContentTypes: [.image],
            allowsMultipleSelection: true
        ) { result in
            if case .success(let urls) = result {
                onAttachImages(urls)
            }
        }
        .dropDestination(for: URL.self) { urls, _ in
            onAttachImages(urls)
            return true
        } isTargeted: { isTargeted in
            isDropTargeted = isTargeted
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.platformBackground.opacity(0.95).background(.ultraThinMaterial))
    }

    private var composerBorderColor: Color {
        if isDropTargeted {
            return .accentColor
        }
        return isComposerFocused
            ? Color.platformSeparator.opacity(0.5)
            : Color.platformSeparator.opacity(0.3)
    }

    private func submitIfPossible() {
        guard canSubmit else {
            return
        }
        onSend()
    }
}

#if os(macOS)
private struct ComposerInputTextView: NSViewRepresentable {
    @Binding var text: String
    let placeholder: String
    let accessibilityLabel: String
    let accessibilityHint: String
    var onAttachImages: ([URL]) -> Void
    var onSubmit: () -> Void

    func makeNSView(context: Context) -> FocusForwardingScrollView {
        let textView = PlaceholderTextView()
        textView.placeholderString = placeholder
        textView.onPasteImageURLs = onAttachImages
        textView.delegate = context.coordinator
        textView.isRichText = false
        textView.allowsUndo = true
        textView.font = .systemFont(ofSize: NSFont.systemFontSize)
        textView.drawsBackground = false
        textView.textContainerInset = NSSize(width: 0, height: 2)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.textContainer?.widthTracksTextView = true
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        textView.configureAccessibility(label: accessibilityLabel, hint: accessibilityHint)

        let scrollView = FocusForwardingScrollView()
        scrollView.documentView = textView
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.hasHorizontalScroller = false
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        scrollView.contentView.drawsBackground = false

        context.coordinator.textView = textView
        return scrollView
    }

    func updateNSView(_ scrollView: FocusForwardingScrollView, context: Context) {
        guard let textView = scrollView.documentView as? PlaceholderTextView else {
            return
        }
        context.coordinator.parent = self
        if textView.string != text {
            textView.string = text
            textView.needsDisplay = true
        }
        textView.isEditable = true
        textView.isSelectable = true
        textView.placeholderString = placeholder
        textView.onPasteImageURLs = onAttachImages
        textView.configureAccessibility(label: accessibilityLabel, hint: accessibilityHint)
    }

    nonisolated func sizeThatFits(
        _ proposal: ProposedViewSize,
        nsView: FocusForwardingScrollView,
        context: Context
    ) -> CGSize? {
        MainActor.assumeIsolated {
            guard let textView = nsView.documentView as? PlaceholderTextView,
                  let textContainer = textView.textContainer else {
                return nil
            }

            let width = proposal.width ?? 200
            let font = textView.font ?? .systemFont(ofSize: NSFont.systemFontSize)
            let lineHeight = font.boundingRectForFont.height
            let padding = textView.textContainerInset.height * 2
            let minHeight = lineHeight + padding
            let maxHeight = lineHeight * 6 + padding
            let textWidth = max(
                0,
                width - (textView.textContainerInset.width * 2) - (textContainer.lineFragmentPadding * 2)
            )
            let measuredText = textView.string.isEmpty ? " " : textView.string
            let boundingRect = (measuredText as NSString).boundingRect(
                with: CGSize(width: textWidth, height: .greatestFiniteMagnitude),
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                attributes: [.font: font],
                context: nil
            )
            let contentHeight = ceil(boundingRect.height) + padding

            return CGSize(width: width, height: min(max(contentHeight, minHeight), maxHeight))
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: ComposerInputTextView
        weak var textView: PlaceholderTextView?

        init(_ parent: ComposerInputTextView) {
            self.parent = parent
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? PlaceholderTextView else {
                return
            }
            parent.text = textView.string
            textView.needsDisplay = true
        }

        nonisolated func textView(_ textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            MainActor.assumeIsolated {
                if commandSelector == #selector(NSResponder.insertNewline(_:)) {
                    if NSEvent.modifierFlags.contains(.shift) {
                        textView.insertNewlineIgnoringFieldEditor(nil)
                    } else {
                        parent.onSubmit()
                    }
                    return true
                }
                return false
            }
        }
    }

    final class FocusForwardingScrollView: NSScrollView {
        override var acceptsFirstResponder: Bool {
            true
        }

        override func becomeFirstResponder() -> Bool {
            if let textView = documentView as? NSTextView {
                return window?.makeFirstResponder(textView) ?? false
            }
            return false
        }
    }

    final class PlaceholderTextView: NSTextView {
        var placeholderString: String = "" {
            didSet {
                needsDisplay = true
            }
        }
        var onPasteImageURLs: (([URL]) -> Void)?

        func configureAccessibility(label: String, hint: String) {
            setAccessibilityElement(true)
            setAccessibilityLabel(label)
            setAccessibilityHelp(hint)
            setAccessibilityIdentifier(label)
        }

        override func paste(_ sender: Any?) {
            let pasteboard = NSPasteboard.general
            if let urls = pastedFileURLs(from: pasteboard), urls.isEmpty == false {
                onPasteImageURLs?(urls)
                return
            }
            if let imageURL = pastedImageURL(from: pasteboard) {
                onPasteImageURLs?([imageURL])
                return
            }
            super.paste(sender)
        }

        override func draw(_ dirtyRect: NSRect) {
            super.draw(dirtyRect)
            guard string.isEmpty, placeholderString.isEmpty == false else {
                return
            }
            let attrs: [NSAttributedString.Key: Any] = [
                .foregroundColor: NSColor.placeholderTextColor,
                .font: font ?? NSFont.systemFont(ofSize: NSFont.systemFontSize)
            ]
            let inset = textContainerInset
            let lineFragmentPadding = textContainer?.lineFragmentPadding ?? 5
            let rect = NSRect(
                x: inset.width + lineFragmentPadding,
                y: inset.height,
                width: bounds.width - inset.width * 2 - lineFragmentPadding * 2,
                height: bounds.height - inset.height * 2
            )
            placeholderString.draw(in: rect, withAttributes: attrs)
        }

        private func pastedFileURLs(from pasteboard: NSPasteboard) -> [URL]? {
            let objects = pasteboard.readObjects(forClasses: [NSURL.self], options: nil) ?? []
            let urls = objects.compactMap { object -> URL? in
                if let url = object as? URL {
                    return url
                }
                if let nsURL = object as? NSURL {
                    return nsURL as URL
                }
                return nil
            }
            .filter(\.isFileURL)
            return urls.isEmpty ? nil : urls
        }

        private func pastedImageURL(from pasteboard: NSPasteboard) -> URL? {
            guard let image = NSImage(pasteboard: pasteboard),
                  let data = image.tiffRepresentation else {
                return nil
            }
            let url = ChatAttachmentStore.temporaryPasteURL(fileExtension: "tiff")
            do {
                try data.write(to: url, options: .atomic)
                return url
            } catch {
                return nil
            }
        }
    }
}
#elseif os(iOS)
private struct ComposerInputTextView: UIViewRepresentable {
    @Binding var text: String
    let placeholder: String
    let accessibilityLabel: String
    let accessibilityHint: String
    var onAttachImages: ([URL]) -> Void
    var onSubmit: () -> Void

    func makeUIView(context: Context) -> PlaceholderTextView {
        let textView = PlaceholderTextView()
        textView.delegate = context.coordinator
        textView.font = .preferredFont(forTextStyle: .body)
        textView.adjustsFontForContentSizeCategory = true
        textView.backgroundColor = .clear
        textView.textContainerInset = .zero
        textView.textContainer.lineFragmentPadding = 0
        textView.isScrollEnabled = false
        textView.returnKeyType = .send
        textView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        textView.placeholderText = placeholder
        textView.onPasteImageURLs = onAttachImages
        textView.configureAccessibility(label: accessibilityLabel, hint: accessibilityHint)
        context.coordinator.textView = textView
        return textView
    }

    func updateUIView(_ textView: PlaceholderTextView, context: Context) {
        context.coordinator.parent = self
        if textView.markedTextRange == nil, textView.text != text {
            textView.text = text
        }
        textView.isEditable = true
        textView.isSelectable = true
        textView.placeholderText = placeholder
        textView.onPasteImageURLs = onAttachImages
        textView.configureAccessibility(label: accessibilityLabel, hint: accessibilityHint)
    }

    nonisolated func sizeThatFits(
        _ proposal: ProposedViewSize,
        uiView: PlaceholderTextView,
        context: Context
    ) -> CGSize? {
        MainActor.assumeIsolated {
            let width = proposal.width ?? 200
            let font = uiView.font ?? .preferredFont(forTextStyle: .body)
            let lineHeight = font.lineHeight
            let padding = uiView.textContainerInset.top + uiView.textContainerInset.bottom
            let minHeight = lineHeight + padding
            let maxHeight = lineHeight * 6 + padding
            let textWidth = width
                - uiView.textContainerInset.left
                - uiView.textContainerInset.right
                - uiView.textContainer.lineFragmentPadding * 2
            let measuredText = uiView.text.isEmpty ? " " : uiView.text ?? " "
            let boundingRect = (measuredText as NSString).boundingRect(
                with: CGSize(width: textWidth, height: .greatestFiniteMagnitude),
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                attributes: [.font: font],
                context: nil
            )
            let contentHeight = ceil(boundingRect.height) + padding
            let clampedHeight = min(max(contentHeight, minHeight), maxHeight)
            uiView.isScrollEnabled = contentHeight > maxHeight

            return CGSize(width: width, height: clampedHeight)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    final class Coordinator: NSObject, UITextViewDelegate {
        var parent: ComposerInputTextView
        weak var textView: PlaceholderTextView?

        init(_ parent: ComposerInputTextView) {
            self.parent = parent
        }

        func textViewDidChange(_ textView: UITextView) {
            parent.text = textView.text
            (textView as? PlaceholderTextView)?.updatePlaceholderVisibility()
        }

        func textView(
            _ textView: UITextView,
            shouldChangeTextIn range: NSRange,
            replacementText text: String
        ) -> Bool {
            if text == "\n" {
                parent.onSubmit()
                return false
            }
            return true
        }
    }

    final class PlaceholderTextView: UITextView {
        var placeholderText: String = "" {
            didSet {
                setNeedsDisplay()
            }
        }
        var onPasteImageURLs: (([URL]) -> Void)?

        func updatePlaceholderVisibility() {
            setNeedsDisplay()
        }

        func configureAccessibility(label: String, hint: String) {
            isAccessibilityElement = true
            accessibilityLabel = label
            accessibilityHint = hint
            accessibilityIdentifier = label
        }

        override func layoutSubviews() {
            super.layoutSubviews()
            setNeedsDisplay()
        }

        override func paste(_ sender: Any?) {
            if let urls = UIPasteboard.general.urls?.filter(\.isFileURL), urls.isEmpty == false {
                onPasteImageURLs?(urls)
                return
            }
            if let imageURL = pastedImageURL() {
                onPasteImageURLs?([imageURL])
                return
            }
            super.paste(sender)
        }

        override var text: String! {
            didSet {
                setNeedsDisplay()
            }
        }

        override func draw(_ rect: CGRect) {
            super.draw(rect)
            guard text.isEmpty, placeholderText.isEmpty == false else {
                return
            }

            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.lineBreakMode = .byTruncatingTail
            let attributes: [NSAttributedString.Key: Any] = [
                .font: font ?? .preferredFont(forTextStyle: .body),
                .foregroundColor: UIColor.placeholderText,
                .paragraphStyle: paragraphStyle
            ]
            let placeholderRect = CGRect(
                x: textContainerInset.left + textContainer.lineFragmentPadding,
                y: textContainerInset.top,
                width: bounds.width - textContainerInset.left - textContainerInset.right - (textContainer.lineFragmentPadding * 2),
                height: bounds.height - textContainerInset.top - textContainerInset.bottom
            )
            (placeholderText as NSString).draw(in: placeholderRect, withAttributes: attributes)
        }

        private func pastedImageURL() -> URL? {
            guard let image = UIPasteboard.general.image,
                  let data = image.pngData() else {
                return nil
            }
            let url = ChatAttachmentStore.temporaryPasteURL(fileExtension: "png")
            do {
                try data.write(to: url, options: .atomic)
                return url
            } catch {
                return nil
            }
        }
    }
}
#endif

extension Color {
    static var platformBackground: Color {
        #if os(macOS)
        Color(nsColor: .windowBackgroundColor)
        #else
        Color(uiColor: .systemBackground)
        #endif
    }

    static var platformControlBackground: Color {
        #if os(macOS)
        Color(nsColor: .controlBackgroundColor)
        #else
        Color(uiColor: .secondarySystemBackground)
        #endif
    }

    static var platformTextBackground: Color {
        #if os(macOS)
        Color(nsColor: .textBackgroundColor)
        #else
        Color(uiColor: .secondarySystemBackground)
        #endif
    }

    static var platformSeparator: Color {
        #if os(macOS)
        Color(nsColor: .separatorColor)
        #else
        Color(uiColor: .separator)
        #endif
    }
}
