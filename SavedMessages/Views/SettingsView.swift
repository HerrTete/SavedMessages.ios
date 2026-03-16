import SwiftUI

struct SettingsView: View {
    var body: some View {
        List {
            Section {
                LabeledContent("Version", value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "–")
                LabeledContent("Build", value: Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "–")
            } header: {
                Text("App")
            }
        }
    }
}
