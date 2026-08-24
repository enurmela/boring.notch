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
                    T3PairingControls(
                        serverID: nil,
                        status: manager.localStatus,
                        manager: manager
                    )
                } header: {
                    Text("Pairing")
                } footer: {
                    Text("Run `t3 pair` (or `npx t3@latest pair`) in a terminal while the T3 Code server is running, then paste the printed pairing link here. Links expire after a few minutes.")
                        .foregroundStyle(.secondary)
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
