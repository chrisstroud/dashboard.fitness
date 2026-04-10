# Product Roadmap -- dashboard.fitness

**Last Updated:** 2026-04-10

---

## North Star

Personal health operating system. One place to see training, recovery, nutrition, and biomarkers -- all connected, all actionable.

---

## Now (Q2 2026)

**Foundation -- iOS App + Flask API**

- [x] Stack decision: SwiftUI + SwiftData (iOS) + Flask + PostgreSQL (Railway)
- [ ] Railway project setup (Flask API scaffold, PostgreSQL provisioned)
- [ ] Core data model designed (workouts, exercises, sets, metrics)
- [ ] iOS project scaffold (Xcode project, SwiftData models, basic navigation)
- [ ] Manual workout logging (enter sets/reps/weight on phone)
- [ ] Daily generation pipeline continues working (existing, no changes needed)

Running locally via Xcode free provisioning. Apple Developer fee deferred until TestFlight needed.

---

## Next (Q3 2026)

**Core App**

- Workout tracking with progression charts
- Weight trend visualization
- Supplement schedule in-app
- Training program cycle management
- Apple Developer fee + TestFlight (when ready)

---

## Later (Q4 2026+)

**Integrations & Expansion**

- Wearable integration (Apple Watch HealthKit or Whoop API -- TBD)
- Bloodwork panel tracking with optimal ranges
- Push notifications (training reminders, supplement timing)
- Historical trend analysis (month-over-month, year-over-year)
- Multi-user support
- Goal setting and progress tracking
- Nutrition macro tracking integration
- Sleep quality correlation with training performance

---

## Not Planned

- Social features or sharing
- Coaching marketplace
- Exercise video library
- Meal planning or recipe database
- Supplement purchasing or affiliate links

---

## Review Cadence

Quarterly, or when a major feature ships. Update this file to reflect what shipped, what moved, and what changed priority.
