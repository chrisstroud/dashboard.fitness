import Foundation
import SwiftData

@Observable
final class WorkoutManager {
    static let shared = WorkoutManager()

    // State
    var isActive = false
    var isPaused = false
    var activeDocument: UserDocument?
    var startTime: Date?
    var pausedDuration: TimeInterval = 0
    var pauseStart: Date?

    // Computed
    var elapsedTime: TimeInterval {
        guard let start = startTime else { return 0 }
        let active = isPaused ? (pauseStart ?? Date()).timeIntervalSince(start) : Date().timeIntervalSince(start)
        return active - pausedDuration
    }

    var elapsedFormatted: String {
        let total = Int(elapsedTime)
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%02d:%02d", minutes, seconds)
    }

    // Actions
    func startWorkout(document: UserDocument) {
        activeDocument = document
        startTime = Date()
        pausedDuration = 0
        pauseStart = nil
        isPaused = false
        isActive = true
    }

    func pause() {
        guard isActive, !isPaused else { return }
        isPaused = true
        pauseStart = Date()
    }

    func resume() {
        guard isActive, isPaused, let ps = pauseStart else { return }
        pausedDuration += Date().timeIntervalSince(ps)
        pauseStart = nil
        isPaused = false
    }

    func finish(modelContext: ModelContext) -> WorkoutSummary {
        let duration = Int(elapsedTime / 60)
        let doc = activeDocument

        // Save workout completion
        if let doc {
            let completion = WorkoutCompletion(date: Date())
            completion.document = doc
            modelContext.insert(completion)
            try? modelContext.save()
        }

        let summary = WorkoutSummary(
            title: doc?.title ?? "Workout",
            durationMinutes: duration,
            startTime: startTime ?? Date(),
            endTime: Date()
        )

        // Reset
        isActive = false
        isPaused = false
        activeDocument = nil
        startTime = nil
        pausedDuration = 0
        pauseStart = nil

        return summary
    }

    func cancel() {
        isActive = false
        isPaused = false
        activeDocument = nil
        startTime = nil
        pausedDuration = 0
        pauseStart = nil
    }
}

struct WorkoutSummary {
    let title: String
    let durationMinutes: Int
    let startTime: Date
    let endTime: Date
}
