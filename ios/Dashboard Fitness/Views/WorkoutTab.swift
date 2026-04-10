import SwiftUI
import SwiftData

struct WorkoutTab: View {
    @Query(sort: \WorkoutSession.date, order: .reverse) private var sessions: [WorkoutSession]
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        NavigationStack {
            Group {
                if sessions.isEmpty {
                    ContentUnavailableView(
                        "No Workouts Yet",
                        systemImage: "dumbbell",
                        description: Text("Tap + to log your first workout")
                    )
                } else {
                    List(sessions) { session in
                        NavigationLink(value: session) {
                            SessionRow(session: session)
                        }
                    }
                    .navigationDestination(for: WorkoutSession.self) { session in
                        SessionDetailView(session: session)
                    }
                }
            }
            .navigationTitle("Workouts")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: addSession) {
                        Label("Log Workout", systemImage: "plus")
                    }
                }
            }
        }
    }

    private func addSession() {
        let session = WorkoutSession(date: Date())
        modelContext.insert(session)
    }
}

struct SessionRow: View {
    let session: WorkoutSession

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(session.date, format: .dateTime.weekday(.wide).month().day())
                .font(.headline)
            HStack(spacing: 12) {
                if let template = session.template {
                    Text(template.name)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                if let duration = session.durationMinutes {
                    Label("\(duration) min", systemImage: "clock")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if !session.exerciseLogs.isEmpty {
                    Label("\(session.exerciseLogs.count) exercises", systemImage: "figure.strengthtraining.traditional")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 2)
    }
}

struct SessionDetailView: View {
    let session: WorkoutSession

    var body: some View {
        List {
            Section("Details") {
                LabeledContent("Date", value: session.date, format: .dateTime.weekday(.wide).month().day())
                if let duration = session.durationMinutes {
                    LabeledContent("Duration", value: "\(duration) min")
                }
                if let rating = session.rating {
                    LabeledContent("Rating") {
                        HStack(spacing: 2) {
                            ForEach(1...5, id: \.self) { star in
                                Image(systemName: star <= rating ? "star.fill" : "star")
                                    .foregroundStyle(.yellow)
                                    .font(.caption)
                            }
                        }
                    }
                }
            }

            if !session.exerciseLogs.isEmpty {
                Section("Exercises") {
                    ForEach(session.exerciseLogs.sorted(by: { $0.position < $1.position })) { log in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(log.exercise?.name ?? "Unknown")
                                .font(.headline)
                            ForEach(log.sets.sorted(by: { $0.setNumber < $1.setNumber })) { set in
                                HStack {
                                    Text("Set \(set.setNumber)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Spacer()
                                    if let weight = set.weight {
                                        Text("\(Int(weight)) lbs")
                                    }
                                    if let reps = set.reps {
                                        Text("× \(reps)")
                                    }
                                }
                                .font(.subheadline)
                            }
                        }
                    }
                }
            }

            if let notes = session.notes, !notes.isEmpty {
                Section("Notes") {
                    Text(notes)
                }
            }
        }
        .navigationTitle(session.template?.name ?? "Workout")
    }
}

#Preview {
    WorkoutTab()
        .modelContainer(for: WorkoutSession.self, inMemory: true)
}
