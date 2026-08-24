//
//  T3Auth.swift
//  boringNotch
//
//  Pairing-link parsing and Keychain persistence for the T3 Code bearer token.
//  Pairing links look like http://host:port/pair#token=<credential> (the
//  credential can also be pasted bare).
//

import Foundation
import Security

enum T3Auth {
    private static let service = "boringNotch.t3code"

    /// One Keychain item per paired server. The local server keeps the
    /// original account name so existing pairings survive.
    static func account(forServer serverID: UUID?) -> String {
        guard let serverID else { return "access-token" }
        return "access-token-\(serverID.uuidString)"
    }

    struct StoredToken: Codable {
        let accessToken: String
        let expiresAt: Date
        let scope: String

        var isExpired: Bool { Date() >= expiresAt }
    }

    /// Accepts a full pairing URL or a bare credential string.
    static func pairingCredential(from input: String) -> String? {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if let url = URL(string: trimmed), let fragment = url.fragment {
            let pairs = fragment.split(separator: "&").map { pair -> (String, String) in
                let parts = pair.split(separator: "=", maxSplits: 1).map(String.init)
                return (parts.first ?? "", parts.count > 1 ? parts[1] : "")
            }
            if let token = pairs.first(where: { $0.0 == "token" })?.1.removingPercentEncoding {
                return token
            }
        }
        // Bare credential: no scheme, no whitespace.
        if !trimmed.contains("://"), !trimmed.contains(" ") {
            return trimmed
        }
        return nil
    }

    static func store(result: T3AccessTokenResult, account: String) {
        let token = StoredToken(
            accessToken: result.access_token,
            expiresAt: Date().addingTimeInterval(result.expires_in),
            scope: result.scope
        )
        guard let data = try? JSONEncoder().encode(token) else { return }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(query as CFDictionary)
        var attributes = query
        attributes[kSecValueData as String] = data
        attributes[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        SecItemAdd(attributes as CFDictionary, nil)
    }

    static func load(account: String) -> StoredToken? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data
        else { return nil }
        return try? JSONDecoder().decode(StoredToken.self, from: data)
    }

    static func clear(account: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(query as CFDictionary)
    }
}
