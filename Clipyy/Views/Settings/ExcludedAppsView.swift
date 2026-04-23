import SwiftUI
import UniformTypeIdentifiers

struct ExcludedAppsView: View {
    @State private var excludedApps: [ExcludedApp] = []

    var body: some View {
        Form {
            Section {
                if excludedApps.isEmpty {
                    HStack {
                        Spacer()
                        VStack(spacing: 6) {
                            Image(systemName: "checkmark.shield")
                                .font(.title2)
                                .foregroundStyle(.tertiary)
                            Text("No excluded apps")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Text("All apps are being monitored.")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                        .padding(.vertical, 16)
                        Spacer()
                    }
                } else {
                    ForEach(excludedApps) { app in
                        HStack(spacing: 10) {
                            if let icon = app.icon {
                                Image(nsImage: icon)
                                    .resizable()
                                    .frame(width: 24, height: 24)
                            } else {
                                Image(systemName: "app")
                                    .frame(width: 24, height: 24)
                                    .foregroundStyle(.secondary)
                            }

                            VStack(alignment: .leading, spacing: 1) {
                                Text(app.displayName)
                                    .font(.body)
                                Text(app.bundleID)
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }

                            Spacer()

                            Button {
                                excludedApps.removeAll { $0.bundleID == app.bundleID }
                                saveApps()
                            } label: {
                                Image(systemName: "minus.circle.fill")
                                    .foregroundStyle(.red)
                            }
                            .buttonStyle(.plain)
                            .help("Remove from exclusion list")
                        }
                    }
                }
            } header: {
                Text("Excluded Apps")
            } footer: {
                Text("Clipboard monitoring is paused when these apps are in the foreground.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            Section {
                Button {
                    addApp()
                } label: {
                    Label("Add Application...", systemImage: "plus.circle")
                }
            }
        }
        .formStyle(.grouped)
        .onAppear { loadApps() }
    }

    private func addApp() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.application]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.allowsMultipleSelection = false

        if panel.runModal() == .OK, let url = panel.url {
            if let bundle = Bundle(url: url),
               let bundleID = bundle.bundleIdentifier {
                guard !excludedApps.contains(where: { $0.bundleID == bundleID }) else { return }
                let name = FileManager.default.displayName(atPath: url.path)
                let icon = NSWorkspace.shared.icon(forFile: url.path)
                excludedApps.append(ExcludedApp(bundleID: bundleID, displayName: name, icon: icon))
                saveApps()
            }
        }
    }

    private func loadApps() {
        let ids = UserDefaults.standard.stringArray(forKey: Constants.excludedAppsKey) ?? []
        excludedApps = ids.map { bundleID in
            let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID)
            let name: String
            let icon: NSImage?
            if let url {
                name = FileManager.default.displayName(atPath: url.path)
                icon = NSWorkspace.shared.icon(forFile: url.path)
            } else {
                name = bundleID
                icon = nil
            }
            return ExcludedApp(bundleID: bundleID, displayName: name, icon: icon)
        }
    }

    private func saveApps() {
        UserDefaults.standard.set(excludedApps.map(\.bundleID), forKey: Constants.excludedAppsKey)
    }
}

// MARK: - Model

private struct ExcludedApp: Identifiable {
    let bundleID: String
    let displayName: String
    let icon: NSImage?
    var id: String { bundleID }
}
