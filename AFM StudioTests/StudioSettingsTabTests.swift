import Foundation

@main
struct StudioSettingsTabTests {
    static func main() throws {
        try exposesPerspectiveStyleSettingsTabs()
        try settingsModelLibraryUsesInlineActions()
        print("StudioSettingsTabTests passed")
    }

    private static func exposesPerspectiveStyleSettingsTabs() throws {
        try expect(
            StudioSettingsTab.allCases.map(\.title) == ["General", "Models", "Private Cloud", "Developer"],
            "settings should expose stable sidebar tabs"
        )

        let symbols = Dictionary(uniqueKeysWithValues: StudioSettingsTab.allCases.map { ($0, $0.systemImage) })
        try expect(symbols[.general] == "gearshape", "general tab should use the system settings symbol")
        try expect(symbols[.models] == "shippingbox", "models tab should use the model library symbol")
        try expect(symbols[.privateCloud] == "cloud", "private cloud tab should use the cloud symbol")
        try expect(symbols[.developer] == "hammer", "developer tab should use the developer symbol")

        try expect(
            StudioSettingsTab.allCases.allSatisfy { $0.accessibilityHint.isEmpty == false },
            "settings tabs should provide VoiceOver hints"
        )
    }

    private static func settingsModelLibraryUsesInlineActions() throws {
        try expect(
            ModelLibraryPresentation.standalone.showsToolbarActions,
            "standalone model library should keep toolbar actions"
        )
        try expect(
            ModelLibraryPresentation.standalone.showsInlineSettingsActions == false,
            "standalone model library should not duplicate settings rows"
        )

        try expect(
            ModelLibraryPresentation.settingsDetail.showsToolbarActions == false,
            "settings model library should hide detached toolbar actions"
        )
        try expect(
            ModelLibraryPresentation.settingsDetail.showsInlineSettingsActions,
            "settings model library should expose actions as settings rows"
        )
    }

    private static func expect(_ condition: Bool, _ message: String) throws {
        if condition == false {
            throw TestFailure(message)
        }
    }

    private struct TestFailure: Error, CustomStringConvertible {
        var description: String

        init(_ description: String) {
            self.description = description
        }
    }
}
