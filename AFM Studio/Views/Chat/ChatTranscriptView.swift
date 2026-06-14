import SwiftData
import SwiftUI

struct ChatTranscriptView: View {
    @Environment(\.modelContext) private var modelContext

    let conversation: ConversationRecord
    let registry: ModelRegistry
    let chatStore: ChatStore

    @State private var draft = ""

    private var messages: [MessageRecord] {
        conversation.messages.sorted { $0.createdAt < $1.createdAt }
    }

    private var selectedDescriptor: ModelDescriptor? {
        registry.descriptor(for: conversation.selectedModelID)
    }

    private var canSend: Bool {
        selectedDescriptor?.canSend == true && chatStore.isGenerating == false
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            transcript
            Divider()
            ComposerView(
                draft: $draft,
                isSending: chatStore.isGenerating,
                canSend: canSend,
                unavailableReason: unavailableReason,
                onSend: send
            )
        }
        .navigationTitle(conversation.title)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Label("Model", systemImage: "cpu")
                    .font(.headline)
                    .labelStyle(.titleAndIcon)
                ModelPickerView(conversation: conversation, registry: registry)
                    .frame(maxWidth: 360)
                Spacer()
                if let selectedDescriptor {
                    Text(selectedDescriptor.lane.title)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }

            if let selectedDescriptor {
                Text(selectedDescriptor.statusLine)
                    .font(.caption)
                    .foregroundStyle(selectedDescriptor.canSend ? Color.secondary : Color.orange)
                    .lineLimit(2)
            } else {
                Text("The selected model is no longer in the registry.")
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            if let errorMessage = chatStore.errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
        .padding()
    }

    private var transcript: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 14) {
                    if messages.isEmpty {
                        emptyTranscript
                    } else {
                        ForEach(messages) { message in
                            ChatMessageBubble(message: message, registry: registry)
                                .id(message.id)
                        }
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(Color.platformBackground)
            .onChange(of: messages.count) { _, _ in
                scrollToBottom(with: proxy)
            }
            .onChange(of: chatStore.isGenerating) { _, _ in
                scrollToBottom(with: proxy)
            }
        }
    }

    private var emptyTranscript: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: "bubble.left.and.text.bubble.right")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            Text("Send a prompt to begin.")
                .font(.title3.weight(.semibold))
                .accessibilityAddTraits(.isHeader)
            Text("Responses stream through FoundationModels and are stored with run timing for later comparison.")
                .foregroundStyle(.secondary)
        }
        .padding(.top, 32)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var unavailableReason: String? {
        guard let selectedDescriptor else {
            return "No model is selected."
        }
        guard selectedDescriptor.canSend else {
            return selectedDescriptor.statusLine
        }
        return nil
    }

    private func send() {
        let prompt = draft
        draft = ""
        Task {
            await chatStore.send(prompt, in: modelContext)
        }
    }

    private func scrollToBottom(with proxy: ScrollViewProxy) {
        guard let lastMessage = messages.last else {
            return
        }
        withAnimation(.easeOut(duration: 0.2)) {
            proxy.scrollTo(lastMessage.id, anchor: .bottom)
        }
    }
}

private struct ChatMessageBubble: View {
    let message: MessageRecord
    let registry: ModelRegistry

    private var isUser: Bool {
        message.role == .user
    }

    private var run: RunRecord? {
        message.runs.sorted { $0.startedAt < $1.startedAt }.last
    }

    private var displayContent: String {
        let trimmed = message.content.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty && message.role == .assistant {
            return "Thinking..."
        }
        return trimmed
    }

    private var thinkingContent: String? {
        guard isUser == false else {
            return nil
        }
        let trimmed = message.thinkingContent?.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed?.isEmpty == false ? trimmed : nil
    }

    var body: some View {
        HStack(alignment: .top) {
            if isUser {
                Spacer(minLength: 48)
                content(alignment: .trailing)
            } else {
                content(alignment: .leading)
                Spacer(minLength: 48)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func content(alignment: HorizontalAlignment) -> some View {
        VStack(alignment: alignment, spacing: 6) {
            Text(isUser ? "You" : "Assistant")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            Text(displayContent)
                .textSelection(.enabled)
                .padding(.horizontal, isUser ? 14 : 0)
                .padding(.vertical, isUser ? 10 : 0)
                .background {
                    if isUser {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.accentColor.opacity(0.14))
                    }
                }
                .frame(maxWidth: isUser ? 560 : .infinity, alignment: isUser ? .trailing : .leading)

            if let thinkingContent {
                DisclosureGroup("Thinking") {
                    Text(thinkingContent)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 2)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            metadata
        }
        .frame(maxWidth: isUser ? 600 : .infinity, alignment: isUser ? .trailing : .leading)
    }

    @ViewBuilder
    private var metadata: some View {
        if isUser {
            Text(message.createdAt, style: .time)
                .font(.caption2)
                .foregroundStyle(.tertiary)
        } else if let run {
            HStack(spacing: 8) {
                Text(modelName(for: run.modelID))
                if let duration = run.duration {
                    Text("\(duration, specifier: "%.2f")s")
                }
                if let errorCategory = run.errorCategory {
                    Text(errorCategory)
                }
            }
            .font(.caption2)
            .foregroundStyle(run.errorCategory == nil ? Color.secondary.opacity(0.65) : Color.red)
        }
    }

    private func modelName(for modelID: String) -> String {
        registry.descriptor(for: modelID)?.displayName ?? modelID
    }
}
