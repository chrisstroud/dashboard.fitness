import Foundation
import SwiftData

@Model
final class DailyInstance {
    @Attribute(.unique) var id: UUID
    var date: Date
    var createdAt: Date

    @Relationship(deleteRule: .cascade, inverse: \DailyTask.instance)
    var tasks: [DailyTask] = []

    init(date: Date) {
        self.id = UUID()
        self.date = date
        self.createdAt = Date()
    }

    var totalTasks: Int { tasks.count }
    var completedTasks: Int { tasks.filter { $0.status == "completed" }.count }
    var skippedTasks: Int { tasks.filter { $0.status == "skipped" }.count }

    var completionRate: Double {
        guard totalTasks > 0 else { return 0 }
        return Double(completedTasks) / Double(totalTasks)
    }

    func tasksBySection() -> (morning: [TaskGroup], evening: [TaskGroup], anytime: [TaskGroup]) {
        let sorted = tasks.sorted { ($0.groupPosition, $0.position) < ($1.groupPosition, $1.position) }

        var groups: [String: TaskGroup] = [:]
        for task in sorted {
            let key = "\(task.section):\(task.groupName)"
            if groups[key] == nil {
                groups[key] = TaskGroup(name: task.groupName, section: task.section, position: task.groupPosition, tasks: [])
            }
            groups[key]!.tasks.append(task)
        }

        let all = groups.values.sorted { $0.position < $1.position }
        return (
            morning: all.filter { $0.section == "morning" },
            evening: all.filter { $0.section == "evening" },
            anytime: all.filter { $0.section == "anytime" }
        )
    }
}

struct TaskGroup: Identifiable {
    let name: String
    let section: String
    let position: Int
    var tasks: [DailyTask]
    var id: String { "\(section):\(name)" }

    var allCompleted: Bool {
        !tasks.isEmpty && tasks.allSatisfy { $0.status == "completed" }
    }

    var completedCount: Int {
        tasks.filter { $0.status == "completed" }.count
    }
}

@Model
final class DailyTask {
    @Attribute(.unique) var id: UUID
    var instance: DailyInstance?
    var sourceProtocolId: String?
    var groupName: String
    var section: String
    var groupPosition: Int
    var label: String
    var subtitle: String?
    var position: Int
    var scheduledTime: String?  // "HH:mm" format
    var documentId: UUID?
    var status: String  // pending, completed, skipped
    var completedAt: Date?

    init(groupName: String, section: String, groupPosition: Int, label: String, position: Int) {
        self.id = UUID()
        self.groupName = groupName
        self.section = section
        self.groupPosition = groupPosition
        self.label = label
        self.position = position
        self.status = "pending"
    }

    var taskStatus: TaskStatus {
        TaskStatus(rawValue: status) ?? .pending
    }
}
