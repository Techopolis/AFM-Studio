import Foundation
import FoundationModels

#if canImport(CoreAILanguageModels)
import CoreAILanguageModels
#endif

enum CoreAILanguageModelSupport {
    static var isCompiledIn: Bool {
        #if canImport(CoreAILanguageModels)
        true
        #else
        false
        #endif
    }

    static var statusLine: String {
        if isCompiledIn {
            return "Core AI language models package linked"
        }
        return "Waiting for Apple's Core AI models package"
    }

    static func makeSession(for descriptor: ModelDescriptor) async throws -> LanguageModelSession {
        #if canImport(CoreAILanguageModels)
        let modelURL = try modelURL(for: descriptor)
        let didAccessSecurityScope = modelURL.startAccessingSecurityScopedResource()
        defer {
            if didAccessSecurityScope {
                modelURL.stopAccessingSecurityScopedResource()
            }
        }

        let model = try await CoreAILanguageModel(
            resourcesAt: modelURL,
            variant: descriptor.variant?.nilIfBlank,
            kvCacheStrategy: .auto
        )
        return LanguageModelSession(model: model)
        #else
        throw SessionFactoryError.unavailable("Core AI language model support is not linked in this build.")
        #endif
    }

    private static func modelURL(for descriptor: ModelDescriptor) throws -> URL {
        if let bookmark = descriptor.resourceBookmark {
            var isStale = false
            #if os(macOS)
            let options: URL.BookmarkResolutionOptions = [.withSecurityScope]
            #else
            let options: URL.BookmarkResolutionOptions = []
            #endif
            return try URL(
                resolvingBookmarkData: bookmark,
                options: options,
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )
        }

        if let resourcePath = descriptor.resourcePath?.nilIfBlank {
            return URL(fileURLWithPath: resourcePath, isDirectory: true)
        }

        throw SessionFactoryError.unavailable("Select a Core AI model bundle before running this model.")
    }
}

private extension String {
    var nilIfBlank: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
