import Foundation
import SwiftData

@Model
final class ProtocolGroup {
    @Attribute(.unique) var id: UUID
    var name: String
    var section: String  // morning, evening, anytime
    var position: Int

    @Relationship(deleteRule: .cascade, inverse: \UserProtocol.group)
    var protocols: [UserProtocol] = []

    init(name: String, section: String = "anytime", position: Int = 0) {
        self.id = UUID()
        self.name = name
        self.section = section
        self.position = position
    }

    var sortedProtocols: [UserProtocol] {
        protocols.sorted { $0.position < $1.position }
    }

    func allCompleted(on date: Date) -> Bool {
        !protocols.isEmpty && protocols.allSatisfy { $0.status(on: date) == .completed }
    }

    func completedCount(on date: Date) -> Int {
        protocols.filter { $0.status(on: date) == .completed }.count
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

    @Relationship(deleteRule: .cascade, inverse: \ProtocolCompletion.protocol)
    var completions: [ProtocolCompletion] = []

    init(label: String, subtitle: String? = nil, position: Int = 0) {
        self.id = UUID()
        self.label = label
        self.subtitle = subtitle
        self.position = position
    }

    func status(on date: Date) -> TaskStatus {
        let calendar = Calendar.current
        guard let completion = completions.first(where: { calendar.isDate($0.date, inSameDayAs: date) }) else {
            return .pending
        }
        return TaskStatus(rawValue: completion.status) ?? .pending
    }
}

enum TaskStatus: String {
    case pending
    case completed
    case skipped
}

@Model
final class ProtocolCompletion {
    @Attribute(.unique) var id: UUID
    var `protocol`: UserProtocol?
    var date: Date
    var status: String  // completed, skipped
    var completedAt: Date

    init(date: Date, status: String = "completed") {
        self.id = UUID()
        self.date = date
        self.status = status
        self.completedAt = Date()
    }
}
