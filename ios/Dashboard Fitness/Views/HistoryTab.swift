import SwiftUI
import SwiftData

struct HistoryTab: View {
    @Query(sort: \ProtocolCompletion.date, order: .reverse) private var allCompletions: [ProtocolCompletion]
    @Query(sort: \WorkoutSession.date, order: .reverse) private var allSessions: [WorkoutSession]

    private var activeDates: [Date] {
        let calendar = Calendar.current
        var dates = Set<Date>()
        for c in allCompletions {
            dates.insert(calendar.startOfDay(for: c.date))
        }
        for s in allSessions {
            dates.insert(calendar.startOfDay(for: s.date))
        }
        return dates.sorted(by: >)
    }

    var body: some View {
        NavigationStack {
            Group {
                if activeDates.isEmpty {
                    ContentUnavailableView(
                        "No History",
                        systemImage: "calendar",
                        description: Text("Complete tasks on the Today tab to build your history")
                    )
                } else {
                    List(activeDates, id: \.self) { date in
                        NavigationLink(value: date) {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(date, format: .dateTime.weekday(.wide).month().day())
                                        .font(.body.bold())
                                    Text(daySummary(for: date))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                            }
                        }
                    }
                    .navigationDestination(for: Date.self) { date in
                        DayDetailView(date: date)
                    }
                }
            }
            .navigationTitle("History")
        }
    }

    private func daySummary(for date: Date) -> String {
        let calendar = Calendar.current
        let completedCount = allCompletions.filter {
            calendar.isDate($0.date, inSameDayAs: date) && $0.status == "completed"
        }.count
        let skippedCount = allCompletions.filter {
            calendar.isDate($0.date, inSameDayAs: date) && $0.status == "skipped"
        }.count
        let sessionCount = allSessions.filter {
            calendar.isDate($0.date, inSameDayAs: date)
        }.count

        var parts: [String] = []
        if completedCount > 0 { parts.append("\(completedCount) done") }
        if skippedCount > 0 { parts.append("\(skippedCount) skipped") }
        if sessionCount > 0 { parts.append("\(sessionCount) workout\(sessionCount == 1 ? "" : "s")") }
        return parts.joined(separator: " · ")
    }
}

struct DayDetailView: View {
    let date: Date
    @Query private var allCompletions: [ProtocolCompletion]
    @Query private var allSessions: [WorkoutSession]

    private var dayCompletions: [ProtocolCompletion] {
        let calendar = Calendar.current
        return allCompletions.filter { calendar.isDate($0.date, inSameDayAs: date) }
    }

    private var daySessions: [WorkoutSession] {
        let calendar = Calendar.current
        return allSessions.filter { calendar.isDate($0.date, inSameDayAs: date) }
    }

    var body: some View {
        List {
            if !dayCompletions.isEmpty {
                Section("Tasks") {
                    ForEach(dayCompletions) { completion in
                        HStack(spacing: 10) {
                            Image(systemName: completion.status == "completed" ? "checkmark.circle.fill" : "minus.circle.fill")
                                .foregroundStyle(completion.status == "completed" ? .green : .orange)
                            Text(completion.item?.label ?? "Unknown")
                            Spacer()
                            Text(completion.status.capitalized)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            if !daySessions.isEmpty {
                Section("Workouts") {
                    ForEach(daySessions) { session in
                        HStack {
                            Text(session.template?.name ?? "Workout")
                                .font(.body)
                            Spacer()
                            if let duration = session.durationMinutes {
                                Text("\(duration) min")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle(date.formatted(.dateTime.weekday(.wide).month().day()))
    }
}

#Preview {
    HistoryTab()
        .modelContainer(for: [
            ProtocolCompletion.self,
            WorkoutSession.self,
        ], inMemory: true)
}
