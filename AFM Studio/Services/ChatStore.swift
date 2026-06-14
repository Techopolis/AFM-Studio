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

    func send(_ prompt: String, attachments: [ChatImageAttachment] = [], in context: ModelContext) async {
        let payload = ChatPromptPayload(text: prompt, attachments: attachments)
        guard payload.canSubmit, isGenerating == false else {
            return
        }

        let conversation = ensureConversation(in: context)
        let descriptor = registry.descriptor(for: conversation.selectedModelID) ?? registry.descriptors.first
        guard let descriptor else {
            errorMessage = "No model is available."
            return
        }

        guard payload.attachments.isEmpty || descriptor.capabilities.vision else {
            errorMessage = "The selected model does not support image attachments."
            return
        }

        if conversation.messages.isEmpty {
            conversation.title = title(for: payload.userVisibleText)
        }

        let userMessage = MessageRecord(role: .user, content: payload.userVisibleText, conversation: conversation)
        let attachmentRecords = payload.attachments.map { attachment in
            MessageAttachmentRecord(attachment: attachment, message: userMessage)
        }
        userMessage.attachments = attachmentRecords
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
            let stream = responseStream(for: payload, session: session)
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

    private func responseStream(
        for payload: ChatPromptPayload,
        session: LanguageModelSession
    ) -> LanguageModelSession.ResponseStream<String> {
        if payload.attachments.isEmpty {
            return session.streamResponse(to: payload.modelPromptText)
        }

        let prompt = Prompt {
            payload.modelPromptText
            for attachment in payload.attachments {
                Attachment(imageURL: attachment.fileURL).label(attachment.displayName)
            }
        }
        return session.streamResponse(to: prompt)
    }

    private func title(for prompt: String) -> String {
        let title = String(prompt.prefix(56)).trimmingCharacters(in: .whitespacesAndNewlines)
        if prompt.count > title.count {
            return "\(title)..."
        }
        return title.isEmpty ? "New Chat" : title
    }
}
