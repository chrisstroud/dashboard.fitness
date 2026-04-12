import SwiftUI

// MARK: - Habit Stack Header

/// Shared header for habit stack cards on both My Protocols and Daily Today pages.
/// Shows stack name and optional completion progress.
struct HabitStackHeader: View {
    let name: String
    let completedCount: Int
    let totalCount: Int
    var showCompletion: Bool = true
    var showRing: Bool = false
    var isCollapsed: Bool = false
    var onToggleCollapse: (() -> Void)? = nil
    var onMarkAllComplete: (() -> Void)? = nil

    private var allCompleted: Bool { totalCount > 0 && completedCount == totalCount }

    var body: some View {
        HStack(alignment: .center, spacing: 4) {
            collapseArea
            Spacer()
            if showRing && totalCount > 0 {
                markCompleteRing
            }
        }
        .padding(.horizontal, 4)
        .padding(.top, 8)
        .padding(.bottom, 2)
    }

    // MARK: - Collapse Area

    @ViewBuilder
    private var collapseArea: some View {
        let label = HStack(spacing: 4) {
            if onToggleCollapse != nil {
                Image(systemName: "chevron.right")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.tertiary)
                    .rotationEffect(.degrees(isCollapsed ? 0 : 90))
                    .animation(.easeInOut(duration: 0.2), value: isCollapsed)
            }

            Text(name.uppercased())
                .font(.caption2.bold())
                .foregroundStyle(.secondary)
                .tracking(0.6)

            completionBadge
        }

        if let action = onToggleCollapse {
            Button(action: action) {
                label.contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        } else {
            label
        }
    }

    // MARK: - Completion Badge

    @ViewBuilder
    private var completionBadge: some View {
        if showCompletion {
            if totalCount == 0 {
                EmptyView()
            } else if allCompleted {
                HStack(spacing: 2) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption2)
                        .foregroundStyle(.green)
                    Text("All done")
                        .font(.caption2)
                        .foregroundStyle(.green)
                }
            } else {
                Text("\(completedCount)/\(totalCount)")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.tertiary)
            }
        } else if totalCount > 0 {
            Text("\(totalCount)")
                .font(.caption2.monospacedDigit())
                .foregroundStyle(.tertiary)
        }
    }

    // MARK: - Mark Complete Ring

    @ViewBuilder
    private var markCompleteRing: some View {
        let ring = ZStack {
            Circle()
                .stroke(Color(.systemGray5), lineWidth: 2)
            Circle()
                .trim(from: 0, to: Double(completedCount) / Double(max(totalCount, 1)))
                .stroke(.green, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.3), value: completedCount)
        }
        .frame(width: 20, height: 20)

        if let action = onMarkAllComplete {
            Button(action: action) {
                ring.frame(width: 32, height: 32)
            }
            .buttonStyle(.borderless)
        } else {
            ring
        }
    }
}

// MARK: - Empty Stack Placeholder

/// Placeholder shown when a stack has no protocols.
struct EmptyStackPlaceholder: View {
    var body: some View {
        HStack {
            Spacer()
            Text("No protocols — tap + to add one")
                .font(.caption)
                .foregroundStyle(.tertiary)
            Spacer()
        }
        .padding(.vertical, 12)
    }
}

// MARK: - Single-Stack Collapsing Helper

/// Returns true when the stack header should be hidden because the section has
/// only one stack with the same name as the section.
func shouldCollapseStack(sectionName: String, stackName: String, stackCount: Int) -> Bool {
    stackCount == 1 && stackName == sectionName
}

// MARK: - Previews

#Preview("Stack with protocols") {
    VStack(alignment: .leading) {
        HabitStackHeader(name: "Wake Up", completedCount: 2, totalCount: 4)
        Divider()
        Text("  Protocol rows would go here...")
            .font(.caption)
            .foregroundStyle(.tertiary)
            .padding(.vertical, 8)
    }
    .padding(.horizontal, 12)
    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    .padding()
}

#Preview("Completed stack") {
    VStack(alignment: .leading) {
        HabitStackHeader(name: "Mindset", completedCount: 3, totalCount: 3)
    }
    .padding(.horizontal, 12)
    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    .padding()
}

#Preview("Stack with ring") {
    VStack(alignment: .leading) {
        HabitStackHeader(name: "Wake Up", completedCount: 2, totalCount: 5, showRing: true)
    }
    .padding(.horizontal, 12)
    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    .padding()
}

#Preview("My Protocols mode (count only)") {
    VStack(alignment: .leading) {
        HabitStackHeader(name: "Wake Up", completedCount: 0, totalCount: 4, showCompletion: false)
    }
    .padding(.horizontal, 12)
    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    .padding()
}

#Preview("Empty stack") {
    VStack(alignment: .leading) {
        HabitStackHeader(name: "New Stack", completedCount: 0, totalCount: 0)
        EmptyStackPlaceholder()
    }
    .padding(.horizontal, 12)
    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    .padding()
}
