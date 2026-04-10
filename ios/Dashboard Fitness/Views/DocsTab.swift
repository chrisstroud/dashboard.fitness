import SwiftUI
import SwiftData

struct DocsTab: View {
    @Query(sort: \UserDocument.updatedAt, order: .reverse) private var documents: [UserDocument]
    @Environment(\.modelContext) private var modelContext
    @State private var showingNewDoc = false

    private var grouped: [(String, [UserDocument])] {
        let dict = Dictionary(grouping: documents) { $0.category ?? "Uncategorized" }
        return dict.sorted { $0.key < $1.key }
    }

    var body: some View {
        NavigationStack {
            Group {
                if documents.isEmpty {
                    ContentUnavailableView(
                        "No Documents",
                        systemImage: "doc.text",
                        description: Text("Tap + to create your first document")
                    )
                } else {
                    List {
                        ForEach(grouped, id: \.0) { category, docs in
                            Section(category) {
                                ForEach(docs) { doc in
                                    NavigationLink(value: doc) {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(doc.title)
                                                .font(.body)
                                            Text(doc.updatedAt, format: .dateTime.month().day().year())
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                }
                                .onDelete { offsets in
                                    for offset in offsets {
                                        modelContext.delete(docs[offset])
                                    }
                                }
                            }
                        }
                    }
                    .navigationDestination(for: UserDocument.self) { doc in
                        DocEditorView(document: doc)
                    }
                }
            }
            .navigationTitle("Docs")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: { showingNewDoc = true }) {
                        Label("New Document", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingNewDoc) {
                NewDocView()
            }
        }
    }
}

// MARK: - New Document

struct NewDocView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var category = "notes"

    private let categories = ["training", "nutrition", "research", "notes"]

    var body: some View {
        NavigationStack {
            Form {
                TextField("Title", text: $title)
                Picker("Category", selection: $category) {
                    ForEach(categories, id: \.self) { cat in
                        Text(cat.capitalized).tag(cat)
                    }
                }
            }
            .navigationTitle("New Document")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        let doc = UserDocument(title: title, category: category)
                        modelContext.insert(doc)
                        dismiss()
                    }
                    .disabled(title.isEmpty)
                }
            }
        }
    }
}

// MARK: - Document Editor

struct DocEditorView: View {
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
                    Text(document.content.isEmpty ? "Empty document. Tap Edit to start writing." : document.content)
                        .font(.body)
                        .foregroundStyle(document.content.isEmpty ? .secondary : .primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
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
        .modelContainer(for: UserDocument.self, inMemory: true)
}
