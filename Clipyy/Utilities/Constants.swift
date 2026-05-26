import Foundation

enum Constants {
    static let pollInterval: TimeInterval = 1.0
    static let maxHistoryDefault: Int = 500
    static let panelWidth: CGFloat = 480
    static let panelHeight: CGFloat = 600
    static let rowCornerRadius: CGFloat = 8
    static let rowSpacing: CGFloat = 4
    static let sectionSpacing: CGFloat = 16
    static let itemsPerPage: Int = 25

    // UserDefaults keys
    static let maxHistoryKey = "maxHistory"
    static let launchAtLoginKey = "launchAtLogin"
    static let excludedAppsKey = "excludedApps"
}
