import SwiftUI

struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralSettingsView()
                .tabItem {
                    Label("General", systemImage: "gear")
                }

            ExcludedAppsView()
                .tabItem {
                    Label("Excluded Apps", systemImage: "nosign")
                }
        }
        .frame(width: 450, height: 300)
    }
}
