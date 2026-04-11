import SwiftUI
import SwiftData

struct MasterTemplateEditor: View {
    @Query(sort: \ProtocolSection.position) private var sections: [ProtocolSection]
    @Environment(\.modelContext) private var modelContext
    @State private var showingAddProtocol = false
    @State private var showingAddSection = false
    @State private var newSectionName = ""
    @State private var renamingSection: ProtocolSection?
    @State private var hasSeeded = false

    /// All protocols flattened from all groups in a section, sorted by position.
    private func protocols(in section: ProtocolSection) -> [UserProtocol] {
        section.groups.flatMap(\.protocols).sorted { $0.position < $1.position }
    }

    var body: some View {
        List {
            if sections.isEmpty && hasSeeded {
                ContentUnavailableView(
                    "No Protocols",
                    systemImage: "list.bullet.rectangle",
                    description: Text("Tap + to add your first protocol")
                )
            }

            ForEach(sections) { section in
                Section {
                    let protos = protocols(in: section)

                    if protos.isEmpty {
                        Text("No protocols yet — tap + to add one")
                            .font(.subheadline)
                            .foregroundStyle(.tertiary)
                            .listRowBackground(Color.clear)
                    }

                    ForEach(protos) { proto in
                        NavigationLink {
                            ProtocolDetailView(
                                protocolId: proto.id.uuidString,
                                label: proto.label,
                                subtitle: proto.subtitle,
                                documentId: proto.documentId
                            )
                        } label: {
                            ProtocolRow(proto: proto)
                        }
                    }
                    .onDelete { offsets in
                        let items = protos
                        for offset in offsets { modelContext.delete(items[offset]) }
                    }
                } header: {
                    sectionHeader(section)
                }
            }
        }
        .navigationTitle("My Protocols")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button { showingAddProtocol = true } label: {
                        Label("Add Protocol", systemImage: "plus.circle")
                    }
                    Button { newSectionName = ""; showingAddSection = true } label: {
                        Label("Add Section", systemImage: "folder.badge.plus")
                    }
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .onAppear { seedDefaultSectionsIfNeeded() }
        .onDisappear { LocalRefreshService.refreshToday(modelContext: modelContext) }
        .sheet(isPresented: $showingAddProtocol) {
            CreateProtocolSheet {
                Task { await SyncService.shared.syncAll(modelContext: modelContext) }
            }
        }
        .alert("New Section", isPresented: $showingAddSection) {
            TextField("Section name", text: $newSectionName)
            Button("Create") {
                guard !newSectionName.isEmpty else { return }
                let section = ProtocolSection(name: newSectionName, position: sections.count)
                let group = ProtocolGroup(name: newSectionName, position: 0)
                group.section = section
                modelContext.insert(section)
                modelContext.insert(group)
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

    // MARK: - Section Header

    private func sectionHeader(_ section: ProtocolSection) -> some View {
        HStack {
            Text(section.name)
                .font(.subheadline.weight(.semibold))
            Spacer()
            Menu {
                Button {
                    showingAddProtocol = true
                } label: {
                    Label("Add Protocol Here", systemImage: "plus.circle")
                }
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

    // MARK: - Default Sections

    private func seedDefaultSectionsIfNeeded() {
        guard !hasSeeded else { return }
        hasSeeded = true

        let defaults = [
            ("Morning Routine", 0),
            ("Evening Routine", 1),
            ("Workouts", 2),
        ]

        let existingNames = Set(sections.map(\.name))

        for (name, position) in defaults where !existingNames.contains(name) {
            let section = ProtocolSection(name: name, position: position)
            let group = ProtocolGroup(name: name, position: 0)
            group.section = section
            modelContext.insert(section)
            modelContext.insert(group)
        }

        try? modelContext.save()
    }

    private func renameSection(_ section: ProtocolSection) {
        newSectionName = section.name
        renamingSection = section
    }
}

// MARK: - Protocol Row

private struct ProtocolRow: View {
    let proto: UserProtocol

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: iconName)
                .foregroundStyle(proto.type == "workout" ? .blue : .green)
                .font(.body)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(proto.label)
                        .font(.body)

                    if proto.type == "workout" {
                        Text(activityDisplayName)
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(.blue)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.1), in: Capsule())
                    }
                }
                if let subtitle = proto.subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            if let dur = proto.durationMinutes {
                Text("\(dur)m")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var iconName: String {
        if proto.type == "workout" {
            return activityIcon(proto.activityType)
        }
        return "checkmark.circle"
    }

    private var activityDisplayName: String {
        guard let at = proto.activityType else { return "Workout" }
        // Convert snake_case raw values to display names
        return at.replacingOccurrences(of: "_", with: " ").capitalized
    }

    private func activityIcon(_ activityType: String?) -> String {
        switch activityType {
        case "traditional_strength_training": "figure.strengthtraining.traditional"
        case "functional_strength_training": "figure.strengthtraining.functional"
        case "core_training": "figure.core.training"
        case "cross_training": "figure.cross.training"
        case "running": "figure.run"
        case "walking": "figure.walk"
        case "hiking": "figure.hiking"
        case "cycling": "figure.outdoor.cycle"
        case "indoor_cycling": "figure.indoor.cycle"
        case "swimming": "figure.pool.swim"
        case "rowing": "figure.rower"
        case "elliptical": "figure.elliptical"
        case "stair_climbing": "figure.stair.stepper"
        case "jump_rope": "figure.jumprope"
        case "high_intensity_interval_training": "figure.highintensity.intervaltraining"
        case "dance": "figure.dance"
        case "barre": "figure.barre"
        case "kickboxing": "figure.kickboxing"
        case "yoga": "figure.yoga"
        case "pilates": "figure.pilates"
        case "flexibility": "figure.flexibility"
        case "mind_and_body": "figure.mind.and.body"
        case "cooldown": "figure.cooldown"
        case "basketball": "figure.basketball"
        case "soccer": "figure.soccer"
        case "tennis": "figure.tennis"
        case "golf": "figure.golf"
        case "pickleball": "figure.pickleball"
        case "martial_arts": "figure.martial.arts"
        default: "figure.mixed.cardio"
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
