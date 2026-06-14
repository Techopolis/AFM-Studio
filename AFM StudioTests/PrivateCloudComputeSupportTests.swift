import Foundation

@main
struct PrivateCloudComputeSupportTests {
    static func main() throws {
        try hidesEntitlementInstructionsWhenPrivateCloudIsAvailable()
        try showsEntitlementInstructionsWhenPrivateCloudIsUnavailable()
        try appendsEntitlementInstructionsToRuntimeFailures()
        print("PrivateCloudComputeSupportTests passed")
    }

    private static func hidesEntitlementInstructionsWhenPrivateCloudIsAvailable() throws {
        let descriptor = privateCloudDescriptor(availability: .available)

        try expect(
            PrivateCloudComputeSupport.entitlementGuidance(for: descriptor) == nil,
            "available Private Cloud Compute should not show setup guidance"
        )
    }

    private static func showsEntitlementInstructionsWhenPrivateCloudIsUnavailable() throws {
        let descriptor = privateCloudDescriptor(availability: .unavailable)
        let guidance = try expectValue(
            PrivateCloudComputeSupport.entitlementGuidance(for: descriptor),
            "unavailable Private Cloud Compute should show setup guidance"
        )

        try expect(guidance.contains("Signing & Capabilities"), "guidance should point to Xcode capabilities")
        try expect(guidance.contains("Apple Developer"), "guidance should mention developer entitlement setup")
    }

    private static func appendsEntitlementInstructionsToRuntimeFailures() throws {
        let descriptor = privateCloudDescriptor(availability: .available)
        let message = PrivateCloudComputeSupport.runtimeFailureMessage(
            for: descriptor,
            error: TestError("request denied")
        )

        try expect(message.contains("request denied"), "runtime failure should preserve the original error")
        try expect(message.contains("Private Cloud Compute failed"), "runtime failure should name Private Cloud Compute")
        try expect(message.contains("Signing & Capabilities"), "runtime failure should include entitlement guidance")
    }

    private static func privateCloudDescriptor(availability: ModelAvailabilityState) -> ModelDescriptor {
        ModelDescriptor(
            id: "apple.private-cloud.default",
            displayName: "Private Cloud Compute",
            lane: .privateCloud,
            modelID: "PrivateCloudComputeLanguageModel.default",
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

    private static func expectValue<T>(_ value: T?, _ message: String) throws -> T {
        guard let value else {
            throw TestFailure(message)
        }
        return value
    }

    private struct TestError: LocalizedError {
        let errorDescription: String?

        init(_ message: String) {
            errorDescription = message
        }
    }

    private struct TestFailure: Error, CustomStringConvertible {
        var description: String

        init(_ description: String) {
            self.description = description
        }
    }
}
