import SwiftUI
import SwiftData

struct MasterTemplateEditor: View {
    @Query(sort: \ProtocolGroup.position) private var groups: [ProtocolGroup]
    @Environment(\.modelContext) private var modelContext
    @State private var showingNewGroup = false
    @State private var newGroupName = ""
    @State private var newGroupSection = "morning"

    private let sections = ["morning", "evening", "anytime"]

    var body: some View {
        List {
            ForEach(sections, id: \.self) { section in
                let sectionGroups = groups.filter { $0.section == section }
                if !sectionGroups.isEmpty {
                    Section(section.uppercased()) {
                        ForEach(sectionGroups) { group in
                            NavigationLink(value: group) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(group.name)
                                            .font(.body.bold())
                                        Text("\(group.protocols.count) protocols")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                }
                            }
                        }
                        .onDelete { offsets in
                            for offset in offsets {
                                modelContext.delete(sectionGroups[offset])
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("My Protocols")
        .navigationDestination(for: ProtocolGroup.self) { group in
            GroupEditor(group: group)
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: { showingNewGroup = true }) {
                    Image(systemName: "plus")
                }
            }
        }
        .alert("New Protocol Group", isPresented: $showingNewGroup) {
            TextField("Group name", text: $newGroupName)
            Picker("Section", selection: $newGroupSection) {
                Text("Morning").tag("morning")
                Text("Evening").tag("evening")
                Text("Anytime").tag("anytime")
            }
            Button("Create") {
                guard !newGroupName.isEmpty else { return }
                let group = ProtocolGroup(
                    name: newGroupName,
                    section: newGroupSection,
                    position: groups.filter { $0.section == newGroupSection }.count
                )
                modelContext.insert(group)
                newGroupName = ""
            }
            Button("Cancel", role: .cancel) {}
        }
    }
}

// MARK: - Group Editor

struct GroupEditor: View {
    @Bindable var group: ProtocolGroup
    @Environment(\.modelContext) private var modelContext
    @State private var showingNewProtocol = false
    @State private var newLabel = ""
    @State private var newSubtitle = ""

    private let sections = ["morning", "evening", "anytime"]

    var body: some View {
        List {
            Section("Group Settings") {
                TextField("Name", text: $group.name)
                Picker("Section", selection: $group.section) {
                    Text("Morning").tag("morning")
                    Text("Evening").tag("evening")
                    Text("Anytime").tag("anytime")
                }
            }

            Section("Protocols (\(group.protocols.count))") {
                ForEach(group.sortedProtocols) { proto in
                    NavigationLink(value: proto) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(proto.label)
                                .font(.body)
                            HStack(spacing: 8) {
                                if let subtitle = proto.subtitle {
                                    Text(subtitle)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                if proto.documentId != nil {
                                    Label("Linked", systemImage: "doc.text")
                                        .font(.caption2)
                                        .foregroundStyle(.blue)
                                }
                            }
                        }
                    }
                }
                .onDelete { offsets in
                    let sorted = group.sortedProtocols
                    for offset in offsets {
                        modelContext.delete(sorted[offset])
                    }
                }

                Button(action: { showingNewProtocol = true }) {
                    Label("Add Protocol", systemImage: "plus")
                }
            }
        }
        .navigationTitle(group.name)
        .navigationDestination(for: UserProtocol.self) { proto in
            ProtocolEditor(proto: proto)
        }
        .alert("New Protocol", isPresented: $showingNewProtocol) {
            TextField("Label (e.g. 'Brush teeth')", text: $newLabel)
            TextField("Subtitle (optional)", text: $newSubtitle)
            Button("Add") {
                guard !newLabel.isEmpty else { return }
                let proto = UserProtocol(
                    label: newLabel,
                    subtitle: newSubtitle.isEmpty ? nil : newSubtitle,
                    position: group.protocols.count
                )
                proto.group = group
                modelContext.insert(proto)
                newLabel = ""
                newSubtitle = ""
            }
            Button("Cancel", role: .cancel) {}
        }
    }
}

// MARK: - Protocol Editor

struct ProtocolEditor: View {
    @Bindable var proto: UserProtocol
    @Query(sort: \UserDocument.title) private var allDocs: [UserDocument]
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

            Section("Linked Document") {
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
                        Label("View: \(doc.title)", systemImage: "doc.text")
                            .font(.subheadline)
                            .foregroundStyle(.blue)
                    }
                }
            }

            Section("Group") {
                if let group = proto.group {
                    LabeledContent("Group", value: group.name)
                    LabeledContent("Section", value: group.section.capitalized)
                }
                LabeledContent("Position", value: "\(proto.position)")
            }
        }
        .navigationTitle(proto.label)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { selectedDocId = proto.documentId }
    }
}

#Preview {
    NavigationStack {
        MasterTemplateEditor()
    }
    .modelContainer(for: [ProtocolGroup.self, UserDocument.self], inMemory: true)
}
