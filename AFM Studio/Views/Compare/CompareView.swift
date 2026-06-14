import SwiftUI

struct CompareView: View {
    let registry: ModelRegistry

    @State private var store = CompareStore()

    private var canRun: Bool {
        store.prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
            && store.isRunning == false
            && store.selectedModelIDs.contains { registry.descriptor(for: $0)?.canSend == true }
    }

    private var canAddModel: Bool {
        store.isRunning == false
            && ModelSelectionPolicy.nextComparisonModelID(
                selectedModelIDs: store.selectedModelIDs,
                descriptors: registry.descriptors
            ) != nil
    }

    private var groupedDescriptors: [(lane: ModelLane, descriptors: [ModelDescriptor])] {
        ModelSelectionPolicy.groupedSelectableDescriptors(from: registry.descriptors)
    }

    private let columns = [
        GridItem(.adaptive(minimum: 300), spacing: 14)
    ]

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                controls
                Divider()
                results
            }
            .navigationTitle("Compare")
            .onAppear(perform: repairSelectionIfNeeded)
            .onChange(of: registry.descriptors) { _, _ in
                repairSelectionIfNeeded()
            }
        }
    }

    private var controls: some View {
        VStack(alignment: .leading, spacing: 14) {
            TextField("Prompt", text: $store.prompt, axis: .vertical)
                .textFieldStyle(.plain)
                .lineLimit(2...8)
                .padding(10)
                .background(Color.platformControlBackground)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.secondary.opacity(0.2))
                )

            VStack(alignment: .leading, spacing: 10) {
                if groupedDescriptors.isEmpty {
                    Label("No Available Models", systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(store.selectedModelIDs.indices, id: \.self) { index in
                        HStack {
                            Text("Model \(index + 1)")
                                .font(.headline)
                                .frame(width: 76, alignment: .leading)

                            Picker("Model \(index + 1)", selection: binding(for: index)) {
                                ForEach(groupedDescriptors, id: \.lane.rawValue) { group in
                                    Section(group.lane.title) {
                                        ForEach(group.descriptors) { descriptor in
                                            Text(descriptor.displayName)
                                                .tag(descriptor.id)
                                        }
                                    }
                                }
                            }
                            .labelsHidden()
                            .pickerStyle(.menu)
                            .accessibilityHint("Selects a model for comparison")

                            Spacer()

                            Button {
                                store.removeModel(at: index)
                            } label: {
                                Label("Remove Model", systemImage: "minus.circle")
                                    .labelStyle(.iconOnly)
                            }
                            .disabled(store.selectedModelIDs.count <= 1 || store.isRunning)
                            .help("Remove model")
                            .accessibilityHint("Removes this model from the comparison")
                        }

                        if let descriptor = registry.descriptor(for: store.selectedModelIDs[index]),
                           descriptor.canSend == false {
                            Text(descriptor.statusLine)
                                .font(.caption)
                                .foregroundStyle(.orange)
                        }
                    }
                }
            }

            HStack {
                Button {
                    store.addModel(registry: registry)
                } label: {
                    Label("Add Model", systemImage: "plus")
                }
                .disabled(canAddModel == false)

                Spacer()

                if let errorMessage = store.errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.red)
                }

                Button {
                    Task {
                        await store.run(registry: registry)
                    }
                } label: {
                    Label(store.isRunning ? "Running" : "Compare", systemImage: store.isRunning ? "hourglass" : "play.fill")
                }
                .buttonStyle(.borderedProminent)
                .disabled(canRun == false)
                .accessibilityHint("Runs the prompt against the selected models")
            }
        }
        .padding()
    }

    private var results: some View {
        ScrollView {
            LazyVGrid(columns: columns, alignment: .leading, spacing: 14) {
                if store.results.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Image(systemName: "rectangle.2.swap")
                            .font(.largeTitle)
                            .foregroundStyle(.secondary)
                            .accessibilityHidden(true)
                        Text("No comparison yet")
                            .font(.title3.weight(.semibold))
                            .accessibilityAddTraits(.isHeader)
                        Text("Enter a prompt, choose models, and run a side-by-side comparison.")
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    ForEach(store.results) { result in
                        ComparisonResultCard(result: result)
                    }
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .background(Color.platformBackground)
    }

    private func binding(for index: Int) -> Binding<String> {
        Binding {
            guard store.selectedModelIDs.indices.contains(index) else {
                return ModelSelectionPolicy.preferredComparisonModelIDs(
                    currentModelIDs: store.selectedModelIDs,
                    descriptors: registry.descriptors
                ).first ?? ""
            }
            return store.selectedModelIDs[index]
        } set: { newValue in
            guard store.selectedModelIDs.indices.contains(index) else {
                return
            }
            store.selectedModelIDs[index] = newValue
            repairSelectionIfNeeded()
        }
    }

    private func repairSelectionIfNeeded() {
        store.repairSelection(registry: registry)
    }
}

private struct ComparisonResultCard: View {
    let result: ComparisonResult

    private var bodyText: String {
        let trimmed = result.output.trimmingCharacters(in: .whitespacesAndNewlines)
        if result.isRunning && trimmed.isEmpty {
            return "Thinking..."
        }
        if let errorCategory = result.errorCategory {
            return "Failed: \(errorCategory)"
        }
        return trimmed.isEmpty ? "No output." : trimmed
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(result.displayName)
                    .font(.headline)
                Spacer()
                Label(statusText, systemImage: statusImage)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(statusColor)
                    .labelStyle(.titleAndIcon)
            }

            Text(bodyText)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .topLeading)

            if let duration = result.duration {
                Text("\(duration, specifier: "%.2f") seconds")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .frame(minHeight: 220, alignment: .topLeading)
        .background(Color.platformControlBackground)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.secondary.opacity(0.18))
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(result.displayName)
        .accessibilityValue("\(statusText), \(bodyText)")
    }

    private var statusText: String {
        if result.isRunning {
            return "Running"
        }
        if result.errorCategory != nil {
            return "Error"
        }
        if result.completedAt != nil {
            return "Done"
        }
        return "Queued"
    }

    private var statusImage: String {
        if result.isRunning {
            return "hourglass"
        }
        if result.errorCategory != nil {
            return "xmark.octagon.fill"
        }
        if result.completedAt != nil {
            return "checkmark.circle.fill"
        }
        return "circle"
    }

    private var statusColor: Color {
        if result.isRunning {
            return .blue
        }
        if result.errorCategory != nil {
            return .red
        }
        return .secondary
    }
}
