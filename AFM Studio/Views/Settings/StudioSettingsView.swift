import SwiftData
import SwiftUI

struct StudioSettingsView: View {
    @Query(sort: \UserModelRecord.displayName) private var userModels: [UserModelRecord]

    let registry: ModelRegistry
    let downloadManager: ModelDownloadManager

    @State private var selectedTab: StudioSettingsTab = .general

    private var privateCloudDescriptor: ModelDescriptor? {
        registry.descriptor(for: BuiltInModelID.privateCloud)
    }

    var body: some View {
        NavigationSplitView(columnVisibility: .constant(.all)) {
            sidebar
        } detail: {
            settingsDetail(for: selectedTab)
                #if os(macOS)
                .toolbar(removing: .title)
                #endif
        }
        .navigationSplitViewStyle(.balanced)
        #if os(macOS)
        .presentedWindowToolbarStyle(.unifiedCompact)
        #endif
        .onAppear {
            refreshModelStatus()
            if downloadManager.registry == nil {
                Task {
                    await refreshDownloadRegistry()
                }
            }
        }
        .onChange(of: userModels.count) { _, _ in
            refreshModelStatus()
        }
    }

    @ViewBuilder
    private var sidebar: some View {
        #if os(macOS)
        List(StudioSettingsTab.allCases, selection: $selectedTab) { tab in
            SettingsSidebarRow(tab: tab)
                .tag(tab)
        }
        .listStyle(.sidebar)
        .navigationSplitViewColumnWidth(min: 220, ideal: 220, max: 220)
        .toolbar(removing: .sidebarToggle)
        #else
        List {
            ForEach(StudioSettingsTab.allCases) { tab in
                NavigationLink(value: tab) {
                    SettingsSidebarRow(tab: tab)
                }
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("Settings")
        .navigationDestination(for: StudioSettingsTab.self) { tab in
            settingsDetail(for: tab)
        }
        #endif
    }

    @ViewBuilder
    private func settingsDetail(for tab: StudioSettingsTab) -> some View {
        switch tab {
        case .general:
            generalSettings
        case .models:
            ModelLibraryView(
                registry: registry,
                downloadManager: downloadManager,
                presentation: .settingsDetail
            )
        case .privateCloud:
            privateCloudSettings
        case .developer:
            developerSettings
        }
    }

    private var generalSettings: some View {
        Form {
            Section("Status") {
                if let systemDescriptor = registry.descriptor(for: BuiltInModelID.appleSystem) {
                    SettingsStatusRow(
                        title: systemDescriptor.displayName,
                        value: systemDescriptor.statusLine,
                        state: systemDescriptor.availability
                    )
                }

                SettingsStatusRow(
                    title: "Runnable Models",
                    value: "\(readyModelCount) of \(totalModelCount) tracked models ready",
                    state: readyModelCount > 0 ? .available : .requiresSetup
                )

                SettingsStatusRow(
                    title: "Download Registry",
                    value: registryStatusText,
                    state: registryStatusState
                )
            }

            Section("Library") {
                SettingsValueRow(
                    title: "Core AI Models",
                    value: "\(installedCoreAIModelCount) installed",
                    detail: "\(coreAIModelCount) catalog entries tracked",
                    systemImage: "cpu"
                )

                SettingsValueRow(
                    title: "User Models",
                    value: "\(userModels.count) saved",
                    detail: userModels.isEmpty ? "Add local Core AI bundles from Models" : "Custom model records available in Models",
                    systemImage: "folder"
                )
            }
        }
        .formStyle(.grouped)
        .navigationTitle(StudioSettingsTab.general.title)
    }

    private var privateCloudSettings: some View {
        Form {
            Section("Quota") {
                if let privateCloudDescriptor {
                    SettingsStatusRow(
                        title: privateCloudDescriptor.displayName,
                        value: privateCloudDescriptor.statusLine,
                        state: privateCloudDescriptor.availability
                    )
                } else {
                    SettingsStatusRow(
                        title: "Private Cloud Compute",
                        value: "Requires OS 27 support",
                        state: .unavailable
                    )
                }

                SettingsActionRow(
                    title: "Refresh Availability",
                    detail: "Updates Private Cloud Compute quota and availability",
                    systemImage: "arrow.clockwise",
                    action: refreshModelStatus
                )
            }

            Section("Entitlement") {
                if let privateCloudGuidance {
                    SettingsGuidanceRow(
                        title: "Setup Required",
                        detail: privateCloudGuidance,
                        systemImage: "exclamationmark.triangle"
                    )
                } else {
                    SettingsValueRow(
                        title: "Capability",
                        value: "Configured",
                        detail: "Private Cloud Compute reports available on this device.",
                        systemImage: "checkmark.seal"
                    )
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle(StudioSettingsTab.privateCloud.title)
    }

    private var developerSettings: some View {
        Form {
            Section("Core AI") {
                SettingsStatusRow(
                    title: "Core AI Bridge",
                    value: CoreAILanguageModelSupport.statusLine,
                    state: CoreAILanguageModelSupport.isCompiledIn ? .available : .requiresSetup
                )

                SettingsValueRow(
                    title: "Model Storage",
                    value: CoreAIModelStore.modelFolderName,
                    detail: CoreAIModelStore.modelDirectoryURL().path,
                    systemImage: "externaldrive"
                )
            }

            Section("Registry") {
                SettingsStatusRow(
                    title: "Download Registry",
                    value: registryStatusText,
                    state: registryStatusState
                )

                SettingsActionRow(
                    title: "Refresh Download Registry",
                    detail: "Downloads registry.json and updates model availability",
                    systemImage: "arrow.triangle.2.circlepath",
                    isDisabled: downloadManager.registryStatus == .refreshing
                ) {
                    Task {
                        await refreshDownloadRegistry()
                    }
                }

                SettingsValueRow(
                    title: "Registry URL",
                    value: "registry.json",
                    detail: ModelDownloadManager.defaultRegistryURL.absoluteString,
                    systemImage: "link"
                )
            }

            Section("Local Models") {
                SettingsActionRow(
                    title: "Refresh Local Model Status",
                    detail: "Checks installed Core AI bundles and saved user models",
                    systemImage: "arrow.clockwise",
                    action: refreshModelStatus
                )

                SettingsValueRow(
                    title: "User Models",
                    value: "\(userModels.count) saved",
                    detail: "Saved model records in the local AFM Studio database",
                    systemImage: "folder"
                )
            }
        }
        .formStyle(.grouped)
        .navigationTitle(StudioSettingsTab.developer.title)
    }

    private var readyModelCount: Int {
        registry.descriptors.filter(\.canSend).count
    }

    private var totalModelCount: Int {
        registry.descriptors.count
    }

    private var coreAIModelCount: Int {
        registry.descriptors.filter { $0.lane == .coreAI }.count
    }

    private var installedCoreAIModelCount: Int {
        registry.descriptors.filter { descriptor in
            descriptor.lane == .coreAI &&
            descriptor.resourcePath?.isEmpty == false &&
            descriptor.canSend
        }.count
    }

    private var privateCloudGuidance: String? {
        PrivateCloudComputeSupport.entitlementGuidance(for: privateCloudDescriptor)
    }

    private func refreshModelStatus() {
        registry.refresh(userModels: userModels, remoteRegistry: downloadManager.registry)
    }

    private func refreshDownloadRegistry() async {
        await downloadManager.refreshRegistry()
        refreshModelStatus()
    }

    private var registryStatusText: String {
        switch downloadManager.registryStatus {
        case .idle:
            "Not loaded"
        case .refreshing:
            "Refreshing registry"
        case .ready(let message):
            message
        case .failed(let message):
            "Failed: \(message)"
        }
    }

    private var registryStatusState: ModelAvailabilityState {
        switch downloadManager.registryStatus {
        case .ready:
            .available
        case .refreshing:
            .experimental
        case .idle:
            .requiresSetup
        case .failed:
            .unavailable
        }
    }
}

private struct SettingsSidebarRow: View {
    let tab: StudioSettingsTab

    var body: some View {
        Label(tab.title, systemImage: tab.systemImage)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(tab.title)
            .accessibilityHint(tab.accessibilityHint)
    }
}

private struct SettingsValueRow: View {
    let title: String
    let value: String
    let detail: String
    let systemImage: String

    var body: some View {
        LabeledContent {
            VStack(alignment: .trailing, spacing: 3) {
                Text(value)
                    .foregroundStyle(.primary)
                    .textSelection(.enabled)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .truncationMode(.middle)
                    .textSelection(.enabled)
            }
            .multilineTextAlignment(.trailing)
        } label: {
            Label {
                Text(title)
            } icon: {
                Image(systemName: systemImage)
                    .foregroundStyle(.secondary)
                    .frame(width: 20)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityValue("\(value), \(detail)")
    }
}

private struct SettingsActionRow: View {
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
        }
        .disabled(isDisabled)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityValue(detail)
        .accessibilityHint(isDisabled ? "Unavailable while the current refresh is running" : "Runs this settings action")
    }
}

private struct SettingsGuidanceRow: View {
    let title: String
    let detail: String
    let systemImage: String

    var body: some View {
        Label {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .fontWeight(.medium)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)
            }
        } icon: {
            Image(systemName: systemImage)
                .foregroundStyle(.orange)
                .frame(width: 20)
        }
        .accessibilityElement(children: .combine)
    }
}

private struct SettingsStatusRow: View {
    let title: String
    let value: String
    let state: ModelAvailabilityState

    var body: some View {
        LabeledContent {
            VStack(alignment: .trailing, spacing: 3) {
                Label(state.settingsLabel, systemImage: state.systemImage)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(statusColor)
                    .labelStyle(.titleAndIcon)
                Text(value)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .truncationMode(.middle)
                    .textSelection(.enabled)
            }
            .multilineTextAlignment(.trailing)
        } label: {
            Label {
                Text(title)
            } icon: {
                Image(systemName: state.systemImage)
                    .foregroundStyle(statusColor)
                    .frame(width: 20)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityValue("\(state.settingsLabel), \(value)")
    }

    private var statusColor: Color {
        switch state {
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

private extension ModelAvailabilityState {
    var settingsLabel: String {
        switch self {
        case .available:
            "Available"
        case .experimental:
            "Ready"
        case .requiresSetup:
            "Requires Setup"
        case .unavailable:
            "Unavailable"
        }
    }
}
