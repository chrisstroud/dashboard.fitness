import SwiftUI
import SwiftData

struct ProtocolDetailView: View {
    let protocolId: String
    let label: String
    let subtitle: String?
    let documentId: UUID?
    var dailyTask: DailyTask?

    @State private var detail: ProtocolDetailData?
    @State private var isLoading = true
    @Query private var allDocs: [UserDocument]
    @Query private var allProtocols: [UserProtocol]

    private var masterProtocol: UserProtocol? {
        guard let uuid = UUID(uuidString: protocolId) else { return nil }
        return allProtocols.first { $0.id == uuid }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header card
                headerCard
                    .padding(.horizontal, 16)

                // Today status
                if let task = dailyTask {
                    todayCard(task)
                        .padding(.horizontal, 16)
                }

                // Stats
                if let stats = detail?.stats, stats.totalDays > 0 {
                    statsCard(stats)
                        .padding(.horizontal, 16)
                }

                // Reference doc
                if let doc = detail?.document {
                    documentCard(doc)
                        .padding(.horizontal, 16)
                }

                // Change history
                if let changes = detail?.changes, !changes.isEmpty {
                    changeLogCard(changes)
                        .padding(.horizontal, 16)
                }

                if isLoading {
                    ProgressView()
                        .padding(.vertical, 20)
                }

                Spacer(minLength: 40)
            }
            .padding(.top, 8)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Protocol")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if let proto = masterProtocol {
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
        .task { await loadDetail() }
    }

    // MARK: - Header

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.title2.bold())

            if let subtitle {
                Text(subtitle)
                    .font(.body)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 8) {
                if let section = detail?.sectionName {
                    Label(section, systemImage: "clock")
                        .font(.caption.weight(.medium))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.blue.opacity(0.1), in: Capsule())
                        .foregroundStyle(.blue)
                }
                if let group = detail?.groupName {
                    Text(group)
                        .font(.caption.weight(.medium))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color(.systemGray5), in: Capsule())
                        .foregroundStyle(.secondary)
                }
                if let time = detail?.scheduledTime {
                    Label(time, systemImage: "clock.fill")
                        .font(.caption.weight(.medium))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.purple.opacity(0.1), in: Capsule())
                        .foregroundStyle(.purple)
                }
            }

            if let firstTracked = detail?.firstTracked {
                Text("Tracking since \(firstTracked)")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .padding(.top, 2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    // MARK: - Today Status

    private func todayCard(_ task: DailyTask) -> some View {
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
                }
                StatusButton(label: "Skip", icon: "forward.circle.fill", color: .orange,
                             isActive: task.status == "skipped") {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        task.status = task.status == "skipped" ? "pending" : "skipped"
                        task.completedAt = task.status == "pending" ? nil : Date()
                    }
                }
            }
        }
        .padding(16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    // MARK: - Stats

    private func statsCard(_ stats: ProtocolStats) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("STATS")
                .font(.caption.bold())
                .foregroundStyle(.secondary)
                .tracking(0.8)

            HStack(spacing: 0) {
                StatCard(value: "\(stats.currentStreak)", label: "Streak", icon: "flame.fill", color: .orange)
                StatCard(value: "\(stats.completedDays)", label: "Done", icon: "checkmark", color: .green)
                StatCard(value: "\(Int(stats.completionRate * 100))%", label: "Rate", icon: "chart.bar.fill", color: .blue)
                StatCard(value: "\(stats.totalDays)d", label: "Tracked", icon: "calendar", color: .purple)
            }
        }
        .padding(16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    // MARK: - Document

    private func documentCard(_ doc: ProtocolDocRef) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("REFERENCE")
                .font(.caption.bold())
                .foregroundStyle(.secondary)
                .tracking(0.8)

            if let localDoc = allDocs.first(where: { $0.id.uuidString == doc.id }) {
                NavigationLink {
                    ScrollView {
                        MarkdownView(content: localDoc.content).padding()
                    }
                    .navigationTitle(localDoc.title)
                    .navigationBarTitleDisplayMode(.inline)
                    .background(Color(.systemGroupedBackground))
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "doc.text.fill")
                            .font(.title3)
                            .foregroundStyle(.blue)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(doc.title)
                                .font(.body.weight(.medium))
                                .foregroundStyle(.primary)
                            Text("Tap to view")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color(.systemGray3))
                    }
                }
            }
        }
        .padding(16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    // MARK: - Change Log

    private func changeLogCard(_ changes: [ProtocolChange]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("CHANGES")
                .font(.caption.bold())
                .foregroundStyle(.secondary)
                .tracking(0.8)

            ForEach(Array(changes.enumerated()), id: \.offset) { _, change in
                HStack(alignment: .top, spacing: 10) {
                    Circle()
                        .fill(Color.blue.opacity(0.6))
                        .frame(width: 6, height: 6)
                        .padding(.top, 6)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(changeDescription(change))
                            .font(.subheadline)
                        if let dateStr = change.changedAt {
                            Text(String(dateStr.prefix(10)))
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
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
        } catch {}
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
                .font(.system(size: 20, weight: .bold, design: .rounded).monospacedDigit())
            Text(label)
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
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
