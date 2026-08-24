//
//  T3SessionsManager.swift
//  boringNotch
//
//  Watches T3 Code servers — the local one plus any user-configured remote
//  machines — polls their orchestration shells, and raises notch notifications
//  when a thread crosses into a phase the user should act on.
//

import Combine
import Defaults
import Foundation
import SwiftUI

extension Defaults.Keys {
    static let enableT3Sessions = Key<Bool>("enableT3Sessions", default: false)
    static let t3ServerPort = Key<Int>("t3ServerPort", default: 3773)
    static let t3RemoteServers = Key<[T3RemoteServer]>("t3RemoteServers", default: [])
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
        case unreachable
        case badOrigin
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

    /// One connected-or-configured server and its current threads. The local
    /// server is always first; remotes follow in settings order.
    struct ServerSection: Identifiable {
        let id: String
        let name: String
        let isLocal: Bool
        let status: ServerStatus
        var rows: [ThreadRow] = []
    }

    struct NotchAlert {
        let threadTitle: String
        let projectTitle: String
        let serverName: String?
        let phase: T3AwarenessPhase
    }

    static let localServerID = "local"

    @Published private(set) var sections: [ServerSection] = []
    @Published private(set) var latestAlert: NotchAlert?
    @Published private(set) var lastError: String?

    var localStatus: ServerStatus {
        sections.first(where: { $0.isLocal })?.status ?? .disabled
    }

    func status(forRemote id: UUID) -> ServerStatus {
        sections.first(where: { $0.id == id.uuidString })?.status ?? .unreachable
    }

    var hasAnyRows: Bool { sections.contains { !$0.rows.isEmpty } }

    /// Threads currently blocked on the user (approval/input) across all
    /// servers — shown as the tab badge.
    var actionableCount: Int {
        sections
            .flatMap(\.rows)
            .filter { $0.phase == .waitingForApproval || $0.phase == .waitingForInput }
            .count
    }

    private var pollTask: Task<Void, Never>?
    private var lastAutoPairAttempt: Date = .distantPast
    private var settingsCancellables: Set<AnyCancellable> = []
    /// Last known phase per "serverID/threadID"; baseline tracked per server
    /// so a newly added remote doesn't fire a notification burst.
    private var knownPhases: [String: T3AwarenessPhase] = [:]
    private var baselinedServers: Set<String> = []

    private static let appBundleCandidates: [(path: String, build: String)] = [
        ("/Applications/T3 Code.app", "release"),
        ("/Applications/T3 Code (Nightly).app", "nightly"),
    ]

    private init() {
        Defaults.publisher(.enableT3Sessions)
            .sink { [weak self] change in
                Task { @MainActor in
                    change.newValue ? self?.start() : self?.stop()
                }
            }
            .store(in: &settingsCancellables)
        Defaults.publisher(.t3RemoteServers)
            .sink { [weak self] _ in
                Task { @MainActor in self?.refreshNow() }
            }
            .store(in: &settingsCancellables)
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
                let anyConnected = await self.pollAll()
                try? await Task.sleep(for: .seconds(anyConnected ? 3 : 10))
            }
        }
    }

    func stop() {
        pollTask?.cancel()
        pollTask = nil
        sections = []
        knownPhases = [:]
        baselinedServers = []
    }

    func refreshNow() {
        Task { await pollAll() }
    }

    // MARK: - Pairing

    /// True when the local t3 state directory is writable, i.e. zero-click
    /// pairing works and the manual flow is only needed for remote machines.
    var canAutoPairLocal: Bool { T3AutoPair.isAvailable }

    private func autoPairLocal() async -> Bool {
        guard T3AutoPair.isAvailable,
              Date().timeIntervalSince(lastAutoPairAttempt) > 30
        else { return false }
        lastAutoPairAttempt = Date()
        do {
            let credential = try T3AutoPair.mintCredential()
            let client = T3Client(port: Defaults[.t3ServerPort])
            let result = try await client.exchangeToken(pairingCredential: credential)
            T3Auth.store(result: result, account: T3Auth.account(forServer: nil))
            lastError = nil
            return true
        } catch {
            lastError = "Auto-pairing failed: \(error.localizedDescription)"
            return false
        }
    }

    func pair(serverID: UUID?, with input: String) async -> Bool {
        guard let credential = T3Auth.pairingCredential(from: input) else {
            lastError = "Could not find a pairing token in that link."
            return false
        }
        guard let client = client(forServerID: serverID) else {
            lastError = "Invalid server address."
            return false
        }
        do {
            let result = try await client.exchangeToken(pairingCredential: credential)
            T3Auth.store(result: result, account: T3Auth.account(forServer: serverID))
            lastError = nil
            await pollAll()
            return true
        } catch let error as T3ServerError {
            lastError = "Pairing failed (HTTP \(error.statusCode)). Pairing links expire after a few minutes — mint a fresh one with `t3 pair`."
            return false
        } catch {
            lastError = "Pairing failed: \(error.localizedDescription)"
            return false
        }
    }

    func unpair(serverID: UUID?) {
        T3Auth.clear(account: T3Auth.account(forServer: serverID))
        let sectionID = serverID?.uuidString ?? Self.localServerID
        knownPhases = knownPhases.filter { !$0.key.hasPrefix("\(sectionID)/") }
        baselinedServers.remove(sectionID)
        refreshNow()
    }

    func removeRemote(_ server: T3RemoteServer) {
        unpair(serverID: server.id)
        Defaults[.t3RemoteServers].removeAll { $0.id == server.id }
    }

    // MARK: - Polling

    private func client(forServerID serverID: UUID?) -> T3Client? {
        guard let serverID else { return T3Client(port: Defaults[.t3ServerPort]) }
        guard let server = Defaults[.t3RemoteServers].first(where: { $0.id == serverID }) else {
            return nil
        }
        return T3Client(originString: server.origin)
    }

    /// Polls every configured server concurrently; returns whether any of
    /// them is connected (drives the poll cadence).
    @discardableResult
    private func pollAll() async -> Bool {
        let remotes = Defaults[.t3RemoteServers]

        func pollLocal() async -> ServerSection {
            await pollServer(
                sectionID: Self.localServerID,
                name: "This Mac",
                isLocal: true,
                client: T3Client(port: Defaults[.t3ServerPort]),
                tokenAccount: T3Auth.account(forServer: nil)
            )
        }
        async let localResult = pollLocal()
        let remoteResults = await withTaskGroup(
            of: (Int, ServerSection).self,
            returning: [ServerSection].self
        ) { group in
            for (index, remote) in remotes.enumerated() {
                group.addTask { @MainActor in
                    let section = await self.pollServer(
                        sectionID: remote.id.uuidString,
                        name: remote.name.isEmpty ? remote.origin : remote.name,
                        isLocal: false,
                        client: T3Client(originString: remote.origin),
                        tokenAccount: T3Auth.account(forServer: remote.id)
                    )
                    return (index, section)
                }
            }
            var collected: [(Int, ServerSection)] = []
            for await item in group { collected.append(item) }
            return collected.sorted { $0.0 < $1.0 }.map(\.1)
        }

        var localSection = await localResult
        // Local server needs (re-)pairing: mint a credential in the t3
        // server's own store and exchange it — no user interaction.
        switch localSection.status {
        case .unpaired, .tokenExpired:
            if await autoPairLocal() {
                localSection = await pollLocal()
            }
        default:
            break
        }

        var newSections = [localSection]
        newSections.append(contentsOf: remoteResults)

        withAnimation(.smooth) {
            sections = newSections
        }
        notifyOnTransitions(sections: newSections)

        return newSections.contains { $0.status.isReachable }
    }

    private func pollServer(
        sectionID: String,
        name: String,
        isLocal: Bool,
        client: T3Client?,
        tokenAccount: String
    ) async -> ServerSection {
        func section(_ status: ServerStatus, rows: [ThreadRow] = []) -> ServerSection {
            ServerSection(id: sectionID, name: name, isLocal: isLocal, status: status, rows: rows)
        }

        guard let client else { return section(.badOrigin) }

        guard let descriptor = try? await client.fetchDescriptor() else {
            baselinedServers.remove(sectionID)
            knownPhases = knownPhases.filter { !$0.key.hasPrefix("\(sectionID)/") }
            if isLocal {
                if let build = Self.detectInstalledBuild() {
                    return section(.installedNotRunning(build: build))
                }
                return section(.notDetected)
            }
            return section(.unreachable)
        }

        guard let token = T3Auth.load(account: tokenAccount) else {
            return section(.unpaired(serverVersion: descriptor.serverVersion))
        }
        guard !token.isExpired else {
            return section(.tokenExpired(serverVersion: descriptor.serverVersion))
        }

        do {
            let shell = try await client.fetchShell(token: token.accessToken)
            lastError = nil
            return section(
                .connected(label: descriptor.label, serverVersion: descriptor.serverVersion),
                rows: rows(from: shell)
            )
        } catch let error as T3ServerError where error.statusCode == 401 {
            return section(.tokenExpired(serverVersion: descriptor.serverVersion))
        } catch {
            lastError = error.localizedDescription
            return section(.unreachable)
        }
    }

    private func rows(from shell: T3ShellSnapshot) -> [ThreadRow] {
        let projectTitles = Dictionary(
            shell.projects.map { ($0.id, $0.title) },
            uniquingKeysWith: { first, _ in first }
        )

        var rows: [ThreadRow] = []
        for thread in shell.threads {
            guard thread.archivedAt == nil, !isSnoozed(thread) else { continue }
            guard let phase = T3AgentAwareness.phase(for: thread) else { continue }
            rows.append(
                ThreadRow(
                    thread: thread,
                    projectTitle: projectTitles[thread.projectId] ?? "Unknown project",
                    phase: phase,
                    detail: T3AgentAwareness.detail(for: phase, thread: thread)
                )
            )
        }

        rows.sort { lhs, rhs in
            if lhs.phase.isActionable != rhs.phase.isActionable {
                return lhs.phase.isActionable
            }
            return lhs.thread.updatedAt > rhs.thread.updatedAt
        }
        return rows
    }

    // MARK: - Notifications

    private func notifyOnTransitions(sections: [ServerSection]) {
        var newPhases: [String: T3AwarenessPhase] = [:]
        var candidates: [(row: ThreadRow, section: ServerSection, key: String)] = []

        for section in sections where section.status.isReachable {
            for row in section.rows {
                let key = "\(section.id)/\(row.id)"
                newPhases[key] = row.phase
                if baselinedServers.contains(section.id) {
                    candidates.append((row, section, key))
                }
            }
            baselinedServers.insert(section.id)
        }

        defer { knownPhases = newPhases }

        // Highest-priority transition wins the (single) notch slot.
        let priority: [T3AwarenessPhase] = [.waitingForApproval, .waitingForInput, .failed, .completed]
        for wanted in priority {
            guard isNotifyEnabled(for: wanted) else { continue }
            guard let hit = candidates.first(where: { candidate in
                candidate.row.phase == wanted && knownPhases[candidate.key] != wanted
            }) else { continue }
            // "completed" only counts coming out of live work — a thread first
            // seen as completed (e.g. server restart) shouldn't ping.
            if wanted == .completed {
                let previous = knownPhases[hit.key]
                guard previous == .running || previous == .starting else { continue }
            }
            latestAlert = NotchAlert(
                threadTitle: hit.row.thread.title,
                projectTitle: hit.row.projectTitle,
                serverName: hit.section.isLocal ? nil : hit.section.name,
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
