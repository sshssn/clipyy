import SwiftUI
import UniformTypeIdentifiers

struct ExcludedAppsView: View {
    @State private var excludedApps: [String] = []

    var body: some View {
        VStack(alignment: .leading) {
            Text("Clipboard monitoring is disabled for these apps:")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            List {
                ForEach(excludedApps, id: \.self) { app in
                    HStack {
                        Text(app)
                        Spacer()
                        Button(role: .destructive) {
                            excludedApps.removeAll { $0 == app }
                            saveApps()
                        } label: {
                            Image(systemName: "minus.circle")
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            HStack {
                Button("Add App...") {
                    addApp()
                }
                Spacer()
            }
        }
        .padding()
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
                if !excludedApps.contains(bundleID) {
                    excludedApps.append(bundleID)
                    saveApps()
                }
            }
        }
    }

    private func loadApps() {
        excludedApps = UserDefaults.standard.stringArray(
            forKey: Constants.excludedAppsKey
        ) ?? []
    }

    private func saveApps() {
        UserDefaults.standard.set(excludedApps, forKey: Constants.excludedAppsKey)
    }
}
