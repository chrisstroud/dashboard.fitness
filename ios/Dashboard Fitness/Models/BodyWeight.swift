import Foundation
import SwiftData

@Model
final class BodyWeight {
    @Attribute(.unique) var id: UUID
    var date: Date
    var weight: Double
    var createdAt: Date

    init(date: Date, weight: Double) {
        self.id = UUID()
        self.date = date
        self.weight = weight
        self.createdAt = Date()
    }
}
