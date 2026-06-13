import SwiftUI

struct CompareView: View {
    let registry: ModelRegistry

    @State private var store = CompareStore()

    private var canRun: Bool {
        store.prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
            && store.isRunning == false
            && store.selectedModelIDs.contains { registry.descriptor(for: $0)?.canSend == true }
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
                ForEach(store.selectedModelIDs.indices, id: \.self) { index in
                    HStack {
                        Text("Model \(index + 1)")
                            .font(.headline)
                            .frame(width: 76, alignment: .leading)
                        Picker("Model \(index + 1)", selection: binding(for: index)) {
                            ForEach(registry.groupedDescriptors(), id: \.lane.rawValue) { group in
                                Section(group.lane.title) {
                                    ForEach(group.descriptors) { descriptor in
                                        Text(descriptor.displayName)
                                            .tag(descriptor.id)
                                    }
                                }
                            }
                        }
                        .pickerStyle(.menu)
                        Spacer()
                        Button("Remove") {
                            store.removeModel(at: index)
                        }
                        .disabled(store.selectedModelIDs.count <= 1 || store.isRunning)
                    }

                    if let descriptor = registry.descriptor(for: store.selectedModelIDs[index]),
                       descriptor.canSend == false {
                        Text(descriptor.statusLine)
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }
            }

            HStack {
                Button("Add Model") {
                    store.addModel(registry: registry)
                }
                .disabled(store.isRunning)

                Spacer()

                if let errorMessage = store.errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.red)
                }

                Button(store.isRunning ? "Running..." : "Compare") {
                    Task {
                        await store.run(registry: registry)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(canRun == false)
            }
        }
        .padding()
    }

    private var results: some View {
        ScrollView {
            LazyVGrid(columns: columns, alignment: .leading, spacing: 14) {
                if store.results.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("No comparison yet")
                            .font(.title3.weight(.semibold))
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
                return registry.descriptors.first?.id ?? BuiltInModelID.appleSystem
            }
            return store.selectedModelIDs[index]
        } set: { newValue in
            guard store.selectedModelIDs.indices.contains(index) else {
                return
            }
            store.selectedModelIDs[index] = newValue
        }
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
                Text(statusText)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(statusColor)
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
