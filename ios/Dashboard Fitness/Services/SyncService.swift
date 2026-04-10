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

            let apiProtocols = try decoder.decode([APIProtocol].self, from: data)

            // Fetch existing protocols to diff
            let existingProtocols = try modelContext.fetch(FetchDescriptor<UserProtocol>())
            let existingById = Dictionary(uniqueKeysWithValues: existingProtocols.compactMap { p in
                UUID(uuidString: p.id.uuidString).map { ($0, p) }
            })

            var seenIds = Set<UUID>()

            for apiProto in apiProtocols {
                guard let protoId = UUID(uuidString: apiProto.id) else { continue }
                seenIds.insert(protoId)

                if let existing = existingById[protoId] {
                    // Update
                    existing.name = apiProto.name
                    existing.section = apiProto.section
                    existing.position = apiProto.position
                    syncItems(apiItems: apiProto.items, into: existing, modelContext: modelContext)
                } else {
                    // Insert
                    let newProto = UserProtocol(name: apiProto.name, section: apiProto.section, position: apiProto.position)
                    newProto.id = protoId
                    modelContext.insert(newProto)

                    for apiItem in apiProto.items {
                        guard let itemId = UUID(uuidString: apiItem.id) else { continue }
                        let newItem = ProtocolItem(label: apiItem.label, subtitle: apiItem.subtitle, position: apiItem.position)
                        newItem.id = itemId
                        newItem.protocol = newProto
                        if let docIdStr = apiItem.documentId {
                            newItem.documentId = UUID(uuidString: docIdStr)
                        }
                        modelContext.insert(newItem)
                    }
                }
            }

            // Delete protocols not in API response
            for (id, proto) in existingById where !seenIds.contains(id) {
                modelContext.delete(proto)
            }

            try modelContext.save()
        } catch {
            lastError = error.localizedDescription
        }

        isSyncing = false
    }

    private func syncItems(apiItems: [APIProtocolItem], into proto: UserProtocol, modelContext: ModelContext) {
        let existingItems = proto.items
        let existingById = Dictionary(uniqueKeysWithValues: existingItems.compactMap { item in
            UUID(uuidString: item.id.uuidString).map { ($0, item) }
        })

        var seenIds = Set<UUID>()

        for apiItem in apiItems {
            guard let itemId = UUID(uuidString: apiItem.id) else { continue }
            seenIds.insert(itemId)

            if let existing = existingById[itemId] {
                existing.label = apiItem.label
                existing.subtitle = apiItem.subtitle
                existing.position = apiItem.position
                if let docIdStr = apiItem.documentId {
                    existing.documentId = UUID(uuidString: docIdStr)
                }
            } else {
                let newItem = ProtocolItem(label: apiItem.label, subtitle: apiItem.subtitle, position: apiItem.position)
                newItem.id = itemId
                newItem.protocol = proto
                if let docIdStr = apiItem.documentId {
                    newItem.documentId = UUID(uuidString: docIdStr)
                }
                modelContext.insert(newItem)
            }
        }

        for (id, item) in existingById where !seenIds.contains(id) {
            modelContext.delete(item)
        }
    }
}

// MARK: - API Response Types

private struct APIProtocol: Decodable {
    let id: String
    let name: String
    let section: String
    let position: Int
    let items: [APIProtocolItem]
}

private struct APIProtocolItem: Decodable {
    let id: String
    let label: String
    let subtitle: String?
    let position: Int
    let notes: String?
    let documentId: String?
}
