import SwiftUI

struct CalendarHeatmap: View {
    let entries: [DayEntry]

    // Build a 7-column grid aligned to weekdays
    private var grid: [[DayEntry?]] {
        let calendar = Calendar.current
        let today = Date()
        guard let startDate = calendar.date(byAdding: .day, value: -29, to: today) else { return [] }

        // Build lookup
        let lookup = Dictionary(uniqueKeysWithValues: entries.map { entry in
            (calendar.startOfDay(for: entry.date), entry)
        })

        // Find the Monday on or before startDate
        let startWeekday = calendar.component(.weekday, from: startDate)
        let mondayOffset = (startWeekday == 1) ? -6 : (2 - startWeekday) // Monday = 2
        guard let gridStart = calendar.date(byAdding: .day, value: mondayOffset, to: startDate) else { return [] }

        var rows: [[DayEntry?]] = []
        var current = gridStart

        while current <= today || rows.isEmpty {
            var week: [DayEntry?] = []
            for _ in 0..<7 {
                if current > today {
                    week.append(nil)  // future beyond today
                } else if current < startDate {
                    week.append(nil)  // padding before our 30-day window
                } else {
                    let day = calendar.startOfDay(for: current)
                    if let entry = lookup[day] {
                        week.append(entry)
                    } else {
                        // No entry = missed (if in the past) or future
                        let status: DayStatus = day <= calendar.startOfDay(for: today) ? .missed : .future
                        week.append(DayEntry(date: current, status: status))
                    }
                }
                current = calendar.date(byAdding: .day, value: 1, to: current)!
            }
            rows.append(week)
        }

        return rows
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            // Weekday headers
            HStack(spacing: 3) {
                ForEach(["M", "T", "W", "T", "F", "S", "S"], id: \.self) { day in
                    Text(day)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(.tertiary)
                        .frame(maxWidth: .infinity)
                }
            }

            // Grid
            ForEach(Array(grid.enumerated()), id: \.offset) { _, week in
                HStack(spacing: 3) {
                    ForEach(Array(week.enumerated()), id: \.offset) { _, entry in
                        if let entry {
                            RoundedRectangle(cornerRadius: 3, style: .continuous)
                                .fill(color(for: entry.status))
                                .aspectRatio(1, contentMode: .fit)
                                .frame(maxWidth: .infinity)
                        } else {
                            Color.clear
                                .aspectRatio(1, contentMode: .fit)
                                .frame(maxWidth: .infinity)
                        }
                    }
                }
            }
        }
    }

    private func color(for status: DayStatus) -> Color {
        switch status {
        case .completed: .green
        case .skipped: .orange
        case .missed: Color(.systemGray5)
        case .future: Color(.systemGray6)
        case .today: .blue.opacity(0.3)
        }
    }
}

#Preview {
    CalendarHeatmap(entries: (0..<30).map { offset in
        let date = Calendar.current.date(byAdding: .day, value: -offset, to: Date())!
        let statuses: [DayStatus] = [.completed, .completed, .completed, .skipped, .missed]
        return DayEntry(date: date, status: offset == 0 ? .today : statuses[offset % statuses.count])
    })
    .padding()
}
