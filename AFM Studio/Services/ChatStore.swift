import Foundation
import FoundationModels
import Observation
import SwiftData

@MainActor
@Observable
final class ChatStore {
    var activeConversation: ConversationRecord?
    var isGenerating = false
    var errorMessage: String?

    private let registry: ModelRegistry

    init(registry: ModelRegistry) {
        self.registry = registry
    }

    func ensureConversation(in context: ModelContext) -> ConversationRecord {
        if let activeConversation {
            return activeConversation
        }

        let conversation = ConversationRecord(selectedModelID: BuiltInModelID.appleSystem)
        context.insert(conversation)
        activeConversation = conversation
        return conversation
    }

    func send(_ prompt: String, in context: ModelContext) async {
        let trimmed = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false, isGenerating == false else {
            return
        }

        let conversation = ensureConversation(in: context)
        let descriptor = registry.descriptor(for: conversation.selectedModelID) ?? registry.descriptors.first
        guard let descriptor else {
            errorMessage = "No model is available."
            return
        }

        if conversation.messages.isEmpty {
            conversation.title = title(for: trimmed)
        }

        let userMessage = MessageRecord(role: .user, content: trimmed, conversation: conversation)
        let assistantMessage = MessageRecord(role: .assistant, content: "", conversation: conversation)
        conversation.messages.append(userMessage)
        conversation.messages.append(assistantMessage)
        conversation.updatedAt = .now

        isGenerating = true
        errorMessage = nil
        let startedAt = Date()
        let run = RunRecord(modelID: descriptor.id, startedAt: startedAt, message: assistantMessage)
        assistantMessage.runs.append(run)

        do {
            let session = try await SessionFactory.makeSession(for: descriptor)
            let stream = session.streamResponse(to: trimmed)
            for try await snapshot in stream {
                let parsedOutput = ModelOutputParser.parse(snapshot.content)
                assistantMessage.rawContent = parsedOutput.rawText
                assistantMessage.thinkingContent = parsedOutput.thinkingText
                assistantMessage.content = parsedOutput.displayText
            }
            if assistantMessage.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
               assistantMessage.rawContent?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false {
                assistantMessage.content = "No final response."
            }
            let completedAt = Date()
            run.completedAt = completedAt
            run.duration = completedAt.timeIntervalSince(startedAt)
        } catch {
            assistantMessage.content = "Generation failed."
            assistantMessage.rawContent = nil
            assistantMessage.thinkingContent = nil
            run.errorCategory = String(describing: type(of: error))
            errorMessage = PrivateCloudComputeSupport.runtimeFailureMessage(for: descriptor, error: error)
        }

        isGenerating = false
    }

    private func title(for prompt: String) -> String {
        let title = String(prompt.prefix(56)).trimmingCharacters(in: .whitespacesAndNewlines)
        if prompt.count > title.count {
            return "\(title)..."
        }
        return title.isEmpty ? "New Chat" : title
    }
}
