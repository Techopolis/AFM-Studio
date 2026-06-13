import Foundation
import FoundationModels

enum SessionFactoryError: LocalizedError {
    case unsupportedModel(String)
    case unavailable(String)

    var errorDescription: String? {
        switch self {
        case .unsupportedModel(let modelID):
            "Unsupported model: \(modelID)"
        case .unavailable(let message):
            message
        }
    }
}

enum SessionFactory {
    static func makeSession(for descriptor: ModelDescriptor) throws -> LanguageModelSession {
        switch descriptor.id {
        case BuiltInModelID.appleSystem:
            return LanguageModelSession(model: SystemLanguageModel.default)
        case BuiltInModelID.privateCloud:
            if #available(iOS 27.0, macOS 27.0, visionOS 27.0, watchOS 27.0, *) {
                return LanguageModelSession(model: PrivateCloudComputeLanguageModel())
            }
            throw SessionFactoryError.unavailable("Private Cloud Compute requires OS 27.")
        case BuiltInModelID.gemma4E2B:
            throw SessionFactoryError.unavailable("MLXFoundationModels has not been validated in this build.")
        default:
            throw SessionFactoryError.unsupportedModel(descriptor.id)
        }
    }
}
