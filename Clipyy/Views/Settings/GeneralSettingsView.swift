import SwiftUI
import ServiceManagement

struct GeneralSettingsView: View {
    @AppStorage(Constants.maxHistoryKey) private var maxHistory = Constants.maxHistoryDefault
    @AppStorage(Constants.launchAtLoginKey) private var launchAtLogin = false

    var body: some View {
        Form {
            Section {
                HStack {
                    Label("Maximum items", systemImage: "tray.full")
                    Spacer()
                    Text("\(maxHistory)")
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                        .frame(width: 50, alignment: .trailing)
                    Stepper("", value: $maxHistory, in: 50...5000, step: 50)
                        .labelsHidden()
                }
            } header: {
                Text("History")
            } footer: {
                Text("Pinned items are never automatically removed.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            Section("Startup") {
                Toggle(isOn: $launchAtLogin) {
                    Label("Launch at login", systemImage: "power")
                }
                .onChange(of: launchAtLogin) { _, newValue in
                    toggleLaunchAtLogin(newValue)
                }
            }

            Section {
                HStack {
                    Label("Open panel", systemImage: "keyboard")
                    Spacer()
                    HStack(spacing: 3) {
                        KeyCapView("Cmd")
                        KeyCapView("Shift")
                        KeyCapView("Z")
                    }
                }

                HStack {
                    Label("Close panel", systemImage: "escape")
                    Spacer()
                    KeyCapView("Esc")
                }

                HStack {
                    Label("Navigate items", systemImage: "arrow.up.arrow.down")
                    Spacer()
                    HStack(spacing: 3) {
                        KeyCapView("Up")
                        KeyCapView("Down")
                    }
                }

                HStack {
                    Label("Paste selected", systemImage: "return")
                    Spacer()
                    KeyCapView("Return")
                }
            } header: {
                Text("Keyboard Shortcuts")
            }
        }
        .formStyle(.grouped)
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

// MARK: - Key Cap

private struct KeyCapView: View {
    let label: String

    init(_ label: String) {
        self.label = label
    }

    var body: some View {
        Text(label)
            .font(.system(size: 11, weight: .medium, design: .rounded))
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 4))
            .foregroundStyle(.secondary)
    }
}
