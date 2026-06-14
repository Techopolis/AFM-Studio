import Foundation

enum StudioSettingsTab: String, CaseIterable, Hashable, Identifiable, Sendable {
    case general
    case models
    case privateCloud
    case developer

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .general:
            "General"
        case .models:
            "Models"
        case .privateCloud:
            "Private Cloud"
        case .developer:
            "Developer"
        }
    }

    var subtitle: String {
        switch self {
        case .general:
            "Application status and local library health"
        case .models:
            "Download, add, and manage runnable models"
        case .privateCloud:
            "Quota and entitlement readiness"
        case .developer:
            "Registry, Core AI, and local storage details"
        }
    }

    var systemImage: String {
        switch self {
        case .general:
            "gearshape"
        case .models:
            "shippingbox"
        case .privateCloud:
            "cloud"
        case .developer:
            "hammer"
        }
    }

    var accessibilityHint: String {
        switch self {
        case .general:
            "Shows AFM Studio status and local model counts"
        case .models:
            "Shows downloaded, available, and addable models"
        case .privateCloud:
            "Shows Private Cloud Compute availability and quota status"
        case .developer:
            "Shows registry, Core AI, and local model storage diagnostics"
        }
    }
}
