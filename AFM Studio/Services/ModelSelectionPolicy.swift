import Foundation

enum ModelSelectionPolicy {
    static func selectableDescriptors(from descriptors: [ModelDescriptor]) -> [ModelDescriptor] {
        descriptors.filter(\.canSend)
    }

    static func preferredModelID(
        currentModelID: String,
        descriptors: [ModelDescriptor]
    ) -> String? {
        let selectable = selectableDescriptors(from: descriptors)
        if selectable.contains(where: { $0.id == currentModelID }) {
            return currentModelID
        }
        return selectable.first?.id
    }

    static func groupedSelectableDescriptors(
        from descriptors: [ModelDescriptor]
    ) -> [(lane: ModelLane, descriptors: [ModelDescriptor])] {
        let selectable = selectableDescriptors(from: descriptors)
        return ModelLane.allCases.compactMap { lane in
            let values = selectable.filter { $0.lane == lane }
            return values.isEmpty ? nil : (lane, values)
        }
    }

    static func preferredComparisonModelIDs(
        currentModelIDs: [String],
        descriptors: [ModelDescriptor],
        preferredCount: Int = 2
    ) -> [String] {
        let selectable = selectableDescriptors(from: descriptors)
        guard selectable.isEmpty == false else {
            return []
        }

        let selectableIDs = Set(selectable.map(\.id))
        var selected: [String] = []
        var seen = Set<String>()

        for modelID in currentModelIDs where selectableIDs.contains(modelID) && seen.contains(modelID) == false {
            selected.append(modelID)
            seen.insert(modelID)
        }

        let desiredCount = min(preferredCount, selectable.count)
        for descriptor in selectable where selected.count < desiredCount {
            guard seen.contains(descriptor.id) == false else {
                continue
            }
            selected.append(descriptor.id)
            seen.insert(descriptor.id)
        }

        return selected
    }

    static func nextComparisonModelID(
        selectedModelIDs: [String],
        descriptors: [ModelDescriptor]
    ) -> String? {
        let selected = Set(selectedModelIDs)
        return selectableDescriptors(from: descriptors)
            .first { selected.contains($0.id) == false }?
            .id
    }
}
