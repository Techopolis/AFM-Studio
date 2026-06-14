import SwiftUI

struct AFMStudioView: View {
    let registry: ModelRegistry
    let downloadManager: ModelDownloadManager
    let chatStore: ChatStore

    var body: some View {
        TabView {
            ChatWorkspaceView(registry: registry, downloadManager: downloadManager, chatStore: chatStore)
                .tabItem {
                    Label("Chat", systemImage: "bubble.left.and.text.bubble.right")
                }

            CompareView(registry: registry)
                .tabItem {
                    Label("Compare", systemImage: "rectangle.2.swap")
                }

            BenchmarkView(registry: registry)
                .tabItem {
                    Label("Benchmarks", systemImage: "speedometer")
                }

            #if !os(macOS)
            StudioSettingsView(registry: registry, downloadManager: downloadManager)
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
            #endif
        }
        .frame(minWidth: 980, minHeight: 680)
        #if os(macOS)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                SettingsLink {
                    Label("Settings", systemImage: "gearshape")
                }
                .help("Open Settings")
                .accessibilityLabel("Settings")
                .accessibilityHint("Opens AFM Studio settings")
            }
        }
        #endif
    }
}
