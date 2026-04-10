import SwiftUI
import SwiftData

struct ContentView: View {
    var body: some View {
        TabView {
            Tab("Home", systemImage: "house") {
                HomeTab()
            }
            Tab("Docs", systemImage: "doc.text") {
                DocsTab()
            }
            Tab("Metrics", systemImage: "chart.line.uptrend.xyaxis") {
                MetricsTab()
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
            UserProtocol.self,
            WorkoutSession.self,
            BodyWeight.self,
            UserDocument.self,
        ], inMemory: true)
}
