import Foundation

@main
struct ModelSelectionPolicyTests {
    static func main() throws {
        try filtersToSendableDescriptors()
        try repairsUnavailableSelection()
        print("ModelSelectionPolicyTests passed")
    }

    private static func filtersToSendableDescriptors() throws {
        let descriptors = [
            descriptor(id: "system", availability: .available),
            descriptor(id: "downloaded-coreai", availability: .experimental),
            descriptor(id: "needs-download", availability: .requiresSetup),
            descriptor(id: "blocked", availability: .unavailable)
        ]

        let selectable = ModelSelectionPolicy.selectableDescriptors(from: descriptors).map(\.id)

        try expect(selectable == ["system", "downloaded-coreai"], "chat model picker should only include available or downloaded models")
    }

    private static func repairsUnavailableSelection() throws {
        let descriptors = [
            descriptor(id: "needs-download", availability: .requiresSetup),
            descriptor(id: "system", availability: .available)
        ]

        try expect(
            ModelSelectionPolicy.preferredModelID(currentModelID: "needs-download", descriptors: descriptors) == "system",
            "unavailable chat selection should move to the first selectable model"
        )
        try expect(
            ModelSelectionPolicy.preferredModelID(currentModelID: "system", descriptors: descriptors) == "system",
            "available chat selection should be preserved"
        )
    }

    private static func descriptor(id: String, availability: ModelAvailabilityState) -> ModelDescriptor {
        ModelDescriptor(
            id: id,
            displayName: id,
            lane: .coreAI,
            modelID: id,
            capabilities: .textOnly,
            availability: availability,
            statusLine: availability.rawValue,
            isBuiltIn: true
        )
    }

    private static func expect(_ condition: Bool, _ message: String) throws {
        if condition == false {
            throw TestFailure(message)
        }
    }

    private struct TestFailure: Error, CustomStringConvertible {
        var description: String

        init(_ description: String) {
            self.description = description
        }
    }
}
