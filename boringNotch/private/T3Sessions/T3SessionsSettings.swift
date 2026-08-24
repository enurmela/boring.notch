//
//  T3SessionsSettings.swift
//  boringNotch
//
//  Settings pane: enable the T3 Code integration, pair with the local server,
//  manage remote machines, choose which phase changes surface in the notch.
//

import Defaults
import SwiftUI

struct T3SessionsSettings: View {
    @Default(.enableT3Sessions) var enableT3Sessions
    @Default(.t3ServerPort) var t3ServerPort
    @Default(.t3RemoteServers) var remoteServers
    @ObservedObject var manager = T3SessionsManager.shared

    @State private var newRemoteName = ""
    @State private var newRemoteOrigin = ""

    private var installedBuild: String? { T3SessionsManager.detectInstalledBuild() }

    var body: some View {
        Form {
            Section {
                Defaults.Toggle(key: .enableT3Sessions) {
                    HStack(spacing: 8) {
                        T3LogoView(size: 22)
                        Text("Enable T3 Code sessions")
                    }
                }

                HStack {
                    Text("Status")
                    Spacer()
                    statusBadge(manager.localStatus)
                }

                TextField("Server port", value: $t3ServerPort, format: .number.grouping(.never))
                    .onChange(of: t3ServerPort) {
                        manager.refreshNow()
                    }
            } header: {
                Text("This Mac")
            } footer: {
                if installedBuild == nil && !manager.localStatus.isReachable {
                    Text("T3 Code was not found. Install the desktop app (`brew install --cask t3-code`) or run `npx t3` — then enable the integration here.")
                        .foregroundStyle(.secondary)
                }
            }

            if enableT3Sessions {
                Section {
                    if manager.canAutoPairLocal {
                        HStack {
                            Text("Pairing")
                            Spacer()
                            if case .connected(let label, _) = manager.localStatus {
                                Label("Automatic · \(label)", systemImage: "wand.and.stars")
                                    .foregroundStyle(.secondary)
                            } else {
                                Label("Automatic", systemImage: "wand.and.stars")
                                    .foregroundStyle(.secondary)
                            }
                        }
                        if let error = manager.lastError {
                            Text(error)
                                .font(.caption)
                                .foregroundStyle(.red)
                        }
                    } else {
                        T3PairingControls(
                            serverID: nil,
                            status: manager.localStatus,
                            manager: manager
                        )
                    }
                } header: {
                    Text("Pairing")
                } footer: {
                    if manager.canAutoPairLocal {
                        Text("This Mac pairs itself with the local T3 Code server — nothing to do here. Remote machines below still need a pairing link.")
                            .foregroundStyle(.secondary)
                    } else {
                        Text("Run `t3 pair` (or `npx t3@latest pair`) in a terminal while the T3 Code server is running, then paste the printed pairing link here. Links expire after a few minutes.")
                            .foregroundStyle(.secondary)
                    }
                }

                Section {
                    ForEach(remoteServers) { server in
                        T3RemoteServerRow(server: server, manager: manager)
                    }

                    HStack {
                        TextField("Name", text: $newRemoteName)
                            .frame(width: 120)
                        TextField("Address (host:port)", text: $newRemoteOrigin)
                        Button("Add") {
                            let server = T3RemoteServer(
                                name: newRemoteName.trimmingCharacters(in: .whitespaces),
                                origin: newRemoteOrigin.trimmingCharacters(in: .whitespaces)
                            )
                            remoteServers.append(server)
                            newRemoteName = ""
                            newRemoteOrigin = ""
                        }
                        .disabled(newRemoteOrigin.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                } header: {
                    Text("Remote Macs")
                } footer: {
                    Text("Other machines running T3 Code, reachable over your network (e.g. `devbox.local:3773` or a Tailscale address). Each one is paired separately — run `t3 pair` on that machine and paste its link here. Sessions from remote machines appear in their own group in the notch.")
                        .foregroundStyle(.secondary)
                }

                Section {
                    Defaults.Toggle(key: .t3OpenInApp) {
                        Text("Open sessions in the T3 Code app")
                    }
                    if manager.desktopNeedsRelaunch {
                        HStack {
                            Text("T3 Code is running without its control channel — sessions open in the browser until it's relaunched.")
                                .font(.caption)
                                .foregroundStyle(.orange)
                            Spacer()
                            Button("Relaunch T3 Code") {
                                manager.relaunchDesktopWithControl()
                            }
                        }
                    }
                } header: {
                    Text("Opening sessions")
                } footer: {
                    Text("In-app opening navigates the desktop app directly (boring.notch starts it with a local control channel). Turn this off to always use the web app in your browser. Relaunching quits T3 Code — pick a moment when no agent is mid-task.")
                        .foregroundStyle(.secondary)
                }

                Section {
                    Defaults.Toggle(key: .t3StickyTab) {
                        Text("Keep T3 tab selected when the notch closes")
                    }
                    Defaults.Toggle(key: .t3LiveActivity) {
                        Text("Live status in the closed notch")
                    }
                    Defaults.Toggle(key: .t3LiveActivityIdle) {
                        Text("Keep it visible when nothing is running")
                    }
                    .disabled(!Defaults[.t3LiveActivity])
                    LabeledContent("T3 sessions on the Home tab") {
                        Text("Settings → Home")
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("Notch")
                } footer: {
                    Text("Live status shows while agents run, wait for you, or just finished (music playback takes priority). Clicking a session anywhere opens its chat in T3 Code.")
                        .foregroundStyle(.secondary)
                }

                Section {
                    Defaults.Toggle(key: .t3NotifyApproval) {
                        Text("Approval needed")
                    }
                    Defaults.Toggle(key: .t3NotifyInput) {
                        Text("Waiting for input")
                    }
                    Defaults.Toggle(key: .t3NotifyCompleted) {
                        Text("Agent finished")
                    }
                    Defaults.Toggle(key: .t3NotifyFailed) {
                        Text("Agent failed")
                    }
                } header: {
                    Text("Notch notifications")
                }
            }
        }
        .navigationTitle("T3 Code")
    }
}

/// Status + pair/unpair controls shared by the local server and remote rows.
struct T3PairingControls: View {
    let serverID: UUID?
    let status: T3SessionsManager.ServerStatus
    @ObservedObject var manager: T3SessionsManager

    @State private var pairingInput = ""
    @State private var isPairing = false

    var body: some View {
        switch status {
        case .connected(let label, _):
            HStack {
                Text("Paired with")
                Spacer()
                Text(label).foregroundStyle(.secondary)
            }
            Button("Unpair") { manager.unpair(serverID: serverID) }
        default:
            TextField("Pairing link or token", text: $pairingInput)
                .textFieldStyle(.roundedBorder)
            HStack {
                Button(isPairing ? "Pairing…" : "Pair") {
                    isPairing = true
                    Task {
                        if await manager.pair(serverID: serverID, with: pairingInput) {
                            pairingInput = ""
                        }
                        isPairing = false
                    }
                }
                .disabled(pairingInput.isEmpty || isPairing || !status.isReachable)
            }
            if let error = manager.lastError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
    }
}

struct T3RemoteServerRow: View {
    let server: T3RemoteServer
    @ObservedObject var manager: T3SessionsManager
    @State private var isExpanded = false

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            T3PairingControls(
                serverID: server.id,
                status: manager.status(forRemote: server.id),
                manager: manager
            )
            Button("Remove server", role: .destructive) {
                manager.removeRemote(server)
            }
        } label: {
            HStack {
                Text(server.name.isEmpty ? server.origin : server.name)
                Text(server.origin)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                statusBadge(manager.status(forRemote: server.id))
            }
        }
    }
}

@ViewBuilder
func statusBadge(_ status: T3SessionsManager.ServerStatus) -> some View {
    switch status {
    case .disabled:
        Label("Disabled", systemImage: "circle").foregroundStyle(.secondary)
    case .notDetected:
        Label("Not detected", systemImage: "questionmark.circle").foregroundStyle(.secondary)
    case .unreachable:
        Label("Unreachable", systemImage: "wifi.slash").foregroundStyle(.secondary)
    case .badOrigin:
        Label("Invalid address", systemImage: "exclamationmark.circle").foregroundStyle(.red)
    case .installedNotRunning(let build):
        Label("Installed (\(build)), not running", systemImage: "pause.circle")
            .foregroundStyle(.orange)
    case .unpaired(let version):
        Label("Running v\(version), unpaired", systemImage: "link.circle")
            .foregroundStyle(.orange)
    case .tokenExpired(let version):
        Label("Running v\(version), pairing expired", systemImage: "clock.circle")
            .foregroundStyle(.orange)
    case .connected(_, let version):
        Label("Connected · v\(version)", systemImage: "checkmark.circle.fill")
            .foregroundStyle(.green)
    }
}
