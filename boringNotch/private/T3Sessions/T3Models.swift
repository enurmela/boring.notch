//
//  T3Models.swift
//  boringNotch
//
//  Codable views of the T3 Code local server API (only the fields we consume;
//  unknown fields are ignored so contract additions don't break decoding).
//

import Foundation

/// A user-configured remote T3 Code server (another machine reachable over
/// LAN/VPN). The local server is built in and not represented here.
struct T3RemoteServer: Codable, Hashable, Identifiable {
    var id = UUID()
    var name: String
    var origin: String
}

struct T3EnvironmentDescriptor: Decodable {
    let environmentId: String
    let label: String
    let serverVersion: String
    let orchestrationProtocolVersion: Int?
}

struct T3ShellSnapshot: Decodable {
    let projects: [T3Project]
    let threads: [T3ThreadShell]
    let updatedAt: String?
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

struct T3PendingRuntimeRequest: Decodable {
    let kind: String
}

struct T3ThreadLineage: Decodable {
    let relationshipToParent: String?
}

struct T3BackgroundTask: Decodable {
    let kind: String?
    let description: String?
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
    // Legacy fields remain optional for remote servers on protocol v1.
    let hasPendingApprovals: Bool?
    let hasPendingUserInput: Bool?
    let hasActionableProposedPlan: Bool?
    let backgroundLiveness: String?
    let planProgress: T3PlanProgress?
    // Protocol v2 owns run state directly, rather than through a session.
    let status: String?
    let activityRunStatus: String?
    let latestRunCompletedAt: String?
    let lastError: String?
    let pendingRuntimeRequest: T3PendingRuntimeRequest?
    let pendingBackgroundTasks: [T3BackgroundTask]?
    let lineage: T3ThreadLineage?
    let deletedAt: String?

    var completionTimestamp: String { latestRunCompletedAt ?? latestTurn?.completedAt ?? updatedAt }
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
