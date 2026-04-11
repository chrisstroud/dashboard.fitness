import SwiftUI

struct CreateProtocolSheet: View {
    let groupId: UUID
    let onSave: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var protocolType: ProtocolType = .task
    @State private var label = ""
    @State private var subtitle = ""
    @State private var activityType: ActivityType = .strength
    @State private var durationMinutes: String = ""
    @State private var weeklyTarget: String = ""
    @State private var isSaving = false

    var body: some View {
        NavigationStack {
            Form {
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
                    Text("Protocol Type")
                }

                // Common fields
                Section("Details") {
                    TextField("Name", text: $label)
                    TextField("Description (optional)", text: $subtitle)

                    if !durationFieldHidden {
                        TextField("Estimated minutes", text: $durationMinutes)
                            .keyboardType(.numberPad)
                    }
                }

                // Workout-specific fields
                if protocolType == .workout {
                    Section("Workout Settings") {
                        Picker("Activity", selection: $activityType) {
                            ForEach(ActivityType.allCases, id: \.self) { type in
                                Label(type.displayName, systemImage: type.icon)
                                    .tag(type)
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
                        .disabled(label.isEmpty || isSaving)
                        .bold()
                }
            }
        }
    }

    private var durationFieldHidden: Bool {
        false  // show for both types
    }

    private func save() {
        isSaving = true

        Task {
            do {
                guard let token = AuthService.shared.token else {
                    isSaving = false
                    return
                }

                #if DEBUG
                let baseURL = "http://localhost:5001"
                #else
                let baseURL = "https://dashboardfitness-production.up.railway.app"
                #endif

                let url = URL(string: "\(baseURL)/api/protocols/groups/\(groupId.uuidString)/protocols")!
                var request = URLRequest(url: url)
                request.httpMethod = "POST"
                request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")

                var body: [String: Any] = [
                    "label": label,
                    "type": protocolType.rawValue,
                ]
                if !subtitle.isEmpty {
                    body["subtitle"] = subtitle
                }
                if let duration = Int(durationMinutes) {
                    body["duration_minutes"] = duration
                }
                if protocolType == .workout {
                    body["activity_type"] = activityType.rawValue
                    if let target = Int(weeklyTarget) {
                        body["weekly_target"] = target
                    }
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
                // Silently fail -- user can retry
            }

            await MainActor.run { isSaving = false }
        }
    }
}

// MARK: - Activity Type

enum ActivityType: String, CaseIterable {
    case strength
    case running
    case cycling
    case hiit
    case yoga
    case flexibility
    case other

    var displayName: String {
        switch self {
        case .strength: "Strength"
        case .running: "Running"
        case .cycling: "Cycling"
        case .hiit: "HIIT"
        case .yoga: "Yoga"
        case .flexibility: "Flexibility"
        case .other: "Other"
        }
    }

    var icon: String {
        switch self {
        case .strength: "figure.strengthtraining.traditional"
        case .running: "figure.run"
        case .cycling: "figure.outdoor.cycle"
        case .hiit: "figure.highintensity.intervaltraining"
        case .yoga: "figure.yoga"
        case .flexibility: "figure.flexibility"
        case .other: "figure.mixed.cardio"
        }
    }
}

#Preview {
    CreateProtocolSheet(groupId: UUID()) {}
}
