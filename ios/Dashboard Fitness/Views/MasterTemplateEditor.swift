import SwiftUI
import SwiftData
import UIKit

struct MasterTemplateEditor: View {
    @Query(sort: \ProtocolSection.position) private var sections: [ProtocolSection]
    @Environment(\.modelContext) private var modelContext
    @State private var showingAddProtocol = false
    @State private var showingAddSection = false
    @State private var newSectionName = ""
    @State private var renamingSection: ProtocolSection?
    @State private var hasSeeded = false

    // Stack CRUD state
    @State private var showingAddStack = false
    @State private var addStackTargetSection: ProtocolSection?
    @State private var newStackName = ""
    @State private var renamingStack: ProtocolGroup?
    @State private var showingDeleteConfirm = false
    @State private var deleteStackTarget: ProtocolGroup?
    @State private var deleteError: String?
    @State private var addProtocolTargetSection: ProtocolSection?
    @State private var deleteSectionTarget: ProtocolSection?

    private func shouldCollapse(_ section: ProtocolSection, _ group: ProtocolGroup) -> Bool {
        shouldCollapseStack(sectionName: section.name, stackName: group.name, stackCount: section.groups.count)
    }

    private var protocolList: some View {
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
                    ForEach(section.sortedGroups) { group in
                        groupContent(group: group, section: section)
                    }
                    .onMove { indices, destination in
                        moveStacks(indices, destination, in: section)
                    }
                    .deleteDisabled(true)
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
    }

    var body: some View {
        protocolList
        .sheet(isPresented: $showingAddProtocol) {
            CreateProtocolSheet(initialSection: addProtocolTargetSection) {
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
        .alert("New Habit Stack", isPresented: $showingAddStack) {
            TextField("Stack name", text: $newStackName)
            Button("Create") { createStack() }
            Button("Cancel", role: .cancel) {}
        }
        .alert("Rename Stack", isPresented: Binding(
            get: { renamingStack != nil },
            set: { if !$0 { renamingStack = nil } }
        )) {
            TextField("Stack name", text: $newStackName)
            Button("Rename") {
                guard !newStackName.isEmpty, let group = renamingStack else { return }
                group.name = newStackName
                renamingStack = nil
                newStackName = ""
            }
            Button("Cancel", role: .cancel) { renamingStack = nil }
        }
        .confirmationDialog("Delete Stack?", isPresented: $showingDeleteConfirm, titleVisibility: .visible) {
            Button("Delete", role: .destructive) { deleteStack() }
        } message: {
            Text("Protocols in this stack will be moved to another stack in the same section.")
        }
        .confirmationDialog("Delete Section?", isPresented: Binding(
            get: { deleteSectionTarget != nil },
            set: { if !$0 { deleteSectionTarget = nil } }
        ), titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                if let section = deleteSectionTarget {
                    modelContext.delete(section)
                    LocalRefreshService.refreshToday(modelContext: modelContext)
                }
                deleteSectionTarget = nil
            }
        } message: {
            Text("This will delete all stacks and protocols in this section.")
        }
        .alert("Cannot Delete", isPresented: Binding(
            get: { deleteError != nil },
            set: { if !$0 { deleteError = nil } }
        )) {
            Button("OK") { deleteError = nil }
        } message: {
            Text(deleteError ?? "")
        }
    }

    // MARK: - Group Content

    @ViewBuilder
    private func groupContent(group: ProtocolGroup, section: ProtocolSection) -> some View {
        if !shouldCollapse(section, group) {
            stackHeader(group: group, section: section)
        }

        let protos = group.sortedProtocols
        if protos.isEmpty {
            EmptyStackPlaceholder()
                .listRowSeparator(.hidden)
        }

        ForEach(protos) { proto in
            protocolRow(proto: proto, group: group, section: section)
        }
        .onDelete { offsets in
            let items = protos
            for offset in offsets { modelContext.delete(items[offset]) }
        }
        .onMove { indices, destination in
            moveProtocols(indices, destination, in: group)
        }
    }

    private func stackHeader(group: ProtocolGroup, section: ProtocolSection) -> some View {
        HabitStackHeader(
            name: group.name,
            completedCount: 0,
            totalCount: group.protocols.count,
            showCompletion: false
        )
        .listRowSeparator(.hidden)
        .listRowInsets(EdgeInsets(top: 4, leading: 20, bottom: 0, trailing: 20))
        .contextMenu {
            Button {
                newStackName = group.name
                renamingStack = group
            } label: {
                Label("Rename Stack", systemImage: "pencil")
            }
            if sections.count > 1 && section.groups.count > 1 {
                Menu("Move to Section…") {
                    ForEach(sections.filter { $0.id != section.id }) { target in
                        Button(target.name) { moveStack(group, to: target) }
                    }
                }
            }
            Divider()
            if section.groups.count > 1 {
                Button(role: .destructive) {
                    deleteStackTarget = group
                    showingDeleteConfirm = true
                } label: {
                    Label("Delete Stack", systemImage: "trash")
                }
            }
        }
    }

    private func protocolRow(proto: UserProtocol, group: ProtocolGroup, section: ProtocolSection) -> some View {
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
        .contextMenu {
            if section.groups.count > 1 {
                Menu("Move to Stack…") {
                    ForEach(section.sortedGroups.filter { $0.id != group.id }) { target in
                        Button(target.name) { moveProtocol(proto, to: target) }
                    }
                }
            }
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
                    addProtocolTargetSection = section
                    showingAddProtocol = true
                } label: {
                    Label("Add Protocol Here", systemImage: "plus.circle")
                }
                Button {
                    addStackTargetSection = section
                    newStackName = ""
                    showingAddStack = true
                } label: {
                    Label("Add Habit Stack", systemImage: "square.stack")
                }

                // Stack management — rename, move, delete each stack
                Divider()
                ForEach(section.sortedGroups) { group in
                    Menu {
                        stackMenuItems(group: group, section: section)
                    } label: {
                        Label(group.name, systemImage: "square.stack")
                    }
                }

                Divider()
                Button { renameSection(section) } label: {
                    Label("Rename Section", systemImage: "pencil")
                }
                if section.position > 0 {
                    Button { moveSectionUp(section) } label: {
                        Label("Move Up", systemImage: "arrow.up")
                    }
                }
                if section.position < sections.count - 1 {
                    Button { moveSectionDown(section) } label: {
                        Label("Move Down", systemImage: "arrow.down")
                    }
                }
                Divider()
                Button(role: .destructive) {
                    deleteSectionTarget = section
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

    @ViewBuilder
    private func stackMenuItems(group: ProtocolGroup, section: ProtocolSection) -> some View {
        Button {
            newStackName = group.name
            renamingStack = group
        } label: {
            Label("Rename", systemImage: "pencil")
        }
        if sections.count > 1 && section.groups.count > 1 {
            Menu("Move to Section…") {
                ForEach(sections.filter { $0.id != section.id }) { target in
                    Button(target.name) { moveStack(group, to: target) }
                }
            }
        }
        if section.groups.count > 1 {
            Divider()
            Button(role: .destructive) {
                deleteStackTarget = group
                showingDeleteConfirm = true
            } label: {
                Label("Delete", systemImage: "trash")
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

    // MARK: - Reorder Handlers

    private func moveSectionUp(_ section: ProtocolSection) {
        let sorted = sections.sorted { $0.position < $1.position }
        guard let idx = sorted.firstIndex(where: { $0.id == section.id }), idx > 0 else { return }
        let temp = sorted[idx].position
        sorted[idx].position = sorted[idx - 1].position
        sorted[idx - 1].position = temp
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        SyncService.shared.syncPositions(sections: [sorted[idx], sorted[idx - 1]])
    }

    private func moveSectionDown(_ section: ProtocolSection) {
        let sorted = sections.sorted { $0.position < $1.position }
        guard let idx = sorted.firstIndex(where: { $0.id == section.id }), idx < sorted.count - 1 else { return }
        let temp = sorted[idx].position
        sorted[idx].position = sorted[idx + 1].position
        sorted[idx + 1].position = temp
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        SyncService.shared.syncPositions(sections: [sorted[idx], sorted[idx + 1]])
    }

    private func moveStacks(_ indices: IndexSet, _ destination: Int, in section: ProtocolSection) {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        var ordered = section.sortedGroups
        ordered.move(fromOffsets: indices, toOffset: destination)
        for (i, group) in ordered.enumerated() { group.position = i }
        SyncService.shared.syncPositions(groups: ordered)
    }

    private func moveProtocols(_ indices: IndexSet, _ destination: Int, in group: ProtocolGroup) {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        var ordered = group.sortedProtocols
        ordered.move(fromOffsets: indices, toOffset: destination)
        for (i, proto) in ordered.enumerated() { proto.position = i }
        SyncService.shared.syncPositions(protocols: ordered)
    }

    // MARK: - Cross-Moves

    private func moveProtocol(_ proto: UserProtocol, to targetGroup: ProtocolGroup) {
        let maxPos = targetGroup.protocols.map(\.position).max() ?? -1
        proto.group = targetGroup
        proto.position = maxPos + 1
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        SyncService.shared.syncPositions(protocols: [proto])
    }

    private func moveStack(_ group: ProtocolGroup, to targetSection: ProtocolSection) {
        let maxPos = targetSection.groups.map(\.position).max() ?? -1
        group.section = targetSection
        group.position = maxPos + 1
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        SyncService.shared.syncPositions(groups: [group])
    }

    // MARK: - Stack CRUD

    private func createStack() {
        guard !newStackName.isEmpty, let section = addStackTargetSection else { return }
        let group = ProtocolGroup(name: newStackName, position: section.groups.count)
        group.section = section
        modelContext.insert(group)
        try? modelContext.save()

        Task {
            guard let token = AuthService.shared.token else { return }
            #if DEBUG
            let baseURL = "http://localhost:5001"
            #else
            let baseURL = "https://dashboardfitness-production.up.railway.app"
            #endif
            var request = URLRequest(url: URL(string: "\(baseURL)/api/protocols/sections/\(section.id.uuidString)/groups")!)
            request.httpMethod = "POST"
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try? JSONSerialization.data(withJSONObject: [
                "id": group.id.uuidString, "name": group.name, "position": group.position,
            ])
            _ = try? await URLSession.shared.data(for: request)
        }
        newStackName = ""
    }

    private func deleteStack() {
        guard let group = deleteStackTarget else { return }
        guard let section = group.section, section.groups.count > 1 else {
            deleteError = "Cannot delete the last stack in a section."
            deleteStackTarget = nil
            return
        }

        Task {
            guard let token = AuthService.shared.token else { return }
            #if DEBUG
            let baseURL = "http://localhost:5001"
            #else
            let baseURL = "https://dashboardfitness-production.up.railway.app"
            #endif
            var request = URLRequest(url: URL(string: "\(baseURL)/api/protocols/groups/\(group.id.uuidString)")!)
            request.httpMethod = "DELETE"
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            do {
                let (_, response) = try await URLSession.shared.data(for: request)
                if let http = response as? HTTPURLResponse, http.statusCode == 204 {
                    await MainActor.run {
                        Task { await SyncService.shared.syncAll(modelContext: modelContext) }
                    }
                } else if let http = response as? HTTPURLResponse, http.statusCode == 400 {
                    await MainActor.run { deleteError = "Cannot delete the last stack in a section." }
                }
            } catch {
                // Silently fail — user can retry
            }
        }
        deleteStackTarget = nil
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
