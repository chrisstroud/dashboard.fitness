import SwiftUI
import SwiftData

struct ProtocolDocumentsSection: View {
    let protocolId: String
    @Query private var allDocs: [UserDocument]
    @Environment(\.modelContext) private var modelContext
    @State private var attachedDocIds: Set<UUID> = []
    @State private var showDocPicker = false
    @State private var isLoading = true

    private var attachedDocs: [UserDocument] {
        allDocs.filter { attachedDocIds.contains($0.id) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text("DOCUMENTS")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                    .tracking(0.8)

                Spacer()

                Button(action: { showDocPicker = true }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(.blue)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 8)

            if attachedDocs.isEmpty && !isLoading {
                HStack {
                    Spacer()
                    VStack(spacing: 6) {
                        Image(systemName: "doc.text")
                            .font(.title3)
                            .foregroundStyle(.tertiary)
                        Text("No documents attached")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.vertical, 16)
                    Spacer()
                }
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .padding(.horizontal, 16)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(attachedDocs.enumerated()), id: \.element.id) { index, doc in
                        NavigationLink {
                            LinkedDocView(documentId: doc.id)
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "doc.text.fill")
                                    .foregroundStyle(.blue)
                                    .font(.body)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(doc.title)
                                        .font(.body)
                                        .foregroundStyle(.primary)
                                    if !doc.content.isEmpty {
                                        Text(doc.content.prefix(60))
                                            .font(.caption)
                                            .foregroundStyle(.tertiary)
                                            .lineLimit(1)
                                    }
                                }

                                Spacer()

                                Image(systemName: "chevron.right")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundStyle(Color(.systemGray3))
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                        }
                        .buttonStyle(.plain)
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                detachDocument(doc)
                            } label: {
                                Label("Remove", systemImage: "link.badge.minus")
                            }
                            .tint(.orange)
                        }

                        if index < attachedDocs.count - 1 {
                            Divider().padding(.leading, 52)
                        }
                    }
                }
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .padding(.horizontal, 16)
            }
        }
        .sheet(isPresented: $showDocPicker) {
            DocumentPickerSheet(
                protocolId: protocolId,
                attachedDocIds: attachedDocIds,
                onAttach: { docId in attachedDocIds.insert(docId) },
                onCreate: { docId in attachedDocIds.insert(docId) }
            )
        }
        .task { await loadAttachedDocs() }
    }

    private func loadAttachedDocs() async {
        guard let token = AuthService.shared.token else {
            isLoading = false
            return
        }

        #if DEBUG
        let baseURL = "http://localhost:5001"
        #else
        let baseURL = "https://dashboardfitness-production.up.railway.app"
        #endif

        do {
            var request = URLRequest(url: URL(string: "\(baseURL)/api/protocols/protocol/\(protocolId)/documents")!)
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                isLoading = false
                return
            }

            let docs = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] ?? []
            var ids = Set<UUID>()
            for doc in docs {
                if let idStr = doc["id"] as? String, let uuid = UUID(uuidString: idStr) {
                    ids.insert(uuid)
                }
            }
            attachedDocIds = ids
        } catch {
            // Silently fail -- show empty state
        }

        isLoading = false
    }

    private func detachDocument(_ doc: UserDocument) {
        attachedDocIds.remove(doc.id)

        guard let token = AuthService.shared.token else { return }

        #if DEBUG
        let baseURL = "http://localhost:5001"
        #else
        let baseURL = "https://dashboardfitness-production.up.railway.app"
        #endif

        Task {
            var request = URLRequest(url: URL(string: "\(baseURL)/api/protocols/protocol/\(protocolId)/documents/\(doc.id.uuidString)")!)
            request.httpMethod = "DELETE"
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            let _ = try? await URLSession.shared.data(for: request)
        }
    }
}

// MARK: - Document Picker Sheet

struct DocumentPickerSheet: View {
    let protocolId: String
    let attachedDocIds: Set<UUID>
    let onAttach: (UUID) -> Void
    let onCreate: (UUID) -> Void
    @Environment(\.dismiss) private var dismiss
    @Query private var allDocs: [UserDocument]
    @State private var searchText = ""
    @State private var showNewDoc = false
    @State private var newDocTitle = ""
    @State private var isAttaching = false

    private var availableDocs: [UserDocument] {
        let unattached = allDocs.filter { !attachedDocIds.contains($0.id) }
        if searchText.isEmpty { return unattached }
        return unattached.filter { $0.title.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button(action: { showNewDoc = true }) {
                        Label("New Document", systemImage: "plus")
                    }
                }

                if !availableDocs.isEmpty {
                    Section("Existing Documents") {
                        ForEach(availableDocs) { doc in
                            Button(action: {
                                attachExistingDocument(doc.id)
                            }) {
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text(doc.title)
                                        if !doc.content.isEmpty {
                                            Text(doc.content.prefix(50))
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                                .lineLimit(1)
                                        }
                                    }
                                    Spacer()
                                    Image(systemName: "link.badge.plus")
                                        .foregroundStyle(.blue)
                                }
                            }
                            .buttonStyle(.plain)
                            .disabled(isAttaching)
                        }
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Search documents")
            .navigationTitle("Attach Document")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .alert("New Document", isPresented: $showNewDoc) {
                TextField("Title", text: $newDocTitle)
                Button("Create") {
                    guard !newDocTitle.isEmpty else { return }
                    createAndAttachDocument(title: newDocTitle)
                    newDocTitle = ""
                }
                Button("Cancel", role: .cancel) { newDocTitle = "" }
            }
        }
    }

    private func attachExistingDocument(_ docId: UUID) {
        guard let token = AuthService.shared.token else { return }
        isAttaching = true

        #if DEBUG
        let baseURL = "http://localhost:5001"
        #else
        let baseURL = "https://dashboardfitness-production.up.railway.app"
        #endif

        Task {
            do {
                var request = URLRequest(url: URL(string: "\(baseURL)/api/protocols/protocol/\(protocolId)/documents")!)
                request.httpMethod = "POST"
                request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                request.httpBody = try JSONSerialization.data(withJSONObject: ["document_id": docId.uuidString])

                let (_, response) = try await URLSession.shared.data(for: request)
                if let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) {
                    await MainActor.run {
                        onAttach(docId)
                        dismiss()
                    }
                }
            } catch {
                // Silently fail
            }
            await MainActor.run { isAttaching = false }
        }
    }

    private func createAndAttachDocument(title: String) {
        guard let token = AuthService.shared.token else { return }

        #if DEBUG
        let baseURL = "http://localhost:5001"
        #else
        let baseURL = "https://dashboardfitness-production.up.railway.app"
        #endif

        Task {
            do {
                // Step 1: Create the document
                var createReq = URLRequest(url: URL(string: "\(baseURL)/api/documents")!)
                createReq.httpMethod = "POST"
                createReq.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                createReq.setValue("application/json", forHTTPHeaderField: "Content-Type")
                createReq.httpBody = try JSONSerialization.data(withJSONObject: ["title": title, "content": ""])

                let (createData, createResp) = try await URLSession.shared.data(for: createReq)
                guard let createHttp = createResp as? HTTPURLResponse, (200...299).contains(createHttp.statusCode) else { return }

                let createJson = try JSONSerialization.jsonObject(with: createData) as? [String: Any] ?? [:]
                guard let newDocIdStr = createJson["id"] as? String, let newDocId = UUID(uuidString: newDocIdStr) else { return }

                // Step 2: Attach the document to this protocol
                var attachReq = URLRequest(url: URL(string: "\(baseURL)/api/protocols/protocol/\(protocolId)/documents")!)
                attachReq.httpMethod = "POST"
                attachReq.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                attachReq.setValue("application/json", forHTTPHeaderField: "Content-Type")
                attachReq.httpBody = try JSONSerialization.data(withJSONObject: ["document_id": newDocIdStr])

                let (_, attachResp) = try await URLSession.shared.data(for: attachReq)
                if let attachHttp = attachResp as? HTTPURLResponse, (200...299).contains(attachHttp.statusCode) {
                    await MainActor.run {
                        onCreate(newDocId)
                        dismiss()
                    }
                }
            } catch {
                // Silently fail
            }
        }
    }
}
