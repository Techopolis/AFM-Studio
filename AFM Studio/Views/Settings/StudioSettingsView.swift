import SwiftData
import SwiftUI

struct StudioSettingsView: View {
    @Query(sort: \UserModelRecord.displayName) private var userModels: [UserModelRecord]

    let registry: ModelRegistry

    private var privateCloudDescriptor: ModelDescriptor? {
        registry.descriptor(for: BuiltInModelID.privateCloud)
    }

    var body: some View {
        NavigationStack {
            List {
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
                }

                Section("Models") {
                    ForEach(registry.groupedDescriptors(), id: \.lane.rawValue) { group in
                        VStack(alignment: .leading, spacing: 10) {
                            Text(group.lane.title)
                                .font(.headline)
                            ForEach(group.descriptors) { descriptor in
                                SettingsStatusRow(
                                    title: descriptor.displayName,
                                    value: descriptor.statusLine,
                                    state: descriptor.availability
                                )
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }

                Section("Library") {
                    SettingsStatusRow(
                        title: "User Models",
                        value: "\(userModels.count) saved",
                        state: userModels.isEmpty ? .requiresSetup : .available
                    )
                    SettingsStatusRow(
                        title: "MLX Bridge",
                        value: MLXFoundationModelSupport.statusLine,
                        state: MLXFoundationModelSupport.isCompiledIn ? .available : .requiresSetup
                    )
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                Button("Refresh") {
                    registry.refresh(userModels: userModels)
                }
            }
            .onAppear {
                registry.refresh(userModels: userModels)
            }
            .onChange(of: userModels.count) { _, _ in
                registry.refresh(userModels: userModels)
            }
        }
    }
}

private struct SettingsStatusRow: View {
    let title: String
    let value: String
    let state: ModelAvailabilityState

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(value)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
            Spacer()
            Text(state.rawValue)
                .font(.caption.weight(.semibold))
                .foregroundStyle(statusColor)
        }
        .padding(.vertical, 4)
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
