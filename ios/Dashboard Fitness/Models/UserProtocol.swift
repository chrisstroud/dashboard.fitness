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

    @Relationship(deleteRule: .cascade, inverse: \ProtocolCompletion.protocol)
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
    @Attribute(.unique) var id: UUID
    var `protocol`: UserProtocol?
    var date: Date
    var status: String
    var completedAt: Date

    init(date: Date, status: String = "completed") {
        self.id = UUID()
        self.date = date
        self.status = status
        self.completedAt = Date()
    }
}
