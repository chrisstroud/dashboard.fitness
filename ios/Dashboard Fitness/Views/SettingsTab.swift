import SwiftUI

struct SettingsTab: View {
    @State private var displayName = ""
    @State private var email = ""
    @State private var selectedTimezone = TimeZone.current.identifier
    @State private var isLoading = true
    @State private var isSaving = false
    @State private var showSaved = false
    @State private var showSignOutConfirm = false

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
                    HStack(spacing: 14) {
                        ZStack {
                            Circle()
                                .fill(Color.blue.gradient)
                                .frame(width: 48, height: 48)
                            Text(displayName.prefix(1).uppercased())
                                .font(.title3.bold())
                                .foregroundStyle(.white)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            TextField("Display Name", text: $displayName)
                                .font(.body.weight(.medium))
                            TextField("email@example.com", text: $email)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .textContentType(.emailAddress)
                                .keyboardType(.emailAddress)
                                .autocapitalization(.none)
                        }
                    }
                    .padding(.vertical, 4)
                }

                Section {
                    Picker("Time Zone", selection: $selectedTimezone) {
                        ForEach(commonTimezones, id: \.self) { tz in
                            Text(formatTimezone(tz)).tag(tz)
                        }
                    }
                } header: {
                    Text("Time Zone")
                } footer: {
                    Text("Daily protocols are created at midnight in your time zone.")
                }

                Section("Account") {
                    Button(role: .destructive) {
                        showSignOutConfirm = true
                    } label: {
                        HStack {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                            Text("Sign Out")
                        }
                    }
                    .confirmationDialog("Sign Out", isPresented: $showSignOutConfirm) {
                        Button("Sign Out", role: .destructive) {
                            AuthService.shared.signOut()
                        }
                    } message: {
                        Text("Your data is saved on the server and will sync back when you sign in again.")
                    }
                }

                Section {
                    Button(action: { Task { await saveProfile() } }) {
                        HStack {
                            Spacer()
                            if isSaving {
                                ProgressView()
                            } else if showSaved {
                                Label("Saved", systemImage: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                            } else {
                                Text("Save Changes")
                            }
                            Spacer()
                        }
                    }
                    .disabled(isSaving)
                }

                Section {
                    LabeledContent("Version", value: "0.2.0")
                    LabeledContent("Build", value: "1")
                } header: {
                    Text("About")
                }
            }
            .navigationTitle("Settings")
            .task { await loadProfile() }
        }
    }

    private func formatTimezone(_ tz: String) -> String {
        let parts = tz.split(separator: "/")
        if parts.count == 2 {
            return String(parts[1]).replacingOccurrences(of: "_", with: " ")
        }
        return tz.replacingOccurrences(of: "_", with: " ")
    }

    private func authRequest(url: URL) -> URLRequest {
        var req = URLRequest(url: url)
        if let token = AuthService.shared.token {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        return req
    }

    private func loadProfile() async {
        do {
            #if DEBUG
            let url = URL(string: "http://localhost:5001/api/users/me")!
            #else
            let url = URL(string: "https://dashboardfitness-production.up.railway.app/api/users/me")!
            #endif
            let (data, _) = try await URLSession.shared.data(for: authRequest(url: url))
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
        isSaving = true
        do {
            #if DEBUG
            let url = URL(string: "http://localhost:5001/api/users/me")!
            #else
            let url = URL(string: "https://dashboardfitness-production.up.railway.app/api/users/me")!
            #endif
            var request = authRequest(url: url)
            request.httpMethod = "PUT"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONEncoder().encode([
                "display_name": displayName,
                "email": email,
                "timezone": selectedTimezone,
            ])
            let _ = try await URLSession.shared.data(for: request)
            showSaved = true
            try? await Task.sleep(for: .seconds(2))
            showSaved = false
        } catch {}
        isSaving = false
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
