import SwiftUI
import SwiftData

struct ContentView: View {
    var body: some View {
        TabView {
            Tab("Workouts", systemImage: "dumbbell") {
                WorkoutTab()
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
            WorkoutSession.self,
            BodyWeight.self,
        ], inMemory: true)
}
