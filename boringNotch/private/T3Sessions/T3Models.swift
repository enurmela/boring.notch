//
//  T3Models.swift
//  boringNotch
//
//  Codable views of the T3 Code local server API (only the fields we consume;
//  unknown fields are ignored so contract additions don't break decoding).
//

import Defaults
import Foundation

/// A user-configured remote T3 Code server (another machine reachable over
/// LAN/VPN). The local server is built in and not represented here.
struct T3RemoteServer: Codable, Hashable, Identifiable, Defaults.Serializable {
    var id = UUID()
    var name: String
    var origin: String
}

struct T3EnvironmentDescriptor: Decodable {
    let environmentId: String
    let label: String
    let serverVersion: String
}

struct T3ShellSnapshot: Decodable {
    let projects: [T3Project]
    let threads: [T3ThreadShell]
    let updatedAt: String
}

struct T3Project: Decodable, Identifiable {
    let id: String
    let title: String
    let workspaceRoot: String
}

struct T3ModelSelection: Decodable {
    let model: String
    let instanceId: String?
}

struct T3SessionInfo: Decodable {
    let status: String
    let providerName: String?
    let lastError: String?
}

struct T3LatestTurn: Decodable {
    let state: String
    let requestedAt: String
    let startedAt: String?
    let completedAt: String?
}

struct T3PlanProgress: Decodable {
    let step: String
    let completedSteps: Int
    let totalSteps: Int
}

struct T3ThreadShell: Decodable, Identifiable {
    let id: String
    let projectId: String
    let title: String
    let branch: String?
    let modelSelection: T3ModelSelection?
    let latestTurn: T3LatestTurn?
    let session: T3SessionInfo?
    let updatedAt: String
    let archivedAt: String?
    let snoozedUntil: String?
    let settledAt: String?
    let settledOverride: String?
    let hasPendingApprovals: Bool
    let hasPendingUserInput: Bool
    let hasActionableProposedPlan: Bool
    let backgroundLiveness: String?
    let planProgress: T3PlanProgress?
}

struct T3AccessTokenResult: Decodable {
    let access_token: String
    let token_type: String
    let expires_in: Double
    let scope: String
}

struct T3ServerError: Error {
    let statusCode: Int
    let body: String
}
