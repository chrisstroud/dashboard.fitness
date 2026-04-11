import Foundation
import SwiftData

@Observable
final class SyncService {
    static let shared = SyncService()

    var isSyncing = false
    var lastError: String?

    #if DEBUG
    private let baseURL = URL(string: "http://localhost:5001/api")!
    #else
    private let baseURL = URL(string: "https://dashboardfitness-production.up.railway.app/api")!
    #endif

    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        return d
    }()

    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.keyEncodingStrategy = .convertToSnakeCase
        return e
    }()

    // MARK: - Task Status Sync

    func syncTaskStatus(_ task: DailyTask) {
        Task {
            do {
                let url = baseURL.appendingPathComponent("protocols/daily/task/\(task.id.uuidString)")
                var request = URLRequest(url: url)
                request.httpMethod = "PUT"
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                let body: [String: String] = ["status": task.status]
                request.httpBody = try JSONSerialization.data(withJSONObject: body)
                let _ = try await URLSession.shared.data(for: request)
            } catch {
                // Status saved locally; will retry on next sync
            }
        }
    }

    func syncAll(modelContext: ModelContext) async {
        isSyncing = true
        lastError = nil

        await syncFolders(modelContext: modelContext)
        await syncDocuments(modelContext: modelContext)
        await syncProtocols(modelContext: modelContext)
        await syncTodayInstance(modelContext: modelContext)

        isSyncing = false
    }

    // MARK: - Daily Instance

    private func syncTodayInstance(modelContext: ModelContext) async {
        do {
            // Send the client's local date to avoid UTC timezone mismatch
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            let todayStr = formatter.string(from: Date())
            var components = URLComponents(url: baseURL.appendingPathComponent("protocols/today"), resolvingAgainstBaseURL: false)!
            components.queryItems = [URLQueryItem(name: "date", value: todayStr)]
            let url = components.url!
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else { return }

            let apiInstance = try decoder.decode(APIDailyInstance.self, from: data)
            guard let instanceId = UUID(uuidString: apiInstance.id) else { return }

            // Check if we already have this instance
            let existing = try modelContext.fetch(FetchDescriptor<DailyInstance>())
            let existingInstance = existing.first { $0.id == instanceId }

            let instance: DailyInstance
            if let existingInstance {
                instance = existingInstance
            } else {
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyy-MM-dd"
                dateFormatter.timeZone = .current
                let date = dateFormatter.date(from: apiInstance.date) ?? Calendar.current.startOfDay(for: Date())
                instance = DailyInstance(date: date)
                instance.id = instanceId
                modelContext.insert(instance)
            }

            // Sync tasks
            var seenTaskIds = Set<UUID>()

            for apiSection in apiInstance.sections {
                for apiGroup in apiSection.groups {
                    for apiTask in apiGroup.tasks {
                        guard let taskId = UUID(uuidString: apiTask.id) else { continue }
                        seenTaskIds.insert(taskId)

                        if let existingTask = instance.tasks.first(where: { $0.id == taskId }) {
                            // Only update from server if local status hasn't been changed
                            // (preserve local completions that haven't synced yet)
                            if existingTask.status == "pending" || existingTask.status == apiTask.status {
                                existingTask.status = apiTask.status
                            }
                            // Always update metadata
                            existingTask.label = apiTask.label
                            existingTask.subtitle = apiTask.subtitle
                            existingTask.scheduledTime = apiTask.scheduledTime
                        } else {
                            let task = DailyTask(
                                sectionName: apiSection.name,
                                sectionPosition: apiSection.position,
                                groupName: apiGroup.groupName,
                                groupPosition: apiGroup.groupPosition,
                                label: apiTask.label,
                                position: apiTask.position
                            )
                            task.id = taskId
                            task.subtitle = apiTask.subtitle
                            task.scheduledTime = apiTask.scheduledTime
                            task.status = apiTask.status
                            task.sourceProtocolId = apiTask.sourceProtocolId
                            if let docId = apiTask.documentId { task.documentId = UUID(uuidString: docId) }
                            task.instance = instance
                            modelContext.insert(task)
                        }
                    }
                }
            }

            // Remove tasks no longer in API
            for task in instance.tasks where !seenTaskIds.contains(task.id) {
                modelContext.delete(task)
            }

            try modelContext.save()
        } catch {
            lastError = (lastError ?? "") + " " + error.localizedDescription
        }
    }

    // MARK: - Folders

    private func syncFolders(modelContext: ModelContext) async {
        do {
            let url = baseURL.appendingPathComponent("documents/folders")
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else { return }

            let apiFolders = try decoder.decode([APIFolder].self, from: data)

            let existing = try modelContext.fetch(FetchDescriptor<DocFolder>())
            let existingById = Dictionary(uniqueKeysWithValues: existing.compactMap { f in
                UUID(uuidString: f.id.uuidString).map { ($0, f) }
            })

            var seenIds = Set<UUID>()

            for apiFolder in apiFolders {
                guard let folderId = UUID(uuidString: apiFolder.id) else { continue }
                seenIds.insert(folderId)

                if let existingFolder = existingById[folderId] {
                    existingFolder.name = apiFolder.name
                    existingFolder.position = apiFolder.position
                } else {
                    let newFolder = DocFolder(name: apiFolder.name, position: apiFolder.position)
                    newFolder.id = folderId
                    if let parentIdStr = apiFolder.parentId {
                        newFolder.parentId = UUID(uuidString: parentIdStr)
                    }
                    modelContext.insert(newFolder)
                }
            }

            // Don't delete folders not from API — user may have created locally
            try modelContext.save()
        } catch {
            lastError = error.localizedDescription
        }
    }

    // MARK: - Documents

    private func syncDocuments(modelContext: ModelContext) async {
        do {
            let url = baseURL.appendingPathComponent("documents")
            let (listData, listResponse) = try await URLSession.shared.data(from: url)
            guard let http = listResponse as? HTTPURLResponse, (200...299).contains(http.statusCode) else { return }

            let apiDocList = try decoder.decode([APIDocumentSummary].self, from: listData)

            let existing = try modelContext.fetch(FetchDescriptor<UserDocument>())
            let existingById = Dictionary(uniqueKeysWithValues: existing.compactMap { d in
                UUID(uuidString: d.id.uuidString).map { ($0, d) }
            })

            // Fetch all folders for linking
            let allFolders = try modelContext.fetch(FetchDescriptor<DocFolder>())
            let foldersById = Dictionary(uniqueKeysWithValues: allFolders.compactMap { f in
                UUID(uuidString: f.id.uuidString).map { ($0, f) }
            })

            var seenIds = Set<UUID>()

            for apiDoc in apiDocList {
                guard let docId = UUID(uuidString: apiDoc.id) else { continue }
                seenIds.insert(docId)

                let detailURL = baseURL.appendingPathComponent("documents/\(apiDoc.id)")
                let (detailData, _) = try await URLSession.shared.data(from: detailURL)
                let fullDoc = try decoder.decode(APIDocumentFull.self, from: detailData)

                if let existingDoc = existingById[docId] {
                    existingDoc.title = fullDoc.title
                    existingDoc.content = fullDoc.content
                    existingDoc.weeklyTarget = fullDoc.weeklyTarget
                    existingDoc.durationMinutes = fullDoc.durationMinutes
                    existingDoc.activityType = fullDoc.activityType
                    if let folderIdStr = fullDoc.folderId, let folderId = UUID(uuidString: folderIdStr) {
                        existingDoc.folder = foldersById[folderId]
                    }
                } else {
                    let newDoc = UserDocument(title: fullDoc.title, content: fullDoc.content)
                    newDoc.id = docId
                    newDoc.weeklyTarget = fullDoc.weeklyTarget
                    newDoc.durationMinutes = fullDoc.durationMinutes
                    newDoc.activityType = fullDoc.activityType
                    if let folderIdStr = fullDoc.folderId, let folderId = UUID(uuidString: folderIdStr) {
                        newDoc.folder = foldersById[folderId]
                    }
                    modelContext.insert(newDoc)
                }
            }

            // Don't delete docs not from API — user may have created locally
            try modelContext.save()
        } catch {
            lastError = (lastError ?? "") + " " + error.localizedDescription
        }
    }

    // MARK: - Protocols (sections → groups → protocols)

    private func syncProtocols(modelContext: ModelContext) async {
        do {
            let url = baseURL.appendingPathComponent("protocols/sections")
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else { return }

            let apiSections = try decoder.decode([APISection].self, from: data)

            let existingSections = try modelContext.fetch(FetchDescriptor<ProtocolSection>())
            let existingSectionById = Dictionary(uniqueKeysWithValues: existingSections.compactMap { s in
                UUID(uuidString: s.id.uuidString).map { ($0, s) }
            })

            var seenSectionIds = Set<UUID>()

            for apiSection in apiSections {
                guard let sectionId = UUID(uuidString: apiSection.id) else { continue }
                seenSectionIds.insert(sectionId)

                let section: ProtocolSection
                if let existing = existingSectionById[sectionId] {
                    existing.name = apiSection.name
                    existing.position = apiSection.position
                    section = existing
                } else {
                    section = ProtocolSection(name: apiSection.name, position: apiSection.position)
                    section.id = sectionId
                    modelContext.insert(section)
                }

                // Sync groups in this section
                let existingGroupById = Dictionary(uniqueKeysWithValues: section.groups.compactMap { g in
                    UUID(uuidString: g.id.uuidString).map { ($0, g) }
                })
                var seenGroupIds = Set<UUID>()

                for apiGroup in apiSection.groups {
                    guard let groupId = UUID(uuidString: apiGroup.id) else { continue }
                    seenGroupIds.insert(groupId)

                    let group: ProtocolGroup
                    if let existing = existingGroupById[groupId] {
                        existing.name = apiGroup.name
                        existing.position = apiGroup.position
                        group = existing
                    } else {
                        group = ProtocolGroup(name: apiGroup.name, position: apiGroup.position)
                        group.id = groupId
                        group.section = section
                        modelContext.insert(group)
                    }

                    // Sync protocols in this group
                    let existingProtoById = Dictionary(uniqueKeysWithValues: group.protocols.compactMap { p in
                        UUID(uuidString: p.id.uuidString).map { ($0, p) }
                    })
                    var seenProtoIds = Set<UUID>()

                    for apiProto in apiGroup.protocols {
                        guard let protoId = UUID(uuidString: apiProto.id) else { continue }
                        seenProtoIds.insert(protoId)

                        if let existing = existingProtoById[protoId] {
                            existing.label = apiProto.label
                            existing.subtitle = apiProto.subtitle
                            existing.position = apiProto.position
                            if let docId = apiProto.documentId { existing.documentId = UUID(uuidString: docId) }
                        } else {
                            let newProto = UserProtocol(label: apiProto.label, subtitle: apiProto.subtitle, position: apiProto.position)
                            newProto.id = protoId
                            newProto.group = group
                            if let docId = apiProto.documentId { newProto.documentId = UUID(uuidString: docId) }
                            modelContext.insert(newProto)
                        }
                    }

                    for (id, proto) in existingProtoById where !seenProtoIds.contains(id) {
                        modelContext.delete(proto)
                    }
                }

                for (id, group) in existingGroupById where !seenGroupIds.contains(id) {
                    modelContext.delete(group)
                }
            }

            for (id, section) in existingSectionById where !seenSectionIds.contains(id) {
                modelContext.delete(section)
            }

            try modelContext.save()
        } catch {
            lastError = (lastError ?? "") + " " + error.localizedDescription
        }
    }
}

// MARK: - API Response Types

private struct APISection: Decodable {
    let id: String
    let name: String
    let position: Int
    let groups: [APIProtocolGroup]
}

private struct APIProtocolGroup: Decodable {
    let id: String
    let name: String
    let position: Int
    let protocols: [APIProtocol]
}

private struct APIProtocol: Decodable {
    let id: String
    let label: String
    let subtitle: String?
    let position: Int
    let documentId: String?
}

private struct APIFolder: Decodable {
    let id: String
    let name: String
    let parentId: String?
    let position: Int
}

private struct APIDocumentSummary: Decodable {
    let id: String
    let title: String
    let folderId: String?
}

private struct APIDocumentFull: Decodable {
    let id: String
    let title: String
    let content: String
    let folderId: String?
    let weeklyTarget: Int?
    let durationMinutes: Int?
    let activityType: String?
}

private struct APIDailyInstance: Decodable {
    let id: String
    let date: String
    let sections: [APIDailySection]
}

private struct APIDailySection: Decodable {
    let name: String
    let position: Int
    let groups: [APIDailyGroup]
}

private struct APIDailyGroup: Decodable {
    let groupName: String
    let groupPosition: Int
    let tasks: [APIDailyTask]
}

private struct APIDailyTask: Decodable {
    let id: String
    let sourceProtocolId: String?
    let label: String
    let subtitle: String?
    let position: Int
    let scheduledTime: String?
    let documentId: String?
    let status: String
}
