import Foundation
import SwiftData

@Model
final class WorkoutTemplate {
    @Attribute(.unique) var id: UUID
    var name: String
    var templateDescription: String?
    var durationMinutes: Int?
    var createdAt: Date

    @Relationship(deleteRule: .cascade, inverse: \TemplateExercise.template)
    var exercises: [TemplateExercise] = []

    init(name: String, description: String? = nil, durationMinutes: Int? = nil) {
        self.id = UUID()
        self.name = name
        self.templateDescription = description
        self.durationMinutes = durationMinutes
        self.createdAt = Date()
    }
}

@Model
final class TemplateExercise {
    @Attribute(.unique) var id: UUID
    var template: WorkoutTemplate?
    var exercise: Exercise?
    var position: Int
    var section: String?
    var targetSets: Int?
    var targetReps: String?
    var notes: String?

    init(exercise: Exercise, position: Int, section: String? = nil, targetSets: Int? = nil, targetReps: String? = nil) {
        self.id = UUID()
        self.exercise = exercise
        self.position = position
        self.section = section
        self.targetSets = targetSets
        self.targetReps = targetReps
    }
}
