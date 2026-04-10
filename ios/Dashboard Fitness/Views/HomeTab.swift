import SwiftUI
import SwiftData

struct HomeTab: View {
    @Query(sort: \ProtocolGroup.position) private var groups: [ProtocolGroup]
    @Environment(\.modelContext) private var modelContext

    private var morningGroups: [ProtocolGroup] {
        groups.filter { $0.section == "morning" }
    }
    private var eveningGroups: [ProtocolGroup] {
        groups.filter { $0.section == "evening" }
    }
    private var anytimeGroups: [ProtocolGroup] {
        groups.filter { $0.section == "anytime" }
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
                    .padding(.bottom, 16)

                    // Morning
                    if !morningGroups.isEmpty {
                        SectionHeader(title: "MORNING", groups: morningGroups)
                        ForEach(morningGroups) { group in
                            GroupView(group: group)
                        }
                    }

                    // Workout chips
                    WorkoutChipSection(sessions: todaySessions)

                    // Evening
                    if !eveningGroups.isEmpty {
                        SectionHeader(title: "EVENING", groups: eveningGroups)
                        ForEach(eveningGroups) { group in
                            GroupView(group: group)
                        }
                    }

                    // Anytime
                    if !anytimeGroups.isEmpty {
                        SectionHeader(title: "OTHER", groups: anytimeGroups)
                        ForEach(anytimeGroups) { group in
                            GroupView(group: group)
                        }
                    }
                }
                .padding(.vertical)
            }
            .navigationDestination(for: UUID.self) { docId in
                LinkedDocView(documentId: docId)
            }
        }
    }
}

// MARK: - Linked Document View (lookup by ID)

struct LinkedDocView: View {
    let documentId: UUID
    @Query private var allDocs: [UserDocument]

    private var document: UserDocument? {
        allDocs.first { $0.id == documentId }
    }

    var body: some View {
        if let doc = document {
            ScrollView {
                if doc.content.isEmpty {
                    Text("No content yet.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .padding()
                } else {
                    MarkdownView(content: doc.content)
                        .padding()
                }
            }
            .navigationTitle(doc.title)
            .navigationBarTitleDisplayMode(.inline)
        } else {
            ContentUnavailableView(
                "Document Not Found",
                systemImage: "doc.questionmark",
                description: Text("This document may not have synced yet")
            )
        }
    }
}

// MARK: - Section Header (with bulk complete)

struct SectionHeader: View {
    let title: String
    let groups: [ProtocolGroup]
    @Environment(\.modelContext) private var modelContext

    private var allProtocols: [UserProtocol] {
        groups.flatMap(\.protocols)
    }

    private var allCompleted: Bool {
        !allProtocols.isEmpty && allProtocols.allSatisfy { $0.status(on: Date()) == .completed }
    }

    private var completedCount: Int {
        allProtocols.filter { $0.status(on: Date()) == .completed }.count
    }

    var body: some View {
        HStack(alignment: .center) {
            Text(title)
                .font(.caption.bold())
                .foregroundStyle(.blue)

            if !allProtocols.isEmpty {
                Text("\(completedCount)/\(allProtocols.count)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button(action: toggleSection) {
                Image(systemName: allCompleted ? "checkmark.circle.fill" : "checkmark.circle")
                    .foregroundStyle(allCompleted ? .green : .secondary)
                    .font(.body)
            }
        }
        .padding(.horizontal)
        .padding(.top, 20)
        .padding(.bottom, 4)
    }

    private func toggleSection() {
        let today = Date()
        let calendar = Calendar.current

        if allCompleted {
            // Clear all
            for proto in allProtocols {
                if let existing = proto.completions.first(where: { calendar.isDate($0.date, inSameDayAs: today) }) {
                    modelContext.delete(existing)
                }
            }
        } else {
            // Complete all
            for proto in allProtocols where proto.status(on: today) != .completed {
                let existing = proto.completions.first(where: { calendar.isDate($0.date, inSameDayAs: today) })
                if let existing {
                    existing.status = "completed"
                    existing.completedAt = Date()
                } else {
                    let completion = ProtocolCompletion(date: today, status: "completed")
                    completion.protocol = proto
                    modelContext.insert(completion)
                }
            }
        }
    }
}

// MARK: - Group View (with group-level complete)

struct GroupView: View {
    let group: ProtocolGroup
    @Environment(\.modelContext) private var modelContext

    private var allCompleted: Bool {
        group.allCompleted(on: Date())
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Group header
            HStack {
                Text(group.name)
                    .font(.subheadline.bold())
                    .foregroundStyle(.primary)

                Text("\(group.completedCount(on: Date()))/\(group.protocols.count)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                Spacer()

                Button(action: toggleGroup) {
                    Image(systemName: allCompleted ? "checkmark.circle.fill" : "checkmark.circle")
                        .foregroundStyle(allCompleted ? .green : .secondary)
                        .font(.callout)
                }
            }
            .padding(.horizontal)
            .padding(.top, 10)
            .padding(.bottom, 4)

            // Protocol items
            ForEach(group.sortedProtocols) { proto in
                ProtocolRow(proto: proto)
            }
        }
    }

    private func toggleGroup() {
        let today = Date()
        let calendar = Calendar.current

        if allCompleted {
            for proto in group.protocols {
                if let existing = proto.completions.first(where: { calendar.isDate($0.date, inSameDayAs: today) }) {
                    modelContext.delete(existing)
                }
            }
        } else {
            for proto in group.protocols where proto.status(on: today) != .completed {
                let existing = proto.completions.first(where: { calendar.isDate($0.date, inSameDayAs: today) })
                if let existing {
                    existing.status = "completed"
                    existing.completedAt = Date()
                } else {
                    let completion = ProtocolCompletion(date: today, status: "completed")
                    completion.protocol = proto
                    modelContext.insert(completion)
                }
            }
        }
    }
}

// MARK: - Protocol Row (atomic unit)

struct ProtocolRow: View {
    let proto: UserProtocol
    @Environment(\.modelContext) private var modelContext

    private var currentStatus: TaskStatus {
        proto.status(on: Date())
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Button(action: cycleStatus) {
                statusIcon
                    .font(.body)
                    .frame(width: 22)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 1) {
                Text(proto.label)
                    .font(.subheadline)
                    .strikethrough(currentStatus == .completed)
                    .foregroundStyle(currentStatus == .completed ? .secondary : .primary)

                if let subtitle = proto.subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer()

            if proto.documentId != nil {
                NavigationLink(value: proto.documentId!) {
                    Image(systemName: "doc.text")
                        .font(.caption)
                        .foregroundStyle(.blue)
                }
            }
        }
        .padding(.horizontal)
        .padding(.leading, 8)
        .padding(.vertical, 5)
        .contentShape(Rectangle())
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
        let existing = proto.completions.first(where: { calendar.isDate($0.date, inSameDayAs: today) })

        switch currentStatus {
        case .pending:
            let completion = ProtocolCompletion(date: today, status: "completed")
            completion.protocol = proto
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
            .padding(.top, 20)

            if !sessions.isEmpty {
                ForEach(sessions) { session in
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Text(session.template?.name ?? "Workout")
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
            .padding(.bottom, 8)
        }
    }
}

// MARK: - Flow Layout

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        layout(proposal: proposal, subviews: subviews).size
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
            ProtocolGroup.self,
            WorkoutSession.self,
            WorkoutTemplate.self,
        ], inMemory: true)
}
