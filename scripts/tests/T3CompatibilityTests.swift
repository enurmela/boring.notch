import Foundation

@main
struct T3CompatibilityTests {
    enum Failure: Error { case expectation(String) }

    static func expect(_ condition: @autoclosure () -> Bool, _ label: String) throws {
        guard condition() else { throw Failure.expectation(label) }
    }

    static func thread(_ fields: [String: Any] = [:]) throws -> T3ThreadShell {
        var json: [String: Any] = [
            "id": "thread", "projectId": "project", "title": "Test task",
            "updatedAt": "2026-10-03T10:00:00.000Z", "status": "running",
        ]
        json.merge(fields) { _, new in new }
        return try JSONDecoder().decode(T3ThreadShell.self, from: JSONSerialization.data(withJSONObject: json))
    }

    static func fixtures() throws {
        for (status, phase) in [
            ("preparing", T3AwarenessPhase.starting), ("starting", .starting),
            ("running", .running), ("waiting", .running), ("completed", .completed), ("failed", .failed),
        ] {
            let row = try thread(["status": status])
            try expect(T3AgentAwareness.phase(for: row) == phase, "v2 status: \(status)")
        }
        for status in ["idle", "queued", "interrupted", "cancelled", "rolled_back", "future_status"] {
            let row = try thread(["status": status])
            try expect(T3AgentAwareness.phase(for: row) == nil, "No notification for \(status)")
        }
        let input = try thread(["status": "failed", "pendingRuntimeRequest": ["kind": "user_input"]])
        try expect(T3AgentAwareness.phase(for: input) == .waitingForInput, "Input outranks failure")
        let approval = try thread(["pendingRuntimeRequest": ["kind": "command"]])
        try expect(T3AgentAwareness.phase(for: approval) == .waitingForApproval, "Approval request")
        let auth = try thread(["pendingRuntimeRequest": ["kind": "auth_refresh"]])
        try expect(T3AgentAwareness.phase(for: auth) == .running, "Auth refresh is not approval")
        let wake = try thread(["status": "completed", "activityRunStatus": "running"])
        try expect(T3AgentAwareness.phase(for: wake) == .running, "Wake owns activity")
        let child = try thread(["lineage": ["relationshipToParent": "subagent"]])
        try expect(T3AgentAwareness.phase(for: child) == nil, "Subagents do not duplicate parent alerts")
        let fork = try thread(["lineage": ["relationshipToParent": "fork"]])
        try expect(T3AgentAwareness.phase(for: fork) == .running, "Forks remain visible")
        for kind in ["command", "subagent", "monitor", "background_task", "future_kind"] {
            let row = try thread(["status": "completed", "pendingBackgroundTasks": [["kind": kind]]])
            try expect(T3AgentAwareness.phase(for: row) == (kind == "command" ? .completed : .running),
                       "Background completion: \(kind)")
        }
        let unnamed = try thread(["status": "completed", "pendingBackgroundTasks": [[:]]])
        try expect(T3AgentAwareness.phase(for: unnamed) == .running, "Unnamed work holds completion")
        let legacy = try thread([
            "status": NSNull(), "hasPendingApprovals": false, "hasPendingUserInput": true,
            "session": ["status": "running"],
        ])
        try expect(T3AgentAwareness.phase(for: legacy) == .waitingForInput, "Legacy remote server")
        let failure = try thread(["status": "failed", "lastError": "Provider unavailable"])
        try expect(T3AgentAwareness.detail(for: .failed, thread: failure) == "Provider unavailable", "v2 error detail")
        let completed = try thread(["latestRunCompletedAt": "2026-10-03T09:00:00.000Z"])
        try expect(completed.completionTimestamp == "2026-10-03T09:00:00.000Z", "Completion age uses run timestamp")
        try expect(T3ThreadRoute.path(environmentId: "env", threadId: "thread", protocolVersion: 2)
                   == "/threads/env/thread", "v2 route")
        try expect(T3ThreadRoute.path(environmentId: "env", threadId: "thread", protocolVersion: nil)
                   == "/env/thread", "Legacy route")
        try expect(T3ThreadRoute.path(environmentId: "a/b", threadId: "c#d", protocolVersion: 2)
                   == "/threads/a%2Fb/c%23d", "Route segments are escaped")
        try expect(T3AutoPair.databasePath(protocolVersion: 2).hasSuffix("/statev2.sqlite"), "v2 pairing store")
        try expect(T3AutoPair.databasePath(protocolVersion: nil).hasSuffix("/state.sqlite"), "Legacy pairing store")
        let shell = try JSONDecoder().decode(T3ShellSnapshot.self, from: Data("{\"projects\":[],\"threads\":[],\"schemaVersion\":2,\"archivedThreads\":[]}".utf8))
        try expect(shell.threads.isEmpty, "v2 snapshot does not need legacy updatedAt")
        print("✓ T3 compatibility fixtures passed")
    }

    static func main() async throws {
        try fixtures()
        if CommandLine.arguments.contains("--live") {
            let client = T3Client(port: 3773)
            let descriptor = try await client.fetchDescriptor()
            // Use the same local pairing flow as the app. Credentials stay in
            // memory and only read access is requested; never print tokens.
            let credential = try T3AutoPair.mintCredential(protocolVersion: descriptor.orchestrationProtocolVersion)
            let token = try await client.exchangeToken(pairingCredential: credential)
            let shell = try await client.fetchShell(token: token.access_token,
                                                  protocolVersion: descriptor.orchestrationProtocolVersion)
            try expect(descriptor.orchestrationProtocolVersion == 2, "Running server uses protocol v2")
            let rootThreads = shell.threads.filter { $0.lineage?.relationshipToParent != "subagent" }
            let active = rootThreads.filter { T3AgentAwareness.phase(for: $0) == .running }
            print("✓ Live T3 \(descriptor.serverVersion): decoded \(shell.threads.count) threads, \(active.count) working")
        }
    }
}
