import SwiftUI
import SwiftData

struct HomeTab: View {
    @Query(sort: \UserProtocol.position) private var protocols: [UserProtocol]
    @Environment(\.modelContext) private var modelContext

    private var todaySessions: [WorkoutSession] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today)!
        let descriptor = FetchDescriptor<WorkoutSession>(
            predicate: #Predicate { $0.date >= today && $0.date < tomorrow },
            sortBy: [SortDescriptor(\.date)]
        )
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Date header
                    Text(Date(), format: .dateTime.weekday(.wide).month(.wide).day())
                        .font(.title2.bold())
                        .padding(.horizontal)

                    // Protocol sections
                    if protocols.isEmpty {
                        ContentUnavailableView(
                            "No Protocols Yet",
                            systemImage: "checklist",
                            description: Text("Add your morning and evening routines")
                        )
                        .frame(minHeight: 200)
                    } else {
                        ForEach(protocols) { proto in
                            ProtocolSection(protocol: proto)
                        }
                    }

                    // Today's workouts
                    WorkoutSection(sessions: todaySessions)
                }
                .padding(.vertical)
            }
            .navigationTitle("Dashboard")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button(action: addWorkoutSession) {
                            Label("Log Workout", systemImage: "dumbbell")
                        }
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
        }
    }

    private func addWorkoutSession() {
        let session = WorkoutSession(date: Date())
        modelContext.insert(session)
    }
}

// MARK: - Protocol Section

struct ProtocolSection: View {
    let `protocol`: UserProtocol
    @Environment(\.modelContext) private var modelContext

    private var sortedItems: [ProtocolItem] {
        `protocol`.items.sorted { $0.position < $1.position }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(`protocol`.name)
                .font(.headline)
                .padding(.horizontal)

            VStack(spacing: 0) {
                ForEach(sortedItems) { item in
                    ProtocolItemRow(item: item)
                    if item.id != sortedItems.last?.id {
                        Divider().padding(.leading, 44)
                    }
                }
            }
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal)
        }
    }
}

struct ProtocolItemRow: View {
    let item: ProtocolItem
    @Environment(\.modelContext) private var modelContext

    private var isCompleted: Bool {
        item.isCompleted(on: Date())
    }

    var body: some View {
        Button(action: toggleCompletion) {
            HStack(spacing: 12) {
                Image(systemName: isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isCompleted ? .green : .secondary)

                Text(item.label)
                    .strikethrough(isCompleted)
                    .foregroundStyle(isCompleted ? .secondary : .primary)

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func toggleCompletion() {
        let calendar = Calendar.current
        let today = Date()

        if let existing = item.completions.first(where: { calendar.isDate($0.date, inSameDayAs: today) }) {
            modelContext.delete(existing)
        } else {
            let completion = ProtocolCompletion(date: today)
            completion.item = item
            modelContext.insert(completion)
        }
    }
}

// MARK: - Workout Section

struct WorkoutSection: View {
    let sessions: [WorkoutSession]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Workouts")
                .font(.headline)
                .padding(.horizontal)

            if sessions.isEmpty {
                HStack {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "figure.strengthtraining.traditional")
                            .font(.largeTitle)
                            .foregroundStyle(.secondary)
                        Text("No workouts logged today")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 24)
                    Spacer()
                }
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal)
            } else {
                VStack(spacing: 0) {
                    ForEach(sessions) { session in
                        NavigationLink(value: session) {
                            SessionRow(session: session)
                        }
                        if session.id != sessions.last?.id {
                            Divider().padding(.leading, 16)
                        }
                    }
                }
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal)
                .navigationDestination(for: WorkoutSession.self) { session in
                    SessionDetailView(session: session)
                }
            }
        }
    }
}

#Preview {
    HomeTab()
        .modelContainer(for: [
            UserProtocol.self,
            WorkoutSession.self,
        ], inMemory: true)
}
