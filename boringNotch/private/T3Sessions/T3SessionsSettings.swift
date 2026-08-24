//
//  T3SessionsSettings.swift
//  boringNotch
//
//  Settings pane: enable the T3 Code integration, pair with the local server,
//  choose which phase changes surface in the notch.
//

import Defaults
import SwiftUI

struct T3SessionsSettings: View {
    @Default(.enableT3Sessions) var enableT3Sessions
    @Default(.t3ServerPort) var t3ServerPort
    @ObservedObject var manager = T3SessionsManager.shared

    @State private var pairingInput = ""
    @State private var isPairing = false

    private var installedBuild: String? { T3SessionsManager.detectInstalledBuild() }

    var body: some View {
        Form {
            Section {
                Defaults.Toggle(key: .enableT3Sessions) {
                    Text("Enable T3 Code sessions")
                }
                .disabled(installedBuild == nil && !manager.status.isReachable && !enableT3Sessions)

                HStack {
                    Text("Status")
                    Spacer()
                    statusBadge
                }

                TextField("Server port", value: $t3ServerPort, format: .number.grouping(.never))
                    .onChange(of: t3ServerPort) {
                        manager.refreshNow()
                    }
            } header: {
                Text("General")
            } footer: {
                if installedBuild == nil && !manager.status.isReachable {
                    Text("T3 Code was not found. Install the desktop app (`brew install --cask t3-code`) or run `npx t3` — then enable the integration here.")
                        .foregroundStyle(.secondary)
                }
            }

            if enableT3Sessions {
                Section {
                    switch manager.status {
                    case .connected(let label, _):
                        HStack {
                            Text("Paired with")
                            Spacer()
                            Text(label).foregroundStyle(.secondary)
                        }
                        Button("Unpair") { manager.unpair() }
                    default:
                        TextField("Pairing link or token", text: $pairingInput)
                            .textFieldStyle(.roundedBorder)
                        HStack {
                            Button(isPairing ? "Pairing…" : "Pair") {
                                isPairing = true
                                Task {
                                    if await manager.pair(with: pairingInput) {
                                        pairingInput = ""
                                    }
                                    isPairing = false
                                }
                            }
                            .disabled(pairingInput.isEmpty || isPairing || !manager.status.isReachable)
                        }
                        if let error = manager.lastError {
                            Text(error)
                                .font(.caption)
                                .foregroundStyle(.red)
                        }
                    }
                } header: {
                    Text("Pairing")
                } footer: {
                    Text("Run `t3 pair` (or `npx t3 pair`) in a terminal while the T3 Code server is running, then paste the printed pairing link here. Links expire after a few minutes.")
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

    @ViewBuilder
    private var statusBadge: some View {
        switch manager.status {
        case .disabled:
            Label("Disabled", systemImage: "circle").foregroundStyle(.secondary)
        case .notDetected:
            Label("Not detected", systemImage: "questionmark.circle").foregroundStyle(.secondary)
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
}
