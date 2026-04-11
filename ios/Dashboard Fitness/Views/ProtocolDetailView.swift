import SwiftUI
import SwiftData

struct ProtocolDetailView: View {
    let protocolId: String
    let label: String
    let subtitle: String?
    let documentId: UUID?
    var dailyTask: DailyTask?

    @State private var analytics: ProtocolAnalytics?
    @State private var history: [DayEntry] = []
    @State private var isLoading = true
    @Query private var allProtocols: [UserProtocol]

    private var userProtocol: UserProtocol? {
        allProtocols.first { $0.id.uuidString == protocolId }
    }

    private var protocolType: String {
        dailyTask?.type ?? userProtocol?.type ?? "task"
    }

    private var activityType: String? {
        dailyTask?.activityType ?? userProtocol?.activityType
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                protocolHeader

                // Today status (if navigated from daily task)
                if let task = dailyTask {
                    todayStatusCard(task)
                }

                // Analytics
                if let analytics {
                    ProtocolAnalyticsCard(analytics: analytics, history: history)
                } else if isLoading {
                    analyticsPlaceholder
                }

                // Documents
                ProtocolDocumentsSection(protocolId: protocolId)

                // Type-specific section
                if protocolType == "workout" {
                    workoutSection
                } else {
                    taskSection
                }

                Spacer(minLength: 40)
            }
            .padding(.top, 8)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(label)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if let proto = userProtocol {
                ToolbarItem(placement: .primaryAction) {
                    NavigationLink {
                        ProtocolEditor(proto: proto)
                    } label: {
                        Text("Edit")
                            .font(.body.weight(.medium))
                    }
                }
            }
        }
        .task { await loadAnalytics() }
    }

    // MARK: - Header

    private var protocolHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                // Type icon
                Image(systemName: protocolType == "workout" ? activitySFSymbol : "checkmark.circle")
                    .font(.title2)
                    .foregroundStyle(protocolType == "workout" ? .blue : .green)
                    .frame(width: 36, height: 36)
                    .background(
                        (protocolType == "workout" ? Color.blue : Color.green).opacity(0.12),
                        in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                    )

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(label)
                            .font(.title3.weight(.semibold))

                        Text(protocolType.capitalized)
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(protocolType == "workout" ? .blue : .green)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                (protocolType == "workout" ? Color.blue : Color.green).opacity(0.1),
                                in: Capsule()
                            )
                    }

                    if let subtitle, !subtitle.isEmpty {
                        Text(subtitle)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(.horizontal, 20)
    }

    // MARK: - Today Status

    private func todayStatusCard(_ task: DailyTask) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("TODAY")
                .font(.caption.bold())
                .foregroundStyle(.secondary)
                .tracking(0.8)

            HStack(spacing: 12) {
                StatusButton(label: "Complete", icon: "checkmark.circle.fill", color: .green,
                             isActive: task.status == "completed") {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        task.status = task.status == "completed" ? "pending" : "completed"
                        task.completedAt = task.status == "pending" ? nil : Date()
                    }
                    SyncService.shared.syncTaskStatus(task)
                }
                StatusButton(label: "Skip", icon: "forward.circle.fill", color: .orange,
                             isActive: task.status == "skipped") {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        task.status = task.status == "skipped" ? "pending" : "skipped"
                        task.completedAt = task.status == "pending" ? nil : Date()
                    }
                    SyncService.shared.syncTaskStatus(task)
                }
            }
        }
        .padding(16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .padding(.horizontal, 16)
    }

    // MARK: - Workout Section

    private var workoutSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("WORKOUT DETAILS")
                .font(.caption.bold())
                .foregroundStyle(.secondary)
                .tracking(0.8)
                .padding(.horizontal, 20)

            VStack(spacing: 0) {
                // Activity type
                if let at = activityType {
                    infoRow(icon: activitySFSymbol, label: "Activity", value: at.capitalized)
                    Divider().padding(.leading, 52)
                }

                // Duration
                if let dur = dailyTask?.durationMinutes ?? userProtocol?.durationMinutes {
                    infoRow(icon: "clock", label: "Estimated", value: "\(dur) min")
                    Divider().padding(.leading, 52)
                }

                // Weekly target
                if let target = userProtocol?.weeklyTarget {
                    infoRow(icon: "repeat", label: "Frequency", value: "\(target)x per week")
                }

                Divider().padding(.leading, 16)

                // Start Workout button (placeholder for Phase 2)
                Button(action: {}) {
                    HStack {
                        Image(systemName: "play.fill")
                        Text("Start Workout")
                            .font(.body.weight(.semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                }
                .foregroundStyle(.blue)
            }
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .padding(.horizontal, 16)
        }
    }

    // MARK: - Task Section

    private var taskSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("COMPLETION HISTORY")
                .font(.caption.bold())
                .foregroundStyle(.secondary)
                .tracking(0.8)
                .padding(.horizontal, 20)

            if history.isEmpty && !isLoading {
                VStack(spacing: 6) {
                    Image(systemName: "chart.bar")
                        .font(.title3)
                        .foregroundStyle(.tertiary)
                    Text("No completions yet")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .padding(.horizontal, 16)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(history.prefix(10).enumerated()), id: \.element.id) { index, entry in
                        HStack {
                            Image(systemName: statusIcon(for: entry.status))
                                .foregroundStyle(statusColor(for: entry.status))

                            Text(entry.date, format: .dateTime.month(.abbreviated).day().weekday(.abbreviated))
                                .font(.body)

                            Spacer()

                            Text(entry.status.rawValue.capitalized)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)

                        if index < min(history.count, 10) - 1 {
                            Divider().padding(.leading, 52)
                        }
                    }
                }
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .padding(.horizontal, 16)
            }
        }
    }

    // MARK: - Helpers

    private func infoRow(icon: String, label: String, value: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.body)
                .foregroundStyle(.blue)
                .frame(width: 28)

            Text(label)
                .font(.body)
                .foregroundStyle(.secondary)

            Spacer()

            Text(value)
                .font(.body)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private var activitySFSymbol: String {
        switch activityType {
        case "strength": "figure.strengthtraining.traditional"
        case "running": "figure.run"
        case "cycling": "figure.outdoor.cycle"
        case "hiit": "figure.highintensity.intervaltraining"
        case "yoga": "figure.yoga"
        case "flexibility": "figure.flexibility"
        default: "figure.mixed.cardio"
        }
    }

    private func statusIcon(for status: DayStatus) -> String {
        switch status {
        case .completed: "checkmark.circle.fill"
        case .skipped: "minus.circle.fill"
        default: "circle"
        }
    }

    private func statusColor(for status: DayStatus) -> Color {
        switch status {
        case .completed: .green
        case .skipped: .orange
        default: Color(.systemGray4)
        }
    }

    private var analyticsPlaceholder: some View {
        VStack(spacing: 8) {
            ProgressView()
            Text("Loading analytics...")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .padding(.horizontal, 16)
    }

    // MARK: - Data Loading

    private func loadAnalytics() async {
        guard let token = AuthService.shared.token else {
            isLoading = false
            return
        }

        #if DEBUG
        let baseURL = "http://localhost:5001"
        #else
        let baseURL = "https://dashboardfitness-production.up.railway.app"
        #endif

        // Fetch analytics
        do {
            var request = URLRequest(url: URL(string: "\(baseURL)/api/protocols/protocol/\(protocolId)/analytics")!)
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                isLoading = false
                return
            }

            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
            analytics = ProtocolAnalytics(
                currentStreak: json["current_streak"] as? Int ?? 0,
                longestStreak: json["longest_streak"] as? Int ?? 0,
                rate7d: json["rate_7d"] as? Double ?? 0,
                rate30d: json["rate_30d"] as? Double ?? 0,
                totalCompletions: json["total_completions"] as? Int ?? 0,
                lastCompleted: json["last_completed"] as? String
            )
        } catch {
            // Silently fail -- show empty state
        }

        // Fetch history
        do {
            var request = URLRequest(url: URL(string: "\(baseURL)/api/protocols/protocol/\(protocolId)/history?limit=30")!)
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                isLoading = false
                return
            }

            let completions = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] ?? []
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"

            history = completions.compactMap { comp in
                guard let dateStr = comp["date"] as? String,
                      let date = dateFormatter.date(from: dateStr),
                      let status = comp["status"] as? String else { return nil }
                let dayStatus: DayStatus = status == "completed" ? .completed : status == "skipped" ? .skipped : .missed
                return DayEntry(date: date, status: dayStatus)
            }
        } catch {
            // Silently fail
        }

        isLoading = false
    }
}

// MARK: - Reusable Components

struct StatusButton: View {
    let label: String
    let icon: String
    let color: Color
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.subheadline)
                Text(label)
                    .font(.subheadline.weight(.medium))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(isActive ? color.opacity(0.12) : Color(.tertiarySystemBackground), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .foregroundStyle(isActive ? color : .secondary)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Previews

#Preview("Task Protocol") {
    NavigationStack {
        ProtocolDetailView(
            protocolId: "preview-1",
            label: "Morning Meditation",
            subtitle: "10 minutes of mindfulness",
            documentId: nil
        )
    }
}

#Preview("Workout Protocol") {
    NavigationStack {
        ProtocolDetailView(
            protocolId: "preview-2",
            label: "Bench Day",
            subtitle: "Upper body strength",
            documentId: nil
        )
    }
}
