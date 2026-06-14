//
//  StructuredMarkdownView.swift
//  Perspective Intelligence
//
//  Renders an array of `MarkdownBlock` elements as native SwiftUI views.
//  Headings get proper font sizes, lists get bullets/numbers with indentation,
//  code blocks get a monospace background, blockquotes get an accent bar,
//  and inline markdown (bold, italic, links) is rendered via AttributedString.
//
//  Links are tappable through SwiftUI's built-in `Text` + `AttributedString`
//  link handling, which respects the `OpenURLAction` environment value.
//

import SwiftUI
#if os(macOS)
import AppKit
#endif

/// Renders markdown content as a sequence of native SwiftUI block views.
struct StructuredMarkdownView: View {
    let content: String
    let textColor: Color
    let isFromUser: Bool
    var isStreaming: Bool = false

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // Streaming insertion-point animation state
    @State private var previousContent: String = ""
    @State private var revealStartDate: Date = .distantPast

    private let streamingRevealDuration: TimeInterval = 0.18
    private let streamingRevealCharacterDelay: TimeInterval = 0.006
    private let streamingRevealMaxCharacters = 96

    /// Parsed blocks, cached per content string to avoid re-parsing on
    /// every body evaluation when only unrelated state changes.
    private var blocks: [MarkdownBlock] {
        MarkdownBlockParser.parse(content)
    }

    /// The text that was appended since the last content update.
    /// Only meaningful during streaming.
    private var appendedText: String {
        guard isStreaming,
              content.count > previousContent.count,
              content.hasPrefix(previousContent) else {
            return ""
        }
        return String(content.dropFirst(previousContent.count))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(Array(blocks.enumerated()), id: \.offset) { index, block in
                if isStreaming && index == blocks.count - 1 {
                    streamingBlockView(for: block)
                        .padding(.top, topPadding(for: block, at: index))
                } else {
                    blockView(for: block)
                        .padding(.top, topPadding(for: block, at: index))
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .onChange(of: content) { oldValue, newValue in
            guard isStreaming else { return }
            previousContent = oldValue
            revealStartDate = Date()
        }
    }

    /// Extra top padding for block-level elements that benefit from visual
    /// separation (code blocks, tables, blockquotes, headings).
    private func topPadding(for block: MarkdownBlock, at index: Int) -> CGFloat {
        guard index > 0 else { return 0 }
        switch block {
        case .codeBlock: return 4
        case .table: return 4
        case .blockquote: return 2
        case .heading: return 4
        case .thematicBreak: return 2
        default: return 0
        }
    }

    // MARK: - Block Rendering

    /// Renders the last block during streaming with a fade-in on newly appended text.
    @ViewBuilder
    private func streamingBlockView(for block: MarkdownBlock) -> some View {
        switch block {
        case .paragraph(let text):
            streamingInlineMarkdownText(text)
                .textSelection(.enabled)
        case .unorderedListItem(let text, let indent):
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("•")
                    .foregroundColor(textColor.opacity(0.7))
                    .accessibilityHidden(true)
                streamingInlineMarkdownText(text)
                    .textSelection(.enabled)
            }
            .padding(.leading, CGFloat(indent) * 16)
        case .orderedListItem(let number, let text, let indent):
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("\(number).")
                    .foregroundColor(textColor.opacity(0.7))
                    .monospacedDigit()
                    .accessibilityHidden(true)
                streamingInlineMarkdownText(text)
                    .textSelection(.enabled)
            }
            .padding(.leading, CGFloat(indent) * 16)
        default:
            // Non-text blocks (code, table, heading, etc.) render normally
            blockView(for: block)
        }
    }

    @ViewBuilder
    private func blockView(for block: MarkdownBlock) -> some View {
        switch block {
        case .heading(let level, let text):
            headingView(level: level, text: text)
        case .paragraph(let text):
            #if os(macOS)
            selectableText(text)
            #else
            inlineMarkdownText(text)
                .textSelection(.enabled)
            #endif
        case .unorderedListItem(let text, let indent):
            unorderedListItemView(text: text, indent: indent)
        case .orderedListItem(let number, let text, let indent):
            orderedListItemView(number: number, text: text, indent: indent)
        case .codeBlock(let language, let code):
            codeBlockView(language: language, code: code)
        case .blockquote(let text):
            blockquoteView(text: text)
        case .table(let header, let alignments, let rows):
            tableView(header: header, alignments: alignments, rows: rows)
        case .thematicBreak:
            thematicBreakView
        }
    }

    // MARK: - Headings

    private func headingView(level: Int, text: String) -> some View {
        inlineMarkdownText(text)
            .font(headingFont(for: level))
            .fontWeight(.semibold)
            .padding(.bottom, 2)
            .accessibilityAddTraits(.isHeader)
    }

    private func headingFont(for level: Int) -> Font {
        switch level {
        case 1: return .title2
        case 2: return .title3
        case 3: return .headline
        default: return .subheadline
        }
    }

    // MARK: - Lists

    private func unorderedListItemView(text: String, indent: Int) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text("•")
                .foregroundColor(textColor.opacity(0.7))
                .accessibilityHidden(true)
            inlineMarkdownText(text)
                .textSelection(.enabled)
        }
        .padding(.leading, CGFloat(indent) * 16)
    }

    private func orderedListItemView(number: Int, text: String, indent: Int) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            Text("\(number).")
                .foregroundColor(textColor.opacity(0.7))
                .monospacedDigit()
                .accessibilityHidden(true)
            inlineMarkdownText(text)
                .textSelection(.enabled)
        }
        .padding(.leading, CGFloat(indent) * 16)
    }

    // MARK: - Code Blocks

    private func codeBlockView(language: String?, code: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            if let language, !language.isEmpty {
                Text(language)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 10)
                    .padding(.top, 6)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                Text(code)
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundColor(codeTextColor)
                    .textSelection(.enabled)
                    .padding(.horizontal, 10)
                    .padding(.vertical, language != nil ? 4 : 10)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(codeBackgroundColor)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .padding(.bottom, 2)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Code block\(language.map { ", \($0)" } ?? ""): \(code)")
    }

    private var codeBackgroundColor: Color {
        if isFromUser {
            return Color.white.opacity(0.12)
        }
        return colorScheme == .dark
            ? Color.white.opacity(0.08)
            : Color.black.opacity(0.05)
    }

    private var codeTextColor: Color {
        if isFromUser {
            return .white.opacity(0.9)
        }
        return colorScheme == .dark
            ? Color(red: 0.85, green: 0.85, blue: 0.9)
            : Color(red: 0.15, green: 0.15, blue: 0.2)
    }

    // MARK: - Blockquotes

    private func blockquoteView(text: String) -> some View {
        HStack(spacing: 0) {
            RoundedRectangle(cornerRadius: 1.5)
                .fill(quoteAccentColor)
                .frame(width: 3)
                .accessibilityHidden(true)
            inlineMarkdownText(text)
                .foregroundColor(textColor.opacity(0.8))
                .padding(.leading, 10)
                .textSelection(.enabled)
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
        .accessibilityHint("Quote")
    }

    private var quoteAccentColor: Color {
        if isFromUser {
            return .white.opacity(0.4)
        }
        return colorScheme == .dark
            ? Color.white.opacity(0.25)
            : Color.black.opacity(0.2)
    }

    // MARK: - Tables

    private func tableView(header: [String], alignments: [TableColumnAlignment], rows: [[String]]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Invisible summary element — VoiceOver lands here first
            Color.clear
                .frame(width: 0, height: 0)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Table with \(header.count) columns and \(rows.count) rows")
                .accessibilityHint("Swipe right to navigate cells")
                .accessibilityAddTraits(.isHeader)

            // Header row
            tableRowView(cells: header, header: header, alignments: alignments, columnCount: header.count, isHeader: true)

            // Separator under header
            Rectangle()
                .fill(tableBorderColor)
                .frame(height: 1)
                .accessibilityHidden(true)

            // Data rows
            ForEach(Array(rows.enumerated()), id: \.offset) { rowIndex, row in
                tableRowView(cells: row, header: header, alignments: alignments, columnCount: header.count, isHeader: false)

                if rowIndex < rows.count - 1 {
                    Rectangle()
                        .fill(tableBorderColor)
                        .frame(height: 0.5)
                        .accessibilityHidden(true)
                }
            }
        }
        .background(tableBackgroundColor)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(tableBorderColor, lineWidth: 1)
        )
        .padding(.bottom, 2)
        .accessibilityElement(children: .contain)
    }

    private func tableRowView(cells: [String], header: [String], alignments: [TableColumnAlignment], columnCount: Int, isHeader: Bool) -> some View {
        HStack(alignment: .top, spacing: 0) {
            ForEach(0..<columnCount, id: \.self) { colIndex in
                let cellText = colIndex < cells.count ? cells[colIndex] : ""
                let alignment = colIndex < alignments.count ? alignments[colIndex] : .leading
                let columnName = colIndex < header.count ? header[colIndex] : ""

                if colIndex > 0 {
                    Rectangle()
                        .fill(tableBorderColor)
                        .frame(width: 0.5)
                        .accessibilityHidden(true)
                }

                inlineMarkdownText(cellText)
                    .font(isHeader ? .subheadline.weight(.semibold) : .subheadline)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
                    .multilineTextAlignment(textAlignment(for: alignment))
                    .frame(maxWidth: .infinity, alignment: frameAlignment(for: alignment))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(isHeader ? "Column: \(cellText)" : "\(columnName): \(cellText)")
            }
        }
    }

    private var tableBackgroundColor: Color {
        if isFromUser {
            return Color.white.opacity(0.06)
        }
        return colorScheme == .dark
            ? Color.white.opacity(0.05)
            : Color.black.opacity(0.03)
    }

    private var tableBorderColor: Color {
        if isFromUser {
            return Color.white.opacity(0.3)
        }
        return colorScheme == .dark
            ? Color.white.opacity(0.25)
            : Color.black.opacity(0.2)
    }

    private func textAlignment(for alignment: TableColumnAlignment) -> TextAlignment {
        switch alignment {
        case .leading: return .leading
        case .center: return .center
        case .trailing: return .trailing
        }
    }

    private func frameAlignment(for alignment: TableColumnAlignment) -> Alignment {
        switch alignment {
        case .leading: return .leading
        case .center: return .center
        case .trailing: return .trailing
        }
    }



    // MARK: - Thematic Break

    private var thematicBreakView: some View {
        Divider()
            .padding(.vertical, 4)
            .accessibilityHidden(true)
    }

    // MARK: - Inline Markdown

    /// Renders inline markdown (bold, italic, code, links) using
    /// `AttributedString` within a SwiftUI `Text` view. Links become
    /// tappable via SwiftUI's built-in link handling.
    private func inlineMarkdownText(_ text: String) -> Text {
        if let attributed = parseInlineMarkdown(text) {
            return Text(attributed)
        }
        return Text(text)
    }

    /// Streaming variant that staggers a short fade across the newest suffix.
    /// This keeps accumulated model chunks visually soft without animating row layout.
    private func streamingInlineMarkdownText(_ text: String) -> some View {
        StreamingInlineMarkdownText(
            text: text,
            appendedText: streamingSuffix(for: text),
            textColor: textColor,
            reduceMotion: reduceMotion,
            revealStartDate: revealStartDate,
            revealDuration: streamingRevealDuration,
            characterDelay: streamingRevealCharacterDelay,
            maxAnimatedCharacters: streamingRevealMaxCharacters
        )
    }

    private func streamingSuffix(for blockText: String) -> String {
        let appended = appendedText
        guard !appended.isEmpty else { return "" }
        if blockText.hasSuffix(appended) { return appended }
        if appended.hasSuffix(blockText) { return blockText }

        let trimmed = appended.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }
        if blockText.hasSuffix(trimmed) { return trimmed }
        if trimmed.hasSuffix(blockText) { return blockText }

        return ""
    }

    private func parseInlineMarkdown(_ text: String) -> AttributedString? {
        var options = AttributedString.MarkdownParsingOptions(
            interpretedSyntax: .inlineOnlyPreservingWhitespace
        )
        options.failurePolicy = .returnPartiallyParsedIfPossible
        guard var attributed = try? AttributedString(markdown: text, options: options) else {
            return nil
        }

        // Apply text color to the entire string
        attributed.foregroundColor = textColor

        // Explicitly style link runs with blue color and underline
        for run in attributed.runs {
            if run.link != nil {
                attributed[run.range].foregroundColor = .blue
                attributed[run.range].underlineStyle = .single
            }
        }

        return attributed
    }

    // MARK: - Selectable Text (macOS NSTextView for proper link cursor)

    #if os(macOS)
    /// Wraps an `AttributedString` in an `NSTextView` on macOS so that the
    /// pointing-hand cursor appears over links while still allowing text selection.
    /// SwiftUI's `.textSelection(.enabled)` forces the I-beam cursor everywhere.
    private func selectableText(_ text: String) -> some View {
        let attributed = parseInlineMarkdown(text) ?? AttributedString(text)
        return SelectableLinkTextView(attributedString: attributed, textColor: NSColor(textColor))
    }
    #endif
}

private struct StreamingInlineMarkdownText: View {
    let text: String
    let appendedText: String
    let textColor: Color
    let reduceMotion: Bool
    let revealStartDate: Date
    let revealDuration: TimeInterval
    let characterDelay: TimeInterval
    let maxAnimatedCharacters: Int

    private var animatedSuffix: String {
        guard !reduceMotion else { return "" }
        guard !appendedText.isEmpty else { return "" }
        return String(appendedText.suffix(maxAnimatedCharacters))
    }

    var body: some View {
        let suffix = animatedSuffix
        if suffix.isEmpty {
            renderedText(at: nil, animatedSuffix: "")
        } else {
            TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: false)) { timeline in
                renderedText(at: timeline.date, animatedSuffix: suffix)
            }
        }
    }

    private func renderedText(at date: Date?, animatedSuffix: String) -> Text {
        guard var attributed = parseInlineMarkdown(text) else {
            return Text(text)
        }

        guard let date,
              !animatedSuffix.isEmpty,
              text.hasSuffix(animatedSuffix) else {
            return Text(attributed)
        }

        applyRevealOpacity(
            to: &attributed,
            animatedSuffix: animatedSuffix,
            elapsed: max(0, date.timeIntervalSince(revealStartDate))
        )
        return Text(attributed)
    }

    private func applyRevealOpacity(
        to attributed: inout AttributedString,
        animatedSuffix: String,
        elapsed: TimeInterval
    ) {
        let visibleCharacterCount = attributed.characters.count
        let suffixLength = min(visibleCharacterCount, animatedSuffix.count)
        guard suffixLength > 0 else { return }

        var cursor = attributed.characters.index(attributed.characters.endIndex, offsetBy: -suffixLength)
        for offset in 0 ..< suffixLength {
            let next = attributed.characters.index(after: cursor)
            let opacity = revealOpacity(characterOffset: offset, elapsed: elapsed)
            if opacity < 0.999 {
                attributed[cursor ..< next].foregroundColor = textColor.opacity(opacity)
            }
            cursor = next
        }
    }

    private func revealOpacity(characterOffset: Int, elapsed: TimeInterval) -> Double {
        let delayedElapsed = elapsed - Double(characterOffset) * characterDelay
        let linearProgress = min(max(delayedElapsed / revealDuration, 0), 1)
        let easedProgress = easeOutCubic(linearProgress)
        return 0.16 + easedProgress * 0.84
    }

    private func easeOutCubic(_ progress: Double) -> Double {
        let inverse = 1 - progress
        return 1 - inverse * inverse * inverse
    }

    private func parseInlineMarkdown(_ text: String) -> AttributedString? {
        var options = AttributedString.MarkdownParsingOptions(
            interpretedSyntax: .inlineOnlyPreservingWhitespace
        )
        options.failurePolicy = .returnPartiallyParsedIfPossible
        guard var attributed = try? AttributedString(markdown: text, options: options) else {
            return nil
        }

        attributed.foregroundColor = textColor

        for run in attributed.runs {
            if run.link != nil {
                attributed[run.range].foregroundColor = .blue
                attributed[run.range].underlineStyle = .single
            }
        }

        return attributed
    }
}

#if os(macOS)
/// Lightweight `NSTextView` wrapper that shows the pointing-hand cursor on links
/// while supporting text selection with the I-beam cursor on regular text.
private struct SelectableLinkTextView: NSViewRepresentable {
    let attributedString: AttributedString
    let textColor: NSColor

    func makeNSView(context: Context) -> SelectableLinkNSTextView {
        let textView = SelectableLinkNSTextView()
        textView.drawsBackground = false
        textView.isEditable = false
        textView.isSelectable = true
        textView.isRichText = true
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.textContainerInset = .zero
        textView.textContainer?.lineFragmentPadding = 0
        textView.textContainer?.widthTracksTextView = true
        textView.isAutomaticLinkDetectionEnabled = false
        return textView
    }

    func updateNSView(_ nsView: SelectableLinkNSTextView, context: Context) {
        let nsAttr = makeNSAttributedString()
        nsView.textStorage?.setAttributedString(nsAttr)
    }

    func sizeThatFits(_ proposal: ProposedViewSize, nsView: SelectableLinkNSTextView, context: Context) -> CGSize? {
        let proposedWidth = proposal.width ?? .greatestFiniteMagnitude
        let containerWidth = proposedWidth > 0 ? proposedWidth : .greatestFiniteMagnitude
        guard let textContainer = nsView.textContainer,
              let layoutManager = nsView.layoutManager else { return nil }
        textContainer.containerSize = NSSize(width: containerWidth, height: .greatestFiniteMagnitude)
        layoutManager.ensureLayout(for: textContainer)
        let usedRect = layoutManager.usedRect(for: textContainer)
        return NSSize(width: min(ceil(usedRect.width), containerWidth), height: ceil(usedRect.height))
    }

    private func makeNSAttributedString() -> NSAttributedString {
        let mutable = NSMutableAttributedString(attributedString: NSAttributedString(attributedString))
        let range = NSRange(location: 0, length: mutable.length)
        let baseFont = NSFont.systemFont(ofSize: NSFont.systemFontSize)
        mutable.beginEditing()
        mutable.enumerateAttribute(.font, in: range) { value, subrange, _ in
            if value == nil {
                mutable.addAttribute(.font, value: baseFont, range: subrange)
            }
        }
        mutable.addAttribute(.foregroundColor, value: textColor, range: range)
        mutable.endEditing()
        return mutable
    }
}

/// NSTextView subclass that reports its first text baseline to SwiftUI
/// so `HStack(alignment: .firstTextBaseline)` aligns bullets/numbers correctly.
final class SelectableLinkNSTextView: NSTextView {
    override var firstBaselineOffsetFromTop: CGFloat {
        guard let layoutManager, let textContainer else {
            return super.firstBaselineOffsetFromTop
        }
        layoutManager.ensureLayout(for: textContainer)
        guard layoutManager.numberOfGlyphs > 0 else {
            return super.firstBaselineOffsetFromTop
        }
        // Get the line fragment rect for the first line
        let lineRect = layoutManager.lineFragmentRect(forGlyphAt: 0, effectiveRange: nil)
        // Get the font at the start to determine the baseline within the line
        let font = textStorage?.attribute(.font, at: 0, effectiveRange: nil) as? NSFont
            ?? NSFont.systemFont(ofSize: NSFont.systemFontSize)
        // Baseline = top of line fragment + line height - descender
        return lineRect.origin.y + font.ascender
    }
}
#endif
