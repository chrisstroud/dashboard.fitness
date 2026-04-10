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

    func syncProtocols(modelContext: ModelContext) async {
        isSyncing = true
        lastError = nil

        do {
            let url = baseURL.appendingPathComponent("protocols")
            let (data, response) = try await URLSession.shared.data(from: url)

            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                lastError = "Server error"
                isSyncing = false
                return
            }

            let apiGroups = try decoder.decode([APIProtocolGroup].self, from: data)

            // Fetch existing groups
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

            // Delete groups not in API
            for (id, group) in existingById where !seenGroupIds.contains(id) {
                modelContext.delete(group)
            }

            try modelContext.save()
        } catch {
            lastError = error.localizedDescription
        }

        isSyncing = false
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
