import Foundation
import FoundationModels
import Observation
import SwiftData

@MainActor
@Observable
final class BenchmarkStore {
    var suiteName = "Quick Benchmark"
    var promptText = [
        "Summarize the privacy tradeoffs of local AI in three sentences.",
        "Write concise empty-state copy for a model picker.",
        "Explain Private Cloud Compute to a Swift developer."
    ].joined(separator: "\n")
    var selectedModelID = BuiltInModelID.appleSystem
    var isRunning = false
    var currentPrompt: String?
    var errorMessage: String?

    var prompts: [String] {
        promptText
            .split(whereSeparator: \.isNewline)
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.isEmpty == false }
    }

    func run(registry: ModelRegistry, context: ModelContext) async {
        let trimmedSuiteName = suiteName.trimmingCharacters(in: .whitespacesAndNewlines)
        let suite = trimmedSuiteName.isEmpty ? "Untitled Benchmark" : trimmedSuiteName

        guard isRunning == false else {
            return
        }
        guard let descriptor = registry.descriptor(for: selectedModelID), descriptor.canSend else {
            errorMessage = "Select an available model."
            return
        }
        guard prompts.isEmpty == false else {
            errorMessage = "Add at least one prompt."
            return
        }

        isRunning = true
        errorMessage = nil

        for prompt in prompts {
            currentPrompt = prompt
            await runPrompt(prompt, suiteName: suite, descriptor: descriptor, context: context)
        }

        currentPrompt = nil
        isRunning = false
    }

    private func runPrompt(
        _ prompt: String,
        suiteName: String,
        descriptor: ModelDescriptor,
        context: ModelContext
    ) async {
        let startedAt = Date()
        var output = ""
        var errorCategory: String?

        do {
            let session = try SessionFactory.makeSession(for: descriptor)
            let stream = session.streamResponse(to: prompt)
            for try await snapshot in stream {
                output = snapshot.content
            }
        } catch {
            errorCategory = String(describing: type(of: error))
            errorMessage = error.localizedDescription
        }

        let duration = Date().timeIntervalSince(startedAt)
        let outputTokens = await tokenCount(for: output)
        let result = BenchmarkResultRecord(
            suiteName: suiteName,
            prompt: prompt,
            modelID: descriptor.id,
            output: output,
            duration: duration,
            outputTokens: outputTokens,
            errorCategory: errorCategory
        )
        context.insert(result)
        try? context.save()
    }

    private func tokenCount(for output: String) async -> Int? {
        guard output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false else {
            return nil
        }
        return try? await SystemLanguageModel.default.tokenCount(for: output)
    }
}
