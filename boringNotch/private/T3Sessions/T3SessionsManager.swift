//
//  T3SessionsManager.swift
//  boringNotch
//
//  Watches the local T3 Code server: detects the install, polls the
//  orchestration shell while the server is up, and raises notch notifications
//  when a thread crosses into a phase the user should act on.
//

import Combine
import Defaults
import Foundation
import SwiftUI

extension Defaults.Keys {
    static let enableT3Sessions = Key<Bool>("enableT3Sessions", default: false)
    static let t3ServerPort = Key<Int>("t3ServerPort", default: 3773)
    static let t3NotifyApproval = Key<Bool>("t3NotifyApproval", default: true)
    static let t3NotifyInput = Key<Bool>("t3NotifyInput", default: true)
    static let t3NotifyCompleted = Key<Bool>("t3NotifyCompleted", default: true)
    static let t3NotifyFailed = Key<Bool>("t3NotifyFailed", default: true)
}

@MainActor
class T3SessionsManager: ObservableObject {
    static let shared = T3SessionsManager()

    enum ServerStatus: Equatable {
        case disabled
        case notDetected
        case installedNotRunning(build: String)
        case unpaired(serverVersion: String)
        case tokenExpired(serverVersion: String)
        case connected(label: String, serverVersion: String)

        var isReachable: Bool {
            switch self {
            case .unpaired, .tokenExpired, .connected: return true
            default: return false
            }
        }
    }

    struct ThreadRow: Identifiable {
        let thread: T3ThreadShell
        let projectTitle: String
        let phase: T3AwarenessPhase
        let detail: String?
        var id: String { thread.id }
    }

    struct NotchAlert {
        let threadTitle: String
        let projectTitle: String
        let phase: T3AwarenessPhase
    }

    @Published private(set) var status: ServerStatus = .disabled
    @Published private(set) var rows: [ThreadRow] = []
    @Published private(set) var latestAlert: NotchAlert?
    @Published private(set) var lastError: String?

    /// Threads currently blocked on the user (approval/input) — shown as the
    /// tab badge.
    var actionableCount: Int {
        rows.filter { $0.phase == .waitingForApproval || $0.phase == .waitingForInput }.count
    }

    private var pollTask: Task<Void, Never>?
    private var enabledCancellable: AnyCancellable?
    private var knownPhases: [String: T3AwarenessPhase] = [:]
    private var hasBaseline = false

    private static let appBundleCandidates: [(path: String, build: String)] = [
        ("/Applications/T3 Code.app", "release"),
        ("/Applications/T3 Code (Nightly).app", "nightly"),
    ]

    private init() {
        enabledCancellable = Defaults.publisher(.enableT3Sessions)
            .sink { [weak self] change in
                Task { @MainActor in
                    change.newValue ? self?.start() : self?.stop()
                }
            }
        if Defaults[.enableT3Sessions] {
            start()
        }
    }

    /// "release" / "nightly" for an installed desktop build, nil when only a
    /// headless server (npx t3) could be present.
    static func detectInstalledBuild() -> String? {
        for candidate in appBundleCandidates where FileManager.default.fileExists(atPath: candidate.path) {
            return candidate.build
        }
        return nil
    }

    func start() {
        guard pollTask == nil else { return }
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                let interval = await self.pollOnce()
                try? await Task.sleep(for: .seconds(interval))
            }
        }
    }

    func stop() {
        pollTask?.cancel()
        pollTask = nil
        status = .disabled
        rows = []
        knownPhases = [:]
        hasBaseline = false
    }

    func refreshNow() {
        Task { await pollOnce() }
    }

    func pair(with input: String) async -> Bool {
        guard let credential = T3Auth.pairingCredential(from: input) else {
            lastError = "Could not find a pairing token in that link."
            return false
        }
        let client = T3Client(port: Defaults[.t3ServerPort])
        do {
            let result = try await client.exchangeToken(pairingCredential: credential)
            T3Auth.store(result: result)
            lastError = nil
            await pollOnce()
            return true
        } catch let error as T3ServerError {
            lastError = "Pairing failed (HTTP \(error.statusCode)). Pairing links expire after a few minutes — mint a fresh one with `t3 pair`."
            return false
        } catch {
            lastError = "Pairing failed: \(error.localizedDescription)"
            return false
        }
    }

    func unpair() {
        T3Auth.clear()
        knownPhases = [:]
        hasBaseline = false
        rows = []
        refreshNow()
    }

    /// One poll cycle; returns the delay until the next one.
    @discardableResult
    private func pollOnce() async -> TimeInterval {
        let client = T3Client(port: Defaults[.t3ServerPort])

        guard let descriptor = try? await client.fetchDescriptor() else {
            knownPhases = [:]
            hasBaseline = false
            rows = []
            if let build = Self.detectInstalledBuild() {
                status = .installedNotRunning(build: build)
            } else {
                status = .notDetected
            }
            return 10
        }

        guard let token = T3Auth.load() else {
            status = .unpaired(serverVersion: descriptor.serverVersion)
            return 5
        }
        guard !token.isExpired else {
            status = .tokenExpired(serverVersion: descriptor.serverVersion)
            return 10
        }

        do {
            let shell = try await client.fetchShell(token: token.accessToken)
            status = .connected(label: descriptor.label, serverVersion: descriptor.serverVersion)
            lastError = nil
            ingest(shell)
            return 3
        } catch let error as T3ServerError where error.statusCode == 401 {
            status = .tokenExpired(serverVersion: descriptor.serverVersion)
            return 10
        } catch {
            lastError = error.localizedDescription
            return 5
        }
    }

    private func ingest(_ shell: T3ShellSnapshot) {
        let projectTitles = Dictionary(
            shell.projects.map { ($0.id, $0.title) },
            uniquingKeysWith: { first, _ in first }
        )

        var newRows: [ThreadRow] = []
        var newPhases: [String: T3AwarenessPhase] = [:]

        for thread in shell.threads {
            guard thread.archivedAt == nil, !isSnoozed(thread) else { continue }
            guard let phase = T3AgentAwareness.phase(for: thread) else { continue }
            newPhases[thread.id] = phase
            newRows.append(
                ThreadRow(
                    thread: thread,
                    projectTitle: projectTitles[thread.projectId] ?? "Unknown project",
                    phase: phase,
                    detail: T3AgentAwareness.detail(for: phase, thread: thread)
                )
            )
        }

        newRows.sort { lhs, rhs in
            if lhs.phase.isActionable != rhs.phase.isActionable {
                return lhs.phase.isActionable
            }
            return lhs.thread.updatedAt > rhs.thread.updatedAt
        }

        withAnimation(.smooth) {
            rows = newRows
        }

        if hasBaseline {
            notifyOnTransitions(newPhases: newPhases, newRows: newRows)
        }
        knownPhases = newPhases
        hasBaseline = true
    }

    private func notifyOnTransitions(newPhases: [String: T3AwarenessPhase], newRows: [ThreadRow]) {
        // Highest-priority transition wins the (single) notch slot.
        let priority: [T3AwarenessPhase] = [.waitingForApproval, .waitingForInput, .failed, .completed]

        for wanted in priority {
            guard isNotifyEnabled(for: wanted) else { continue }
            guard let row = newRows.first(where: { row in
                newPhases[row.id] == wanted && knownPhases[row.id] != wanted
            }) else { continue }
            // "completed" only counts coming out of live work — a thread first
            // seen as completed (e.g. server restart) shouldn't ping.
            if wanted == .completed {
                let previous = knownPhases[row.id]
                guard previous == .running || previous == .starting else { continue }
            }
            latestAlert = NotchAlert(
                threadTitle: row.thread.title,
                projectTitle: row.projectTitle,
                phase: wanted
            )
            BoringViewCoordinator.shared.toggleExpandingView(status: true, type: .t3)
            return
        }
    }

    private func isNotifyEnabled(for phase: T3AwarenessPhase) -> Bool {
        switch phase {
        case .waitingForApproval: return Defaults[.t3NotifyApproval]
        case .waitingForInput: return Defaults[.t3NotifyInput]
        case .completed: return Defaults[.t3NotifyCompleted]
        case .failed: return Defaults[.t3NotifyFailed]
        case .starting, .running: return false
        }
    }

    private func isSnoozed(_ thread: T3ThreadShell) -> Bool {
        guard let until = thread.snoozedUntil,
              let date = T3ISODate.parse(until)
        else { return false }
        return date > Date()
    }
}

enum T3ISODate {
    private static let fractional: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
    private static let plain = ISO8601DateFormatter()

    static func parse(_ string: String) -> Date? {
        fractional.date(from: string) ?? plain.date(from: string)
    }

    static func relative(_ string: String) -> String {
        guard let date = parse(string) else { return "" }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}
