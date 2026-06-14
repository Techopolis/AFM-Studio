import Foundation

@main
struct ModelDescriptorTests {
    static func main() throws {
        try privateCloudLaneUsesBroadSectionTitle()
        try descriptorsExposeExternalDownloadReferences()
        print("ModelDescriptorTests passed")
    }

    private static func privateCloudLaneUsesBroadSectionTitle() throws {
        try expect(
            ModelLane.privateCloud.title == "Apple Cloud",
            "private cloud lane should use a broader section title than the Private Cloud Compute model"
        )
    }

    private static func descriptorsExposeExternalDownloadReferences() throws {
        let descriptor = ModelDescriptor(
            id: "coreai.catalog.gemma-4-e2b",
            displayName: "Gemma 4 E2B (Core AI)",
            lane: .coreAI,
            modelID: "google/gemma-4-E2B-it",
            downloadURL: URL(string: "https://example.com/gemma-4-e2b")!,
            capabilities: .textOnly,
            availability: .requiresSetup,
            statusLine: "Community Core AI bundle",
            isBuiltIn: true
        )

        try expect(
            descriptor.hasDownloadReference,
            "catalog descriptors with a download URL should expose a download reference even before they are sendable"
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
