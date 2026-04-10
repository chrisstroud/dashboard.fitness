import SwiftUI
import SwiftData

struct DocsTab: View {
    var body: some View {
        NavigationStack {
            FolderView(folder: nil, title: "Docs")
                .navigationDestination(for: DocFolder.self) { folder in
                    FolderView(folder: folder, title: folder.name)
                }
                .navigationDestination(for: UserDocument.self) { doc in
                    DocumentView(document: doc)
                }
        }
    }
}

// MARK: - Folder View

struct FolderView: View {
    let folder: DocFolder?
    let title: String
    @Environment(\.modelContext) private var modelContext
    @Query private var allFolders: [DocFolder]
    @Query private var allDocs: [UserDocument]
    @State private var showingNewFolder = false
    @State private var showingNewDoc = false
    @State private var newItemName = ""

    private var subfolders: [DocFolder] {
        if let folder {
            return folder.sortedChildren
        }
        return allFolders.filter { $0.parent == nil }.sorted { $0.position < $1.position }
    }

    private var documents: [UserDocument] {
        if let folder {
            return folder.sortedDocuments
        }
        return allDocs.filter { $0.folder == nil }.sorted { $0.title < $1.title }
    }

    var body: some View {
        List {
            if !subfolders.isEmpty {
                Section("Folders") {
                    ForEach(subfolders) { subfolder in
                        NavigationLink(value: subfolder) {
                            Label(subfolder.name, systemImage: "folder")
                        }
                    }
                    .onDelete(perform: deleteFolders)
                }
            }

            if !documents.isEmpty {
                Section("Documents") {
                    ForEach(documents) { doc in
                        NavigationLink(value: doc) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(doc.title)
                                Text(doc.updatedAt, format: .dateTime.month().day().year())
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .onDelete(perform: deleteDocuments)
                }
            }

            if subfolders.isEmpty && documents.isEmpty {
                ContentUnavailableView(
                    "Empty",
                    systemImage: "folder",
                    description: Text("Add folders or documents with the + button")
                )
            }
        }
        .navigationTitle(title)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button(action: { newItemName = ""; showingNewFolder = true }) {
                        Label("New Folder", systemImage: "folder.badge.plus")
                    }
                    Button(action: { newItemName = ""; showingNewDoc = true }) {
                        Label("New Document", systemImage: "doc.badge.plus")
                    }
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .alert("New Folder", isPresented: $showingNewFolder) {
            TextField("Folder name", text: $newItemName)
            Button("Create") { createFolder() }
            Button("Cancel", role: .cancel) {}
        }
        .alert("New Document", isPresented: $showingNewDoc) {
            TextField("Document title", text: $newItemName)
            Button("Create") { createDocument() }
            Button("Cancel", role: .cancel) {}
        }
    }

    private func createFolder() {
        guard !newItemName.isEmpty else { return }
        let newFolder = DocFolder(name: newItemName, position: subfolders.count)
        newFolder.parent = folder
        modelContext.insert(newFolder)
    }

    private func createDocument() {
        guard !newItemName.isEmpty else { return }
        let doc = UserDocument(title: newItemName, folder: folder)
        modelContext.insert(doc)
    }

    private func deleteFolders(at offsets: IndexSet) {
        for offset in offsets {
            modelContext.delete(subfolders[offset])
        }
    }

    private func deleteDocuments(at offsets: IndexSet) {
        for offset in offsets {
            modelContext.delete(documents[offset])
        }
    }
}

// MARK: - Document View (content + linked protocols)

struct DocumentView: View {
    @Bindable var document: UserDocument
    @State private var selectedTab = 0
    @State private var isEditing = false

    private var tabCount: Int { document.isWorkout ? 3 : 2 }

    var body: some View {
        VStack(spacing: 0) {
            Picker("View", selection: $selectedTab) {
                Text("Content").tag(0)
                if document.isWorkout {
                    Text("Settings").tag(2)
                }
                Text("Protocols").tag(1)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.vertical, 8)

            switch selectedTab {
            case 0:
                if isEditing {
                    TextEditor(text: $document.content)
                        .font(.body.monospaced())
                        .padding(.horizontal, 4)
                } else {
                    ScrollView {
                        if document.content.isEmpty {
                            ContentUnavailableView(
                                "Empty Document",
                                systemImage: "doc.text",
                                description: Text("Tap Edit to start writing")
                            )
                        } else {
                            MarkdownView(content: document.content)
                                .padding()
                        }
                    }
                }
            case 2:
                WorkoutSettingsView(document: document)
            default:
                LinkedProtocolsView(documentId: document.id)
            }
        }
        .navigationTitle(document.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if selectedTab == 0 {
                ToolbarItem(placement: .primaryAction) {
                    Button(isEditing ? "Done" : "Edit") {
                        if isEditing {
                            document.updatedAt = Date()
                        }
                        isEditing.toggle()
                    }
                }
            }
        }
    }
}

// MARK: - Linked Protocols View

struct LinkedProtocolsView: View {
    let documentId: UUID
    @Query(sort: \UserProtocol.position) private var allProtocols: [UserProtocol]

    private var linkedProtocols: [UserProtocol] {
        allProtocols.filter { $0.documentId == documentId }
    }

    private var grouped: [(String, [UserProtocol])] {
        let dict = Dictionary(grouping: linkedProtocols) { proto in
            proto.group?.name ?? "Ungrouped"
        }
        return dict.sorted { $0.key < $1.key }
    }

    var body: some View {
        if linkedProtocols.isEmpty {
            ContentUnavailableView(
                "No Linked Protocols",
                systemImage: "link",
                description: Text("No protocols reference this document yet.\nLink protocols in Settings → My Protocols.")
            )
        } else {
            List {
                ForEach(grouped, id: \.0) { item in
                    let groupName = item.0
                    let protos = item.1
                    Section(groupName) {
                        ForEach(protos, id: \.id) { proto in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(proto.label)
                                    .font(.body)
                                if let subtitle = proto.subtitle {
                                    Text(subtitle)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                if let sectionName = proto.group?.section?.name {
                                    Text(sectionName)
                                        .font(.caption2)
                                        .foregroundStyle(.blue)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Workout Settings

struct WorkoutSettingsView: View {
    @Bindable var document: UserDocument

    private let activityTypes = [
        ("strength", "Strength Training", "dumbbell.fill"),
        ("cycling", "Cycling", "bicycle"),
        ("hiit", "HIIT", "bolt.heart.fill"),
        ("running", "Running", "figure.run"),
        ("yoga", "Yoga", "figure.mind.and.body"),
        ("flexibility", "Flexibility", "figure.flexibility"),
        ("other", "Other", "figure.mixed.cardio"),
    ]

    var body: some View {
        Form {
            Section {
                Picker("Activity Type", selection: Binding(
                    get: { document.activityType ?? "other" },
                    set: { document.activityType = $0 }
                )) {
                    ForEach(activityTypes, id: \.0) { type in
                        Label(type.1, systemImage: type.2).tag(type.0)
                    }
                }
            } header: {
                Text("Activity")
            } footer: {
                Text("Maps to Apple HealthKit workout types for future integration.")
            }

            Section("Schedule") {
                Stepper(
                    "Frequency: \(document.weeklyTarget ?? 0)x / week",
                    value: Binding(
                        get: { document.weeklyTarget ?? 0 },
                        set: { document.weeklyTarget = $0 == 0 ? nil : $0 }
                    ),
                    in: 0...7
                )

                Stepper(
                    "Duration: \(document.durationMinutes ?? 0) min",
                    value: Binding(
                        get: { document.durationMinutes ?? 0 },
                        set: { document.durationMinutes = $0 == 0 ? nil : $0 }
                    ),
                    in: 0...180,
                    step: 5
                )
            }

            Section("This Week") {
                let count = document.weekCompletionCount()
                let target = document.weeklyTarget ?? 0

                HStack {
                    Text("Completed")
                    Spacer()
                    Text("\(count)\(target > 0 ? " / \(target)" : "")")
                        .foregroundStyle(target > 0 && count >= target ? .green : .primary)
                        .fontWeight(.medium)
                }

                if !document.completions.isEmpty {
                    let recent = document.completions
                        .sorted { $0.date > $1.date }
                        .prefix(5)
                    ForEach(Array(recent), id: \.id) { completion in
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                            Text(completion.date, format: .dateTime.weekday(.wide).month().day())
                                .font(.subheadline)
                        }
                    }
                }
            }

            Section {
                HStack {
                    Image(systemName: "heart.fill")
                        .foregroundStyle(.red)
                    Text("Apple HealthKit")
                    Spacer()
                    Text("Coming soon")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            } header: {
                Text("Integrations")
            } footer: {
                Text("When connected, workout completions will sync to Apple Health.")
            }
        }
    }
}

#Preview {
    DocsTab()
        .modelContainer(for: [DocFolder.self, UserDocument.self], inMemory: true)
}
