import SwiftUI
import SwiftData
import Combine

struct ContentView: View {
    @State private var showActiveWorkout = false

    var body: some View {
        ZStack(alignment: .bottom) {
            TabView {
                Tab("Today", systemImage: "checkmark.square") {
                    HomeTab()
                }
                Tab("History", systemImage: "calendar") {
                    HistoryTab()
                }
                Tab("Settings", systemImage: "gear") {
                    SettingsTab()
                }
            }

            // Floating workout bar
            if WorkoutManager.shared.isActive && !showActiveWorkout {
                ActiveWorkoutBar {
                    showActiveWorkout = true
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 52)  // above tab bar
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .fullScreenCover(isPresented: $showActiveWorkout) {
            if let doc = WorkoutManager.shared.activeDocument {
                NavigationStack {
                    ActiveWorkoutView(document: doc)
                }
            } else {
                VStack(spacing: 16) {
                    Text("No active workout")
                        .font(.headline)
                    Button("Dismiss") { showActiveWorkout = false }
                        .buttonStyle(.bordered)
                }
            }
        }
    }
}

// MARK: - Floating Mini Bar

struct ActiveWorkoutBar: View {
    let onTap: () -> Void

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    @State private var tick = false

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Pulsing dot
                Circle()
                    .fill(.green)
                    .frame(width: 8, height: 8)
                    .scaleEffect(tick ? 1.2 : 0.8)
                    .animation(.easeInOut(duration: 1).repeatForever(), value: tick)

                VStack(alignment: .leading, spacing: 1) {
                    Text(WorkoutManager.shared.activeDocument?.title ?? "Workout")
                        .font(.subheadline.weight(.semibold))
                    Text("In Progress")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                let _ = tick
                Text(WorkoutManager.shared.elapsedFormatted)
                    .font(.system(size: 17, weight: .bold, design: .monospaced))
                    .foregroundStyle(.green)

                Image(systemName: "chevron.up")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(.ultraThickMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .shadow(color: .black.opacity(0.1), radius: 8, y: 4)
        }
        .buttonStyle(.plain)
        .onReceive(timer) { _ in tick.toggle() }
        .onAppear { tick = true }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [
            DailyInstance.self,
            ProtocolSection.self,
            DocFolder.self,
            UserDocument.self,
        ], inMemory: true)
}
