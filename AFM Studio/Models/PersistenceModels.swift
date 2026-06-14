import Foundation
import SwiftData

@Model
final class ConversationRecord {
    var id: UUID
    var title: String
    var selectedModelID: String
    var createdAt: Date
    var updatedAt: Date

    @Relationship(deleteRule: .cascade, inverse: \MessageRecord.conversation)
    var messages: [MessageRecord]

    init(
        id: UUID = UUID(),
        title: String = "New Chat",
        selectedModelID: String = BuiltInModelID.appleSystem,
        createdAt: Date = .now,
        updatedAt: Date = .now,
        messages: [MessageRecord] = []
    ) {
        self.id = id
        self.title = title
        self.selectedModelID = selectedModelID
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.messages = messages
    }
}

@Model
final class MessageRecord {
    var id: UUID
    var role: MessageRole
    var content: String
    var rawContent: String?
    var thinkingContent: String?
    var createdAt: Date
    var conversation: ConversationRecord?

    @Relationship(deleteRule: .cascade, inverse: \RunRecord.message)
    var runs: [RunRecord]

    @Relationship(deleteRule: .cascade, inverse: \MessageAttachmentRecord.message)
    var attachments: [MessageAttachmentRecord]

    init(
        id: UUID = UUID(),
        role: MessageRole,
        content: String,
        rawContent: String? = nil,
        thinkingContent: String? = nil,
        createdAt: Date = .now,
        conversation: ConversationRecord? = nil,
        runs: [RunRecord] = [],
        attachments: [MessageAttachmentRecord] = []
    ) {
        self.id = id
        self.role = role
        self.content = content
        self.rawContent = rawContent
        self.thinkingContent = thinkingContent
        self.createdAt = createdAt
        self.conversation = conversation
        self.runs = runs
        self.attachments = attachments
    }
}

@Model
final class MessageAttachmentRecord {
    var id: UUID
    var filePath: String
    var displayName: String
    var byteCount: Int64?
    var pixelWidth: Int?
    var pixelHeight: Int?
    var createdAt: Date
    var message: MessageRecord?

    init(
        id: UUID = UUID(),
        filePath: String,
        displayName: String,
        byteCount: Int64? = nil,
        pixelWidth: Int? = nil,
        pixelHeight: Int? = nil,
        createdAt: Date = .now,
        message: MessageRecord? = nil
    ) {
        self.id = id
        self.filePath = filePath
        self.displayName = displayName
        self.byteCount = byteCount
        self.pixelWidth = pixelWidth
        self.pixelHeight = pixelHeight
        self.createdAt = createdAt
        self.message = message
    }

    convenience init(attachment: ChatImageAttachment, message: MessageRecord? = nil) {
        self.init(
            id: attachment.id,
            filePath: attachment.fileURL.path,
            displayName: attachment.displayName,
            byteCount: attachment.byteCount,
            pixelWidth: attachment.pixelWidth,
            pixelHeight: attachment.pixelHeight,
            message: message
        )
    }

    var fileURL: URL {
        URL(fileURLWithPath: filePath)
    }

    var chatImageAttachment: ChatImageAttachment {
        ChatImageAttachment(
            id: id,
            fileURL: fileURL,
            displayName: displayName,
            byteCount: byteCount,
            pixelWidth: pixelWidth,
            pixelHeight: pixelHeight
        )
    }
}

@Model
final class RunRecord {
    var id: UUID
    var modelID: String
    var startedAt: Date
    var completedAt: Date?
    var duration: TimeInterval?
    var inputTokens: Int?
    var outputTokens: Int?
    var errorCategory: String?
    var message: MessageRecord?

    init(
        id: UUID = UUID(),
        modelID: String,
        startedAt: Date = .now,
        completedAt: Date? = nil,
        duration: TimeInterval? = nil,
        inputTokens: Int? = nil,
        outputTokens: Int? = nil,
        errorCategory: String? = nil,
        message: MessageRecord? = nil
    ) {
        self.id = id
        self.modelID = modelID
        self.startedAt = startedAt
        self.completedAt = completedAt
        self.duration = duration
        self.inputTokens = inputTokens
        self.outputTokens = outputTokens
        self.errorCategory = errorCategory
        self.message = message
    }
}

@Model
final class BenchmarkSuiteRecord {
    var id: UUID
    var name: String
    var prompts: [String]

    init(id: UUID = UUID(), name: String, prompts: [String]) {
        self.id = id
        self.name = name
        self.prompts = prompts
    }
}

@Model
final class BenchmarkResultRecord {
    var id: UUID
    var suiteName: String
    var prompt: String
    var modelID: String
    var output: String
    var duration: TimeInterval
    var outputTokens: Int?
    var errorCategory: String?
    var createdAt: Date

    init(
        id: UUID = UUID(),
        suiteName: String,
        prompt: String,
        modelID: String,
        output: String,
        duration: TimeInterval,
        outputTokens: Int? = nil,
        errorCategory: String? = nil,
        createdAt: Date = .now
    ) {
        self.id = id
        self.suiteName = suiteName
        self.prompt = prompt
        self.modelID = modelID
        self.output = output
        self.duration = duration
        self.outputTokens = outputTokens
        self.errorCategory = errorCategory
        self.createdAt = createdAt
    }
}

@Model
final class UserModelRecord {
    var id: UUID
    var descriptorID: String
    var displayName: String
    var laneRawValue: String
    var modelID: String
    var catalogID: String?
    var resourcePath: String?
    var resourceBookmark: Data?
    var variant: String?

    init(
        id: UUID = UUID(),
        descriptorID: String,
        displayName: String,
        laneRawValue: String,
        modelID: String,
        catalogID: String? = nil,
        resourcePath: String? = nil,
        resourceBookmark: Data? = nil,
        variant: String? = nil
    ) {
        self.id = id
        self.descriptorID = descriptorID
        self.displayName = displayName
        self.laneRawValue = laneRawValue
        self.modelID = modelID
        self.catalogID = catalogID
        self.resourcePath = resourcePath
        self.resourceBookmark = resourceBookmark
        self.variant = variant
    }
}

enum MessageRole: String, Codable, Sendable {
    case user
    case assistant
    case system
}

enum BuiltInModelID {
    static let appleSystem = "apple.system.default"
    static let privateCloud = "apple.private-cloud.default"
    static let gemma4E2BCoreAI = "coreai.catalog.gemma-4-e2b"
    static let gemma4E4BCoreAI = "coreai.catalog.gemma-4-e4b"
    static let gemma3_4BCoreAI = "coreai.catalog.gemma-3-4b-it"
    static let gemma3_12BCoreAI = "coreai.catalog.gemma-3-12b-it"
    static let gptOSS20BCoreAI = "coreai.catalog.gpt-oss-20b"
}

enum AFMStudioSchema {
    static let models: [any PersistentModel.Type] = [
        ConversationRecord.self,
        MessageRecord.self,
        MessageAttachmentRecord.self,
        RunRecord.self,
        BenchmarkSuiteRecord.self,
        BenchmarkResultRecord.self,
        UserModelRecord.self
    ]
}

enum AFMMockData {
    @MainActor
    static var previewContainer: ModelContainer {
        try! ModelContainer(
            for: Schema(AFMStudioSchema.models),
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }
}
