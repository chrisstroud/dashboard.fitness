import SwiftUI
import SwiftData

struct HomeTab: View {
    @Query(sort: \DailyInstance.date, order: .reverse) private var instances: [DailyInstance]

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
                            .controlSize(.large)
                        Text("Setting up your day...")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxHeight: .infinity)
                }
            }
        }
    }
}

// MARK: - Daily Instance View

struct DailyInstanceView: View {
    let instance: DailyInstance
    @State private var selectedWorkouts: Set<String> = []
    @State private var collapsedGroups: Set<String> = []

    var body: some View {
        let sections = instance.tasksBySections()

        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Header + progress
                DayHeader(instance: instance)

                // Workout picker at top
                WorkoutPicker(selectedWorkouts: $selectedWorkouts)

                // Protocol sections
                ForEach(sections) { section in
                    CollapsibleSectionView(
                        section: section,
                        collapsedGroups: $collapsedGroups
                    )
                }

                Spacer(minLength: 40)
            }
            .padding(.top, 8)
        }
        .background(Color(.systemGroupedBackground))
        .scrollIndicators(.hidden)
        .onAppear { autoCollapseCompletedGroups() }
    }

    private func autoCollapseCompletedGroups() {
        let sections = instance.tasksBySections()
        for section in sections {
            for group in section.groups where group.allCompleted {
                collapsedGroups.insert(group.id)
            }
        }
    }
}

// MARK: - Day Header

struct DayHeader: View {
    let instance: DailyInstance

    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text(instance.date, format: .dateTime.weekday(.wide))
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .tracking(1.2)
                Text(instance.date, format: .dateTime.month(.wide).day())
                    .font(.system(size: 34, weight: .bold, design: .rounded))
            }

            Spacer()

            // Progress ring
            ZStack {
                Circle()
                    .stroke(Color(.systemGray5), lineWidth: 4)
                Circle()
                    .trim(from: 0, to: instance.completionRate)
                    .stroke(completionColor, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.4), value: instance.completionRate)

                VStack(spacing: 0) {
                    Text("\(instance.completedTasks)")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                    Text("/\(instance.totalTasks)")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 56, height: 56)
        }
        .padding(.horizontal, 20)
    }

    private var completionColor: Color {
        if instance.completionRate >= 0.8 { return .green }
        if instance.completionRate >= 0.4 { return .blue }
        return .orange
    }
}

// MARK: - Workout Picker

struct WorkoutPicker: View {
    @Binding var selectedWorkouts: Set<String>

    private let workouts = ["Bench Day", "Squat Day", "Press Day", "Hinge Day", "Zone 2", "HIIT"]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("WORKOUT")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                    .tracking(0.8)
                Spacer()
                if !selectedWorkouts.isEmpty {
                    Text("\(selectedWorkouts.count) selected")
                        .font(.caption2)
                        .foregroundStyle(.blue)
                }
            }
            .padding(.horizontal, 20)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(workouts, id: \.self) { name in
                        WorkoutChip(
                            name: name,
                            isSelected: selectedWorkouts.contains(name),
                            action: { toggleWorkout(name) }
                        )
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }

    private func toggleWorkout(_ name: String) {
        withAnimation(.easeInOut(duration: 0.15)) {
            if selectedWorkouts.contains(name) {
                selectedWorkouts.remove(name)
            } else {
                selectedWorkouts.insert(name)
            }
        }
    }
}

struct WorkoutChip: View {
    let name: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.caption2.bold())
                }
                Text(name)
                    .font(.subheadline.weight(.medium))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                isSelected
                    ? AnyShapeStyle(Color.blue)
                    : AnyShapeStyle(.regularMaterial),
                in: RoundedRectangle(cornerRadius: 10, style: .continuous)
            )
            .foregroundStyle(isSelected ? .white : .primary)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Collapsible Section

struct CollapsibleSectionView: View {
    let section: DailySection
    @Binding var collapsedGroups: Set<String>
    @Environment(\.modelContext) private var modelContext

    private var allCompleted: Bool { section.allCompleted }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Section header
            HStack(alignment: .center) {
                Text(section.name.uppercased())
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                    .tracking(0.8)

                // Completion summary
                if allCompleted {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.green)
                    Text("All done")
                        .font(.caption2)
                        .foregroundStyle(.green)
                } else {
                    Text("\(section.completedCount)/\(section.totalCount)")
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.tertiary)
                }

                Spacer()

                Button(action: toggleSection) {
                    Image(systemName: allCompleted ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 20))
                        .foregroundStyle(allCompleted ? .green : Color(.systemGray3))
                        .contentTransition(.symbolEffect(.replace))
                }
            }
            .padding(.horizontal, 20)

            // Groups
            ForEach(section.groups) { group in
                CollapsibleGroupCard(
                    group: group,
                    isCollapsed: collapsedGroups.contains(group.id),
                    toggleCollapse: { toggleGroupCollapse(group) }
                )
            }
        }
    }

    private func toggleSection() {
        let newStatus = allCompleted ? "pending" : "completed"
        withAnimation(.easeInOut(duration: 0.2)) {
            for task in section.allTasks {
                task.status = newStatus
                task.completedAt = newStatus == "pending" ? nil : Date()
            }
            // Auto-collapse/expand
            for group in section.groups {
                if newStatus == "completed" {
                    collapsedGroups.insert(group.id)
                } else {
                    collapsedGroups.remove(group.id)
                }
            }
        }
    }

    private func toggleGroupCollapse(_ group: DailyGroup) {
        withAnimation(.easeInOut(duration: 0.2)) {
            if collapsedGroups.contains(group.id) {
                collapsedGroups.remove(group.id)
            } else {
                collapsedGroups.insert(group.id)
            }
        }
    }
}

// MARK: - Collapsible Group Card

struct CollapsibleGroupCard: View {
    let group: DailyGroup
    let isCollapsed: Bool
    let toggleCollapse: () -> Void
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Group header — always visible, tappable to collapse
            Button(action: toggleCollapse) {
                HStack {
                    Image(systemName: "chevron.right")
                        .font(.caption2.bold())
                        .foregroundStyle(.tertiary)
                        .rotationEffect(.degrees(isCollapsed ? 0 : 90))

                    Text(group.name)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(group.allCompleted ? .secondary : .primary)

                    if group.allCompleted {
                        Image(systemName: "checkmark")
                            .font(.caption2.bold())
                            .foregroundStyle(.green)
                    }

                    Spacer()

                    Text("\(group.completedCount)/\(group.tasks.count)")
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.tertiary)

                    Button(action: toggleGroup) {
                        Image(systemName: group.allCompleted ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 17))
                            .foregroundStyle(group.allCompleted ? .green : Color(.systemGray3))
                            .contentTransition(.symbolEffect(.replace))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // Tasks — collapsible
            if !isCollapsed {
                Divider()
                    .padding(.leading, 16)

                ForEach(Array(group.tasks.enumerated()), id: \.element.id) { index, task in
                    DailyTaskRow(task: task)
                    if index < group.tasks.count - 1 {
                        Divider()
                            .padding(.leading, 52)
                    }
                }
            }
        }
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .padding(.horizontal, 16)
    }

    private func toggleGroup() {
        let newStatus = group.allCompleted ? "pending" : "completed"
        withAnimation(.easeInOut(duration: 0.2)) {
            for task in group.tasks {
                task.status = newStatus
                task.completedAt = newStatus == "pending" ? nil : Date()
            }
        }
    }
}

// MARK: - Task Row

struct DailyTaskRow: View {
    @Bindable var task: DailyTask

    var body: some View {
        HStack(spacing: 12) {
            Button(action: cycleStatus) {
                Image(systemName: statusIcon)
                    .font(.system(size: 22))
                    .foregroundStyle(statusColor)
                    .contentTransition(.symbolEffect(.replace))
                    .frame(width: 28)
            }
            .buttonStyle(.plain)

            NavigationLink {
                ProtocolDetailView(
                    protocolId: task.sourceProtocolId ?? "",
                    label: task.label,
                    subtitle: task.subtitle,
                    documentId: task.documentId,
                    dailyTask: task
                )
            } label: {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(task.label)
                            .font(.body)
                            .foregroundStyle(task.status == "completed" ? .secondary : .primary)
                            .strikethrough(task.status == "completed", color: .secondary.opacity(0.5))

                        if let time = task.scheduledTime {
                            Text(time)
                                .font(.caption2.weight(.medium))
                                .foregroundStyle(.blue)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(Color.blue.opacity(0.08), in: Capsule())
                        }
                    }

                    if let subtitle = task.subtitle {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: 4)

                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Color(.systemGray3))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .contentShape(Rectangle())
    }

    private var statusIcon: String {
        switch task.taskStatus {
        case .pending: "circle"
        case .completed: "checkmark.circle.fill"
        case .skipped: "minus.circle.fill"
        }
    }

    private var statusColor: Color {
        switch task.taskStatus {
        case .pending: Color(.systemGray3)
        case .completed: .green
        case .skipped: .orange
        }
    }

    private func cycleStatus() {
        withAnimation(.easeInOut(duration: 0.15)) {
            switch task.taskStatus {
            case .pending: task.status = "completed"; task.completedAt = Date()
            case .completed: task.status = "skipped"; task.completedAt = Date()
            case .skipped: task.status = "pending"; task.completedAt = nil
            }
        }
    }
}

// MARK: - Linked Doc View

struct LinkedDocView: View {
    let documentId: UUID
    @Query private var allDocs: [UserDocument]
    private var document: UserDocument? { allDocs.first { $0.id == documentId } }

    var body: some View {
        if let doc = document {
            ScrollView {
                if doc.content.isEmpty {
                    Text("No content yet.").foregroundStyle(.secondary).padding()
                } else {
                    MarkdownView(content: doc.content).padding()
                }
            }
            .navigationTitle(doc.title)
            .navigationBarTitleDisplayMode(.inline)
            .background(Color(.systemGroupedBackground))
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
        for (i, pos) in result.positions.enumerated() {
            subviews[i].place(at: CGPoint(x: bounds.minX + pos.x, y: bounds.minY + pos.y), proposal: .unspecified)
        }
    }
    private func layout(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        let maxW = proposal.width ?? .infinity
        var positions: [CGPoint] = []; var x: CGFloat = 0; var y: CGFloat = 0; var rh: CGFloat = 0
        for sv in subviews {
            let s = sv.sizeThatFits(.unspecified)
            if x + s.width > maxW && x > 0 { x = 0; y += rh + spacing; rh = 0 }
            positions.append(CGPoint(x: x, y: y)); rh = max(rh, s.height); x += s.width + spacing
        }
        return (CGSize(width: maxW, height: y + rh), positions)
    }
}

#Preview {
    HomeTab().modelContainer(for: [DailyInstance.self, UserDocument.self], inMemory: true)
}
