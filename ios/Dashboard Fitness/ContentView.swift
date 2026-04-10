import SwiftUI
import SwiftData

struct ContentView: View {
    var body: some View {
        TabView {
            Tab("Today", systemImage: "checkmark.square") {
                HomeTab()
            }
            Tab("Docs", systemImage: "doc.text") {
                DocsTab()
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
            ProtocolGroup.self,
            DocFolder.self,
            UserDocument.self,
        ], inMemory: true)
}
