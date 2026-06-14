import Foundation

enum RemoteModelArchiveInstallerError: LocalizedError {
    case missingModelResources(String)
    case unsafePathComponent(String)

    var errorDescription: String? {
        switch self {
        case .missingModelResources(let modelName):
            "The downloaded archive does not contain Core AI resources for \(modelName)."
        case .unsafePathComponent(let value):
            "The registry contains an unsafe path component: \(value)"
        }
    }
}

enum RemoteModelArchiveInstaller {
    static func installExtractedArchive(
        at extractedURL: URL,
        for model: RemoteModel,
        modelDirectory: URL,
        fileManager: FileManager = .default
    ) throws -> URL {
        let destination = modelDirectory
            .appendingPathComponent(try safePathComponent(model.id), isDirectory: true)
            .appendingPathComponent(try safePathComponent(model.variant), isDirectory: true)

        let source = try resourceRoot(in: extractedURL, for: model, fileManager: fileManager)
        try fileManager.createDirectory(
            at: destination.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        if fileManager.fileExists(atPath: destination.path) {
            try fileManager.removeItem(at: destination)
        }

        if source.standardizedFileURL == extractedURL.standardizedFileURL {
            try fileManager.createDirectory(at: destination, withIntermediateDirectories: true)
            for item in try visibleContents(of: source, fileManager: fileManager) {
                try fileManager.moveItem(
                    at: item,
                    to: destination.appendingPathComponent(item.lastPathComponent)
                )
            }
        } else {
            try fileManager.moveItem(at: source, to: destination)
        }

        return destination
    }

    private static func resourceRoot(
        in extractedURL: URL,
        for model: RemoteModel,
        fileManager: FileManager
    ) throws -> URL {
        let variantDirectory = extractedURL.appendingPathComponent(model.variant, isDirectory: true)
        if containsModelAsset(in: variantDirectory, model: model, fileManager: fileManager) {
            return variantDirectory
        }

        if containsModelAsset(in: extractedURL, model: model, fileManager: fileManager) {
            return extractedURL
        }

        let candidates = try visibleContents(of: extractedURL, fileManager: fileManager)
        for candidate in candidates {
            var isDirectory: ObjCBool = false
            guard fileManager.fileExists(atPath: candidate.path, isDirectory: &isDirectory),
                  isDirectory.boolValue else {
                continue
            }

            if containsModelAsset(in: candidate, model: model, fileManager: fileManager) {
                return candidate
            }
        }

        throw RemoteModelArchiveInstallerError.missingModelResources(model.name)
    }

    private static func containsModelAsset(
        in directory: URL,
        model: RemoteModel,
        fileManager: FileManager
    ) -> Bool {
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: directory.path, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            return false
        }

        let expected = directory.appendingPathComponent(model.aimodel)
        if fileManager.fileExists(atPath: expected.path) {
            return true
        }

        guard let children = try? fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return false
        }

        return children.contains { $0.pathExtension == "aimodel" || $0.pathExtension == "aimodelc" }
    }

    private static func visibleContents(
        of directory: URL,
        fileManager: FileManager
    ) throws -> [URL] {
        try fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )
        .filter { $0.lastPathComponent != "__MACOSX" }
    }

    private static func safePathComponent(_ value: String) throws -> String {
        if value.contains("/") || value.contains(":") || value == "." || value == ".." {
            throw RemoteModelArchiveInstallerError.unsafePathComponent(value)
        }
        return value
    }
}
