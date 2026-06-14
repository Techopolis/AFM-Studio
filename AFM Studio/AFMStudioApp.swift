import SwiftData
import SwiftUI

@main
struct AFMStudioApp: App {
    @State private var registry: ModelRegistry
    @State private var downloadManager: ModelDownloadManager
    @State private var chatStore: ChatStore

    init() {
        let registry = ModelRegistry()
        let downloadManager = ModelDownloadManager()
        _registry = State(initialValue: registry)
        _downloadManager = State(initialValue: downloadManager)
        _chatStore = State(initialValue: ChatStore(registry: registry))
    }

    var body: some Scene {
        WindowGroup {
            ContentView(registry: registry, downloadManager: downloadManager, chatStore: chatStore)
        }
        .modelContainer(for: AFMStudioSchema.models)

        #if os(macOS)
        Settings {
            StudioSettingsView(registry: registry, downloadManager: downloadManager)
                .frame(minWidth: 620, minHeight: 520)
        }
        .modelContainer(for: AFMStudioSchema.models)
        #endif
    }
}
