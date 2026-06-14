import Foundation

@main
struct ChatPromptPayloadTests {
    static func main() throws {
        try acceptsTextOnlyPayloads()
        try acceptsImageOnlyPayloads()
        try describesMixedPayloads()
        print("ChatPromptPayloadTests passed")
    }

    private static func acceptsTextOnlyPayloads() throws {
        let payload = ChatPromptPayload(text: "  Explain this  ", attachments: [])

        try expect(payload.canSubmit, "text-only payload should be sendable")
        try expect(payload.trimmedText == "Explain this", "payload should trim text")
        try expect(payload.modelPromptText == "Explain this", "text-only prompt should preserve user text")
        try expect(payload.userVisibleText == "Explain this", "text-only transcript should show user text")
    }

    private static func acceptsImageOnlyPayloads() throws {
        let payload = ChatPromptPayload(text: "  ", attachments: [sampleAttachment])

        try expect(payload.canSubmit, "image-only payload should be sendable")
        try expect(
            payload.modelPromptText == "Describe the attached image.",
            "image-only prompt should give the model a default instruction"
        )
        try expect(
            payload.userVisibleText == "Image attachment",
            "image-only transcript should show an attachment placeholder"
        )
    }

    private static func describesMixedPayloads() throws {
        let payload = ChatPromptPayload(text: "What is in this?", attachments: [sampleAttachment])

        try expect(payload.canSubmit, "text plus image payload should be sendable")
        try expect(payload.modelPromptText == "What is in this?", "mixed prompt should use user text")
        try expect(payload.userVisibleText == "What is in this?", "mixed transcript should show user text")
    }

    private static var sampleAttachment: ChatImageAttachment {
        ChatImageAttachment(
            fileURL: URL(fileURLWithPath: "/tmp/sample.png"),
            displayName: "sample.png",
            byteCount: 42,
            pixelWidth: 320,
            pixelHeight: 240
        )
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
