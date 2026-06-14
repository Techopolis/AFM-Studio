import Foundation

@main
struct StudioConversationListPresentationTests {
    static func main() throws {
        try trimsSubtitleContent()
        try fallsBackForEmptySubtitleContent()
        try matchesSearchAcrossTitleAndSubtitle()
        print("StudioConversationListPresentationTests passed")
    }

    private static func trimsSubtitleContent() throws {
        let subtitle = StudioConversationListPresentation.subtitle(
            latestMessageContent: "  A concise answer.  ",
            hasMessages: true
        )

        try expect(subtitle == "A concise answer.", "subtitle should trim message content")
    }

    private static func fallsBackForEmptySubtitleContent() throws {
        let attachmentSubtitle = StudioConversationListPresentation.subtitle(
            latestMessageContent: "   ",
            hasMessages: true
        )
        let emptySubtitle = StudioConversationListPresentation.subtitle(
            latestMessageContent: nil,
            hasMessages: false
        )

        try expect(attachmentSubtitle == "Attachment sent", "empty message content should describe an attachment")
        try expect(emptySubtitle == "Start chatting to add messages.", "conversation without messages should invite chat")
    }

    private static func matchesSearchAcrossTitleAndSubtitle() throws {
        let presentation = StudioConversationListPresentation(
            title: "Private Cloud",
            subtitle: "Latency notes",
            updatedAt: Date(timeIntervalSince1970: 0),
            messageCount: 2,
            isActive: false
        )

        try expect(presentation.matchesSearch("cloud"), "search should match title")
        try expect(presentation.matchesSearch("latency"), "search should match subtitle")
        try expect(presentation.matchesSearch("  "), "blank search should match")
        try expect(presentation.matchesSearch("benchmark") == false, "unmatched search should not match")
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
