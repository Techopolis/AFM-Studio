import SwiftUI

struct ModelPickerView: View {
    let conversation: ConversationRecord
    let registry: ModelRegistry

    private var groupedDescriptors: [(lane: ModelLane, descriptors: [ModelDescriptor])] {
        ModelSelectionPolicy.groupedSelectableDescriptors(from: registry.descriptors)
    }

    private var selection: Binding<String> {
        Binding {
            ModelSelectionPolicy.preferredModelID(
                currentModelID: conversation.selectedModelID,
                descriptors: registry.descriptors
            ) ?? conversation.selectedModelID
        } set: { newValue in
            conversation.selectedModelID = newValue
            conversation.updatedAt = .now
        }
    }

    var body: some View {
        Group {
            if groupedDescriptors.isEmpty {
                Label("No Available Models", systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.secondary)
            } else {
                Picker("Model", selection: selection) {
                    ForEach(groupedDescriptors, id: \.lane.rawValue) { group in
                        Section(group.lane.title) {
                            ForEach(group.descriptors) { descriptor in
                                Text(descriptor.displayName)
                                    .tag(descriptor.id)
                            }
                        }
                    }
                }
                .pickerStyle(.menu)
            }
        }
        .onAppear(perform: repairSelectionIfNeeded)
        .onChange(of: registry.descriptors) { _, _ in
            repairSelectionIfNeeded()
        }
        .accessibilityHint("Shows downloaded or currently available models")
    }

    private func repairSelectionIfNeeded() {
        guard let preferredModelID = ModelSelectionPolicy.preferredModelID(
            currentModelID: conversation.selectedModelID,
            descriptors: registry.descriptors
        ) else {
            return
        }

        if conversation.selectedModelID != preferredModelID {
            conversation.selectedModelID = preferredModelID
            conversation.updatedAt = .now
        }
    }
}
