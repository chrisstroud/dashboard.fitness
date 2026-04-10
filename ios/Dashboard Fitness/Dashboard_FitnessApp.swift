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
            ProtocolGroup.self,
            UserProtocol.self,
            ProtocolCompletion.self,
            UserDocument.self,
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
            ContentView()
                .task {
                    let context = sharedModelContainer.mainContext
                    await SyncService.shared.syncProtocols(modelContext: context)
                }
        }
        .modelContainer(sharedModelContainer)
    }
}
