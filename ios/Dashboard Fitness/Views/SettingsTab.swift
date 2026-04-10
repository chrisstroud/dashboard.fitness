import SwiftUI

struct SettingsTab: View {
    var body: some View {
        NavigationStack {
            List {
                Section("Account") {
                    Label("Sign in with Apple", systemImage: "person.crop.circle")
                        .foregroundStyle(.secondary)
                }

                Section("Data") {
                    LabeledContent("Sync Status", value: "Local Only")
                    LabeledContent("Storage", value: "On Device")
                }

                Section("About") {
                    LabeledContent("Version", value: "0.1.0")
                }
            }
            .navigationTitle("Settings")
        }
    }
}

#Preview {
    SettingsTab()
}
