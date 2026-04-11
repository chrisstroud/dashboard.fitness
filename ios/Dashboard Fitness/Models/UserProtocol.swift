import Foundation
import SwiftData

@Model
final class ProtocolSection {
    @Attribute(.unique) var id: UUID
    var name: String
    var position: Int

    @Relationship(deleteRule: .cascade, inverse: \ProtocolGroup.section)
    var groups: [ProtocolGroup] = []

    init(name: String, position: Int = 0) {
        self.id = UUID()
        self.name = name
        self.position = position
    }

    var sortedGroups: [ProtocolGroup] {
        groups.sorted { $0.position < $1.position }
    }
}

@Model
final class ProtocolGroup {
    @Attribute(.unique) var id: UUID
    var name: String
    var section: ProtocolSection?
    var position: Int

    @Relationship(deleteRule: .cascade, inverse: \UserProtocol.group)
    var protocols: [UserProtocol] = []

    init(name: String, position: Int = 0) {
        self.id = UUID()
        self.name = name
        self.position = position
    }

    var sortedProtocols: [UserProtocol] {
        protocols.sorted { $0.position < $1.position }
    }
}

@Model
final class UserProtocol {
    @Attribute(.unique) var id: UUID
    var group: ProtocolGroup?
    var label: String
    var subtitle: String?
    var position: Int
    var documentId: UUID?

    // Protocol type system (v2)
    var type: String = "task"           // "workout" | "task"
    var activityType: String?           // workout only: strength|running|cycling|yoga|hiit|flexibility|other
    var durationMinutes: Int?           // estimated duration
    var weeklyTarget: Int?              // NULL = daily, else N/week
    var reminderTime: Date?             // time-of-day for notifications
    var icon: String?                   // SF Symbol name
    var color: String?                  // system color name

    @Relationship(deleteRule: .cascade, inverse: \ProtocolCompletion.userProtocol)
    var completions: [ProtocolCompletion] = []

    init(label: String, subtitle: String? = nil, position: Int = 0) {
        self.id = UUID()
        self.label = label
        self.subtitle = subtitle
        self.position = position
    }
}

enum TaskStatus: String {
    case pending
    case completed
    case skipped
}

@Model
final class ProtocolCompletion {
    @Attribute(.unique) var id: UUID = UUID()
    var userProtocol: UserProtocol?
    var date: Date = Date()
    var status: String = "completed"    // "completed" | "skipped"
    var completedAt: Date?

    // Workout-specific metadata
    var durationMinutes: Int?           // actual duration
    var calories: Int?                  // from HealthKit
    var avgHeartRate: Int?              // from HealthKit
    var notes: String?

    init(date: Date = Date(), status: String = "completed", completedAt: Date? = nil) {
        self.date = date
        self.status = status
        self.completedAt = completedAt
    }
}
