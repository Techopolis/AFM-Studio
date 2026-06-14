//
//  MarkdownBlock.swift
//  Perspective Intelligence
//
//  Lightweight markdown block parser. Splits raw markdown text into
//  structured blocks (headings, paragraphs, lists, code blocks,
//  blockquotes) that can be rendered as native SwiftUI views.
//
//  This intentionally avoids adding a third-party dependency like
//  swift-markdown or cmark. It handles the subset of markdown that
//  AI models commonly produce in chat responses.
//

import Foundation

/// A single block-level element parsed from markdown text.
enum MarkdownBlock: Identifiable, Equatable {
    case heading(level: Int, text: String)
    case paragraph(text: String)
    case unorderedListItem(text: String, indent: Int)
    case orderedListItem(number: Int, text: String, indent: Int)
    case codeBlock(language: String?, code: String)
    case blockquote(text: String)
    case table(header: [String], alignments: [TableColumnAlignment], rows: [[String]])
    case thematicBreak

    var id: String {
        switch self {
        case .heading(let level, let text):
            return "h\(level)-\(text.prefix(40).hashValue)"
        case .paragraph(let text):
            return "p-\(text.prefix(40).hashValue)"
        case .unorderedListItem(let text, let indent):
            return "ul\(indent)-\(text.prefix(40).hashValue)"
        case .orderedListItem(let number, let text, let indent):
            return "ol\(indent)\(number)-\(text.prefix(40).hashValue)"
        case .codeBlock(let language, let code):
            return "code-\(language ?? "")-\(code.prefix(40).hashValue)"
        case .blockquote(let text):
            return "bq-\(text.prefix(40).hashValue)"
        case .table(let header, _, let rows):
            return "table-\(header.hashValue)-\(rows.count)"
        case .thematicBreak:
            return "hr-\(UUID().uuidString)"
        }
    }
}

/// Column alignment parsed from the separator row of a markdown table.
enum TableColumnAlignment: Equatable {
    case leading
    case center
    case trailing
}

/// Parses raw markdown text into an array of `MarkdownBlock` elements.
enum MarkdownBlockParser {

    static func parse(_ markdown: String) -> [MarkdownBlock] {
        let normalized = markdown
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")

        let lines = normalized.components(separatedBy: "\n")
        var blocks: [MarkdownBlock] = []
        var index = 0

        while index < lines.count {
            let line = lines[index]

            // Blank line — skip
            if line.trimmingCharacters(in: .whitespaces).isEmpty {
                index += 1
                continue
            }

            // Fenced code block: ``` or ~~~
            if let codeResult = tryParseCodeBlock(lines: lines, startIndex: index) {
                blocks.append(codeResult.block)
                index = codeResult.nextIndex
                continue
            }

            // Table: | header | header |  (must check before thematic break
            // because separator rows like | --- | --- | would match as breaks)
            if let tableResult = tryParseTable(lines: lines, startIndex: index) {
                blocks.append(tableResult.block)
                index = tableResult.nextIndex
                continue
            }

            // Thematic break: ---, ***, ___
            if isThematicBreak(line) {
                blocks.append(.thematicBreak)
                index += 1
                continue
            }

            // Heading: # ... ######
            if let heading = tryParseHeading(line) {
                blocks.append(heading)
                index += 1
                continue
            }

            // Blockquote: > text
            if let bqResult = tryParseBlockquote(lines: lines, startIndex: index) {
                blocks.append(bqResult.block)
                index = bqResult.nextIndex
                continue
            }

            // Unordered list item: - , * , +  (with possible indent)
            if let listItem = tryParseUnorderedListItem(line) {
                blocks.append(listItem)
                index += 1
                continue
            }

            // Ordered list item: 1. , 2) , etc.
            if let listItem = tryParseOrderedListItem(line) {
                blocks.append(listItem)
                index += 1
                continue
            }

            // Paragraph: collect contiguous non-blank, non-special lines
            let paraResult = parseParagraph(lines: lines, startIndex: index)
            blocks.append(paraResult.block)
            index = paraResult.nextIndex
        }

        return blocks
    }

    // MARK: - Code Blocks

    private struct ParseResult {
        let block: MarkdownBlock
        let nextIndex: Int
    }

    private static func tryParseCodeBlock(lines: [String], startIndex: Int) -> ParseResult? {
        let trimmed = lines[startIndex].trimmingCharacters(in: .whitespaces)
        let fenceChar: Character
        if trimmed.hasPrefix("```") {
            fenceChar = "`"
        } else if trimmed.hasPrefix("~~~") {
            fenceChar = "~"
        } else {
            return nil
        }

        let fencePrefix = String(repeating: fenceChar, count: 3)
        let language: String? = {
            let afterFence = trimmed.dropFirst(3).trimmingCharacters(in: .whitespaces)
            return afterFence.isEmpty ? nil : afterFence
        }()

        var codeLines: [String] = []
        var i = startIndex + 1
        while i < lines.count {
            let current = lines[i].trimmingCharacters(in: .whitespaces)
            if current.hasPrefix(fencePrefix) {
                i += 1
                break
            }
            codeLines.append(lines[i])
            i += 1
        }

        let code = codeLines.joined(separator: "\n")
        return ParseResult(block: .codeBlock(language: language, code: code), nextIndex: i)
    }

    // MARK: - Tables

    private static func tryParseTable(lines: [String], startIndex: Int) -> ParseResult? {
        // A markdown table requires at least a header row and a separator row.
        // Header:    | Col1 | Col2 | Col3 |
        // Separator: | ---  | :--: | ---: |
        // Data rows: | val  | val  | val  |
        guard startIndex + 1 < lines.count else { return nil }

        let headerLine = lines[startIndex].trimmingCharacters(in: .whitespaces)
        guard isTableRow(headerLine) else { return nil }

        let separatorLine = lines[startIndex + 1].trimmingCharacters(in: .whitespaces)
        guard isTableSeparator(separatorLine) else { return nil }

        let headerCells = parseTableCells(headerLine)
        let alignments = parseAlignments(separatorLine)

        // Normalize column count to the header
        let columnCount = headerCells.count

        var dataRows: [[String]] = []
        var i = startIndex + 2
        while i < lines.count {
            let rowLine = lines[i].trimmingCharacters(in: .whitespaces)
            guard isTableRow(rowLine) else { break }
            var cells = parseTableCells(rowLine)
            // Pad or truncate to match header column count
            while cells.count < columnCount { cells.append("") }
            if cells.count > columnCount { cells = Array(cells.prefix(columnCount)) }
            dataRows.append(cells)
            i += 1
        }

        // Pad alignments to match column count
        var finalAlignments = alignments
        while finalAlignments.count < columnCount { finalAlignments.append(.leading) }
        if finalAlignments.count > columnCount { finalAlignments = Array(finalAlignments.prefix(columnCount)) }

        return ParseResult(
            block: .table(header: headerCells, alignments: finalAlignments, rows: dataRows),
            nextIndex: i
        )
    }

    /// Checks if a line looks like a table row (contains at least one pipe).
    private static func isTableRow(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        return trimmed.contains("|")
    }

    /// Checks if a line is a table separator row: | --- | :---: | ---: |
    private static func isTableSeparator(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard trimmed.contains("|") else { return false }
        let cells = parseTableCells(trimmed)
        guard !cells.isEmpty else { return false }
        return cells.allSatisfy { cell in
            let c = cell.trimmingCharacters(in: .whitespaces)
            guard !c.isEmpty else { return true }
            // Must be dashes with optional leading/trailing colons: ---, :---, ---:, :---:
            let stripped = c.replacingOccurrences(of: ":", with: "")
                .replacingOccurrences(of: "-", with: "")
                .trimmingCharacters(in: .whitespaces)
            let hasDash = c.contains("-")
            return stripped.isEmpty && hasDash
        }
    }

    /// Parses alignment indicators from a separator row.
    private static func parseAlignments(_ separatorLine: String) -> [TableColumnAlignment] {
        let cells = parseTableCells(separatorLine)
        return cells.map { cell in
            let c = cell.trimmingCharacters(in: .whitespaces)
            let startsWithColon = c.hasPrefix(":")
            let endsWithColon = c.hasSuffix(":")
            if startsWithColon && endsWithColon { return .center }
            if endsWithColon { return .trailing }
            return .leading
        }
    }

    /// Splits a pipe-delimited table row into cell strings, trimming whitespace.
    private static func parseTableCells(_ line: String) -> [String] {
        var trimmed = line.trimmingCharacters(in: .whitespaces)
        // Remove leading and trailing pipes
        if trimmed.hasPrefix("|") { trimmed = String(trimmed.dropFirst()) }
        if trimmed.hasSuffix("|") { trimmed = String(trimmed.dropLast()) }
        return trimmed.components(separatedBy: "|")
            .map { $0.trimmingCharacters(in: .whitespaces) }
    }

    // MARK: - Thematic Break

    private static func isThematicBreak(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard trimmed.count >= 3 else { return false }
        let chars = Set(trimmed.filter { !$0.isWhitespace })
        return chars.count == 1 && (chars.contains("-") || chars.contains("*") || chars.contains("_"))
    }

    // MARK: - Headings

    private static func tryParseHeading(_ line: String) -> MarkdownBlock? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        var hashCount = 0
        for char in trimmed {
            if char == "#" {
                hashCount += 1
            } else {
                break
            }
        }
        guard hashCount >= 1, hashCount <= 6 else { return nil }
        let afterHashes = trimmed.dropFirst(hashCount)
        guard afterHashes.first == " " else { return nil }
        let text = String(afterHashes.dropFirst()).trimmingCharacters(in: .whitespaces)
        return .heading(level: hashCount, text: text)
    }

    // MARK: - Blockquotes

    private static func tryParseBlockquote(lines: [String], startIndex: Int) -> ParseResult? {
        let trimmed = lines[startIndex].trimmingCharacters(in: .whitespaces)
        guard trimmed.hasPrefix(">") else { return nil }

        var quoteLines: [String] = []
        var i = startIndex
        while i < lines.count {
            let lineTrimmed = lines[i].trimmingCharacters(in: .whitespaces)
            if lineTrimmed.hasPrefix(">") {
                var content = String(lineTrimmed.dropFirst())
                if content.hasPrefix(" ") {
                    content = String(content.dropFirst())
                }
                quoteLines.append(content)
                i += 1
            } else if lineTrimmed.isEmpty {
                break
            } else {
                // Continuation line (lazy blockquote)
                quoteLines.append(lineTrimmed)
                i += 1
            }
        }

        let text = quoteLines.joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return ParseResult(block: .blockquote(text: text), nextIndex: i)
    }

    // MARK: - List Items

    private static func tryParseUnorderedListItem(_ line: String) -> MarkdownBlock? {
        // Count leading spaces for indent level
        let leadingSpaces = line.prefix(while: { $0 == " " }).count
        let indent = leadingSpaces / 2 // Each indent level = 2 spaces
        let stripped = line.trimmingCharacters(in: .whitespaces)

        for marker in ["-", "*", "+"] {
            if stripped.hasPrefix("\(marker) ") {
                let text = String(stripped.dropFirst(2))
                return .unorderedListItem(text: text, indent: indent)
            }
        }
        return nil
    }

    private static func tryParseOrderedListItem(_ line: String) -> MarkdownBlock? {
        let leadingSpaces = line.prefix(while: { $0 == " " }).count
        let indent = leadingSpaces / 2
        let stripped = line.trimmingCharacters(in: .whitespaces)

        // Match: digits followed by . or ) then space
        var digitEnd = stripped.startIndex
        while digitEnd < stripped.endIndex, stripped[digitEnd].isNumber {
            digitEnd = stripped.index(after: digitEnd)
        }
        guard digitEnd > stripped.startIndex,
              digitEnd < stripped.endIndex,
              (stripped[digitEnd] == "." || stripped[digitEnd] == ")") else {
            return nil
        }
        let afterMarker = stripped.index(after: digitEnd)
        guard afterMarker < stripped.endIndex, stripped[afterMarker] == " " else {
            return nil
        }

        let number = Int(stripped[stripped.startIndex..<digitEnd]) ?? 1
        let text = String(stripped[stripped.index(after: afterMarker)...])
        return .orderedListItem(number: number, text: text, indent: indent)
    }

    // MARK: - Paragraphs

    private static func parseParagraph(lines: [String], startIndex: Int) -> ParseResult {
        var paraLines: [String] = []
        var i = startIndex
        while i < lines.count {
            let line = lines[i]
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // Stop at blank lines
            if trimmed.isEmpty { break }
            // Stop at block-level elements
            if trimmed.hasPrefix("#") && tryParseHeading(line) != nil { break }
            if trimmed.hasPrefix("```") || trimmed.hasPrefix("~~~") { break }
            if trimmed.hasPrefix(">") { break }
            // Stop at table start (header row followed by separator)
            if isTableRow(line), i + 1 < lines.count,
               isTableSeparator(lines[i + 1].trimmingCharacters(in: .whitespaces)) { break }
            if isThematicBreak(line) { break }
            if tryParseUnorderedListItem(line) != nil { break }
            if tryParseOrderedListItem(line) != nil { break }

            paraLines.append(line)
            i += 1
        }

        let text = paraLines.joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return ParseResult(block: .paragraph(text: text), nextIndex: i)
    }
}
