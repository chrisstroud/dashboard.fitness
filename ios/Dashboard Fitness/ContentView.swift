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
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [
            ProtocolGroup.self,
            WorkoutSession.self,
            WorkoutTemplate.self,
            BodyWeight.self,
            UserDocument.self,
        ], inMemory: true)
}
