import Foundation
import FoundationModels
import Observation

@MainActor
@Observable
final class ModelRegistry {
    private(set) var descriptors: [ModelDescriptor] = []
    private var cachedRemoteRegistry: RemoteModelRegistry?

    init() {
        refresh()
    }

    func refresh(userModels: [UserModelRecord] = [], remoteRegistry: RemoteModelRegistry? = nil) {
        if let remoteRegistry {
            cachedRemoteRegistry = remoteRegistry
        }

        var next: [ModelDescriptor] = []
        next.append(systemDescriptor())

        if #available(iOS 27.0, macOS 27.0, visionOS 27.0, watchOS 27.0, *) {
            next.append(privateCloudDescriptor())
        }

        let activeRemoteRegistry = remoteRegistry ?? cachedRemoteRegistry
        next.append(contentsOf: CoreAIModelCatalog.entries.map { entry in
            coreAICatalogDescriptor(
                for: entry,
                remoteModel: activeRemoteRegistry?.remoteModel(matching: entry)
            )
        })
        next.append(contentsOf: userModels.map(userDescriptor))
        descriptors = next
    }

    func descriptor(for id: String) -> ModelDescriptor? {
        descriptors.first { $0.id == id }
    }

    func groupedDescriptors() -> [(lane: ModelLane, descriptors: [ModelDescriptor])] {
        ModelLane.allCases.compactMap { lane in
            let values = descriptors.filter { $0.lane == lane }
            return values.isEmpty ? nil : (lane, values)
        }
    }

    private func systemDescriptor() -> ModelDescriptor {
        let model = SystemLanguageModel.default
        let status = FoundationModelStatusFormatting.systemAvailabilityText(model.availability)
        return ModelDescriptor(
            id: BuiltInModelID.appleSystem,
            displayName: "Apple System Model",
            lane: .appleSystem,
            modelID: "SystemLanguageModel.default",
            capabilities: ModelCapabilitySet(
                text: true,
                reasoning: false,
                toolCalling: false,
                guidedGeneration: false,
                vision: true
            ),
            availability: status.0,
            statusLine: status.1,
            isBuiltIn: true
        )
    }

    @available(iOS 27.0, macOS 27.0, visionOS 27.0, watchOS 27.0, *)
    private func privateCloudDescriptor() -> ModelDescriptor {
        let model = PrivateCloudComputeLanguageModel()
        let availability = FoundationModelStatusFormatting.privateCloudAvailabilityText(model.availability)
        let quota = FoundationModelStatusFormatting.privateCloudQuotaText(model.quotaUsage)
        return ModelDescriptor(
            id: BuiltInModelID.privateCloud,
            displayName: "Private Cloud Compute",
            lane: .privateCloud,
            modelID: "PrivateCloudComputeLanguageModel.default",
            capabilities: ModelCapabilitySet(
                text: true,
                reasoning: true,
                toolCalling: false,
                guidedGeneration: true,
                vision: true
            ),
            availability: availability.0,
            statusLine: availability.0 == .available ? quota : availability.1,
            isBuiltIn: true
        )
    }

    private func coreAICatalogDescriptor(
        for entry: CoreAIModelCatalogEntry,
        remoteModel: RemoteModel?
    ) -> ModelDescriptor {
        let isLinked = CoreAILanguageModelSupport.isCompiledIn
        let installedBundleURL = CoreAIModelStore.installedBundleIfAvailable(for: entry)
            ?? remoteModel.flatMap(CoreAIModelStore.installedBundleIfAvailable)
        let availability: ModelAvailabilityState
        let statusLine: String

        if isLinked == false {
            availability = .unavailable
            statusLine = CoreAILanguageModelSupport.statusLine
        } else if installedBundleURL != nil {
            availability = .experimental
            statusLine = "Installed local Core AI bundle - \(entry.source.title)"
        } else if let remoteModel {
            availability = .requiresSetup
            statusLine = "Ready to download - \(remoteModel.formattedSize)"
        } else {
            availability = .requiresSetup
            statusLine = entry.statusLine
        }

        return ModelDescriptor(
            id: entry.id,
            displayName: entry.displayName,
            lane: .coreAI,
            modelID: entry.modelID,
            catalogID: entry.id,
            catalogSource: entry.source.title,
            catalogURL: entry.modelCardURL,
            downloadURL: remoteModel?.primaryFile?.url ?? entry.downloadURL,
            exportCommand: entry.exportCommand,
            platformSummary: entry.platformSummary,
            resourcePath: installedBundleURL?.path,
            capabilities: .textOnly,
            availability: availability,
            statusLine: statusLine,
            isBuiltIn: true
        )
    }

    private func userDescriptor(for record: UserModelRecord) -> ModelDescriptor {
        let lane = ModelLane(rawValue: record.laneRawValue) ?? .coreAI
        let catalogEntry = record.catalogID.flatMap(CoreAIModelCatalog.entry)
        let hasCoreAIPath = record.resourcePath?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
        let hasCoreAIResource = record.resourceBookmark != nil || hasCoreAIPath
        let availability: ModelAvailabilityState
        let statusLine: String
        switch lane {
        case .server:
            availability = .requiresSetup
            statusLine = "Waiting for AFM provider configuration"
        case .coreAI:
            if CoreAILanguageModelSupport.isCompiledIn == false {
                availability = .requiresSetup
                statusLine = CoreAILanguageModelSupport.statusLine
            } else if hasCoreAIResource == false {
                availability = .requiresSetup
                statusLine = catalogEntry?.statusLine ?? "Select a Core AI model bundle"
            } else {
                availability = .experimental
                statusLine = "Core AI bundle ready - \(catalogEntry?.source.title ?? "Custom bundle")"
            }
        case .appleSystem, .privateCloud:
            availability = .requiresSetup
            statusLine = "Custom descriptor"
        }

        return ModelDescriptor(
            id: record.descriptorID,
            displayName: record.displayName,
            lane: lane,
            modelID: record.modelID,
            catalogID: record.catalogID,
            catalogSource: catalogEntry?.source.title,
            catalogURL: catalogEntry?.modelCardURL,
            downloadURL: catalogEntry?.downloadURL,
            exportCommand: catalogEntry?.exportCommand,
            platformSummary: catalogEntry?.platformSummary,
            resourcePath: record.resourcePath,
            resourceBookmark: record.resourceBookmark,
            variant: record.variant,
            capabilities: .textOnly,
            availability: availability,
            statusLine: statusLine,
            isBuiltIn: false
        )
    }
}

private extension RemoteModelRegistry {
    func remoteModel(matching entry: CoreAIModelCatalogEntry) -> RemoteModel? {
        models.first { remoteModel in
            remoteModel.hfModelId == entry.modelID ||
            remoteModel.id == entry.id ||
            entry.localBundlePath?.hasPrefix("\(remoteModel.id)/") == true
        }
    }
}
