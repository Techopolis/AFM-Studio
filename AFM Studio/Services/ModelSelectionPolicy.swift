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
}
