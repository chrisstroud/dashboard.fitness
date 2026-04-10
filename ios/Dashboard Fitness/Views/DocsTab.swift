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

// MARK: - Document View (read + edit with markdown rendering)

struct DocumentView: View {
    @Bindable var document: UserDocument
    @State private var isEditing = false

    var body: some View {
        Group {
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
        }
        .navigationTitle(document.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
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

#Preview {
    DocsTab()
        .modelContainer(for: [DocFolder.self, UserDocument.self], inMemory: true)
}
