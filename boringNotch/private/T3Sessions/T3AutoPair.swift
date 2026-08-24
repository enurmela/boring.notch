//
//  T3AutoPair.swift
//  boringNotch
//
//  Zero-click pairing with the LOCAL t3 server: mints a one-time pairing
//  credential the same way `t3 pair` does — inserting a row into the server's
//  own auth_pairing_links table (~/.t3/userdata/state.sqlite) — then runs the
//  standard token exchange over HTTP. The server honors externally inserted
//  rows: its consume path falls through to SQL on an in-memory miss.
//
//  Requires filesystem access to ~/.t3, i.e. the unsandboxed fork build.
//  Remote servers always use manual pairing links.
//

import Foundation
import SQLite3

enum T3AutoPair {
    // Mirrors PairingGrantStore.ts. The 32-char alphabet divides 256 evenly,
    // so plain modulo introduces no bias.
    private static let alphabet = Array("23456789ABCDEFGHJKLMNPQRSTUVWXYZ")
    private static let tokenLength = 12

    static var databasePath: String {
        (realHomeDirectory() as NSString).appendingPathComponent(".t3/userdata/state.sqlite")
    }

    static var isAvailable: Bool {
        FileManager.default.isWritableFile(atPath: databasePath)
    }

    enum AutoPairError: Error {
        case databaseUnavailable
        case sqlite(String)
        case randomnessFailed
    }

    /// Inserts a fresh short-lived pairing credential for the local server and
    /// returns it, ready for the /oauth/token exchange.
    static func mintCredential() throws -> String {
        guard isAvailable else { throw AutoPairError.databaseUnavailable }
        let credential = try generateToken()

        var db: OpaquePointer?
        guard sqlite3_open_v2(databasePath, &db, SQLITE_OPEN_READWRITE, nil) == SQLITE_OK else {
            let message = db.map { String(cString: sqlite3_errmsg($0)) } ?? "open failed"
            sqlite3_close(db)
            throw AutoPairError.sqlite(message)
        }
        defer { sqlite3_close(db) }
        sqlite3_busy_timeout(db, 2000)

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let now = Date()
        let createdAt = formatter.string(from: now)
        let expiresAt = formatter.string(from: now.addingTimeInterval(120))

        let sql = """
            INSERT INTO auth_pairing_links
              (id, credential, method, scopes, subject, label, proof_key_thumbprint,
               created_at, expires_at, consumed_at, revoked_at)
            VALUES (?, ?, 'one-time-token', ?, 'one-time-token', ?, NULL, ?, ?, NULL, NULL)
            """
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            throw AutoPairError.sqlite(String(cString: sqlite3_errmsg(db)))
        }
        defer { sqlite3_finalize(statement) }

        let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        sqlite3_bind_text(statement, 1, UUID().uuidString.lowercased(), -1, transient)
        sqlite3_bind_text(statement, 2, credential, -1, transient)
        sqlite3_bind_text(statement, 3, "[\"orchestration:read\"]", -1, transient)
        sqlite3_bind_text(statement, 4, "boring.notch auto-pair", -1, transient)
        sqlite3_bind_text(statement, 5, createdAt, -1, transient)
        sqlite3_bind_text(statement, 6, expiresAt, -1, transient)

        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw AutoPairError.sqlite(String(cString: sqlite3_errmsg(db)))
        }
        return credential
    }

    private static func generateToken() throws -> String {
        var bytes = [UInt8](repeating: 0, count: tokenLength)
        guard SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes) == errSecSuccess else {
            throw AutoPairError.randomnessFailed
        }
        return String(bytes.map { alphabet[Int($0) % alphabet.count] })
    }

    /// The user's real home even if some future build runs sandboxed again
    /// (NSHomeDirectory would then point into the container).
    private static func realHomeDirectory() -> String {
        if let pw = getpwuid(getuid()), let dir = pw.pointee.pw_dir {
            return String(cString: dir)
        }
        return NSHomeDirectory()
    }
}
