import SwiftUI
import SwiftData
import UIKit

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
                } else if SyncService.shared.isSyncing {
                    VStack(spacing: 16) {
                        ProgressView()
                            .controlSize(.large)
                        Text("Setting up your day...")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxHeight: .infinity)
                } else {
                    ContentUnavailableView {
                        Label("No Data Yet", systemImage: "checkmark.square")
                    } description: {
                        Text(SyncService.shared.lastError != nil
                             ? "Could not connect to server. Check your connection and try again."
                             : "Your daily protocols will appear here once they're set up.")
                    } actions: {
                        Button("Retry") {
                            Task {
                                await SyncService.shared.syncAll(modelContext: modelContext)
                            }
                        }
                        .buttonStyle(.bordered)
                    }
                    .frame(maxHeight: .infinity)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
        }
    }
}

// MARK: - Daily Instance View

struct DailyInstanceView: View {
    let instance: DailyInstance
    @Query(sort: \ProtocolSection.position) private var masterSections: [ProtocolSection]

    /// Merge master template sections with daily tasks so every section appears,
    /// even empty ones. Merges at the group (stack) level for full hierarchy.
    private var mergedSections: [DailySection] {
        let taskSections = instance.tasksBySections()
        let taskSectionByName = Dictionary(uniqueKeysWithValues: taskSections.map { ($0.name, $0) })

        var result: [DailySection] = []
        var seenNames = Set<String>()

        for master in masterSections {
            guard !seenNames.contains(master.name) else { continue }
            seenNames.insert(master.name)

            if let existing = taskSectionByName[master.name] {
                // Merge: start with task section, add any master groups that have no tasks
                var section = existing
                let existingGroupNames = Set(section.groups.map(\.name))
                for masterGroup in master.sortedGroups where !existingGroupNames.contains(masterGroup.name) {
                    section.groups.append(DailyGroup(name: masterGroup.name, position: masterGroup.position, tasks: []))
                }
                section.groups.sort { $0.position < $1.position }
                result.append(section)
            } else {
                // Section exists in master but has no daily tasks — show with empty groups
                var section = DailySection(name: master.name, position: master.position)
                section.groups = master.sortedGroups.map {
                    DailyGroup(name: $0.name, position: $0.position, tasks: [])
                }
                result.append(section)
            }
        }

        // Include any task sections not in master (edge case — e.g. server data)
        for section in taskSections where !seenNames.contains(section.name) {
            seenNames.insert(section.name)
            result.append(section)
        }

        return result.sorted { $0.position < $1.position }
    }

    var body: some View {
        VStack(spacing: 0) {
            DayHeader(instance: instance)
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 4)

            List {
                ForEach(mergedSections) { section in
                    SwiftUI.Section {
                        dailySectionContent(section)
                    } header: {
                        dailySectionHeader(section)
                    }
                }
            }
        }
        .background(Color(.systemGroupedBackground))
    }

    // MARK: - Section Content

    @ViewBuilder
    private func dailySectionContent(_ section: DailySection) -> some View {
        let isEmpty = section.totalCount == 0
        if section.groups.isEmpty || (section.groups.count == 1 && section.groups[0].tasks.isEmpty && isEmpty) {
            HStack {
                Spacer()
                Text("Add protocols in My Protocols")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                Spacer()
            }
        } else {
            ForEach(section.groups) { group in
                dailyGroupContent(group, section: section)
            }
        }
    }

    @ViewBuilder
    private func dailyGroupContent(_ group: DailyGroup, section: DailySection) -> some View {
        if !shouldCollapseStack(sectionName: section.name, stackName: group.name, stackCount: section.groups.count) {
            HabitStackHeader(
                name: group.name,
                completedCount: group.completedCount,
                totalCount: group.tasks.count,
                showRing: true
            )
            .listRowSeparator(.hidden)
            .listRowInsets(EdgeInsets(top: 4, leading: 20, bottom: 0, trailing: 20))
        }

        if group.tasks.isEmpty {
            EmptyStackPlaceholder()
                .listRowSeparator(.hidden)
        } else {
            ForEach(group.tasks) { task in
                DailyTaskRow(task: task)
            }
        }
    }

    private func dailySectionHeader(_ section: DailySection) -> some View {
        HStack(alignment: .center) {
            Text(section.name)
                .font(.subheadline.weight(.semibold))

            if section.totalCount == 0 {
                Text("No protocols")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            } else if section.allCompleted {
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

            // My Protocols link
            NavigationLink {
                MasterTemplateEditor()
            } label: {
                ZStack {
                    Circle()
                        .stroke(Color(.systemGray5), lineWidth: 4)
                    Image(systemName: "list.bullet.rectangle")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                .frame(width: 56, height: 56)
            }

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
    }

    private var completionColor: Color {
        if instance.completionRate >= 0.8 { return .green }
        if instance.completionRate >= 0.4 { return .blue }
        return .orange
    }
}

// MARK: - (DailySectionView removed — inlined into DailyInstanceView)

// MARK: - Task Row

struct DailyTaskRow: View {
    @Bindable var task: DailyTask

    var body: some View {
        HStack(spacing: 12) {
            // Status button (same for both types)
            Button(action: cycleStatus) {
                Image(systemName: statusIcon)
                    .font(.system(size: 22))
                    .foregroundStyle(statusColor)
                    .contentTransition(.symbolEffect(.replace))
                    .frame(width: 28)
            }
            .buttonStyle(.borderless)

            // Content varies by type
            NavigationLink {
                ProtocolDetailView(
                    protocolId: task.sourceProtocolId ?? "",
                    label: task.label,
                    subtitle: task.subtitle,
                    documentId: task.documentId,
                    dailyTask: task
                )
            } label: {
                if task.type == "workout" {
                    workoutContent
                } else {
                    taskContent
                }
            }
        }
    }

    // MARK: - Task Content (default behavior)

    private var taskContent: some View {
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
    }

    // MARK: - Workout Content

    private var workoutContent: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 6) {
                Image(systemName: activityIcon)
                    .font(.caption)
                    .foregroundStyle(.blue)

                Text(task.label)
                    .font(.body)
                    .foregroundStyle(task.status == "completed" ? .secondary : .primary)
                    .strikethrough(task.status == "completed", color: .secondary.opacity(0.5))
            }

            HStack(spacing: 8) {
                if let duration = task.durationMinutes {
                    Text("\(duration)m")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Color(.systemGray5), in: Capsule())
                }

                if let subtitle = task.subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
            }
        }
    }

    // MARK: - Activity Icon

    private var activityIcon: String {
        switch task.activityType {
        // HealthKit-aligned values
        case "traditional_strength_training": "figure.strengthtraining.traditional"
        case "functional_strength_training": "figure.strengthtraining.functional"
        case "core_training": "figure.core.training"
        case "cross_training": "figure.cross.training"
        case "running": "figure.run"
        case "walking": "figure.walk"
        case "hiking": "figure.hiking"
        case "cycling": "figure.outdoor.cycle"
        case "indoor_cycling": "figure.indoor.cycle"
        case "swimming": "figure.pool.swim"
        case "rowing": "figure.rower"
        case "elliptical": "figure.elliptical"
        case "stair_climbing": "figure.stair.stepper"
        case "jump_rope": "figure.jumprope"
        case "high_intensity_interval_training": "figure.highintensity.intervaltraining"
        case "dance": "figure.dance"
        case "barre": "figure.barre"
        case "kickboxing": "figure.kickboxing"
        case "yoga": "figure.yoga"
        case "pilates": "figure.pilates"
        case "flexibility": "figure.flexibility"
        case "mind_and_body": "figure.mind.and.body"
        case "cooldown": "figure.cooldown"
        case "basketball": "figure.basketball"
        case "soccer": "figure.soccer"
        case "tennis": "figure.tennis"
        case "golf": "figure.golf"
        case "pickleball": "figure.pickleball"
        case "martial_arts": "figure.martial.arts"
        // Legacy values
        case "strength": "figure.strengthtraining.traditional"
        case "hiit": "figure.highintensity.intervaltraining"
        default: "figure.mixed.cardio"
        }
    }

    // MARK: - Status Helpers

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
            case .pending:
                task.status = "completed"; task.completedAt = Date()
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            case .completed:
                task.status = "skipped"; task.completedAt = Date()
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            case .skipped:
                task.status = "pending"; task.completedAt = nil
                UISelectionFeedbackGenerator().selectionChanged()
            }
        }
        SyncService.shared.syncTaskStatus(task)
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
