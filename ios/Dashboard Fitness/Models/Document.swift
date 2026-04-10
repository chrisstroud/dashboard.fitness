import Foundation
import SwiftData

@Model
final class DocFolder {
    @Attribute(.unique) var id: UUID
    var name: String
    var parentId: UUID?
    var position: Int

    @Relationship(deleteRule: .cascade, inverse: \UserDocument.folder)
    var documents: [UserDocument] = []

    @Relationship(deleteRule: .cascade, inverse: \DocFolder.parent)
    var children: [DocFolder] = []

    var parent: DocFolder?

    init(name: String, parentId: UUID? = nil, position: Int = 0) {
        self.id = UUID()
        self.name = name
        self.parentId = parentId
        self.position = position
    }

    var sortedChildren: [DocFolder] {
        children.sorted { $0.position < $1.position }
    }

    var sortedDocuments: [UserDocument] {
        documents.sorted { $0.title < $1.title }
    }
}

@Model
final class UserDocument {
    @Attribute(.unique) var id: UUID
    var title: String
    var content: String
    var folder: DocFolder?
    var weeklyTarget: Int?
    var durationMinutes: Int?
    var activityType: String?  // strength, cycling, hiit, running, yoga, flexibility, other
    var createdAt: Date
    var updatedAt: Date

    @Relationship(deleteRule: .cascade, inverse: \WorkoutCompletion.document)
    var completions: [WorkoutCompletion] = []

    init(title: String, content: String = "", folder: DocFolder? = nil) {
        self.id = UUID()
        self.title = title
        self.content = content
        self.folder = folder
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    var isWorkout: Bool {
        folder?.name.lowercased() == "workouts"
    }

    func weekCompletionCount() -> Int {
        let calendar = Calendar.current
        let today = Date()
        let weekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: today))!
        return completions.filter { $0.date >= weekStart }.count
    }

    func isCompletedToday() -> Bool {
        let calendar = Calendar.current
        return completions.contains { calendar.isDateInToday($0.date) }
    }
}

@Model
final class WorkoutCompletion {
    @Attribute(.unique) var id: UUID
    var document: UserDocument?
    var date: Date
    var completedAt: Date

    init(date: Date) {
        self.id = UUID()
        self.date = date
        self.completedAt = Date()
    }
}
