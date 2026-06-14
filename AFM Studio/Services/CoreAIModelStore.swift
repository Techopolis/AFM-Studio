import Foundation

enum CoreAIModelStore {
    static let appSupportFolderName = "AFM Studio"
    static let modelFolderName = "CoreAIModels"
    static let sandboxBundleIdentifier = "online.techopolis.afmstudio"

    static func installedBundleURL(
        for entry: CoreAIModelCatalogEntry,
        applicationSupportDirectory: URL? = nil
    ) -> URL {
        let localBundlePath = entry.localBundlePath ?? entry.id
        return modelDirectoryURL(applicationSupportDirectory: applicationSupportDirectory)
            .appendingPathComponent(localBundlePath, isDirectory: true)
    }

    static func installedBundleURL(
        for remoteModel: RemoteModel,
        applicationSupportDirectory: URL? = nil
    ) -> URL {
        modelDirectoryURL(applicationSupportDirectory: applicationSupportDirectory)
            .appendingPathComponent(remoteModel.installedBundleRelativePath, isDirectory: true)
    }

    static func applicationSupportRoot(applicationSupportDirectory: URL? = nil) -> URL {
        let baseURL = applicationSupportDirectory ?? defaultApplicationSupportDirectory
        return baseURL.appendingPathComponent(appSupportFolderName, isDirectory: true)
    }

    static func modelDirectoryURL(applicationSupportDirectory: URL? = nil) -> URL {
        applicationSupportRoot(applicationSupportDirectory: applicationSupportDirectory)
            .appendingPathComponent(modelFolderName, isDirectory: true)
    }

    static func installedBundleIfAvailable(for entry: CoreAIModelCatalogEntry) -> URL? {
        guard entry.localBundlePath != nil else {
            return nil
        }

        for applicationSupportDirectory in applicationSupportDirectories {
            let url = installedBundleURL(
                for: entry,
                applicationSupportDirectory: applicationSupportDirectory
            )
            var isDirectory: ObjCBool = false
            if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory),
               isDirectory.boolValue {
                return url
            }
        }

        return nil
    }

    static func installedBundleIfAvailable(for remoteModel: RemoteModel) -> URL? {
        for applicationSupportDirectory in applicationSupportDirectories {
            let url = installedBundleURL(
                for: remoteModel,
                applicationSupportDirectory: applicationSupportDirectory
            )
            var isDirectory: ObjCBool = false
            if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory),
               isDirectory.boolValue {
                return url
            }
        }

        return nil
    }

    static var defaultApplicationSupportDirectory: URL {
        if let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            return directory
        }

        #if os(macOS)
        return FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support", isDirectory: true)
        #else
        return FileManager.default.temporaryDirectory
            .appendingPathComponent("Application Support", isDirectory: true)
        #endif
    }

    private static var applicationSupportDirectories: [URL] {
        var directories = [defaultApplicationSupportDirectory]

        #if os(macOS)
        let sandboxDirectory = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Containers", isDirectory: true)
            .appendingPathComponent(sandboxBundleIdentifier, isDirectory: true)
            .appendingPathComponent("Data/Library/Application Support", isDirectory: true)

        if directories.contains(sandboxDirectory) == false {
            directories.append(sandboxDirectory)
        }
        #endif

        return directories
    }
}
