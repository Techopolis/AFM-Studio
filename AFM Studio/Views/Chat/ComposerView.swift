import SwiftUI

struct ComposerView: View {
    @Binding var draft: String
    let isSending: Bool
    let canSend: Bool
    let unavailableReason: String?
    let onSend: () -> Void

    private var trimmedDraft: String {
        draft.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canSubmit: Bool {
        trimmedDraft.isEmpty == false && canSend && isSending == false
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let unavailableReason {
                Text(unavailableReason)
                    .font(.caption)
                    .foregroundStyle(.orange)
            }

            TextField("Message", text: $draft, axis: .vertical)
                .textFieldStyle(.plain)
                .lineLimit(1...6)
                .padding(10)
                .background(Color.platformControlBackground)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.secondary.opacity(0.2))
                )
                .submitLabel(.send)
                .onSubmit {
                    if canSubmit {
                        onSend()
                    }
                }
                .accessibilityLabel("Message")
                .accessibilityHint("Type a prompt for the selected model")

            HStack {
                Spacer()
                Button(action: onSend) {
                    Label(isSending ? "Sending" : "Send", systemImage: isSending ? "hourglass" : "paperplane.fill")
                }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.return, modifiers: .command)
                    .disabled(canSubmit == false)
                    .accessibilityHint("Sends the message to the selected model")
            }
        }
        .padding()
        .background(Color.platformBackground)
    }
}

extension Color {
    static var platformBackground: Color {
        #if os(macOS)
        Color(nsColor: .windowBackgroundColor)
        #else
        Color(uiColor: .systemBackground)
        #endif
    }

    static var platformControlBackground: Color {
        #if os(macOS)
        Color(nsColor: .controlBackgroundColor)
        #else
        Color(uiColor: .secondarySystemBackground)
        #endif
    }
}
