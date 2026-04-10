import SwiftUI
import SwiftData

struct MasterTemplateEditor: View {
    @Query(sort: \ProtocolSection.position) private var sections: [ProtocolSection]
    @Environment(\.modelContext) private var modelContext
    @State private var showingNewSection = false
    @State private var newSectionName = ""

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
        showingNewSection = true
    }
}

// MARK: - Group Editor

struct GroupEditor: View {
    @Bindable var group: ProtocolGroup
    @Environment(\.modelContext) private var modelContext
    @State private var showingNewProtocol = false
    @State private var newLabel = ""
    @State private var newSubtitle = ""

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
                            Text(proto.label)
                                .font(.body)
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
                    showingNewProtocol = true
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
        .alert("New Protocol", isPresented: $showingNewProtocol) {
            TextField("Label", text: $newLabel)
            TextField("Subtitle (optional)", text: $newSubtitle)
            Button("Add") {
                guard !newLabel.isEmpty else { return }
                let proto = UserProtocol(label: newLabel, subtitle: newSubtitle.isEmpty ? nil : newSubtitle, position: group.protocols.count)
                proto.group = group
                modelContext.insert(proto)
                newLabel = ""; newSubtitle = ""
            }
            Button("Cancel", role: .cancel) {}
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
