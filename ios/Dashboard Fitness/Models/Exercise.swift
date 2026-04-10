import Foundation
import SwiftData

@Model
final class Exercise {
    @Attribute(.unique) var id: UUID
    var name: String
    var category: String?
    var equipment: String?
    var createdAt: Date

    init(name: String, category: String? = nil, equipment: String? = nil) {
        self.id = UUID()
        self.name = name
        self.category = category
        self.equipment = equipment
        self.createdAt = Date()
    }
}
