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

            PlaceholderToolView(title: "Benchmarks", message: "Benchmark suites and result history are next in the build plan.")
                .tabItem {
                    Text("Benchmarks")
                }

            PlaceholderToolView(title: "Settings", message: "Quotas and provider settings will live here.")
                .tabItem {
                    Text("Settings")
                }
        }
        .frame(minWidth: 980, minHeight: 680)
    }
}

private struct PlaceholderToolView: View {
    let title: String
    let message: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.largeTitle.weight(.semibold))
            Text(message)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(32)
    }
}
