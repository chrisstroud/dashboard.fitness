import SwiftUI
import SwiftData

struct ContentView: View {
    var body: some View {
        TabView {
            Tab("Today", systemImage: "checkmark.square") {
                HomeTab()
            }
            Tab("Protocols", systemImage: "list.bullet.rectangle") {
                NavigationStack {
                    MasterTemplateEditor()
                }
            }
            Tab("History", systemImage: "calendar") {
                HistoryTab()
            }
            Tab("Settings", systemImage: "gear") {
                SettingsTab()
            }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [
            DailyInstance.self,
            ProtocolSection.self,
            DocFolder.self,
            UserDocument.self,
        ], inMemory: true)
}
