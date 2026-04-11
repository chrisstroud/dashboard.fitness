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

    var completionRate: Double {
        guard totalTasks > 0 else { return 0 }
        return Double(completedTasks) / Double(totalTasks)
    }

    func tasksBySections() -> [DailySection] {
        let sorted = tasks.sorted { ($0.sectionPosition, $0.groupPosition, $0.position) < ($1.sectionPosition, $1.groupPosition, $1.position) }

        var sectionMap: [String: DailySection] = [:]
        for task in sorted {
            if sectionMap[task.sectionName] == nil {
                sectionMap[task.sectionName] = DailySection(name: task.sectionName, position: task.sectionPosition)
            }
            let gKey = task.groupName
            var section = sectionMap[task.sectionName]!
            if let gIdx = section.groups.firstIndex(where: { $0.name == gKey }) {
                section.groups[gIdx].tasks.append(task)
            } else {
                section.groups.append(DailyGroup(name: gKey, position: task.groupPosition, tasks: [task]))
            }
            sectionMap[task.sectionName] = section
        }

        return sectionMap.values.sorted { $0.position < $1.position }
    }
}

struct DailySection: Identifiable {
    let name: String
    let position: Int
    var groups: [DailyGroup] = []
    var id: String { name }

    var allTasks: [DailyTask] { groups.flatMap(\.tasks) }
    var allCompleted: Bool { !allTasks.isEmpty && allTasks.allSatisfy { $0.status == "completed" } }
    var completedCount: Int { allTasks.filter { $0.status == "completed" }.count }
    var totalCount: Int { allTasks.count }
}

struct DailyGroup: Identifiable {
    let name: String
    let position: Int
    var tasks: [DailyTask]
    var id: String { name }

    var allCompleted: Bool { !tasks.isEmpty && tasks.allSatisfy { $0.status == "completed" } }
    var completedCount: Int { tasks.filter { $0.status == "completed" }.count }
}

@Model
final class DailyTask {
    @Attribute(.unique) var id: UUID
    var instance: DailyInstance?
    var sourceProtocolId: String?
    var sectionName: String
    var sectionPosition: Int
    var groupName: String
    var groupPosition: Int
    var label: String
    var subtitle: String?
    var position: Int
    var scheduledTime: String?
    var documentId: UUID?
    var status: String
    var completedAt: Date?

    // Protocol type system (v2)
    var type: String = "task"           // "workout" | "task"
    var activityType: String?           // workout only
    var durationMinutes: Int?           // estimated

    init(sectionName: String, sectionPosition: Int, groupName: String, groupPosition: Int, label: String, position: Int) {
        self.id = UUID()
        self.sectionName = sectionName
        self.sectionPosition = sectionPosition
        self.groupName = groupName
        self.groupPosition = groupPosition
        self.label = label
        self.position = position
        self.status = "pending"
    }

    var taskStatus: TaskStatus {
        TaskStatus(rawValue: status) ?? .pending
    }

    var protocolType: ProtocolType {
        ProtocolType(rawValue: type) ?? .task
    }
}

enum ProtocolType: String {
    case task
    case workout
}
