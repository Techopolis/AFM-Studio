import SwiftData
import SwiftUI

struct BenchmarkView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \BenchmarkResultRecord.createdAt, order: .reverse) private var results: [BenchmarkResultRecord]

    let registry: ModelRegistry

    @State private var store = BenchmarkStore()

    private var selectedDescriptor: ModelDescriptor? {
        registry.descriptor(for: store.selectedModelID)
    }

    private var canRun: Bool {
        store.isRunning == false
            && store.prompts.isEmpty == false
            && selectedDescriptor?.canSend == true
    }

    var body: some View {
        NavigationSplitView {
            controls
                .navigationTitle("Benchmarks")
                .frame(minWidth: 320, idealWidth: 420)
        } detail: {
            history
                .navigationTitle("Results")
        }
    }

    private var controls: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Suite", systemImage: "list.bullet.rectangle")
                .font(.headline)
            TextField("Suite Name", text: $store.suiteName)
                .textFieldStyle(.roundedBorder)

            Label("Model", systemImage: "cpu")
                .font(.headline)
            Picker("Model", selection: $store.selectedModelID) {
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

            if let selectedDescriptor, selectedDescriptor.canSend == false {
                Text(selectedDescriptor.statusLine)
                    .font(.caption)
                    .foregroundStyle(.orange)
            }

            Label("Prompts", systemImage: "text.quote")
                .font(.headline)
            TextEditor(text: $store.promptText)
                .font(.body)
                .scrollContentBackground(.hidden)
                .padding(8)
                .background(Color.platformControlBackground)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.secondary.opacity(0.2))
                )
                .frame(minHeight: 180)

            if let currentPrompt = store.currentPrompt {
                Text(currentPrompt)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            HStack {
                if let errorMessage = store.errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .lineLimit(2)
                }
                Spacer()
                Button {
                    Task {
                        await store.run(registry: registry, context: modelContext)
                    }
                } label: {
                    Label(store.isRunning ? "Running" : "Run Benchmark", systemImage: store.isRunning ? "hourglass" : "play.fill")
                }
                .buttonStyle(.borderedProminent)
                .disabled(canRun == false)
                .accessibilityHint("Runs every prompt in the benchmark suite")
            }

            Spacer()
        }
        .padding()
        .background(Color.platformBackground)
    }

    private var history: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label("Results", systemImage: "chart.bar.doc.horizontal")
                        .font(.title2.weight(.semibold))
                    Spacer()
                    Text("\(results.count)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }

                if results.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Image(systemName: "speedometer")
                            .font(.largeTitle)
                            .foregroundStyle(.secondary)
                            .accessibilityHidden(true)
                        Text("No benchmark results")
                            .font(.headline)
                            .accessibilityAddTraits(.isHeader)
                        Text("Run a suite to create result history.")
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 24)
                } else {
                    ForEach(results) { result in
                        BenchmarkResultRow(result: result, registry: registry)
                    }
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .background(Color.platformBackground)
    }
}

private struct BenchmarkResultRow: View {
    let result: BenchmarkResultRecord
    let registry: ModelRegistry

    private var modelName: String {
        registry.descriptor(for: result.modelID)?.displayName ?? result.modelID
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(result.suiteName)
                    .font(.headline)
                Spacer()
                Text(result.createdAt, style: .relative)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text(modelName)
                .font(.subheadline.weight(.medium))

            Text(result.prompt)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(2)

            Text(outputText)
                .textSelection(.enabled)
                .lineLimit(5)

            HStack(spacing: 10) {
                Label("\(result.duration, specifier: "%.2f") seconds", systemImage: "timer")
                if let outputTokens = result.outputTokens {
                    Label("\(outputTokens) output tokens", systemImage: "number")
                }
                if let errorCategory = result.errorCategory {
                    Label(errorCategory, systemImage: "xmark.octagon.fill")
                        .foregroundStyle(.red)
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .labelStyle(.titleAndIcon)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(Color.platformControlBackground)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.secondary.opacity(0.18))
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(result.suiteName), \(modelName)")
        .accessibilityValue("\(result.duration) seconds, \(outputText)")
    }

    private var outputText: String {
        let trimmed = result.output.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return result.errorCategory == nil ? "No output." : "Failed."
        }
        return trimmed
    }
}
