import SwiftUI

struct StudioConversationListView: View {
    let conversations: [ConversationRecord]
    @Binding var selectedConversationID: UUID?
    let onNewConversation: () -> Void
    let onDelete: (ConversationRecord) -> Void

    @State private var searchText = ""

    private var uniqueConversations: [ConversationRecord] {
        var seenIDs = Set<UUID>()
        return conversations.filter { conversation in
            if seenIDs.contains(conversation.id) {
                return false
            }
            seenIDs.insert(conversation.id)
            return true
        }
    }

    private var filteredConversations: [ConversationRecord] {
        uniqueConversations.filter { conversation in
            presentation(for: conversation).matchesSearch(searchText)
        }
    }

    var body: some View {
        Group {
            if uniqueConversations.isEmpty {
                emptyState
            } else {
                conversationsList
            }
        }
        .navigationTitle("Conversations")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: onNewConversation) {
                    Image(systemName: "square.and.pencil")
                }
                .help("New chat")
                .accessibilityLabel("New chat")
                .accessibilityHint("Creates a new conversation")
            }
        }
    }

    private var conversationsList: some View {
        List(selection: $selectedConversationID) {
            conversationRows
        }
        .listStyle(.sidebar)
        .searchable(text: $searchText, prompt: "Search conversations")
        .scrollContentBackground(.hidden)
        .overlay {
            if searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false,
               filteredConversations.isEmpty {
                noSearchResultsView
            }
        }
    }

    @ViewBuilder
    private var conversationRows: some View {
        ForEach(filteredConversations) { conversation in
            StudioConversationRowView(
                presentation: presentation(for: conversation)
            )
            .tag(conversation.id)
            .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
            .contentShape(Rectangle())
            .contextMenu {
                Button(role: .destructive) {
                    onDelete(conversation)
                } label: {
                    Label("Delete Conversation", systemImage: "trash")
                }
                .accessibilityHint("Delete this conversation")
            }
        }
        .onDelete(perform: deleteFilteredConversations)
    }

    private func presentation(for conversation: ConversationRecord) -> StudioConversationListPresentation {
        let orderedMessages = conversation.messages.sorted { $0.createdAt < $1.createdAt }
        return StudioConversationListPresentation(
            title: conversation.title,
            subtitle: StudioConversationListPresentation.subtitle(
                latestMessageContent: orderedMessages.last?.content,
                hasMessages: orderedMessages.isEmpty == false
            ),
            updatedAt: conversation.updatedAt,
            messageCount: conversation.messages.count,
            isActive: selectedConversationID == conversation.id
        )
    }

    private func deleteFilteredConversations(offsets: IndexSet) {
        offsets
            .compactMap { index in
                index < filteredConversations.count ? filteredConversations[index] : nil
            }
            .forEach(onDelete)
    }

    private var noSearchResultsView: some View {
        VStack(spacing: 16) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)

            Text("No Results")
                .font(.title3.weight(.semibold))

            Text("No conversations match \"\(searchText)\"")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)

            Text("No Conversations")
                .font(.title2.weight(.semibold))

            Text("Start a new conversation to begin chatting")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button(action: onNewConversation) {
                Label("New Conversation", systemImage: "plus.circle.fill")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color.accentColor)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.plain)
            .accessibilityHint("Creates a new conversation")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct StudioConversationRowView: View {
    let presentation: StudioConversationListPresentation

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    if presentation.isActive {
                        Circle()
                            .fill(Color.accentColor)
                            .frame(width: 8, height: 8)
                            .accessibilityLabel("Current conversation")
                    }

                    Text(presentation.title)
                        .font(.headline)
                        .lineLimit(1)
                }

                Text(presentation.subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 6) {
                Text(presentation.updatedAt, style: .relative)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if presentation.messageCount > 0 {
                    Text("\(presentation.messageCount)")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color.accentColor)
                        .clipShape(Capsule())
                        .accessibilityLabel("\(presentation.messageCount) messages")
                }
            }
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 12)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(presentation.title)
        .accessibilityValue(accessibilityValue)
        .accessibilityHint("Opens this conversation")
    }

    private var accessibilityValue: String {
        var values: [String] = []
        if presentation.isActive {
            values.append("selected")
        }
        values.append("\(presentation.messageCount) messages")
        values.append(presentation.subtitle)
        return values.joined(separator: ", ")
    }
}
