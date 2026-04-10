import SwiftUI
import SwiftData

struct ProtocolDetailView: View {
    let protocolId: String
    let label: String
    let subtitle: String?
    let documentId: UUID?

    // If viewing from Today tab, we have the daily task
    var dailyTask: DailyTask?

    @State private var detail: ProtocolDetailData?
    @State private var isLoading = true
    @Query private var allDocs: [UserDocument]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                VStack(alignment: .leading, spacing: 4) {
                    Text(label)
                        .font(.title2.bold())
                    if let subtitle {
                        Text(subtitle)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    if let detail {
                        HStack(spacing: 12) {
                            if let section = detail.sectionName {
                                Text(section)
                                    .font(.caption)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(Color.blue.opacity(0.1), in: Capsule())
                                    .foregroundStyle(.blue)
                            }
                            if let group = detail.groupName {
                                Text(group)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .padding(.horizontal)

                // Today's status (if from Today tab)
                if let task = dailyTask {
                    todaySection(task)
                }

                // Stats
                if let stats = detail?.stats {
                    statsSection(stats)
                }

                // Schedule
                scheduleSection()

                // Linked Document
                if let doc = detail?.document {
                    documentSection(doc)
                }

                // Change History
                if let changes = detail?.changes, !changes.isEmpty {
                    changeLogSection(changes)
                }

                if isLoading {
                    HStack {
                        Spacer()
                        ProgressView()
                        Spacer()
                    }
                    .padding()
                }
            }
            .padding(.vertical)
        }
        .navigationTitle("Protocol")
        .navigationBarTitleDisplayMode(.inline)
        .task { await loadDetail() }
    }

    // MARK: - Sections

    @ViewBuilder
    private func todaySection(_ task: DailyTask) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("TODAY")
                .font(.caption.bold())
                .foregroundStyle(.secondary)

            HStack(spacing: 16) {
                StatusButton(label: "Complete", icon: "checkmark.circle.fill", color: .green,
                             isActive: task.status == "completed") {
                    task.status = task.status == "completed" ? "pending" : "completed"
                    task.completedAt = task.status == "pending" ? nil : Date()
                }
                StatusButton(label: "Skip", icon: "minus.circle.fill", color: .orange,
                             isActive: task.status == "skipped") {
                    task.status = task.status == "skipped" ? "pending" : "skipped"
                    task.completedAt = task.status == "pending" ? nil : Date()
                }
            }
        }
        .padding(.horizontal)
    }

    @ViewBuilder
    private func statsSection(_ stats: ProtocolStats) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("STATS")
                .font(.caption.bold())
                .foregroundStyle(.secondary)

            HStack(spacing: 0) {
                StatCard(value: "\(stats.currentStreak)", label: "Streak", icon: "flame.fill", color: .orange)
                StatCard(value: "\(stats.completedDays)", label: "Completed", icon: "checkmark", color: .green)
                StatCard(value: "\(Int(stats.completionRate * 100))%", label: "Rate", icon: "chart.bar.fill", color: .blue)
                StatCard(value: "\(stats.totalDays)", label: "Days", icon: "calendar", color: .purple)
            }

            if let firstTracked = detail?.firstTracked {
                Text("Tracking since \(firstTracked)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal)
    }

    @ViewBuilder
    private func scheduleSection() -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("SCHEDULE")
                .font(.caption.bold())
                .foregroundStyle(.secondary)

            if let time = detail?.scheduledTime {
                HStack {
                    Image(systemName: "clock")
                        .foregroundStyle(.blue)
                    Text(time)
                        .font(.body)
                }
            } else {
                Text("No specific time set")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal)
    }

    @ViewBuilder
    private func documentSection(_ doc: ProtocolDocRef) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("REFERENCE")
                .font(.caption.bold())
                .foregroundStyle(.secondary)

            if let localDoc = allDocs.first(where: { $0.id.uuidString == doc.id }) {
                NavigationLink {
                    ScrollView {
                        MarkdownView(content: localDoc.content)
                            .padding()
                    }
                    .navigationTitle(localDoc.title)
                    .navigationBarTitleDisplayMode(.inline)
                } label: {
                    HStack {
                        Image(systemName: "doc.text.fill")
                            .foregroundStyle(.blue)
                        Text(doc.title)
                            .font(.body)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    .padding(12)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
                }
            } else {
                HStack {
                    Image(systemName: "doc.text")
                        .foregroundStyle(.secondary)
                    Text(doc.title)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.horizontal)
    }

    @ViewBuilder
    private func changeLogSection(_ changes: [ProtocolChange]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("CHANGE HISTORY")
                .font(.caption.bold())
                .foregroundStyle(.secondary)

            ForEach(Array(changes.enumerated()), id: \.offset) { _, change in
                HStack(alignment: .top, spacing: 10) {
                    Circle()
                        .fill(Color.blue)
                        .frame(width: 8, height: 8)
                        .padding(.top, 5)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(changeDescription(change))
                            .font(.subheadline)
                        if let dateStr = change.changedAt {
                            Text(dateStr.prefix(10))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .padding(.horizontal)
    }

    private func changeDescription(_ change: ProtocolChange) -> String {
        let field = change.field.replacingOccurrences(of: "_", with: " ").capitalized
        if let old = change.oldValue, let new = change.newValue {
            return "\(field): \(old) → \(new)"
        } else if let new = change.newValue {
            return "\(field) set to \(new)"
        } else if let old = change.oldValue {
            return "\(field) removed (was \(old))"
        }
        return "\(field) changed"
    }

    // MARK: - Load

    private func loadDetail() async {
        do {
            #if DEBUG
            let url = URL(string: "http://localhost:5001/api/protocols/protocol/\(protocolId)/detail")!
            #else
            let url = URL(string: "https://dashboard-fitness-api.up.railway.app/api/protocols/protocol/\(protocolId)/detail")!
            #endif
            let (data, _) = try await URLSession.shared.data(from: url)
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            detail = try decoder.decode(ProtocolDetailData.self, from: data)
        } catch {
            // Silently fail — show what we have
        }
        isLoading = false
    }
}

// MARK: - Components

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
                Text(label)
                    .font(.subheadline)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(isActive ? color.opacity(0.15) : Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10))
            .foregroundStyle(isActive ? color : .secondary)
        }
        .buttonStyle(.plain)
    }
}

struct StatCard: View {
    let value: String
    let label: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(color)
            Text(value)
                .font(.title3.bold().monospacedDigit())
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
    }
}

// MARK: - API Types

struct ProtocolDetailData: Decodable {
    let id: String
    let label: String
    let subtitle: String?
    let scheduledTime: String?
    let groupName: String?
    let sectionName: String?
    let firstTracked: String?
    let stats: ProtocolStats
    let changes: [ProtocolChange]
    let document: ProtocolDocRef?
}

struct ProtocolStats: Decodable {
    let totalDays: Int
    let completedDays: Int
    let skippedDays: Int
    let completionRate: Double
    let currentStreak: Int
}

struct ProtocolChange: Decodable {
    let field: String
    let oldValue: String?
    let newValue: String?
    let changedAt: String?
}

struct ProtocolDocRef: Decodable {
    let id: String
    let title: String
}
