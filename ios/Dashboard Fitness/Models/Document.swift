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
    var createdAt: Date
    var updatedAt: Date

    init(title: String, content: String = "", folder: DocFolder? = nil) {
        self.id = UUID()
        self.title = title
        self.content = content
        self.folder = folder
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}
