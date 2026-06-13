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
    var selectedModelIDs = [BuiltInModelID.appleSystem, BuiltInModelID.privateCloud]
    var results: [ComparisonResult] = []
    var isRunning = false
    var errorMessage: String?

    func run(registry: ModelRegistry) async {
        let trimmed = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false, isRunning == false else {
            return
        }

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
        guard let descriptor = registry.descriptors.first else {
            return
        }
        selectedModelIDs.append(descriptor.id)
    }

    func removeModel(at index: Int) {
        guard selectedModelIDs.indices.contains(index), selectedModelIDs.count > 1 else {
            return
        }
        selectedModelIDs.remove(at: index)
    }

    private func run(descriptor: ModelDescriptor, prompt: String) async {
        guard let resultIndex = results.firstIndex(where: { $0.modelID == descriptor.id }) else {
            return
        }

        let startedAt = Date()
        results[resultIndex].startedAt = startedAt
        results[resultIndex].isRunning = true

        do {
            let session = try SessionFactory.makeSession(for: descriptor)
            let stream = session.streamResponse(to: prompt)
            for try await snapshot in stream {
                updateResult(for: descriptor.id) { result in
                    result.output = snapshot.content
                }
            }

            let completedAt = Date()
            updateResult(for: descriptor.id) { result in
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
            errorMessage = error.localizedDescription
        }
    }

    private func updateResult(for modelID: String, _ update: (inout ComparisonResult) -> Void) {
        guard let index = results.firstIndex(where: { $0.modelID == modelID }) else {
            return
        }
        update(&results[index])
    }
}
