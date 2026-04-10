import SwiftUI

struct SettingsTab: View {
    @State private var displayName = ""
    @State private var email = ""
    @State private var selectedTimezone = TimeZone.current.identifier
    @State private var isLoading = true

    private let commonTimezones = [
        "America/New_York", "America/Chicago", "America/Denver",
        "America/Los_Angeles", "America/Phoenix",
        "Europe/London", "Europe/Paris", "Europe/Berlin",
        "Asia/Tokyo", "Asia/Shanghai", "Australia/Sydney",
        "Pacific/Honolulu",
    ]

    var body: some View {
        NavigationStack {
            Form {
                Section("Profile") {
                    TextField("Display Name", text: $displayName)
                    TextField("Email", text: $email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                }

                Section("Time Zone") {
                    Picker("Time Zone", selection: $selectedTimezone) {
                        ForEach(commonTimezones, id: \.self) { tz in
                            Text(tz.replacingOccurrences(of: "_", with: " "))
                                .tag(tz)
                        }
                    }
                    Text("Daily protocols are created at midnight in your time zone.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Account") {
                    Label("Sign in with Apple", systemImage: "person.crop.circle")
                        .foregroundStyle(.secondary)
                }

                Section("About") {
                    LabeledContent("Version", value: "0.2.0")
                }

                Section {
                    Button("Save Changes") {
                        Task { await saveProfile() }
                    }
                }
            }
            .navigationTitle("Settings")
            .task { await loadProfile() }
        }
    }

    private func loadProfile() async {
        do {
            #if DEBUG
            let url = URL(string: "http://localhost:5001/api/users/me")!
            #else
            let url = URL(string: "https://dashboard-fitness-api.up.railway.app/api/users/me")!
            #endif
            let (data, _) = try await URLSession.shared.data(from: url)
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            let profile = try decoder.decode(UserProfile.self, from: data)
            displayName = profile.displayName ?? ""
            email = profile.email ?? ""
            selectedTimezone = profile.timezone
        } catch {}
        isLoading = false
    }

    private func saveProfile() async {
        do {
            #if DEBUG
            let url = URL(string: "http://localhost:5001/api/users/me")!
            #else
            let url = URL(string: "https://dashboard-fitness-api.up.railway.app/api/users/me")!
            #endif
            var request = URLRequest(url: url)
            request.httpMethod = "PUT"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            let body: [String: String] = [
                "display_name": displayName,
                "email": email,
                "timezone": selectedTimezone,
            ]
            request.httpBody = try JSONEncoder().encode(body)
            let _ = try await URLSession.shared.data(for: request)
        } catch {}
    }
}

private struct UserProfile: Decodable {
    let displayName: String?
    let email: String?
    let timezone: String
}

#Preview {
    SettingsTab()
}
