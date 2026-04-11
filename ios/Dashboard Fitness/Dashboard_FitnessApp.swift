import SwiftUI
import SwiftData

@main
struct Dashboard_FitnessApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Exercise.self,
            WorkoutTemplate.self,
            TemplateExercise.self,
            WorkoutSession.self,
            ExerciseLog.self,
            SetLog.self,
            BodyWeight.self,
            ProtocolSection.self,
            ProtocolGroup.self,
            UserProtocol.self,
            ProtocolCompletion.self,
            DailyInstance.self,
            DailyTask.self,
            DocFolder.self,
            UserDocument.self,
            WorkoutCompletion.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(sharedModelContainer)
    }
}

struct RootView: View {
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        Group {
            if AuthService.shared.isAuthenticated {
                ContentView()
                    .task {
                        await SyncService.shared.syncAll(modelContext: modelContext)
                    }
            } else {
                LoginView()
            }
        }
        .animation(.easeInOut(duration: 0.3), value: AuthService.shared.isAuthenticated)
    }
}
