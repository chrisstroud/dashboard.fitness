import SwiftUI
import SwiftData
import Combine

struct ActiveWorkoutView: View {
    @Bindable var document: UserDocument
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var isEditing = false
    @State private var showFinishConfirm = false
    @State private var showCancelConfirm = false
    @State private var summary: WorkoutSummary?

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    @State private var tick = false  // forces view refresh every second

    var body: some View {
        if let summary {
            WorkoutSummaryView(summary: summary, dismiss: { dismiss() })
        } else {
            workoutContent
        }
    }

    private var workoutContent: some View {
        VStack(spacing: 0) {
            // Sticky timer header
            timerHeader

            // Doc content
            if isEditing {
                TextEditor(text: $document.content)
                    .font(.body.monospaced())
                    .padding(.horizontal, 8)
            } else {
                ScrollView {
                    MarkdownView(content: document.content)
                        .padding()
                }
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Cancel") { showCancelConfirm = true }
                    .foregroundStyle(.red)
            }
            ToolbarItem(placement: .primaryAction) {
                Button(isEditing ? "Done" : "Edit") {
                    if isEditing { document.updatedAt = Date() }
                    isEditing.toggle()
                }
            }
        }
        .onReceive(timer) { _ in tick.toggle() }
        .confirmationDialog("Cancel Workout?", isPresented: $showCancelConfirm) {
            Button("Cancel Workout", role: .destructive) {
                WorkoutManager.shared.cancel()
                dismiss()
            }
            Button("Keep Going", role: .cancel) {}
        } message: {
            Text("Your workout progress will be lost.")
        }
        .confirmationDialog("Finish Workout?", isPresented: $showFinishConfirm) {
            Button("Finish") {
                let result = WorkoutManager.shared.finish(modelContext: modelContext)
                withAnimation { summary = result }
            }
            Button("Keep Going", role: .cancel) {}
        } message: {
            Text("Save this workout session?")
        }
    }

    private var timerHeader: some View {
        VStack(spacing: 8) {
            // Timer
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(document.title)
                        .font(.headline)
                    if let type = document.activityType {
                        Text(type.capitalized)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                // Elapsed time
                let _ = tick  // subscribe to tick for refresh
                Text(WorkoutManager.shared.elapsedFormatted)
                    .font(.system(size: 36, weight: .bold, design: .monospaced))
                    .foregroundStyle(WorkoutManager.shared.isPaused ? .orange : .primary)
                    .contentTransition(.numericText())
            }

            // Controls
            HStack(spacing: 16) {
                // Pause/Resume
                Button(action: {
                    if WorkoutManager.shared.isPaused {
                        WorkoutManager.shared.resume()
                    } else {
                        WorkoutManager.shared.pause()
                    }
                }) {
                    Label(
                        WorkoutManager.shared.isPaused ? "Resume" : "Pause",
                        systemImage: WorkoutManager.shared.isPaused ? "play.fill" : "pause.fill"
                    )
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color(.tertiarySystemBackground), in: RoundedRectangle(cornerRadius: 10))
                }

                // Finish
                Button(action: { showFinishConfirm = true }) {
                    Label("Finish", systemImage: "checkmark.circle.fill")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color.green.opacity(0.15), in: RoundedRectangle(cornerRadius: 10))
                        .foregroundStyle(.green)
                }
            }

            // Future: Heart rate + calories row
            // HStack { heartRate, calories, distance }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
    }
}

// MARK: - Workout Summary

struct WorkoutSummaryView: View {
    let summary: WorkoutSummary
    let dismiss: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(.green)

            Text("Workout Complete!")
                .font(.title.bold())

            // Stats
            VStack(spacing: 12) {
                SummaryRow(icon: "dumbbell.fill", label: summary.title, value: "")
                SummaryRow(icon: "clock.fill", label: "Duration", value: "\(summary.durationMinutes) min")
                SummaryRow(icon: "calendar", label: "Started", value: summary.startTime.formatted(date: .omitted, time: .shortened))
                SummaryRow(icon: "flag.checkered", label: "Finished", value: summary.endTime.formatted(date: .omitted, time: .shortened))
            }
            .padding(20)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .padding(.horizontal, 24)

            Spacer()

            Button(action: dismiss) {
                Text("Done")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.blue, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 20)
        }
        .background(Color(.systemGroupedBackground))
        .navigationBarBackButtonHidden(true)
    }
}

struct SummaryRow: View {
    let icon: String
    let label: String
    let value: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.body)
                .foregroundStyle(.blue)
                .frame(width: 24)
            Text(label)
                .font(.body)
            Spacer()
            if !value.isEmpty {
                Text(value)
                    .font(.body.weight(.medium))
                    .foregroundStyle(.secondary)
            }
        }
    }
}

#Preview {
    NavigationStack {
        ActiveWorkoutView(document: UserDocument(title: "Bench Day", content: "# Bench Day\n\n## Strength\n- Bench Press\n- Incline DB"))
    }
}
