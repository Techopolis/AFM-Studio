import Foundation

struct StudioConversationListPresentation: Equatable, Sendable {
    var title: String
    var subtitle: String
    var updatedAt: Date
    var messageCount: Int
    var isActive: Bool

    static func subtitle(latestMessageContent: String?, hasMessages: Bool) -> String {
        guard hasMessages else {
            return "Start chatting to add messages."
        }

        let rawText = latestMessageContent?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let trimmed = ChatMarkdownUtilities.plainText(from: rawText)
        return trimmed.isEmpty ? "Attachment sent" : trimmed
    }

    func matchesSearch(_ searchText: String) -> Bool {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard query.isEmpty == false else {
            return true
        }

        return title.localizedCaseInsensitiveContains(query)
            || subtitle.localizedCaseInsensitiveContains(query)
    }
}
