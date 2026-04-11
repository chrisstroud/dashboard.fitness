# Story 3.1: Protocol Analytics Card + Calendar Heatmap

**Epic:** [Epic 3: Protocol Detail View](../epics/epic-3-protocol-detail.md)
**Status:** Not Started
**Points:** 3

---

## User Story

**As a** user viewing a protocol's detail page
**I want to** see my streak, completion rate, and a visual calendar of my history
**So that** I can understand my consistency at a glance

---

## Acceptance Criteria

- [ ] **AC1:** Analytics card shows current streak with flame icon and count
- [ ] **AC2:** Analytics card shows longest streak (smaller, secondary)
- [ ] **AC3:** Analytics card shows 7-day and 30-day completion rate as percentage pills
- [ ] **AC4:** Calendar heatmap shows last 30 days as a grid of colored squares (green=done, orange=skipped, gray=missed, no fill=future)
- [ ] **AC5:** Components work with zero completions (empty state)
- [ ] **AC6:** SwiftUI previews render with hardcoded data for multiple scenarios

---

## Technical Context

### New Files to Create
| File | Purpose |
|------|---------|
| `ios/Dashboard Fitness/Views/ProtocolAnalyticsCard.swift` | Streak display + rate pills + heatmap container |
| `ios/Dashboard Fitness/Views/CalendarHeatmap.swift` | 30-day grid of completion status squares |

### Implementation Guidance

**ProtocolAnalyticsCard:**
```swift
struct ProtocolAnalyticsCard: View {
    let currentStreak: Int
    let longestStreak: Int
    let rate7d: Double   // 0.0 - 1.0
    let rate30d: Double
    let history: [DayStatus]  // for heatmap
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Streak row
            HStack {
                Image(systemName: "flame.fill").foregroundStyle(.orange)
                Text("\(currentStreak) day streak")
                Spacer()
                Text("Best: \(longestStreak)").font(.caption).foregroundStyle(.secondary)
            }
            // Rate pills
            HStack(spacing: 8) {
                RatePill(label: "7d", rate: rate7d)
                RatePill(label: "30d", rate: rate30d)
                Spacer()
            }
            // Heatmap
            CalendarHeatmap(history: history)
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, 16)
    }
}
```

**CalendarHeatmap:** 7-column grid (Mon-Sun), 4-5 rows, each cell is a small rounded square. Color based on status. Use `LazyVGrid` with fixed 7 columns.

**Data flow:** Fetch from `GET /api/protocols/{id}/analytics` on view appear. History from `GET /api/protocols/{id}/history?limit=30`.

### Patterns to Follow
- Card styling: match `CollapsibleGroupCard` — `.regularMaterial`, rounded rectangle
- Color system: green (completed), orange (skipped), `Color(.systemGray5)` (missed), clear (future)

---

## Dependencies

### Blocked By
- Story 2.2: Analytics endpoint

### Can Parallel With
- Story 3.2 (documents section — no shared files)

---

## Definition of Done

- [ ] All acceptance criteria met
- [ ] SwiftUI previews: empty state, short streak (3d), long streak (30d+), mixed history
- [ ] File size < 300 lines per file
