import SwiftUI

// MARK: - Analytics Data Model

struct ProtocolAnalytics {
    let currentStreak: Int
    let longestStreak: Int
    let rate7d: Double      // 0.0 - 1.0
    let rate30d: Double
    let totalCompletions: Int
    let lastCompleted: String?  // ISO date string
}

// MARK: - Day Status for Heatmap

enum DayStatus: String {
    case completed
    case skipped
    case missed
    case future
    case today
}

struct DayEntry: Identifiable {
    let id = UUID()
    let date: Date
    let status: DayStatus
}

// MARK: - Analytics Card

struct ProtocolAnalyticsCard: View {
    let analytics: ProtocolAnalytics
    let history: [DayEntry]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Streak row
            HStack(alignment: .firstTextBaseline) {
                Image(systemName: "flame.fill")
                    .foregroundStyle(analytics.currentStreak > 0 ? .orange : Color(.systemGray4))
                    .font(.title3)

                Text("\(analytics.currentStreak)")
                    .font(.system(size: 28, weight: .bold, design: .rounded))

                Text("day streak")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text("Best")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    Text("\(analytics.longestStreak)")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(.secondary)
                }
            }

            Divider()

            // Rate pills
            HStack(spacing: 8) {
                RatePill(label: "7d", rate: analytics.rate7d)
                RatePill(label: "30d", rate: analytics.rate30d)
                Spacer()
                Text("\(analytics.totalCompletions) total")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            Divider()

            // Calendar heatmap
            CalendarHeatmap(entries: history)
        }
        .padding(16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .padding(.horizontal, 16)
    }
}

// MARK: - Rate Pill

struct RatePill: View {
    let label: String
    let rate: Double

    private var percentage: Int { Int(rate * 100) }

    private var color: Color {
        if rate >= 0.8 { return .green }
        if rate >= 0.5 { return .blue }
        if rate > 0 { return .orange }
        return Color(.systemGray4)
    }

    var body: some View {
        HStack(spacing: 4) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text("\(percentage)%")
                .font(.caption.weight(.semibold))
                .foregroundStyle(color)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(color.opacity(0.1), in: Capsule())
    }
}

// Preview with hardcoded data
#Preview("Active Streak") {
    ScrollView {
        ProtocolAnalyticsCard(
            analytics: ProtocolAnalytics(
                currentStreak: 12,
                longestStreak: 23,
                rate7d: 1.0,
                rate30d: 0.87,
                totalCompletions: 45,
                lastCompleted: "2026-04-11"
            ),
            history: (0..<30).map { offset in
                let date = Calendar.current.date(byAdding: .day, value: -offset, to: Date())!
                let status: DayStatus = offset == 0 ? .today : (offset % 5 == 0 ? .missed : .completed)
                return DayEntry(date: date, status: status)
            }
        )
    }
    .background(Color(.systemGroupedBackground))
}

#Preview("No Streak") {
    ScrollView {
        ProtocolAnalyticsCard(
            analytics: ProtocolAnalytics(
                currentStreak: 0,
                longestStreak: 5,
                rate7d: 0.29,
                rate30d: 0.4,
                totalCompletions: 12,
                lastCompleted: "2026-04-08"
            ),
            history: (0..<30).map { offset in
                let date = Calendar.current.date(byAdding: .day, value: -offset, to: Date())!
                let status: DayStatus = offset < 3 ? .missed : (offset % 3 == 0 ? .skipped : .completed)
                return DayEntry(date: date, status: status)
            }
        )
    }
    .background(Color(.systemGroupedBackground))
}
