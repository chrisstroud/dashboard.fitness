import Foundation
import SwiftData

/// Refreshes today's daily instance from the local master template.
/// Call this after any edit to sections, groups, or protocols.
enum LocalRefreshService {

    static func refreshToday(modelContext: ModelContext) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        // Find today's instance
        let descriptor = FetchDescriptor<DailyInstance>(
            predicate: #Predicate { $0.date >= today }
        )
        guard let instance = (try? modelContext.fetch(descriptor))?.first(where: { calendar.isDateInToday($0.date) }) else {
            return
        }

        // Get all master protocols
        let sections = (try? modelContext.fetch(FetchDescriptor<ProtocolSection>(sortBy: [SortDescriptor(\.position)]))) ?? []

        // Build lookup of existing daily tasks by source protocol ID
        var tasksBySource: [String: DailyTask] = [:]
        for task in instance.tasks {
            if let sourceId = task.sourceProtocolId {
                tasksBySource[sourceId] = task
            }
        }

        var seenSourceIds = Set<String>()

        for section in sections {
            for group in section.sortedGroups {
                for proto in group.sortedProtocols {
                    let sourceId = proto.id.uuidString
                    seenSourceIds.insert(sourceId)

                    if let existingTask = tasksBySource[sourceId] {
                        // Update task to match master — preserve status
                        existingTask.sectionName = section.name
                        existingTask.sectionPosition = section.position
                        existingTask.groupName = group.name
                        existingTask.groupPosition = group.position
                        existingTask.label = proto.label
                        existingTask.subtitle = proto.subtitle
                        existingTask.position = proto.position
                        existingTask.documentId = proto.documentId
                        existingTask.type = proto.type
                        existingTask.activityType = proto.activityType
                        existingTask.durationMinutes = proto.durationMinutes
                    } else {
                        // New protocol — add as pending task
                        let task = DailyTask(
                            sectionName: section.name,
                            sectionPosition: section.position,
                            groupName: group.name,
                            groupPosition: group.position,
                            label: proto.label,
                            position: proto.position
                        )
                        task.subtitle = proto.subtitle
                        task.sourceProtocolId = sourceId
                        task.documentId = proto.documentId
                        task.type = proto.type
                        task.activityType = proto.activityType
                        task.durationMinutes = proto.durationMinutes
                        task.instance = instance
                        modelContext.insert(task)
                    }
                }
            }
        }

        // Remove tasks whose source protocol no longer exists
        for task in instance.tasks {
            if let sourceId = task.sourceProtocolId, !seenSourceIds.contains(sourceId) {
                modelContext.delete(task)
            }
        }
    }
}
