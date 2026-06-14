import Accessibility
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct ModelLibraryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \UserModelRecord.displayName) private var userModels: [UserModelRecord]

    let registry: ModelRegistry
    let downloadManager: ModelDownloadManager
    var presentation: ModelLibraryPresentation = .standalone

    @State private var isAddingModel = false
    @State private var deletionCandidate: RemoteModel?
    @State private var deletionError: ModelLibraryError?
    @State private var lastAnnouncedDownloadMilestones: [String: Int] = [:]

    var body: some View {
        Group {
            if presentation.wrapsInNavigationStack {
                NavigationStack {
                    content
                }
            } else {
                content
            }
        }
    }

    private var content: some View {
        Group {
            List {
                if presentation.showsInlineSettingsActions {
                    modelLibraryActionsSection
                }

                ForEach(registry.groupedDescriptors(), id: \.lane.rawValue) { group in
                    Section {
                        ForEach(group.descriptors) { descriptor in
                            let remoteModel = downloadManager.remoteModel(for: descriptor)
                            let isDownloaded = remoteModel.map(downloadManager.isDownloaded) ?? false
                            ModelDescriptorRow(
                                descriptor: descriptor,
                                remoteModel: remoteModel,
                                downloadStatus: remoteModel.map { downloadManager.status(for: $0.id) } ?? .idle,
                                isDownloaded: isDownloaded,
                                downloadAction: {
                                    guard let remoteModel else { return }
                                    Task {
                                        await downloadManager.download(remoteModel)
                                        registry.refresh(
                                            userModels: userModels,
                                            remoteRegistry: downloadManager.registry
                                        )
                                    }
                                },
                                cancelAction: {
                                    guard let remoteModel else { return }
                                    downloadManager.cancelDownload(for: remoteModel.id)
                                },
                                deleteAction: {
                                    guard let remoteModel else { return }
                                    deletionCandidate = remoteModel
                                }
                            )
                        }
                    } header: {
                        Label(group.lane.title, systemImage: group.lane.systemImage)
                    }
                }
            }
            .navigationTitle("Models")
            .toolbar {
                if presentation.showsToolbarActions {
                    ToolbarItemGroup {
                        Button {
                            refreshModels()
                        } label: {
                            Label("Refresh", systemImage: "arrow.clockwise")
                        }
                        .help("Refresh Models")
                        .accessibilityHint("Updates model availability and installed bundle status")

                        Button {
                            Task {
                                await refreshDownloadRegistry()
                            }
                        } label: {
                            Label("Refresh Registry", systemImage: "arrow.triangle.2.circlepath")
                        }
                        .disabled(downloadManager.registryStatus == .refreshing)
                        .help("Refresh Download Registry")
                        .accessibilityHint("Downloads the latest AFM Studio model registry")

                        Button {
                            showAddModelSheet()
                        } label: {
                            Label("Add Model", systemImage: "plus")
                        }
                        .help("Add Model")
                    }
                }
            }
            .sheet(isPresented: $isAddingModel) {
                AddModelSheet()
            }
            .confirmationDialog(
                "Delete Downloaded Model?",
                isPresented: Binding(
                    get: { deletionCandidate != nil },
                    set: { isPresented in
                        if isPresented == false {
                            deletionCandidate = nil
                        }
                    }
                ),
                titleVisibility: .visible,
                presenting: deletionCandidate
            ) { remoteModel in
                Button("Delete \(remoteModel.name)", role: .destructive) {
                    deleteDownloadedModel(remoteModel)
                }
                Button("Cancel", role: .cancel) {
                    deletionCandidate = nil
                }
            } message: { remoteModel in
                Text("This removes \(remoteModel.name) from local AFM Studio storage. You can download it again from the registry.")
            }
            .alert(item: $deletionError) { error in
                Alert(
                    title: Text("Could Not Delete Model"),
                    message: Text(error.message),
                    dismissButton: .default(Text("OK"))
                )
            }
            .onAppear {
                refreshModels()
                if downloadManager.registry == nil {
                    Task {
                        await refreshDownloadRegistry()
                    }
                }
            }
            .onChange(of: userModels.count) { _, _ in
                refreshModels()
            }
            .onChange(of: downloadManager.downloadStatuses) { _, statuses in
                announceDownloadMilestones(statuses)
            }
        }
    }

    private var modelLibraryActionsSection: some View {
        Section("Model Library") {
            ModelLibraryActionRow(
                title: "Refresh Model Status",
                detail: "Checks installed Core AI bundles and saved user models",
                systemImage: "arrow.clockwise",
                action: refreshModels
            )

            ModelLibraryActionRow(
                title: "Refresh Download Registry",
                detail: "Downloads registry.json and updates model availability",
                systemImage: "arrow.triangle.2.circlepath",
                isDisabled: downloadManager.registryStatus == .refreshing
            ) {
                Task {
                    await refreshDownloadRegistry()
                }
            }

            ModelLibraryActionRow(
                title: "Add Local Model",
                detail: "Adds a local Core AI bundle or server provider record",
                systemImage: "plus",
                action: showAddModelSheet
            )
        }
    }

    private func refreshModels() {
        registry.refresh(userModels: userModels, remoteRegistry: downloadManager.registry)
    }

    private func refreshDownloadRegistry() async {
        await downloadManager.refreshRegistry()
        refreshModels()
    }

    private func showAddModelSheet() {
        isAddingModel = true
    }

    private func deleteDownloadedModel(_ remoteModel: RemoteModel) {
        deletionCandidate = nil

        do {
            try downloadManager.deleteDownloadedModel(remoteModel)
            registry.refresh(userModels: userModels, remoteRegistry: downloadManager.registry)
            AccessibilityNotification.Announcement("\(remoteModel.name) deleted").post()
        } catch {
            let message = error.localizedDescription
            deletionError = ModelLibraryError(message: message)
            AccessibilityNotification.Announcement("Could not delete \(remoteModel.name). \(message)").post()
        }
    }

    private func announceDownloadMilestones(_ statuses: [String: ModelDownloadStatus]) {
        for (modelID, status) in statuses {
            switch status {
            case .downloading(let progress, _, _):
                let percent = Int(progress * 100)
                let milestone = (percent / 25) * 25
                if milestone > 0, milestone > (lastAnnouncedDownloadMilestones[modelID] ?? 0) {
                    lastAnnouncedDownloadMilestones[modelID] = milestone
                    AccessibilityNotification.Announcement("Model download \(milestone) percent").post()
                }
            case .installed:
                lastAnnouncedDownloadMilestones[modelID] = nil
                AccessibilityNotification.Announcement("Model installed").post()
            case .failed(let message):
                lastAnnouncedDownloadMilestones[modelID] = nil
                AccessibilityNotification.Announcement("Download failed. \(message)").post()
            case .idle, .installing:
                break
            }
        }
    }
}

private struct ModelLibraryActionRow: View {
    let title: String
    let detail: String
    let systemImage: String
    var isDisabled = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label {
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .foregroundStyle(.primary)
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            } icon: {
                Image(systemName: systemImage)
                    .frame(width: 20)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
        .disabled(isDisabled)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityValue(detail)
        .accessibilityHint(isDisabled ? "Unavailable while the current refresh is running" : "Runs this model library action")
    }
}

private struct ModelDescriptorRow: View {
    let descriptor: ModelDescriptor
    let remoteModel: RemoteModel?
    let downloadStatus: ModelDownloadStatus
    let isDownloaded: Bool
    let downloadAction: () -> Void
    let cancelAction: () -> Void
    let deleteAction: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: descriptor.lane.systemImage)
                .font(.title3)
                .foregroundStyle(.secondary)
                .frame(width: 24)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline) {
                    Text(descriptor.displayName)
                        .font(.headline)
                    Spacer()
                    Label(descriptor.availability.rawValue, systemImage: descriptor.availability.systemImage)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(statusColor)
                        .labelStyle(.titleAndIcon)
                }

                Text(descriptor.modelID)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)

                Text(descriptor.statusLine)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if let catalogSource = descriptor.catalogSource {
                    Text(catalogSource)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                if let platformSummary = descriptor.platformSummary {
                    Text("Platforms: \(platformSummary)")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }

                if let downloadURL = descriptor.downloadURL {
                    Text(downloadURL.absoluteString)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .textSelection(.enabled)
                } else if let exportCommand = descriptor.exportCommand {
                    Text(exportCommand)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .textSelection(.enabled)
                }

                if let resourcePath = descriptor.resourcePath, resourcePath.isEmpty == false {
                    Text(resourcePath)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .textSelection(.enabled)
                }

                if let remoteModel {
                    HStack(spacing: 10) {
                        Label(remoteModel.formattedSize, systemImage: "externaldrive.badge.icloud")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .accessibilityLabel("Download size \(remoteModel.formattedSize)")

                        Spacer(minLength: 12)

                        ModelDownloadControl(
                            descriptor: descriptor,
                            remoteModel: remoteModel,
                            status: downloadStatus,
                            isDownloaded: isDownloaded,
                            downloadAction: downloadAction,
                            cancelAction: cancelAction,
                            deleteAction: deleteAction
                        )
                    }
                } else if descriptor.hasDownloadReference, let downloadURL = descriptor.downloadURL {
                    HStack {
                        Spacer()
                        Link(destination: downloadURL) {
                            Label("Open Download", systemImage: "arrow.down.circle")
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .accessibilityLabel("Open \(descriptor.displayName) download")
                        .accessibilityHint("Opens the external Core AI model download page")
                    }
                }
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(descriptor.displayName)
        .accessibilityValue(accessibilityValue)
    }

    private var accessibilityValue: String {
        var value = "\(descriptor.lane.title), \(descriptor.availability.rawValue), \(descriptor.statusLine)"
        if let remoteModel {
            value += ", download size \(remoteModel.formattedSize)"
        } else if descriptor.hasDownloadReference {
            value += ", external download available"
        }

        switch downloadStatus {
        case .downloading(let progress, _, _):
            value += ", downloading \(Int(progress * 100)) percent"
        case .installing:
            value += ", installing"
        case .installed:
            value += ", installed"
        case .failed(let message):
            value += ", download failed, \(message)"
        case .idle:
            if descriptor.resourcePath?.isEmpty == false {
                value += ", installed"
            }
            break
        }

        return value
    }

    private var statusColor: Color {
        switch descriptor.availability {
        case .available:
            .green
        case .experimental:
            .blue
        case .requiresSetup:
            .orange
        case .unavailable:
            .red
        }
    }
}

private struct ModelDownloadControl: View {
    let descriptor: ModelDescriptor
    let remoteModel: RemoteModel
    let status: ModelDownloadStatus
    let isDownloaded: Bool
    let downloadAction: () -> Void
    let cancelAction: () -> Void
    let deleteAction: () -> Void

    var body: some View {
        switch status {
        case .downloading(let progress, _, _):
            Button(action: cancelAction) {
                ZStack {
                    Circle()
                        .stroke(Color.blue.opacity(0.2), lineWidth: 3)
                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(Color.blue, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    Image(systemName: "stop.fill")
                        .font(.system(size: 8))
                        .foregroundStyle(.blue)
                }
                .frame(width: 26, height: 26)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Cancel \(remoteModel.name) download")
            .accessibilityValue("\(Int(progress * 100)) percent")
            .accessibilityHint("Stops the current model download")
        case .installing:
            HStack(spacing: 6) {
                ProgressView()
                    .controlSize(.small)
                    .accessibilityHidden(true)
                Text("Installing")
                    .font(.caption)
                    .foregroundStyle(.blue)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Installing \(remoteModel.name)")
        case .failed(let message):
            Button(action: downloadAction) {
                Label("Retry", systemImage: "arrow.clockwise")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
                .accessibilityLabel("Retry \(remoteModel.name) download")
                .accessibilityHint(message)
        case .installed:
            installedControl(canDelete: true)
        case .idle:
            if descriptor.resourcePath?.isEmpty == false {
                installedControl(canDelete: isDownloaded)
            } else {
                Button(action: downloadAction) {
                    Label("Download", systemImage: "icloud.and.arrow.down")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .accessibilityLabel("Download \(remoteModel.name)")
                .accessibilityValue(remoteModel.formattedSize)
            }
        }
    }

    private func installedControl(canDelete: Bool) -> some View {
        HStack(spacing: 8) {
            Label("Installed", systemImage: "checkmark.circle.fill")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.green)
                .accessibilityLabel("\(remoteModel.name) installed")

            if canDelete {
                Button(action: deleteAction) {
                    Image(systemName: "trash")
                }
                .buttonStyle(.borderless)
                .controlSize(.small)
                .help("Delete Downloaded Model")
                .accessibilityLabel("Delete \(remoteModel.name)")
                .accessibilityHint("Removes the downloaded model from local storage")
            }
        }
    }
}

private struct ModelLibraryError: Identifiable {
    let id = UUID()
    let message: String
}

private struct AddModelSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var displayName = ""
    @State private var modelID = ""
    @State private var lane: ModelLane = .coreAI
    @State private var resourcePath: String?
    @State private var resourceBookmark: Data?
    @State private var variant = ""
    @State private var isShowingCoreAIImporter = false
    @State private var bundleErrorMessage: String?
    @State private var selectedCatalogID = BuiltInModelID.gemma4E2BCoreAI

    private let customCoreAICatalogID = "coreai.custom"

    private var selectedCatalogEntry: CoreAIModelCatalogEntry? {
        if selectedCatalogID == customCoreAICatalogID {
            return nil
        }
        return CoreAIModelCatalog.entry(id: selectedCatalogID)
    }

    private var canAdd: Bool {
        if trimmedDisplayName.isEmpty {
            return false
        }

        if lane == .coreAI {
            return resourcePath?.isEmpty == false && resourceBookmark != nil
        }

        return trimmedModelID.isEmpty == false
    }

    private var trimmedDisplayName: String {
        displayName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var trimmedModelID: String {
        modelID.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var trimmedVariant: String? {
        let value = variant.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }

    private var selectedBundleName: String {
        guard let resourcePath, resourcePath.isEmpty == false else {
            return "No bundle selected"
        }
        return URL(fileURLWithPath: resourcePath).lastPathComponent
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Model") {
                    TextField("Display Name", text: $displayName)
                    TextField("Model ID", text: $modelID)
                    Picker("Lane", selection: $lane) {
                        Text("Core AI").tag(ModelLane.coreAI)
                        Text("Server Provider").tag(ModelLane.server)
                    }
                }

                if lane == .coreAI {
                    Section("Core AI Preset") {
                        Picker("Preset", selection: $selectedCatalogID) {
                            ForEach(CoreAIModelCatalog.entries) { entry in
                                Text(entry.displayName).tag(entry.id)
                            }
                            Text("Custom Core AI Bundle").tag(customCoreAICatalogID)
                        }

                        if let selectedCatalogEntry {
                            Text(selectedCatalogEntry.source.title)
                                .foregroundStyle(.secondary)
                            Text("Model: \(selectedCatalogEntry.modelID)")
                                .foregroundStyle(.secondary)
                                .textSelection(.enabled)
                            Text("Platforms: \(selectedCatalogEntry.platformSummary)")
                                .foregroundStyle(.secondary)

                            if let downloadURL = selectedCatalogEntry.downloadURL {
                                Text(downloadURL.absoluteString)
                                    .foregroundStyle(.secondary)
                                    .textSelection(.enabled)
                            }

                            Text(selectedCatalogEntry.exportCommand)
                                .foregroundStyle(.secondary)
                                .textSelection(.enabled)
                        } else {
                            Text("Custom Core AI bundle")
                                .foregroundStyle(.secondary)
                        }
                    }

                    Section("Core AI Bundle") {
                        HStack {
                            Text(selectedBundleName)
                                .foregroundStyle(resourcePath == nil ? .secondary : .primary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                            Spacer()
                            Button {
                                isShowingCoreAIImporter = true
                            } label: {
                                Label("Choose Bundle", systemImage: "folder")
                            }
                            .accessibilityHint("Choose an exported Core AI model bundle")
                        }

                        TextField("Variant", text: $variant)

                        if let bundleErrorMessage {
                            Text(bundleErrorMessage)
                                .foregroundStyle(.red)
                        }
                    }
                }

                Section("Status") {
                    Text(statusText)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Add Model")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Label("Cancel", systemImage: "xmark")
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        addModel()
                    } label: {
                        Label("Add", systemImage: "plus")
                    }
                    .disabled(canAdd == false)
                }
            }
            .fileImporter(
                isPresented: $isShowingCoreAIImporter,
                allowedContentTypes: [.folder],
                allowsMultipleSelection: false,
                onCompletion: handleBundleImport
            )
            .onChange(of: lane) { _, newValue in
                if newValue == .coreAI {
                    applySelectedCatalogEntry()
                }
            }
            .onChange(of: selectedCatalogID) { _, _ in
                applySelectedCatalogEntry()
            }
            .onAppear {
                applySelectedCatalogEntry()
            }
        }
        #if os(macOS)
        .frame(width: 560, height: 620)
        #endif
    }

    private var statusText: String {
        switch lane {
        case .coreAI:
            guard CoreAILanguageModelSupport.isCompiledIn else {
                return CoreAILanguageModelSupport.statusLine
            }
            return selectedCatalogEntry?.statusLine ?? "Custom Core AI bundle will run through FoundationModels."
        case .server:
            return "Server provider records are saved for AFM provider setup."
        case .appleSystem, .privateCloud:
            return "System models are managed by Apple."
        }
    }

    private func addModel() {
        let record = UserModelRecord(
            descriptorID: "user.\(UUID().uuidString)",
            displayName: trimmedDisplayName,
            laneRawValue: lane.rawValue,
            modelID: savedModelID,
            catalogID: selectedCatalogEntry?.id,
            resourcePath: resourcePath,
            resourceBookmark: resourceBookmark,
            variant: trimmedVariant
        )
        modelContext.insert(record)
        try? modelContext.save()
        dismiss()
    }

    private var savedModelID: String {
        if trimmedModelID.isEmpty, let resourcePath {
            return URL(fileURLWithPath: resourcePath).lastPathComponent
        }
        return trimmedModelID
    }

    private func applySelectedCatalogEntry() {
        guard lane == .coreAI, let selectedCatalogEntry else {
            return
        }

        displayName = selectedCatalogEntry.displayName
        modelID = selectedCatalogEntry.modelID
    }

    private func handleBundleImport(_ result: Result<[URL], any Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else {
                return
            }
            selectBundle(at: url)
        case .failure(let error):
            bundleErrorMessage = error.localizedDescription
        }
    }

    private func selectBundle(at url: URL) {
        let didAccessSecurityScope = url.startAccessingSecurityScopedResource()
        defer {
            if didAccessSecurityScope {
                url.stopAccessingSecurityScopedResource()
            }
        }

        do {
            #if os(macOS)
            let bookmarkOptions: URL.BookmarkCreationOptions = [.withSecurityScope]
            #else
            let bookmarkOptions: URL.BookmarkCreationOptions = []
            #endif
            let bookmark = try url.bookmarkData(
                options: bookmarkOptions,
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
            resourcePath = url.path
            resourceBookmark = bookmark
            bundleErrorMessage = nil

            if trimmedDisplayName.isEmpty {
                displayName = url.deletingPathExtension().lastPathComponent
            }

            if trimmedModelID.isEmpty {
                modelID = url.lastPathComponent
            }
        } catch {
            bundleErrorMessage = error.localizedDescription
        }
    }
}
