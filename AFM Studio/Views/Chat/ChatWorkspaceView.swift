import SwiftData
import SwiftUI

struct ChatWorkspaceView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ConversationRecord.updatedAt, order: .reverse) private var conversations: [ConversationRecord]
    @Query(sort: \UserModelRecord.displayName) private var userModels: [UserModelRecord]

    let registry: ModelRegistry
    let downloadManager: ModelDownloadManager
    let chatStore: ChatStore

    @State private var selectedConversationID: UUID?

    private var selectedConversation: ConversationRecord? {
        if let selectedConversationID,
           let conversation = conversations.first(where: { $0.id == selectedConversationID }) {
            return conversation
        }
        if let activeConversation = chatStore.activeConversation {
            return activeConversation
        }
        return conversations.first
    }

    var body: some View {
        NavigationSplitView {
            StudioConversationListView(
                conversations: conversations,
                selectedConversationID: $selectedConversationID,
                onNewConversation: createConversation,
                onDelete: deleteConversation
            )
            .navigationSplitViewColumnWidth(min: 260, ideal: 320, max: 420)
        } detail: {
            if let selectedConversation {
                ChatTranscriptView(
                    conversation: selectedConversation,
                    registry: registry,
                    chatStore: chatStore
                )
            } else {
                EmptyChatView(onNewConversation: createConversation)
            }
        }
        .onAppear {
            registry.refresh(userModels: userModels, remoteRegistry: downloadManager.registry)
            restoreSelectionIfNeeded()
        }
        .onChange(of: userModels.count) { _, _ in
            registry.refresh(userModels: userModels, remoteRegistry: downloadManager.registry)
        }
        .onChange(of: selectedConversationID) { _, newValue in
            guard let newValue,
                  let conversation = conversations.first(where: { $0.id == newValue }) else {
                return
            }
            chatStore.activeConversation = conversation
        }
    }

    private func createConversation() {
        registry.refresh(userModels: userModels, remoteRegistry: downloadManager.registry)
        let selectedModelID = ModelSelectionPolicy
            .preferredModelID(currentModelID: BuiltInModelID.appleSystem, descriptors: registry.descriptors)
            ?? BuiltInModelID.appleSystem
        let conversation = ConversationRecord(selectedModelID: selectedModelID)
        modelContext.insert(conversation)
        try? modelContext.save()
        selectedConversationID = conversation.id
        chatStore.activeConversation = conversation
    }

    private func deleteConversation(_ conversation: ConversationRecord) {
        let deletedID = conversation.id
        modelContext.delete(conversation)
        try? modelContext.save()

        guard selectedConversationID == deletedID else {
            return
        }

        let nextConversation = conversations.first { $0.id != deletedID }
        selectedConversationID = nextConversation?.id
        chatStore.activeConversation = nextConversation
    }

    private func restoreSelectionIfNeeded() {
        if let selectedConversationID,
           conversations.contains(where: { $0.id == selectedConversationID }) {
            return
        }

        if let activeConversation = chatStore.activeConversation {
            selectedConversationID = activeConversation.id
            return
        }

        if let firstConversation = conversations.first {
            selectedConversationID = firstConversation.id
            chatStore.activeConversation = firstConversation
            return
        }

        createConversation()
    }
}

private struct EmptyChatView: View {
    let onNewConversation: () -> Void

    var body: some View {
        VStack(alignment: .center, spacing: 16) {
            Text("Start a new chat")
                .font(.title2.weight(.semibold))
            Text("Pick a model, send a prompt, and inspect the run details as the response streams.")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button(action: onNewConversation) {
                Label("New Chat", systemImage: "plus")
            }
                .buttonStyle(.borderedProminent)
                .accessibilityHint("Creates a new conversation")
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
