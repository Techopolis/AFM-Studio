import Foundation

@main
struct MarkdownRenderingTests {
    static func main() throws {
        try parsesCommonAssistantMarkdownBlocks()
        try convertsMarkdownToPlainText()
        print("MarkdownRenderingTests passed")
    }

    private static func parsesCommonAssistantMarkdownBlocks() throws {
        let markdown = """
        ## Summary

        - **Fast** local response
        1. Check latency

        ```swift
        let model = "AFM"
        ```

        | Model | Status |
        | --- | ---: |
        | Apple | Ready |
        """

        let blocks = MarkdownBlockParser.parse(markdown)

        try expect(blocks.contains(.heading(level: 2, text: "Summary")), "should parse headings")
        try expect(blocks.contains(.unorderedListItem(text: "**Fast** local response", indent: 0)), "should parse unordered lists")
        try expect(blocks.contains(.orderedListItem(number: 1, text: "Check latency", indent: 0)), "should parse ordered lists")
        try expect(blocks.contains(.codeBlock(language: "swift", code: "let model = \"AFM\"")), "should parse fenced code blocks")
        try expect(
            blocks.contains(.table(header: ["Model", "Status"], alignments: [.leading, .trailing], rows: [["Apple", "Ready"]])),
            "should parse markdown tables"
        )
    }

    private static func convertsMarkdownToPlainText() throws {
        let text = ChatMarkdownUtilities.plainText(from: "## Title\n\nVisit [AFM](https://example.com) and `run` **fast**.")

        try expect(text == "Title\n\nVisit AFM and run fast.", "plain text should strip common markdown markers")
    }

    private static func expect(_ condition: Bool, _ message: String) throws {
        if condition == false {
            throw TestFailure(message)
        }
    }

    private struct TestFailure: Error, CustomStringConvertible {
        var description: String

        init(_ description: String) {
            self.description = description
        }
    }
}
