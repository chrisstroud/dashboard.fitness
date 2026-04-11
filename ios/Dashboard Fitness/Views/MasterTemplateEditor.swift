import SwiftUI
import SwiftData

struct MasterTemplateEditor: View {
    @Query(sort: \ProtocolSection.position) private var sections: [ProtocolSection]
    @Query private var allDocuments: [UserDocument]
    @Environment(\.modelContext) private var modelContext
    @State private var showingNewSection = false
    @State private var newSectionName = ""
    @State private var renamingSection: ProtocolSection?

    // For now, treat all documents as "orphans" until protocol-document sync is implemented
    private var orphanDocs: [UserDocument] {
        allDocuments
    }

    var body: some View {
        List {
            if sections.isEmpty {
                ContentUnavailableView(
                    "No Protocols",
                    systemImage: "list.bullet.rectangle",
                    description: Text("Tap + to create your first section")
                )
            }

            ForEach(sections) { section in
                Section {
                    ForEach(section.sortedGroups) { group in
                        NavigationLink {
                            GroupEditor(group: group)
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "folder.fill")
                                    .foregroundStyle(.blue)
                                    .font(.body)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(group.name)
                                        .font(.body.weight(.medium))
                                    Text("\(group.protocols.count) protocol\(group.protocols.count == 1 ? "" : "s")")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                            }
                        }
                    }
                    .onMove { from, to in moveGroups(in: section, from: from, to: to) }
                    .onDelete { offsets in deleteGroups(in: section, at: offsets) }

                    Button {
                        addGroup(to: section)
                    } label: {
                        Label("Add Group", systemImage: "plus.circle.fill")
                            .font(.subheadline)
                            .foregroundStyle(.blue)
                    }
                } header: {
                    HStack {
                        Text(section.name)
                            .font(.subheadline.weight(.semibold))
                        Spacer()
                        Menu {
                            Button { renameSection(section) } label: {
                                Label("Rename", systemImage: "pencil")
                            }
                            Button(role: .destructive) {
                                modelContext.delete(section)
                                LocalRefreshService.refreshToday(modelContext: modelContext)
                            } label: {
                                Label("Delete Section", systemImage: "trash")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .onMove { from, to in moveSections(from: from, to: to) }

            // Notes section — orphan documents
            Section("Notes") {
                if orphanDocs.isEmpty {
                    ContentUnavailableView {
                        Label("No Notes", systemImage: "doc.text")
                    } description: {
                        Text("Unattached documents will appear here")
                    }
                } else {
                    ForEach(orphanDocs) { doc in
                        NavigationLink {
                            LinkedDocView(documentId: doc.id)
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "doc.text.fill")
                                    .foregroundStyle(.secondary)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(doc.title)
                                        .font(.body)
                                    if !doc.content.isEmpty {
                                        Text(doc.content.prefix(60))
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                            .lineLimit(1)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("My Protocols")
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                EditButton()
            }
            ToolbarItem(placement: .primaryAction) {
                Button(action: { newSectionName = ""; showingNewSection = true }) {
                    Image(systemName: "plus")
                }
            }
        }
        .onDisappear { LocalRefreshService.refreshToday(modelContext: modelContext) }
        .alert("New Section", isPresented: $showingNewSection) {
            TextField("Section name", text: $newSectionName)
            Button("Create") {
                guard !newSectionName.isEmpty else { return }
                let section = ProtocolSection(name: newSectionName, position: sections.count)
                modelContext.insert(section)
                newSectionName = ""
            }
            Button("Cancel", role: .cancel) {}
        }
        .alert("Rename Section", isPresented: Binding(
            get: { renamingSection != nil },
            set: { if !$0 { renamingSection = nil } }
        )) {
            TextField("Section name", text: $newSectionName)
            Button("Rename") {
                guard !newSectionName.isEmpty, let section = renamingSection else { return }
                section.name = newSectionName
                renamingSection = nil
                newSectionName = ""
            }
            Button("Cancel", role: .cancel) { renamingSection = nil }
        }
    }

    private func moveSections(from: IndexSet, to: Int) {
        var ordered = sections.sorted { $0.position < $1.position }
        ordered.move(fromOffsets: from, toOffset: to)
        for (i, s) in ordered.enumerated() { s.position = i }
    }

    private func moveGroups(in section: ProtocolSection, from: IndexSet, to: Int) {
        var ordered = section.sortedGroups
        ordered.move(fromOffsets: from, toOffset: to)
        for (i, g) in ordered.enumerated() { g.position = i }
    }

    private func deleteGroups(in section: ProtocolSection, at offsets: IndexSet) {
        let sorted = section.sortedGroups
        for offset in offsets { modelContext.delete(sorted[offset]) }
    }

    private func addGroup(to section: ProtocolSection) {
        let group = ProtocolGroup(name: "New Group", position: section.groups.count)
        group.section = section
        modelContext.insert(group)
    }

    private func renameSection(_ section: ProtocolSection) {
        newSectionName = section.name
        renamingSection = section
    }
}

// MARK: - Group Editor

struct GroupEditor: View {
    @Bindable var group: ProtocolGroup
    @Environment(\.modelContext) private var modelContext
    @State private var showingCreateSheet = false

    var body: some View {
        List {
            Section("Group Settings") {
                HStack {
                    Image(systemName: "folder.fill")
                        .foregroundStyle(.blue)
                    TextField("Name", text: $group.name)
                        .font(.body.weight(.medium))
                }
                if let section = group.section {
                    LabeledContent("Section", value: section.name)
                }
            }

            Section {
                if group.protocols.isEmpty {
                    Text("No protocols yet")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .listRowBackground(Color.clear)
                }

                ForEach(group.sortedProtocols) { proto in
                    NavigationLink {
                        ProtocolDetailView(
                            protocolId: proto.id.uuidString,
                            label: proto.label,
                            subtitle: proto.subtitle,
                            documentId: proto.documentId
                        )
                    } label: {
                        VStack(alignment: .leading, spacing: 3) {
                            HStack(spacing: 6) {
                                Text(proto.label)
                                    .font(.body)
                                if proto.type == "workout" {
                                    Text("Workout")
                                        .font(.caption2.weight(.medium))
                                        .foregroundStyle(.blue)
                                        .padding(.horizontal, 5)
                                        .padding(.vertical, 2)
                                        .background(Color.blue.opacity(0.1), in: Capsule())
                                }
                            }
                            if let subtitle = proto.subtitle {
                                Text(subtitle)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            if proto.documentId != nil {
                                Label("Has reference doc", systemImage: "doc.text")
                                    .font(.caption2)
                                    .foregroundStyle(.blue)
                            }
                        }
                    }
                }
                .onMove { from, to in
                    var ordered = group.sortedProtocols
                    ordered.move(fromOffsets: from, toOffset: to)
                    for (i, p) in ordered.enumerated() { p.position = i }
                }
                .onDelete { offsets in
                    let sorted = group.sortedProtocols
                    for offset in offsets { modelContext.delete(sorted[offset]) }
                }

                Button {
                    showingCreateSheet = true
                } label: {
                    Label("Add Protocol", systemImage: "plus.circle.fill")
                        .font(.subheadline)
                        .foregroundStyle(.blue)
                }
            } header: {
                Text("Protocols (\(group.protocols.count))")
            }
        }
        .navigationTitle(group.name)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                EditButton()
            }
        }
        .onDisappear { LocalRefreshService.refreshToday(modelContext: modelContext) }
        .sheet(isPresented: $showingCreateSheet) {
            CreateProtocolSheet(groupId: group.id) {
                // Refresh protocols from API after creation
                Task {
                    await SyncService.shared.syncAll(modelContext: modelContext)
                }
            }
        }
    }
}

// MARK: - Protocol Editor

struct ProtocolEditor: View {
    @Bindable var proto: UserProtocol
    @Query(sort: \UserDocument.title) private var allDocs: [UserDocument]
    @Environment(\.modelContext) private var modelContext
    @State private var selectedDocId: UUID?

    var body: some View {
        Form {
            Section("Details") {
                TextField("Label", text: $proto.label)
                TextField("Subtitle", text: Binding(
                    get: { proto.subtitle ?? "" },
                    set: { proto.subtitle = $0.isEmpty ? nil : $0 }
                ))
            }

            Section {
                Picker("Document", selection: $selectedDocId) {
                    Text("None").tag(nil as UUID?)
                    ForEach(allDocs) { doc in
                        Text(doc.title).tag(doc.id as UUID?)
                    }
                }
                .onChange(of: selectedDocId) { _, newValue in
                    proto.documentId = newValue
                }

                if let docId = proto.documentId, let doc = allDocs.first(where: { $0.id == docId }) {
                    NavigationLink {
                        DocumentView(document: doc)
                    } label: {
                        Label(doc.title, systemImage: "doc.text.fill")
                            .font(.subheadline)
                            .foregroundStyle(.blue)
                    }
                }
            } header: {
                Text("Reference Document")
            } footer: {
                Text("Link a document that explains why this protocol exists.")
            }
        }
        .navigationTitle("Edit Protocol")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { selectedDocId = proto.documentId }
        .onDisappear { LocalRefreshService.refreshToday(modelContext: modelContext) }
    }
}

#Preview {
    NavigationStack {
        MasterTemplateEditor()
    }
    .modelContainer(for: [ProtocolSection.self, UserDocument.self], inMemory: true)
}
