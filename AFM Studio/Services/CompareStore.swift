import Foundation
import FoundationModels
import Observation

struct ComparisonResult: Identifiable, Equatable {
    let id: UUID
    var modelID: String
    var displayName: String
    var output: String
    var startedAt: Date?
    var completedAt: Date?
    var duration: TimeInterval?
    var errorCategory: String?
    var isRunning: Bool

    init(modelID: String, displayName: String) {
        self.id = UUID()
        self.modelID = modelID
        self.displayName = displayName
        self.output = ""
        self.startedAt = nil
        self.completedAt = nil
        self.duration = nil
        self.errorCategory = nil
        self.isRunning = false
    }
}

@MainActor
@Observable
final class CompareStore {
    var prompt = ""
    var selectedModelIDs: [String] = []
    var results: [ComparisonResult] = []
    var isRunning = false
    var errorMessage: String?

    func run(registry: ModelRegistry) async {
        let trimmed = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false, isRunning == false else {
            return
        }

        repairSelection(registry: registry)

        let descriptors = selectedModelIDs
            .compactMap { registry.descriptor(for: $0) }
            .filter(\.canSend)

        guard descriptors.isEmpty == false else {
            errorMessage = "Select at least one available model."
            return
        }

        results = descriptors.map { ComparisonResult(modelID: $0.id, displayName: $0.displayName) }
        isRunning = true
        errorMessage = nil

        for descriptor in descriptors {
            await run(descriptor: descriptor, prompt: trimmed)
        }

        isRunning = false
    }

    func addModel(registry: ModelRegistry) {
        guard let modelID = ModelSelectionPolicy.nextComparisonModelID(
            selectedModelIDs: selectedModelIDs,
            descriptors: registry.descriptors
        ) else {
            return
        }
        selectedModelIDs.append(modelID)
    }

    func removeModel(at index: Int) {
        guard selectedModelIDs.indices.contains(index), selectedModelIDs.count > 1 else {
            return
        }
        selectedModelIDs.remove(at: index)
    }

    func repairSelection(registry: ModelRegistry) {
        let repaired = ModelSelectionPolicy.preferredComparisonModelIDs(
            currentModelIDs: selectedModelIDs,
            descriptors: registry.descriptors
        )
        if selectedModelIDs != repaired {
            selectedModelIDs = repaired
        }
    }

    private func run(descriptor: ModelDescriptor, prompt: String) async {
        guard let resultIndex = results.firstIndex(where: { $0.modelID == descriptor.id }) else {
            return
        }

        let startedAt = Date()
        results[resultIndex].startedAt = startedAt
        results[resultIndex].isRunning = true
        var rawOutput = ""

        do {
            let session = try await SessionFactory.makeSession(for: descriptor)
            let stream = session.streamResponse(to: prompt)
            for try await snapshot in stream {
                rawOutput = snapshot.content
                let parsedOutput = ModelOutputParser.parse(snapshot.content)
                updateResult(for: descriptor.id) { result in
                    result.output = parsedOutput.displayText
                }
            }

            let completedAt = Date()
            updateResult(for: descriptor.id) { result in
                if result.output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                   rawOutput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false {
                    result.output = "No final response."
                }
                result.completedAt = completedAt
                result.duration = completedAt.timeIntervalSince(startedAt)
                result.isRunning = false
            }
        } catch {
            updateResult(for: descriptor.id) { result in
                result.output = ""
                result.completedAt = .now
                result.duration = result.completedAt?.timeIntervalSince(startedAt)
                result.errorCategory = String(describing: type(of: error))
                result.isRunning = false
            }
            errorMessage = PrivateCloudComputeSupport.runtimeFailureMessage(for: descriptor, error: error)
        }
    }

    private func updateResult(for modelID: String, _ update: (inout ComparisonResult) -> Void) {
        guard let index = results.firstIndex(where: { $0.modelID == modelID }) else {
            return
        }
        update(&results[index])
    }
}
