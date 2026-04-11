import AuthenticationServices
import Foundation

@Observable
final class AuthService {
    static let shared = AuthService()

    private(set) var isAuthenticated = false
    private(set) var token: String?

    private let tokenKey = "auth_token"

    init() {
        token = KeychainHelper.load(key: tokenKey)
        isAuthenticated = token != nil
    }

    // MARK: - Sign In with Apple

    func signInWithApple(authorization: ASAuthorization) async throws {
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
              let tokenData = credential.identityToken,
              let identityToken = String(data: tokenData, encoding: .utf8)
        else {
            throw AuthError.invalidCredential
        }

        var body: [String: Any] = ["identity_token": identityToken]
        if let givenName = credential.fullName?.givenName {
            body["first_name"] = givenName
        }
        if let familyName = credential.fullName?.familyName {
            body["last_name"] = familyName
        }

        #if DEBUG
        let url = URL(string: "http://localhost:5001/api/auth/apple")!
        #else
        let url = URL(string: "https://dashboardfitness-production.up.railway.app/api/auth/apple")!
        #endif

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw AuthError.serverError
        }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let result = try decoder.decode(AuthResponse.self, from: data)

        KeychainHelper.save(key: tokenKey, value: result.token)
        token = result.token
        isAuthenticated = true
    }

    // MARK: - Dev Sign In (DEBUG only)

    #if DEBUG
    func devSignIn() async throws {
        let url = URL(string: "http://localhost:5001/api/auth/dev")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: [:] as [String: String])

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw AuthError.serverError
        }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let result = try decoder.decode(AuthResponse.self, from: data)

        KeychainHelper.save(key: tokenKey, value: result.token)
        token = result.token
        isAuthenticated = true
    }
    #endif

    // MARK: - Sign Out

    func signOut() {
        KeychainHelper.delete(key: tokenKey)
        token = nil
        isAuthenticated = false
    }
}

// MARK: - Errors

enum AuthError: LocalizedError {
    case invalidCredential
    case serverError

    var errorDescription: String? {
        switch self {
        case .invalidCredential: return "Invalid Apple credential"
        case .serverError: return "Could not sign in. Please try again."
        }
    }
}

// MARK: - API Response

private struct AuthResponse: Decodable {
    let token: String
    let user: AuthUser
}

private struct AuthUser: Decodable {
    let id: String
    let displayName: String?
    let email: String?
    let timezone: String
}

// MARK: - Keychain Helper

enum KeychainHelper {
    static func save(key: String, value: String) {
        guard let data = value.data(using: .utf8) else { return }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
        ]
        SecItemDelete(query as CFDictionary)
        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock,
        ]
        SecItemAdd(addQuery as CFDictionary, nil)
    }

    static func load(key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: AnyObject?
        SecItemCopyMatching(query as CFDictionary, &result)
        guard let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func delete(key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
        ]
        SecItemDelete(query as CFDictionary)
    }
}
