import Foundation
import SwiftData

@Model
final class UserProtocol {
    @Attribute(.unique) var id: UUID
    var name: String
    var position: Int

    @Relationship(deleteRule: .cascade, inverse: \ProtocolItem.protocol)
    var items: [ProtocolItem] = []

    init(name: String, position: Int = 0) {
        self.id = UUID()
        self.name = name
        self.position = position
    }
}

@Model
final class ProtocolItem {
    @Attribute(.unique) var id: UUID
    var `protocol`: UserProtocol?
    var label: String
    var position: Int
    var notes: String?

    @Relationship(deleteRule: .cascade, inverse: \ProtocolCompletion.item)
    var completions: [ProtocolCompletion] = []

    init(label: String, position: Int = 0, notes: String? = nil) {
        self.id = UUID()
        self.label = label
        self.position = position
        self.notes = notes
    }

    func isCompleted(on date: Date) -> Bool {
        let calendar = Calendar.current
        return completions.contains { calendar.isDate($0.date, inSameDayAs: date) }
    }
}

@Model
final class ProtocolCompletion {
    @Attribute(.unique) var id: UUID
    var item: ProtocolItem?
    var date: Date
    var completedAt: Date

    init(date: Date) {
        self.id = UUID()
        self.date = date
        self.completedAt = Date()
    }
}
