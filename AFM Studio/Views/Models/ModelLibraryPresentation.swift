import Foundation

enum ModelLibraryPresentation: Sendable {
    case standalone
    case settingsDetail

    var wrapsInNavigationStack: Bool {
        self == .standalone
    }

    var showsToolbarActions: Bool {
        self == .standalone
    }

    var showsInlineSettingsActions: Bool {
        self == .settingsDetail
    }
}
