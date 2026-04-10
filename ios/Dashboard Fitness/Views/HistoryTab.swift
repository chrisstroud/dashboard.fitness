import SwiftUI
import SwiftData

struct HistoryTab: View {
    @Query(sort: \DailyInstance.date, order: .reverse) private var instances: [DailyInstance]
    @State private var selectedDate: Date?
    @State private var displayedMonth = Date()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Month navigation
                    HStack {
                        Button(action: previousMonth) {
                            Image(systemName: "chevron.left")
                        }
                        Spacer()
                        Text(displayedMonth, format: .dateTime.month(.wide).year())
                            .font(.headline)
                        Spacer()
                        Button(action: nextMonth) {
                            Image(systemName: "chevron.right")
                        }
                    }
                    .padding(.horizontal)

                    // Calendar grid
                    CalendarGrid(
                        month: displayedMonth,
                        instances: instances,
                        selectedDate: $selectedDate
                    )
                    .padding(.horizontal)

                    // Legend
                    HStack(spacing: 16) {
                        LegendItem(color: .gray.opacity(0.15), label: "No data")
                        LegendItem(color: .green.opacity(0.3), label: "< 50%")
                        LegendItem(color: .green.opacity(0.6), label: "50-80%")
                        LegendItem(color: .green, label: "> 80%")
                    }
                    .font(.caption2)
                    .padding(.horizontal)

                    // Selected day detail
                    if let date = selectedDate, let instance = instanceFor(date) {
                        DayDetailCard(instance: instance)
                            .padding(.horizontal)
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("History")
        }
    }

    private func instanceFor(_ date: Date) -> DailyInstance? {
        let calendar = Calendar.current
        return instances.first { calendar.isDate($0.date, inSameDayAs: date) }
    }

    private func previousMonth() {
        displayedMonth = Calendar.current.date(byAdding: .month, value: -1, to: displayedMonth) ?? displayedMonth
    }

    private func nextMonth() {
        displayedMonth = Calendar.current.date(byAdding: .month, value: 1, to: displayedMonth) ?? displayedMonth
    }
}

// MARK: - Calendar Grid

struct CalendarGrid: View {
    let month: Date
    let instances: [DailyInstance]
    @Binding var selectedDate: Date?

    private let calendar = Calendar.current
    private let dayNames = ["S", "M", "T", "W", "T", "F", "S"]

    private var daysInMonth: [Date?] {
        guard let range = calendar.range(of: .day, in: .month, for: month),
              let firstDay = calendar.date(from: calendar.dateComponents([.year, .month], from: month)) else {
            return []
        }

        let weekdayOfFirst = calendar.component(.weekday, from: firstDay) - 1
        var days: [Date?] = Array(repeating: nil, count: weekdayOfFirst)

        for day in range {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: firstDay) {
                days.append(date)
            }
        }

        return days
    }

    var body: some View {
        VStack(spacing: 4) {
            // Day headers
            HStack(spacing: 0) {
                ForEach(dayNames, id: \.self) { name in
                    Text(name)
                        .font(.caption2.bold())
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }

            // Day cells
            let columns = 7
            let rows = (daysInMonth.count + columns - 1) / columns

            ForEach(0..<rows, id: \.self) { row in
                HStack(spacing: 0) {
                    ForEach(0..<columns, id: \.self) { col in
                        let index = row * columns + col
                        if index < daysInMonth.count, let date = daysInMonth[index] {
                            DayCell(
                                date: date,
                                completionRate: completionRate(for: date),
                                isSelected: isSelected(date),
                                isToday: calendar.isDateInToday(date)
                            )
                            .onTapGesture { selectedDate = date }
                        } else {
                            Color.clear.frame(maxWidth: .infinity, minHeight: 36)
                        }
                    }
                }
            }
        }
    }

    private func completionRate(for date: Date) -> Double? {
        guard let instance = instances.first(where: { calendar.isDate($0.date, inSameDayAs: date) }) else {
            return nil
        }
        return instance.completionRate
    }

    private func isSelected(_ date: Date) -> Bool {
        guard let selected = selectedDate else { return false }
        return calendar.isDate(date, inSameDayAs: selected)
    }
}

struct DayCell: View {
    let date: Date
    let completionRate: Double?
    let isSelected: Bool
    let isToday: Bool

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6)
                .fill(cellColor)

            if isSelected {
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color.blue, lineWidth: 2)
            }

            Text("\(Calendar.current.component(.day, from: date))")
                .font(.caption)
                .fontWeight(isToday ? .bold : .regular)
                .foregroundStyle(isToday ? .blue : .primary)
        }
        .frame(maxWidth: .infinity, minHeight: 36)
    }

    private var cellColor: Color {
        guard let rate = completionRate else {
            return Color.gray.opacity(0.08)
        }
        if rate == 0 { return Color.gray.opacity(0.15) }
        if rate < 0.5 { return Color.green.opacity(0.3) }
        if rate < 0.8 { return Color.green.opacity(0.6) }
        return Color.green.opacity(0.85)
    }
}

struct LegendItem: View {
    let color: Color
    let label: String

    var body: some View {
        HStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 3)
                .fill(color)
                .frame(width: 12, height: 12)
            Text(label)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Day Detail Card

struct DayDetailCard: View {
    let instance: DailyInstance

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(instance.date, format: .dateTime.weekday(.wide).month().day())
                    .font(.headline)
                Spacer()
                Text("\(instance.completedTasks)/\(instance.totalTasks)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if instance.totalTasks > 0 {
                ProgressView(value: instance.completionRate)
                    .tint(.green)
            }

            let sections = instance.tasksBySection()
            let allGroups = sections.morning + sections.evening + sections.anytime

            ForEach(allGroups) { group in
                HStack(spacing: 8) {
                    Text(group.name)
                        .font(.caption)
                    Spacer()
                    Text("\(group.completedCount)/\(group.tasks.count)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}

#Preview {
    HistoryTab()
        .modelContainer(for: DailyInstance.self, inMemory: true)
}
