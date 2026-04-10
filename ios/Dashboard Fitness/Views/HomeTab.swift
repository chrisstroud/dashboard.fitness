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

    var body: some View {
        let sections = instance.tasksBySections()

        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Hero header
                DayHeader(instance: instance)

                // Sections
                ForEach(sections) { section in
                    TaskSectionView(section: section)
                }

                // Workout picker
                WorkoutChipSection()

                Spacer(minLength: 40)
            }
            .padding(.top, 8)
        }
        .background(Color(.systemGroupedBackground))
        .scrollIndicators(.hidden)
    }
}

// MARK: - Day Header with Progress Ring

struct DayHeader: View {
    let instance: DailyInstance

    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text(instance.date, format: .dateTime.weekday(.wide))
                    .font(.subheadline)
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

// MARK: - Section

struct TaskSectionView: View {
    let section: DailySection
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Section header
            HStack(alignment: .center) {
                Text(section.name.uppercased())
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                    .tracking(0.8)

                Spacer()

                Text("\(section.completedCount)/\(section.totalCount)")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.tertiary)

                Button(action: toggleSection) {
                    Image(systemName: section.allCompleted ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 20))
                        .foregroundStyle(section.allCompleted ? .green : Color(.systemGray3))
                        .contentTransition(.symbolEffect(.replace))
                }
            }
            .padding(.horizontal, 20)

            // Groups
            VStack(spacing: 2) {
                ForEach(section.groups) { group in
                    TaskGroupCard(group: group)
                }
            }
            .padding(.horizontal, 16)
        }
    }

    private func toggleSection() {
        let newStatus = section.allCompleted ? "pending" : "completed"
        for task in section.allTasks {
            task.status = newStatus
            task.completedAt = newStatus == "pending" ? nil : Date()
        }
    }
}

// MARK: - Group Card

struct TaskGroupCard: View {
    let group: DailyGroup
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Group header
            HStack {
                Text(group.name)
                    .font(.subheadline.weight(.semibold))

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
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            Divider()
                .padding(.leading, 16)

            // Tasks
            ForEach(Array(group.tasks.enumerated()), id: \.element.id) { index, task in
                DailyTaskRow(task: task)

                if index < group.tasks.count - 1 {
                    Divider()
                        .padding(.leading, 52)
                }
            }
        }
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
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
            // Status circle
            Button(action: cycleStatus) {
                Image(systemName: statusIcon)
                    .font(.system(size: 22))
                    .foregroundStyle(statusColor)
                    .contentTransition(.symbolEffect(.replace))
                    .frame(width: 28)
            }
            .buttonStyle(.plain)

            // Content — tappable for detail
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

// MARK: - Workout Chips

struct WorkoutChipSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("WORKOUT")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                    .tracking(0.8)
                Spacer()
                Button(action: {}) {
                    Text("Program")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.blue)
                }
            }
            .padding(.horizontal, 20)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(["Bench Day", "Squat Day", "Press Day", "Hinge Day", "Zone 2", "HIIT"], id: \.self) { name in
                        Text(name)
                            .font(.subheadline.weight(.medium))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                }
                .padding(.horizontal, 16)
            }
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

// MARK: - Linked Doc View (reused from protocol detail)

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
        } else {
            ContentUnavailableView("Document Not Found", systemImage: "doc.questionmark")
        }
    }
}

#Preview {
    HomeTab().modelContainer(for: [DailyInstance.self, UserDocument.self], inMemory: true)
}
