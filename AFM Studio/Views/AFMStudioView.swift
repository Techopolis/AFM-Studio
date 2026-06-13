import SwiftUI

struct AFMStudioView: View {
    @State private var registry: ModelRegistry
    @State private var chatStore: ChatStore

    init() {
        let registry = ModelRegistry()
        _registry = State(initialValue: registry)
        _chatStore = State(initialValue: ChatStore(registry: registry))
    }

    var body: some View {
        TabView {
            ChatWorkspaceView(registry: registry, chatStore: chatStore)
                .tabItem {
                    Text("Chat")
                }

            ModelLibraryView(registry: registry)
                .tabItem {
                    Text("Models")
                }

            CompareView(registry: registry)
                .tabItem {
                    Text("Compare")
                }

            BenchmarkView(registry: registry)
                .tabItem {
                    Text("Benchmarks")
                }

            StudioSettingsView(registry: registry)
                .tabItem {
                    Text("Settings")
                }
        }
        .frame(minWidth: 980, minHeight: 680)
    }
}
