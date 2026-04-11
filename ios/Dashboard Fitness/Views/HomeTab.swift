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
    @State private var collapsedGroups: Set<String> = []
    @State private var workoutsCollapsed = true
    @State private var hasInitialized = false

    var body: some View {
        let sections = instance.tasksBySections()

        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                DayHeader(instance: instance)

                // Weekly training (collapsible, same style as protocol groups)
                WorkoutSection(isCollapsed: $workoutsCollapsed)

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
        .onAppear {
            guard !hasInitialized else { return }
            hasInitialized = true
            let sections = instance.tasksBySections()
            for section in sections {
                for group in section.groups {
                    collapsedGroups.insert(group.id)
                }
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
        .padding(.horizontal, 20)
    }

    private var completionColor: Color {
        if instance.completionRate >= 0.8 { return .green }
        if instance.completionRate >= 0.4 { return .blue }
        return .orange
    }
}

// MARK: - Workout Picker (checkable chips with weekly progress)

// MARK: - Weekly Training Section (collapsible, matches protocol style)

struct WorkoutSection: View {
    @Query private var allFolders: [DocFolder]
    @Binding var isCollapsed: Bool

    private var workoutDocs: [UserDocument] {
        if let folder = allFolders.first(where: { $0.name.lowercased() == "workouts" }) {
            return folder.sortedDocuments
        }
        return []
    }

    private var totalTarget: Int {
        workoutDocs.compactMap(\.weeklyTarget).reduce(0, +)
    }

    private var totalDone: Int {
        workoutDocs.map { $0.weekCompletionCount() }.reduce(0, +)
    }

    var body: some View {
        if !workoutDocs.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                // Section header
                HStack {
                    Text("WEEKLY TRAINING")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                        .tracking(0.8)

                    Text("\(totalDone)/\(totalTarget)")
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.tertiary)

                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 8)

                // Collapsible card
                VStack(alignment: .leading, spacing: 0) {
                    // Card header
                    Button(action: { withAnimation(.easeInOut(duration: 0.2)) { isCollapsed.toggle() } }) {
                        HStack {
                            Image(systemName: "chevron.right")
                                .font(.caption2.bold())
                                .foregroundStyle(.tertiary)
                                .rotationEffect(.degrees(isCollapsed ? 0 : 90))

                            Text("Workouts")
                                .font(.subheadline.weight(.semibold))

                            if totalDone >= totalTarget && totalTarget > 0 {
                                Image(systemName: "checkmark")
                                    .font(.caption2.bold())
                                    .foregroundStyle(.green)
                            }

                            Spacer()

                            Text("\(totalDone)/\(totalTarget)")
                                .font(.caption2.monospacedDigit())
                                .foregroundStyle(.tertiary)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    if !isCollapsed {
                        Divider().padding(.leading, 16)

                        ForEach(workoutDocs) { doc in
                            WorkoutSlots(doc: doc)
                        }
                    }
                }
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .padding(.horizontal, 16)
            }
        }
    }
}

// MARK: - Workout Slots (one row per workout, shows frequency)

struct WorkoutSlots: View {
    @Bindable var doc: UserDocument
    @Environment(\.modelContext) private var modelContext
    @State private var showStartConfirm = false
    @State private var showActiveWorkout = false
    @State private var showAlreadyActive = false

    private var weekCount: Int { doc.weekCompletionCount() }
    private var target: Int { doc.weeklyTarget ?? 1 }
    private var isThisActive: Bool {
        WorkoutManager.shared.isActive && WorkoutManager.shared.activeDocument?.id == doc.id
    }

    var body: some View {
        VStack(spacing: 0) {
            Button(action: rowTapped) {
                HStack(spacing: 12) {
                    // Status
                    Image(systemName: isThisActive ? "flame.fill" : weekCount >= target ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 20))
                        .foregroundStyle(isThisActive ? .orange : weekCount >= target ? .green : Color(.systemGray3))

                    // Label + info
                    VStack(alignment: .leading, spacing: 2) {
                        Text(doc.title)
                            .font(.body)
                            .foregroundStyle(weekCount >= target ? .secondary : .primary)
                            .strikethrough(weekCount >= target, color: .secondary.opacity(0.5))

                        HStack(spacing: 8) {
                            if let duration = doc.durationMinutes {
                                Text("\(duration)m")
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            }
                            if isThisActive {
                                Text("In Progress")
                                    .font(.caption2.weight(.medium))
                                    .foregroundStyle(.orange)
                            }
                        }
                    }

                    Spacer()

                    // Frequency dots
                    HStack(spacing: 4) {
                        ForEach(0..<target, id: \.self) { i in
                            Circle()
                                .fill(i < weekCount ? Color.green : Color(.systemGray4))
                                .frame(width: 8, height: 8)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .confirmationDialog("Start Workout", isPresented: $showStartConfirm) {
                Button("Start \(doc.title)") {
                    WorkoutManager.shared.startWorkout(document: doc)
                    showActiveWorkout = true
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                if let duration = doc.durationMinutes {
                    Text("Expected duration: ~\(duration) min")
                }
            }
            .fullScreenCover(isPresented: $showActiveWorkout) {
                NavigationStack {
                    ActiveWorkoutView(document: doc)
                }
            }
            .alert("Workout In Progress", isPresented: $showAlreadyActive) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Finish or cancel \"\(WorkoutManager.shared.activeDocument?.title ?? "your current workout")\" first.")
            }

            Divider().padding(.leading, 52)
        }
    }

    private func rowTapped() {
        if isThisActive {
            showActiveWorkout = true
        } else if WorkoutManager.shared.isActive {
            showAlreadyActive = true
        } else {
            showStartConfirm = true
        }
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
                SyncService.shared.syncTaskStatus(task)
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
                SyncService.shared.syncTaskStatus(task)
            }
        }
    }
}

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
            .buttonStyle(.plain)

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
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .contentShape(Rectangle())
    }

    // MARK: - Task Content (default behavior)

    private var taskContent: some View {
        HStack {
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

    // MARK: - Workout Content

    private var workoutContent: some View {
        HStack {
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

            Spacer(minLength: 4)

            Image(systemName: "chevron.right")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(Color(.systemGray3))
        }
    }

    // MARK: - Activity Icon

    private var activityIcon: String {
        switch task.activityType {
        case "strength": "figure.strengthtraining.traditional"
        case "running": "figure.run"
        case "cycling": "figure.outdoor.cycle"
        case "hiit": "figure.highintensity.intervaltraining"
        case "yoga": "figure.yoga"
        case "flexibility": "figure.flexibility"
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
            case .pending: task.status = "completed"; task.completedAt = Date()
            case .completed: task.status = "skipped"; task.completedAt = Date()
            case .skipped: task.status = "pending"; task.completedAt = nil
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
