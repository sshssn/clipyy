import Foundation

enum Constants {
    static let pollInterval: TimeInterval = 0.5
    static let maxHistoryDefault: Int = 500
    static let cardWidth: CGFloat = 120
    static let cardHeight: CGFloat = 90
    static let panelWidth: CGFloat = 780
    static let panelHeight: CGFloat = 400
    static let cardCornerRadius: CGFloat = 8
    static let cardSpacing: CGFloat = 8
    static let sectionSpacing: CGFloat = 16

    // UserDefaults keys
    static let maxHistoryKey = "maxHistory"
    static let launchAtLoginKey = "launchAtLogin"
    static let excludedAppsKey = "excludedApps"
}
