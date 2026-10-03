//
//  T3AgentAwareness.swift
//  boringNotch
//
//  Port of t3code's packages/shared/src/agentAwareness.ts (MIT, T3 Tools Inc.):
//  maps a thread shell to the phase its own clients notify on. Kept in the
//  upstream priority order — approvals outrank input, errors outrank liveness.
//

import SwiftUI

enum T3AwarenessPhase: String {
    case starting
    case running
    case waitingForApproval = "waiting_for_approval"
    case waitingForInput = "waiting_for_input"
    case completed
    case failed

    var headline: String {
        switch self {
        case .starting: return "Starting agent"
        case .running: return "Agent is working"
        case .waitingForApproval: return "Approval needed"
        case .waitingForInput: return "Waiting for input"
        case .completed: return "Agent finished"
        case .failed: return "Agent failed"
        }
    }

    var systemImage: String {
        switch self {
        case .starting: return "hourglass"
        case .running: return "circle.dotted.circle"
        case .waitingForApproval: return "exclamationmark.shield.fill"
        case .waitingForInput: return "questionmark.bubble.fill"
        case .completed: return "checkmark.circle.fill"
        case .failed: return "xmark.octagon.fill"
        }
    }

    var tint: Color {
        switch self {
        case .starting: return .yellow
        case .running: return .green
        case .waitingForApproval: return .orange
        case .waitingForInput: return .cyan
        case .completed: return .gray
        case .failed: return .red
        }
    }

    /// Phases where the agent is blocked on or done for the user — the ones
    /// worth interrupting them for.
    var isActionable: Bool {
        switch self {
        case .waitingForApproval, .waitingForInput, .completed, .failed: return true
        case .starting, .running: return false
        }
    }
}

enum T3AgentAwareness {
    static func phase(for thread: T3ThreadShell) -> T3AwarenessPhase? {
        guard thread.lineage?.relationshipToParent != "subagent" else { return nil }
        if let status = thread.status {
            if let request = thread.pendingRuntimeRequest {
                if request.kind == "user_input" { return .waitingForInput }
                if request.kind != "auth_refresh" { return .waitingForApproval }
            }
            switch thread.activityRunStatus ?? status {
            case "preparing", "starting": return .starting
            case "running", "waiting": return .running
            case "completed":
                // Commands (e.g. dev servers) can outlive a finished turn.
                // Subagents, monitors and unknown work still wake the agent.
                return (thread.pendingBackgroundTasks ?? []).contains { $0.kind != "command" }
                    ? .running : .completed
            case "failed": return .failed
            default: return nil
            }
        }
        if thread.hasPendingApprovals == true { return .waitingForApproval }
        if thread.hasPendingUserInput == true { return .waitingForInput }
        if thread.session?.status == "error" || thread.latestTurn?.state == "error" {
            return .failed
        }
        if thread.session?.status == "starting" { return .starting }
        if thread.session?.status == "running" || thread.latestTurn?.state == "running" {
            return .running
        }
        if thread.latestTurn?.state == "completed" { return .completed }
        // Session teardown can settle a finished turn as "interrupted"; a
        // completion timestamp means it actually finished (upstream comment).
        if thread.latestTurn?.state == "interrupted", thread.latestTurn?.completedAt != nil {
            return .completed
        }
        if thread.session?.status == "ready" || thread.session?.status == "idle" {
            return .completed
        }
        return nil
    }

    static func detail(for phase: T3AwarenessPhase, thread: T3ThreadShell) -> String? {
        switch phase {
        case .failed: return thread.lastError ?? thread.session?.lastError
        case .running:
            if let step = thread.planProgress?.step { return step }
            if let task = thread.pendingBackgroundTasks?.first(where: { $0.kind != "command" }) {
                return task.description ?? "Waiting for background work"
            }
            if let provider = thread.session?.providerName { return "\(provider) is active" }
            return nil
        default: return nil
        }
    }
}
