import Foundation

enum DownloadedModelStore {
    static func installedBundleURL(for model: RemoteModel, modelDirectory: URL) -> URL {
        modelDirectory.appendingPathComponent(model.installedBundleRelativePath, isDirectory: true)
    }

    static func containsDownloadedModel(
        _ model: RemoteModel,
        modelDirectory: URL,
        fileManager: FileManager = .default
    ) -> Bool {
        let bundleURL = installedBundleURL(for: model, modelDirectory: modelDirectory)
        var isDirectory: ObjCBool = false
        return fileManager.fileExists(atPath: bundleURL.path, isDirectory: &isDirectory) && isDirectory.boolValue
    }

    static func deleteDownloadedModel(
        _ model: RemoteModel,
        modelDirectory: URL,
        fileManager: FileManager = .default
    ) throws {
        let bundleURL = installedBundleURL(for: model, modelDirectory: modelDirectory)
        if fileManager.fileExists(atPath: bundleURL.path) {
            try fileManager.removeItem(at: bundleURL)
        }

        let modelParentURL = bundleURL.deletingLastPathComponent()
        if try isEmptyDirectory(modelParentURL, fileManager: fileManager) {
            try fileManager.removeItem(at: modelParentURL)
        }
    }

    private static func isEmptyDirectory(_ url: URL, fileManager: FileManager) throws -> Bool {
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory), isDirectory.boolValue else {
            return false
        }

        return try fileManager.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ).isEmpty
    }
}
