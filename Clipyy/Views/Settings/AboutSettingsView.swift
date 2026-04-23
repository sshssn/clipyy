import SwiftUI

struct AboutSettingsView: View {
    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
    }

    private var buildNumber: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
    }

    var body: some View {
        VStack(spacing: 16) {
            Spacer()

            if let icon = NSApp.applicationIconImage {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 96, height: 96)
            }

            Text("Clipyy")
                .font(.title)
                .fontWeight(.semibold)

            Text("Version \(appVersion) (\(buildNumber))")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Text("A native macOS clipboard manager.\nLightweight, fast, and private.")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)

            Divider()
                .frame(width: 200)

            HStack(spacing: 16) {
                Link(destination: URL(string: "https://github.com/sshssn/clipyy")!) {
                    Label("GitHub", systemImage: "link")
                        .font(.subheadline)
                }

                Link(destination: URL(string: "https://github.com/sshssn/clipyy/issues")!) {
                    Label("Report Issue", systemImage: "exclamationmark.bubble")
                        .font(.subheadline)
                }
            }

            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}
