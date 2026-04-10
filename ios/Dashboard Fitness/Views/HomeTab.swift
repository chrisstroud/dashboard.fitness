import SwiftUI
import SwiftData

struct HomeTab: View {
    @Query(sort: \DailyInstance.date, order: .reverse) private var instances: [DailyInstance]
    @Environment(\.modelContext) private var modelContext

    private var todayInstance: DailyInstance? {
        let calendar = Calendar.current
        return instances.first { calendar.isDateInToday($0.date) }
    }

    var body: some View {
        NavigationStack {
            Group {
                if let instance = todayInstance {
                    DailyInstanceView(instance: instance)
                } else {
                    VStack(spacing: 16) {
                        ProgressView()
                        Text("Loading today's protocols...")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationDestination(for: UUID.self) { docId in
                LinkedDocView(documentId: docId)
            }
        }
    }
}

// MARK: - Daily Instance View

struct DailyInstanceView: View {
    let instance: DailyInstance
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        let sections = instance.tasksBySection()

        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // Date header
                VStack(alignment: .leading, spacing: 2) {
                    Text("Today")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                    Text(instance.date, format: .dateTime.weekday(.wide).month(.wide).day())
                        .font(.largeTitle.bold())
                }
                .padding(.horizontal)
                .padding(.bottom, 16)

                // Morning
                if !sections.morning.isEmpty {
                    TaskSectionHeader(title: "MORNING", groups: sections.morning)
                    ForEach(sections.morning) { group in
                        TaskGroupView(group: group)
                    }
                }

                // Workout chips
                WorkoutChipSection()

                // Evening
                if !sections.evening.isEmpty {
                    TaskSectionHeader(title: "EVENING", groups: sections.evening)
                    ForEach(sections.evening) { group in
                        TaskGroupView(group: group)
                    }
                }

                // Anytime
                if !sections.anytime.isEmpty {
                    TaskSectionHeader(title: "OTHER", groups: sections.anytime)
                    ForEach(sections.anytime) { group in
                        TaskGroupView(group: group)
                    }
                }
            }
            .padding(.vertical)
        }
    }
}

// MARK: - Section Header

struct TaskSectionHeader: View {
    let title: String
    let groups: [TaskGroup]
    @Environment(\.modelContext) private var modelContext

    private var allTasks: [DailyTask] {
        groups.flatMap(\.tasks)
    }

    private var allCompleted: Bool {
        !allTasks.isEmpty && allTasks.allSatisfy { $0.status == "completed" }
    }

    private var completedCount: Int {
        allTasks.filter { $0.status == "completed" }.count
    }

    var body: some View {
        HStack {
            Text(title)
                .font(.caption.bold())
                .foregroundStyle(.blue)
            Text("\(completedCount)/\(allTasks.count)")
                .font(.caption2)
                .foregroundStyle(.secondary)
            Spacer()
            Button(action: toggleSection) {
                Image(systemName: allCompleted ? "checkmark.circle.fill" : "checkmark.circle")
                    .foregroundStyle(allCompleted ? .green : .secondary)
            }
        }
        .padding(.horizontal)
        .padding(.top, 20)
        .padding(.bottom, 4)
    }

    private func toggleSection() {
        let newStatus = allCompleted ? "pending" : "completed"
        for task in allTasks {
            task.status = newStatus
            task.completedAt = newStatus == "pending" ? nil : Date()
        }
    }
}

// MARK: - Task Group

struct TaskGroupView: View {
    let group: TaskGroup
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(group.name)
                    .font(.subheadline.bold())
                Text("\(group.completedCount)/\(group.tasks.count)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Spacer()
                Button(action: toggleGroup) {
                    Image(systemName: group.allCompleted ? "checkmark.circle.fill" : "checkmark.circle")
                        .foregroundStyle(group.allCompleted ? .green : .secondary)
                        .font(.callout)
                }
            }
            .padding(.horizontal)
            .padding(.top, 10)
            .padding(.bottom, 4)

            ForEach(group.tasks) { task in
                DailyTaskRow(task: task)
            }
        }
    }

    private func toggleGroup() {
        let newStatus = group.allCompleted ? "pending" : "completed"
        for task in group.tasks {
            task.status = newStatus
            task.completedAt = newStatus == "pending" ? nil : Date()
        }
    }
}

// MARK: - Task Row

struct DailyTaskRow: View {
    @Bindable var task: DailyTask

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Button(action: cycleStatus) {
                statusIcon
                    .font(.body)
                    .frame(width: 22)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 6) {
                    Text(task.label)
                        .font(.subheadline)
                        .strikethrough(task.status == "completed")
                        .foregroundStyle(task.status == "completed" ? .secondary : .primary)

                    if let time = task.scheduledTime {
                        Text(time)
                            .font(.caption2)
                            .foregroundStyle(.blue)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Color.blue.opacity(0.1), in: Capsule())
                    }
                }

                if let subtitle = task.subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer()

            if let docId = task.documentId {
                NavigationLink(value: docId) {
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
        switch task.taskStatus {
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
        switch task.taskStatus {
        case .pending:
            task.status = "completed"
            task.completedAt = Date()
        case .completed:
            task.status = "skipped"
            task.completedAt = Date()
        case .skipped:
            task.status = "pending"
            task.completedAt = nil
        }
    }
}

// MARK: - Workout Chips

struct WorkoutChipSection: View {
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

            let chipNames = ["Bench Day", "Squat Day", "Press Day", "Hinge Day",
                             "Zone 2", "Zone 2", "Zone 2", "Zone 2", "HIIT"]

            FlowLayout(spacing: 8) {
                ForEach(Array(chipNames.enumerated()), id: \.offset) { _, name in
                    Text(name)
                        .font(.subheadline)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.3)))
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 8)
        }
    }
}

// MARK: - Linked Doc View

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
            ContentUnavailableView("Document Not Found", systemImage: "doc.questionmark")
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
                x = 0; y += rowHeight + spacing; rowHeight = 0
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
        .modelContainer(for: [DailyInstance.self, UserDocument.self], inMemory: true)
}
