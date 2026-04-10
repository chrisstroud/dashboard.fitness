import SwiftUI
import SwiftData

struct MetricsTab: View {
    @Query(sort: \BodyWeight.date, order: .reverse) private var weights: [BodyWeight]
    @Environment(\.modelContext) private var modelContext
    @State private var showingAddWeight = false

    var body: some View {
        NavigationStack {
            Group {
                if weights.isEmpty {
                    ContentUnavailableView(
                        "No Weigh-Ins",
                        systemImage: "scalemass",
                        description: Text("Tap + to log your weight")
                    )
                } else {
                    List {
                        if let latest = weights.first {
                            Section("Current") {
                                HStack {
                                    Text("\(latest.weight, specifier: "%.1f") lbs")
                                        .font(.largeTitle.bold())
                                    Spacer()
                                    Text(latest.date, format: .dateTime.month().day())
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }

                        Section("History") {
                            ForEach(weights) { entry in
                                HStack {
                                    Text(entry.date, format: .dateTime.month().day().year())
                                    Spacer()
                                    Text("\(entry.weight, specifier: "%.1f") lbs")
                                        .monospacedDigit()
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Metrics")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: { showingAddWeight = true }) {
                        Label("Log Weight", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddWeight) {
                AddWeightView()
            }
        }
    }
}

struct AddWeightView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var weight: Double = 170.0
    @State private var date = Date()

    var body: some View {
        NavigationStack {
            Form {
                DatePicker("Date", selection: $date, displayedComponents: .date)

                HStack {
                    Text("Weight")
                    Spacer()
                    TextField("lbs", value: $weight, format: .number.precision(.fractionLength(1)))
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 80)
                    Text("lbs")
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Log Weight")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let entry = BodyWeight(date: date, weight: weight)
                        modelContext.insert(entry)
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    MetricsTab()
        .modelContainer(for: BodyWeight.self, inMemory: true)
}
