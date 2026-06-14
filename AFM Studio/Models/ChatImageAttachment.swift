import Foundation

struct ChatImageAttachment: Identifiable, Equatable, Sendable {
    var id: UUID
    var fileURL: URL
    var displayName: String
    var byteCount: Int64?
    var pixelWidth: Int?
    var pixelHeight: Int?

    init(
        id: UUID = UUID(),
        fileURL: URL,
        displayName: String,
        byteCount: Int64? = nil,
        pixelWidth: Int? = nil,
        pixelHeight: Int? = nil
    ) {
        self.id = id
        self.fileURL = fileURL
        self.displayName = displayName
        self.byteCount = byteCount
        self.pixelWidth = pixelWidth
        self.pixelHeight = pixelHeight
    }

    var accessibilityLabel: String {
        var components = [displayName]
        if let pixelWidth, let pixelHeight {
            components.append("\(pixelWidth) by \(pixelHeight) pixels")
        }
        return components.joined(separator: ", ")
    }
}

struct ChatPromptPayload: Equatable, Sendable {
    static let defaultImagePrompt = "Describe the attached image."

    var text: String
    var attachments: [ChatImageAttachment]

    var trimmedText: String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var canSubmit: Bool {
        trimmedText.isEmpty == false || attachments.isEmpty == false
    }

    var modelPromptText: String {
        trimmedText.isEmpty ? Self.defaultImagePrompt : trimmedText
    }

    var userVisibleText: String {
        if trimmedText.isEmpty == false {
            return trimmedText
        }
        if attachments.count == 1 {
            return "Image attachment"
        }
        return "\(attachments.count) image attachments"
    }
}
