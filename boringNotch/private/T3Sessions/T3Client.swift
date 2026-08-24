//
//  T3Client.swift
//  boringNotch
//
//  Minimal HTTP client for the T3 Code local server. The server is discovered
//  by probing its configurable loopback port; auth is a bearer token obtained
//  once via the pairing flow (see T3Auth).
//

import Foundation

struct T3Client {
    let origin: URL

    private static let session: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 4
        config.waitsForConnectivity = false
        return URLSession(configuration: config)
    }()

    init(port: Int) {
        self.origin = URL(string: "http://127.0.0.1:\(port)")!
    }

    /// Unauthenticated liveness + identity probe.
    func fetchDescriptor() async throws -> T3EnvironmentDescriptor {
        try await get("/.well-known/t3/environment", token: nil)
    }

    func fetchShell(token: String) async throws -> T3ShellSnapshot {
        try await get("/api/orchestration/shell", token: token)
    }

    /// RFC 8693 token exchange: pairing credential -> bearer access token.
    func exchangeToken(pairingCredential: String) async throws -> T3AccessTokenResult {
        var request = URLRequest(url: origin.appendingPathComponent("oauth/token"))
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        let fields: [(String, String)] = [
            ("grant_type", "urn:ietf:params:oauth:grant-type:token-exchange"),
            ("subject_token", pairingCredential),
            ("subject_token_type", "urn:t3:params:oauth:token-type:environment-bootstrap"),
            ("requested_token_type", "urn:ietf:params:oauth:token-type:access_token"),
            ("scope", "orchestration:read"),
            ("client_label", "boring.notch"),
            ("client_device_type", "desktop"),
            ("client_os", "macOS"),
        ]
        request.httpBody = fields
            .map { "\($0.0)=\($0.1.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? $0.1)" }
            .joined(separator: "&")
            .data(using: .utf8)

        let (data, response) = try await Self.session.data(for: request)
        try Self.ensureOK(response, data: data)
        return try JSONDecoder().decode(T3AccessTokenResult.self, from: data)
    }

    private func get<T: Decodable>(_ path: String, token: String?) async throws -> T {
        var request = URLRequest(url: URL(string: path, relativeTo: origin)!)
        if let token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        let (data, response) = try await Self.session.data(for: request)
        try Self.ensureOK(response, data: data)
        return try JSONDecoder().decode(T.self, from: data)
    }

    private static func ensureOK(_ response: URLResponse, data: Data) throws {
        guard let http = response as? HTTPURLResponse else { return }
        guard (200..<300).contains(http.statusCode) else {
            throw T3ServerError(
                statusCode: http.statusCode,
                body: String(data: data.prefix(512), encoding: .utf8) ?? ""
            )
        }
    }
}
