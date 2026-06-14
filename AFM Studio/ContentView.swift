import SwiftUI

struct ContentView: View {
    let registry: ModelRegistry
    let downloadManager: ModelDownloadManager
    let chatStore: ChatStore

    var body: some View {
        AFMStudioView(registry: registry, downloadManager: downloadManager, chatStore: chatStore)
    }
}
