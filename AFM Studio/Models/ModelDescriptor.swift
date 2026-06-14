import Foundation

enum ModelLane: String, Codable, CaseIterable, Identifiable, Sendable {
    case appleSystem
    case privateCloud
    case coreAI
    case server

    var id: String { rawValue }

    var title: String {
        switch self {
        case .appleSystem:
            "Apple"
        case .privateCloud:
            "Apple Cloud"
        case .coreAI:
            "Core AI"
        case .server:
            "Server Providers"
        }
    }

    var systemImage: String {
        switch self {
        case .appleSystem:
            "apple.logo"
        case .privateCloud:
            "icloud"
        case .coreAI:
            "cpu"
        case .server:
            "server.rack"
        }
    }
}

enum ModelAvailabilityState: String, Codable, Equatable, Sendable {
    case available
    case unavailable
    case requiresSetup
    case experimental

    var systemImage: String {
        switch self {
        case .available:
            "checkmark.circle.fill"
        case .experimental:
            "flask.fill"
        case .requiresSetup:
            "wrench.and.screwdriver.fill"
        case .unavailable:
            "xmark.octagon.fill"
        }
    }
}

struct ModelCapabilitySet: Codable, Equatable, Sendable {
    var text: Bool
    var reasoning: Bool
    var toolCalling: Bool
    var guidedGeneration: Bool
    var vision: Bool

    static let textOnly = ModelCapabilitySet(
        text: true,
        reasoning: false,
        toolCalling: false,
        guidedGeneration: false,
        vision: false
    )
}

struct ModelDescriptor: Identifiable, Codable, Equatable, Sendable {
    var id: String
    var displayName: String
    var lane: ModelLane
    var modelID: String
    var catalogID: String? = nil
    var catalogSource: String? = nil
    var catalogURL: URL? = nil
    var downloadURL: URL? = nil
    var exportCommand: String? = nil
    var platformSummary: String? = nil
    var resourcePath: String? = nil
    var resourceBookmark: Data? = nil
    var variant: String? = nil
    var capabilities: ModelCapabilitySet
    var availability: ModelAvailabilityState
    var statusLine: String
    var isBuiltIn: Bool

    var canSend: Bool {
        availability == .available || availability == .experimental
    }

    var hasDownloadReference: Bool {
        downloadURL != nil
    }
}
