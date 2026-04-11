import SwiftUI
import SwiftData

struct CreateProtocolSheet: View {
    /// Pre-selected section (nil = show picker, user chooses)
    var initialSection: ProtocolSection?
    /// Pre-selected stack (nil = auto-select first in section)
    var initialStack: ProtocolGroup?
    let onSave: () -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ProtocolSection.position) private var sections: [ProtocolSection]

    @State private var selectedSectionId: UUID?
    @State private var selectedGroupId: UUID?
    @State private var protocolType: ProtocolType = .task
    @State private var label = ""
    @State private var subtitle = ""
    @State private var activityType: ActivityType = .traditionalStrength
    @State private var durationMinutes: String = ""
    @State private var weeklyTarget: String = ""
    @State private var isSaving = false

    private var selectedSection: ProtocolSection? {
        sections.first { $0.id == selectedSectionId }
    }

    private var selectedGroup: ProtocolGroup? {
        selectedSection?.groups.first { $0.id == selectedGroupId }
    }

    private var sectionHasMultipleStacks: Bool {
        (selectedSection?.groups.count ?? 0) > 1
    }

    var body: some View {
        NavigationStack {
            Form {
                // Section + stack picker
                if initialSection == nil {
                    Section("Add to") {
                        Picker("Section", selection: $selectedSectionId) {
                            ForEach(sections) { section in
                                Text(section.name).tag(section.id as UUID?)
                            }
                        }
                        .pickerStyle(.menu)
                        .onChange(of: selectedSectionId) { _, newValue in
                            if let section = sections.first(where: { $0.id == newValue }) {
                                selectedGroupId = section.sortedGroups.first?.id
                            }
                        }

                        // Stack picker — only when section has multiple stacks
                        if sectionHasMultipleStacks && initialStack == nil {
                            Picker("Habit Stack", selection: $selectedGroupId) {
                                ForEach(selectedSection?.sortedGroups ?? []) { group in
                                    Text(group.name).tag(group.id as UUID?)
                                }
                            }
                            .pickerStyle(.menu)
                        }
                    }
                }

                // Type picker
                Section {
                    Picker("Type", selection: $protocolType) {
                        Label("Task", systemImage: "checkmark.circle")
                            .tag(ProtocolType.task)
                        Label("Workout", systemImage: "figure.strengthtraining.traditional")
                            .tag(ProtocolType.workout)
                    }
                    .pickerStyle(.segmented)
                } header: {
                    Text("Type")
                }

                // Common fields
                Section("Details") {
                    TextField("Name", text: $label)
                    TextField("Description (optional)", text: $subtitle)
                    TextField("Estimated minutes", text: $durationMinutes)
                        .keyboardType(.numberPad)
                }

                // Workout-specific fields
                if protocolType == .workout {
                    Section("Activity") {
                        Picker("Activity Type", selection: $activityType) {
                            ForEach(ActivityType.grouped, id: \.name) { group in
                                SwiftUI.Section(group.name) {
                                    ForEach(group.types, id: \.self) { type in
                                        Label(type.displayName, systemImage: type.icon)
                                            .tag(type)
                                    }
                                }
                            }
                        }

                        TextField("Times per week", text: $weeklyTarget)
                            .keyboardType(.numberPad)
                    }
                }
            }
            .navigationTitle("New Protocol")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(label.isEmpty || selectedSection == nil || isSaving)
                        .bold()
                }
            }
            .onAppear {
                selectedSectionId = initialSection?.id ?? sections.first?.id
                selectedGroupId = initialStack?.id ?? selectedSection?.sortedGroups.first?.id
            }
        }
    }

    // MARK: - Save

    private func save() {
        guard let section = selectedSection else { return }
        isSaving = true

        // Use selected group, or fall back to first group in section
        let group: ProtocolGroup
        if let selected = selectedGroup {
            group = selected
        } else if let existing = section.groups.first {
            group = existing
        } else {
            let newGroup = ProtocolGroup(name: section.name, position: 0)
            newGroup.section = section
            modelContext.insert(newGroup)
            group = newGroup
        }

        Task {
            do {
                guard let token = AuthService.shared.token else {
                    await MainActor.run { isSaving = false }
                    return
                }

                #if DEBUG
                let baseURL = "http://localhost:5001"
                #else
                let baseURL = "https://dashboardfitness-production.up.railway.app"
                #endif

                // Push all local sections to the server so sync doesn't delete them
                try await ensureAllSectionsExist(baseURL: baseURL, token: token)

                // Create the protocol
                let url = URL(string: "\(baseURL)/api/protocols/groups/\(group.id.uuidString)/protocols")!
                var request = URLRequest(url: url)
                request.httpMethod = "POST"
                request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")

                var body: [String: Any] = [
                    "label": label,
                    "type": protocolType.rawValue,
                ]
                if !subtitle.isEmpty { body["subtitle"] = subtitle }
                if let duration = Int(durationMinutes) { body["duration_minutes"] = duration }
                if protocolType == .workout {
                    body["activity_type"] = activityType.rawValue
                    if let target = Int(weeklyTarget) { body["weekly_target"] = target }
                }

                request.httpBody = try JSONSerialization.data(withJSONObject: body)
                let (_, response) = try await URLSession.shared.data(for: request)

                if let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) {
                    await MainActor.run {
                        onSave()
                        dismiss()
                    }
                }
            } catch {
                // Silently fail — user can retry
            }

            await MainActor.run { isSaving = false }
        }
    }

    /// Push ALL local sections and their default groups to the server (idempotent).
    /// This prevents syncAll from deleting sections that only exist locally.
    private func ensureAllSectionsExist(baseURL: String, token: String) async throws {
        for section in sections {
            // Ensure section
            var sectionReq = URLRequest(url: URL(string: "\(baseURL)/api/protocols/sections")!)
            sectionReq.httpMethod = "POST"
            sectionReq.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            sectionReq.setValue("application/json", forHTTPHeaderField: "Content-Type")
            sectionReq.httpBody = try JSONSerialization.data(withJSONObject: [
                "id": section.id.uuidString, "name": section.name, "position": section.position,
            ])
            let _ = try? await URLSession.shared.data(for: sectionReq)

            // Ensure each group in this section
            for group in section.groups {
                var groupReq = URLRequest(url: URL(string: "\(baseURL)/api/protocols/sections/\(section.id.uuidString)/groups")!)
                groupReq.httpMethod = "POST"
                groupReq.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                groupReq.setValue("application/json", forHTTPHeaderField: "Content-Type")
                groupReq.httpBody = try JSONSerialization.data(withJSONObject: [
                    "id": group.id.uuidString, "name": group.name, "position": group.position,
                ])
                let _ = try? await URLSession.shared.data(for: groupReq)
            }
        }
    }
}

// MARK: - Activity Type (aligned with HKWorkoutActivityType)

struct ActivityTypeGroup {
    let name: String
    let types: [ActivityType]
}

enum ActivityType: String, CaseIterable, Hashable {
    // Strength & Resistance
    case traditionalStrength = "traditional_strength_training"
    case functionalStrength = "functional_strength_training"
    case coreTraining = "core_training"
    case crossTraining = "cross_training"

    // Cardio
    case running
    case walking
    case hiking
    case cycling
    case indoorCycling = "indoor_cycling"
    case swimming
    case rowing
    case elliptical
    case stairClimbing = "stair_climbing"
    case jumpRope = "jump_rope"

    // HIIT & Classes
    case hiit = "high_intensity_interval_training"
    case dance
    case barre
    case kickboxing

    // Mind-Body & Flexibility
    case yoga
    case pilates
    case flexibility
    case mindAndBody = "mind_and_body"
    case cooldown

    // Sports
    case basketball
    case soccer
    case tennis
    case golf
    case pickleball
    case martialArts = "martial_arts"

    // Other
    case mixedCardio = "mixed_cardio"
    case other

    static var grouped: [ActivityTypeGroup] {
        [
            ActivityTypeGroup(name: "Strength", types: [
                .traditionalStrength, .functionalStrength, .coreTraining, .crossTraining,
            ]),
            ActivityTypeGroup(name: "Cardio", types: [
                .running, .walking, .hiking, .cycling, .indoorCycling,
                .swimming, .rowing, .elliptical, .stairClimbing, .jumpRope,
            ]),
            ActivityTypeGroup(name: "HIIT & Classes", types: [
                .hiit, .dance, .barre, .kickboxing,
            ]),
            ActivityTypeGroup(name: "Mind-Body", types: [
                .yoga, .pilates, .flexibility, .mindAndBody, .cooldown,
            ]),
            ActivityTypeGroup(name: "Sports", types: [
                .basketball, .soccer, .tennis, .golf, .pickleball, .martialArts,
            ]),
            ActivityTypeGroup(name: "Other", types: [
                .mixedCardio, .other,
            ]),
        ]
    }

    var displayName: String {
        switch self {
        case .traditionalStrength: "Strength Training"
        case .functionalStrength: "Functional Strength"
        case .coreTraining: "Core Training"
        case .crossTraining: "Cross Training"
        case .running: "Running"
        case .walking: "Walking"
        case .hiking: "Hiking"
        case .cycling: "Cycling"
        case .indoorCycling: "Indoor Cycling"
        case .swimming: "Swimming"
        case .rowing: "Rowing"
        case .elliptical: "Elliptical"
        case .stairClimbing: "Stair Climbing"
        case .jumpRope: "Jump Rope"
        case .hiit: "HIIT"
        case .dance: "Dance"
        case .barre: "Barre"
        case .kickboxing: "Kickboxing"
        case .yoga: "Yoga"
        case .pilates: "Pilates"
        case .flexibility: "Flexibility"
        case .mindAndBody: "Mind & Body"
        case .cooldown: "Cooldown"
        case .basketball: "Basketball"
        case .soccer: "Soccer"
        case .tennis: "Tennis"
        case .golf: "Golf"
        case .pickleball: "Pickleball"
        case .martialArts: "Martial Arts"
        case .mixedCardio: "Mixed Cardio"
        case .other: "Other"
        }
    }

    var icon: String {
        switch self {
        case .traditionalStrength: "figure.strengthtraining.traditional"
        case .functionalStrength: "figure.strengthtraining.functional"
        case .coreTraining: "figure.core.training"
        case .crossTraining: "figure.cross.training"
        case .running: "figure.run"
        case .walking: "figure.walk"
        case .hiking: "figure.hiking"
        case .cycling: "figure.outdoor.cycle"
        case .indoorCycling: "figure.indoor.cycle"
        case .swimming: "figure.pool.swim"
        case .rowing: "figure.rower"
        case .elliptical: "figure.elliptical"
        case .stairClimbing: "figure.stair.stepper"
        case .jumpRope: "figure.jumprope"
        case .hiit: "figure.highintensity.intervaltraining"
        case .dance: "figure.dance"
        case .barre: "figure.barre"
        case .kickboxing: "figure.kickboxing"
        case .yoga: "figure.yoga"
        case .pilates: "figure.pilates"
        case .flexibility: "figure.flexibility"
        case .mindAndBody: "figure.mind.and.body"
        case .cooldown: "figure.cooldown"
        case .basketball: "figure.basketball"
        case .soccer: "figure.soccer"
        case .tennis: "figure.tennis"
        case .golf: "figure.golf"
        case .pickleball: "figure.pickleball"
        case .martialArts: "figure.martial.arts"
        case .mixedCardio: "figure.mixed.cardio"
        case .other: "figure.mixed.cardio"
        }
    }
}

#Preview {
    CreateProtocolSheet(onSave: {})
        .modelContainer(for: ProtocolSection.self, inMemory: true)
}
