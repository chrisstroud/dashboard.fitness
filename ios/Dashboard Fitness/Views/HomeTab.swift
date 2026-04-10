import SwiftUI
import SwiftData

struct HomeTab: View {
    @Query(sort: \UserProtocol.position) private var protocols: [UserProtocol]
    @Environment(\.modelContext) private var modelContext

    private var morningProtocols: [UserProtocol] {
        protocols.filter { $0.section == "morning" }
    }

    private var eveningProtocols: [UserProtocol] {
        protocols.filter { $0.section == "evening" }
    }

    private var anytimeProtocols: [UserProtocol] {
        protocols.filter { $0.section == "anytime" }
    }

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
                VStack(alignment: .leading, spacing: 0) {
                    // Date header
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Today")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)
                        Text(Date(), format: .dateTime.weekday(.wide).month(.wide).day())
                            .font(.largeTitle.bold())
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 20)

                    Divider().padding(.horizontal)

                    // Morning
                    if !morningProtocols.isEmpty {
                        DaySectionView(
                            title: "MORNING",
                            protocols: morningProtocols
                        )
                    }

                    // Workout
                    WorkoutChipSection(sessions: todaySessions)

                    // Evening
                    if !eveningProtocols.isEmpty {
                        DaySectionView(
                            title: "EVENING",
                            protocols: eveningProtocols
                        )
                    }

                    // Anytime
                    if !anytimeProtocols.isEmpty {
                        DaySectionView(
                            title: "OTHER",
                            protocols: anytimeProtocols
                        )
                    }
                }
                .padding(.vertical)
            }
            .background(Color(.systemBackground))
        }
    }
}

// MARK: - Day Section

struct DaySectionView: View {
    let title: String
    let protocols: [UserProtocol]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Section header
            HStack {
                Text(title)
                    .font(.caption.bold())
                    .foregroundStyle(.blue)
                Spacer()
                Text("Routine ›")
                    .font(.caption)
                    .foregroundStyle(.blue)
            }
            .padding(.horizontal)
            .padding(.top, 16)

            // Items from all protocols in this section
            ForEach(protocols) { proto in
                ForEach(proto.items.sorted(by: { $0.position < $1.position })) { item in
                    TaskRow(item: item)
                }
            }
        }
    }
}

// MARK: - Task Row

struct TaskRow: View {
    let item: ProtocolItem
    @Environment(\.modelContext) private var modelContext

    private var currentStatus: TaskStatus {
        item.status(on: Date())
    }

    var body: some View {
        Button(action: cycleStatus) {
            HStack(alignment: .top, spacing: 12) {
                statusIcon
                    .font(.title3)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 2) {
                    Text(item.label)
                        .font(.body)
                        .fontWeight(.medium)
                        .strikethrough(currentStatus == .completed)
                        .foregroundStyle(currentStatus == .completed ? .secondary : .primary)

                    if let subtitle = item.subtitle {
                        Text(subtitle)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                if item.documentId != nil {
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var statusIcon: some View {
        switch currentStatus {
        case .pending:
            Image(systemName: "circle")
                .foregroundStyle(.secondary)
        case .completed:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
        case .skipped:
            Image(systemName: "minus.circle.fill")
                .foregroundStyle(.orange)
        }
    }

    private func cycleStatus() {
        let calendar = Calendar.current
        let today = Date()

        let existing = item.completions.first(where: { calendar.isDate($0.date, inSameDayAs: today) })

        switch currentStatus {
        case .pending:
            let completion = ProtocolCompletion(date: today, status: "completed")
            completion.item = item
            modelContext.insert(completion)
        case .completed:
            if let existing {
                existing.status = "skipped"
                existing.completedAt = Date()
            }
        case .skipped:
            if let existing {
                modelContext.delete(existing)
            }
        }
    }
}

// MARK: - Workout Chips

struct WorkoutChipSection: View {
    let sessions: [WorkoutSession]
    @Query(sort: \WorkoutTemplate.name) private var templates: [WorkoutTemplate]
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("WORKOUT")
                    .font(.caption.bold())
                    .foregroundStyle(.blue)
                Spacer()
                Text("Program ›")
                    .font(.caption)
                    .foregroundStyle(.blue)
            }
            .padding(.horizontal)
            .padding(.top, 16)

            if !sessions.isEmpty {
                ForEach(sessions) { session in
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Text(session.template?.name ?? "Workout")
                            .font(.body)
                        Spacer()
                        if let duration = session.durationMinutes {
                            Text("\(duration)m")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 4)
                }
            }

            // Template chips
            let chipNames = [
                "Bench Day", "Squat Day", "Press Day", "Hinge Day",
                "Zone 2", "Zone 2", "Zone 2", "Zone 2", "HIIT"
            ]

            FlowLayout(spacing: 8) {
                ForEach(Array(chipNames.enumerated()), id: \.offset) { _, name in
                    Text(name)
                        .font(.subheadline)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                        )
                }
            }
            .padding(.horizontal)
        }
    }
}

// MARK: - Flow Layout

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = layout(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = layout(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y), proposal: .unspecified)
        }
    }

    private func layout(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth && x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
        }

        return (CGSize(width: maxWidth, height: y + rowHeight), positions)
    }
}

#Preview {
    HomeTab()
        .modelContainer(for: [
            UserProtocol.self,
            WorkoutSession.self,
            WorkoutTemplate.self,
        ], inMemory: true)
}
