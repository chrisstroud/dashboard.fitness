import Foundation
import SwiftData

@Model
final class WorkoutSession {
    @Attribute(.unique) var id: UUID
    var template: WorkoutTemplate?
    var date: Date
    var durationMinutes: Int?
    var notes: String?
    var rating: Int?
    var createdAt: Date
    var updatedAt: Date

    @Relationship(deleteRule: .cascade, inverse: \ExerciseLog.session)
    var exerciseLogs: [ExerciseLog] = []

    init(date: Date, template: WorkoutTemplate? = nil, durationMinutes: Int? = nil) {
        self.id = UUID()
        self.date = date
        self.template = template
        self.durationMinutes = durationMinutes
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}

@Model
final class ExerciseLog {
    @Attribute(.unique) var id: UUID
    var session: WorkoutSession?
    var exercise: Exercise?
    var position: Int
    var notes: String?

    @Relationship(deleteRule: .cascade, inverse: \SetLog.exerciseLog)
    var sets: [SetLog] = []

    init(exercise: Exercise, position: Int) {
        self.id = UUID()
        self.exercise = exercise
        self.position = position
    }
}

@Model
final class SetLog {
    @Attribute(.unique) var id: UUID
    var exerciseLog: ExerciseLog?
    var setNumber: Int
    var weight: Double?
    var reps: Int?
    var rpe: Double?
    var isWarmup: Bool
    var notes: String?

    init(setNumber: Int, weight: Double? = nil, reps: Int? = nil, rpe: Double? = nil, isWarmup: Bool = false) {
        self.id = UUID()
        self.setNumber = setNumber
        self.weight = weight
        self.reps = reps
        self.rpe = rpe
        self.isWarmup = isWarmup
    }
}
