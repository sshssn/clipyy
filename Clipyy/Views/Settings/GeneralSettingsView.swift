import SwiftUI
import ServiceManagement

struct GeneralSettingsView: View {
    @AppStorage(Constants.maxHistoryKey) private var maxHistory = Constants.maxHistoryDefault
    @AppStorage(Constants.launchAtLoginKey) private var launchAtLogin = false

    var body: some View {
        Form {
            Section("History") {
                Stepper(
                    "Maximum items: \(maxHistory)",
                    value: $maxHistory,
                    in: 50...5000,
                    step: 50
                )
            }

            Section("Startup") {
                Toggle("Launch at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, newValue in
                        toggleLaunchAtLogin(newValue)
                    }
            }

            Section("Keyboard Shortcut") {
                Text("Cmd + Shift + Z to open panel")
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    private func toggleLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            print("Failed to \(enabled ? "enable" : "disable") launch at login: \(error)")
        }
    }
}
