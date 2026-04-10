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

        await syncDocuments(modelContext: modelContext)
        await syncProtocols(modelContext: modelContext)

        isSyncing = false
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

            var seenIds = Set<UUID>()

            for apiDoc in apiDocList {
                guard let docId = UUID(uuidString: apiDoc.id) else { continue }
                seenIds.insert(docId)

                // Fetch full doc content
                let detailURL = baseURL.appendingPathComponent("documents/\(apiDoc.id)")
                let (detailData, _) = try await URLSession.shared.data(from: detailURL)
                let fullDoc = try decoder.decode(APIDocumentFull.self, from: detailData)

                if let existingDoc = existingById[docId] {
                    existingDoc.title = fullDoc.title
                    existingDoc.content = fullDoc.content
                    existingDoc.category = fullDoc.category
                } else {
                    let newDoc = UserDocument(title: fullDoc.title, content: fullDoc.content, category: fullDoc.category)
                    newDoc.id = docId
                    modelContext.insert(newDoc)
                }
            }

            for (id, doc) in existingById where !seenIds.contains(id) {
                modelContext.delete(doc)
            }

            try modelContext.save()
        } catch {
            lastError = error.localizedDescription
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

private struct APIDocumentSummary: Decodable {
    let id: String
    let title: String
    let category: String?
}

private struct APIDocumentFull: Decodable {
    let id: String
    let title: String
    let content: String
    let category: String?
}
