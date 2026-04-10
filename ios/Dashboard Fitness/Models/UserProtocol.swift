import Foundation
import SwiftData

@Model
final class UserProtocol {
    @Attribute(.unique) var id: UUID
    var name: String
    var section: String  // morning, evening, anytime
    var position: Int

    @Relationship(deleteRule: .cascade, inverse: \ProtocolItem.protocol)
    var items: [ProtocolItem] = []

    init(name: String, section: String = "anytime", position: Int = 0) {
        self.id = UUID()
        self.name = name
        self.section = section
        self.position = position
    }
}

@Model
final class ProtocolItem {
    @Attribute(.unique) var id: UUID
    var `protocol`: UserProtocol?
    var label: String
    var subtitle: String?
    var position: Int
    var notes: String?
    var documentId: UUID?

    @Relationship(deleteRule: .cascade, inverse: \ProtocolCompletion.item)
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
    var item: ProtocolItem?
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
