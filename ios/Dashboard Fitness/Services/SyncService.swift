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
    private let baseURL = URL(string: "https://dashboard-fitness-api.up.railway.app/api")!
    #endif

    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        return d
    }()

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
            let url = baseURL.appendingPathComponent("protocols/today")
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
            let existingTaskIds = Set(instance.tasks.map(\.id))
            var seenTaskIds = Set<UUID>()

            let allTasks = (apiInstance.morning + apiInstance.evening + apiInstance.anytime)
                .flatMap { group in
                    group.tasks.map { (group, $0) }
                }

            for (group, apiTask) in allTasks {
                guard let taskId = UUID(uuidString: apiTask.id) else { continue }
                seenTaskIds.insert(taskId)

                if let existingTask = instance.tasks.first(where: { $0.id == taskId }) {
                    existingTask.status = apiTask.status
                    existingTask.completedAt = nil  // TODO: parse from API
                } else {
                    let task = DailyTask(
                        groupName: group.groupName,
                        section: group.section,
                        groupPosition: group.groupPosition,
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
                    if let folderIdStr = fullDoc.folderId, let folderId = UUID(uuidString: folderIdStr) {
                        existingDoc.folder = foldersById[folderId]
                    }
                } else {
                    let newDoc = UserDocument(title: fullDoc.title, content: fullDoc.content)
                    newDoc.id = docId
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

    // MARK: - Protocols

    private func syncProtocols(modelContext: ModelContext) async {
        do {
            let url = baseURL.appendingPathComponent("protocols")
            let (data, response) = try await URLSession.shared.data(from: url)

            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else { return }

            let apiGroups = try decoder.decode([APIProtocolGroup].self, from: data)

            let existingGroups = try modelContext.fetch(FetchDescriptor<ProtocolGroup>())
            let existingById = Dictionary(uniqueKeysWithValues: existingGroups.compactMap { g in
                UUID(uuidString: g.id.uuidString).map { ($0, g) }
            })

            var seenGroupIds = Set<UUID>()

            for apiGroup in apiGroups {
                guard let groupId = UUID(uuidString: apiGroup.id) else { continue }
                seenGroupIds.insert(groupId)

                if let existing = existingById[groupId] {
                    existing.name = apiGroup.name
                    existing.section = apiGroup.section
                    existing.position = apiGroup.position
                    syncProtocolsInGroup(apiProtocols: apiGroup.protocols, into: existing, modelContext: modelContext)
                } else {
                    let newGroup = ProtocolGroup(name: apiGroup.name, section: apiGroup.section, position: apiGroup.position)
                    newGroup.id = groupId
                    modelContext.insert(newGroup)

                    for apiProto in apiGroup.protocols {
                        guard let protoId = UUID(uuidString: apiProto.id) else { continue }
                        let newProto = UserProtocol(label: apiProto.label, subtitle: apiProto.subtitle, position: apiProto.position)
                        newProto.id = protoId
                        newProto.group = newGroup
                        if let docId = apiProto.documentId { newProto.documentId = UUID(uuidString: docId) }
                        modelContext.insert(newProto)
                    }
                }
            }

            for (id, group) in existingById where !seenGroupIds.contains(id) {
                modelContext.delete(group)
            }

            try modelContext.save()
        } catch {
            lastError = (lastError ?? "") + " " + error.localizedDescription
        }
    }

    private func syncProtocolsInGroup(apiProtocols: [APIProtocol], into group: ProtocolGroup, modelContext: ModelContext) {
        let existingById = Dictionary(uniqueKeysWithValues: group.protocols.compactMap { p in
            UUID(uuidString: p.id.uuidString).map { ($0, p) }
        })

        var seenIds = Set<UUID>()

        for apiProto in apiProtocols {
            guard let protoId = UUID(uuidString: apiProto.id) else { continue }
            seenIds.insert(protoId)

            if let existing = existingById[protoId] {
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

        for (id, proto) in existingById where !seenIds.contains(id) {
            modelContext.delete(proto)
        }
    }
}

// MARK: - API Response Types

private struct APIProtocolGroup: Decodable {
    let id: String
    let name: String
    let section: String
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
}

private struct APIDailyInstance: Decodable {
    let id: String
    let date: String
    let morning: [APIDailyGroup]
    let evening: [APIDailyGroup]
    let anytime: [APIDailyGroup]
}

private struct APIDailyGroup: Decodable {
    let groupName: String
    let section: String
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
