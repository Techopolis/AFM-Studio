import Foundation

enum PrivateCloudComputeSupport {
    static let entitlementGuidance = [
        "In Xcode, select the AFM Studio target and open Signing & Capabilities.",
        "Add the Private Cloud Compute capability.",
        "Make sure the App ID in your Apple Developer account has the Private Cloud Compute entitlement enabled."
    ].joined(separator: " ")

    static func entitlementGuidance(for descriptor: ModelDescriptor?) -> String? {
        guard let descriptor else {
            return "Private Cloud Compute requires OS 27 or later. \(entitlementGuidance)"
        }

        guard descriptor.lane == .privateCloud else {
            return nil
        }

        return descriptor.availability == .available ? nil : entitlementGuidance
    }

    static func runtimeFailureMessage(for descriptor: ModelDescriptor, error: any Error) -> String {
        guard descriptor.lane == .privateCloud else {
            return error.localizedDescription
        }

        return "Private Cloud Compute failed: \(error.localizedDescription)\n\n\(entitlementGuidance)"
    }
}
