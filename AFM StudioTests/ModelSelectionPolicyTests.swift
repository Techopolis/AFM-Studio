import Foundation

@main
struct ModelSelectionPolicyTests {
    static func main() throws {
        try filtersToSendableDescriptors()
        try repairsUnavailableSelection()
        try choosesFirstTwoSendableModelsForComparison()
        try repairsComparisonSelectionWhenModelsChange()
        try addsOnlyUnselectedComparisonModels()
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

    private static func choosesFirstTwoSendableModelsForComparison() throws {
        let descriptors = [
            descriptor(id: "needs-download", availability: .requiresSetup),
            descriptor(id: "system", availability: .available),
            descriptor(id: "downloaded-coreai", availability: .experimental),
            descriptor(id: "cloud", availability: .available)
        ]

        let selected = ModelSelectionPolicy.preferredComparisonModelIDs(
            currentModelIDs: [],
            descriptors: descriptors
        )

        try expect(
            selected == ["system", "downloaded-coreai"],
            "comparison should start with the first two sendable models"
        )
    }

    private static func repairsComparisonSelectionWhenModelsChange() throws {
        let descriptors = [
            descriptor(id: "needs-download", availability: .requiresSetup),
            descriptor(id: "system", availability: .available),
            descriptor(id: "downloaded-coreai", availability: .experimental)
        ]

        let selected = ModelSelectionPolicy.preferredComparisonModelIDs(
            currentModelIDs: ["needs-download", "system", "system"],
            descriptors: descriptors
        )

        try expect(
            selected == ["system", "downloaded-coreai"],
            "comparison should remove unavailable and duplicate selections, then fill to two models"
        )
    }

    private static func addsOnlyUnselectedComparisonModels() throws {
        let descriptors = [
            descriptor(id: "system", availability: .available),
            descriptor(id: "downloaded-coreai", availability: .experimental),
            descriptor(id: "needs-download", availability: .requiresSetup)
        ]

        try expect(
            ModelSelectionPolicy.nextComparisonModelID(
                selectedModelIDs: ["system"],
                descriptors: descriptors
            ) == "downloaded-coreai",
            "comparison add should choose the next sendable model not already selected"
        )
        try expect(
            ModelSelectionPolicy.nextComparisonModelID(
                selectedModelIDs: ["system", "downloaded-coreai"],
                descriptors: descriptors
            ) == nil,
            "comparison add should stop when all sendable models are already selected"
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
