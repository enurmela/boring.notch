//
//  T3SessionsView.swift
//  boringNotch
//
//  The "T3" notch tab: live agent threads from the local T3 Code server and
//  any configured remote machines, grouped per server.
//

import Defaults
import SwiftUI

struct T3SessionsView: View {
    @ObservedObject var manager = T3SessionsManager.shared

    private var hasRemotes: Bool { manager.sections.count > 1 }

    var body: some View {
        VStack(spacing: 0) {
            if manager.desktopNeedsRelaunch {
                relaunchBanner
            }
            Group {
                if manager.hasAnyRows {
                    threadList
                } else {
                    localEmptyState
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// Shown when T3 runs without its control channel (e.g. launched from the
    /// Dock, or auto-updated and relaunched itself): sessions open in the
    /// browser until T3 is relaunched with the channel.
    private var relaunchBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "arrow.up.forward.app")
                .foregroundStyle(.orange)
            Text("Sessions open in the browser until T3 Code is relaunched.")
                .font(.caption2)
                .foregroundStyle(.white)
            Spacer(minLength: 4)
            Button("Relaunch") {
                manager.relaunchDesktopWithControl()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.mini)
            .tint(.orange)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.orange.opacity(0.12))
        )
        .padding(.bottom, 4)
    }

    private var threadList: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(manager.sections) { section in
                    // With just the local server there is nothing to separate —
                    // skip the headers entirely.
                    if hasRemotes {
                        sectionHeader(section)
                    }
                    if section.rows.isEmpty {
                        if hasRemotes {
                            Text(emptyLabel(for: section))
                                .font(.caption2)
                                .foregroundStyle(.gray)
                                .padding(.leading, 4)
                                .padding(.bottom, 2)
                        }
                    } else {
                        ForEach(section.rows) { row in
                            Button {
                                T3SessionsManager.shared.openThread(row)
                            } label: {
                                T3ThreadRowView(row: row)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                }
            }
            .padding(.top, 4)
            .padding(.bottom, 8)
        }
    }

    @ViewBuilder
    private func sectionHeader(_ section: T3SessionsManager.ServerSection) -> some View {
        HStack(spacing: 5) {
            Image(systemName: section.isLocal ? "laptopcomputer" : "network")
                .font(.caption2)
            Text(section.name)
                .font(.caption2.weight(.semibold))
                .textCase(.uppercase)
            if !section.status.isReachable {
                Text("· offline")
                    .font(.caption2)
            }
            Spacer()
        }
        .foregroundStyle(.gray)
        .padding(.leading, 4)
        .padding(.top, 2)
    }

    private func emptyLabel(for section: T3SessionsManager.ServerSection) -> String {
        switch section.status {
        case .connected: return "No active sessions"
        case .unpaired, .tokenExpired: return "Not paired"
        case .badOrigin: return "Invalid address"
        default: return "Not reachable"
        }
    }

    @ViewBuilder
    private var localEmptyState: some View {
        switch manager.localStatus {
        case .connected:
            emptyState(
                icon: "moon.zzz",
                title: "No active sessions",
                subtitle: "Threads appear here as soon as an agent runs."
            )
        case .disabled:
            emptyState(
                icon: nil,
                title: "T3 Code integration is off",
                subtitle: "Enable it in Settings → T3 Code.",
                showsSettings: true
            )
        case .notDetected, .badOrigin, .unreachable:
            emptyState(
                icon: nil,
                title: "T3 Code not detected",
                subtitle: "Install T3 Code or start it with `npx t3`.",
                showsSettings: true
            )
        case .installedNotRunning(let build):
            VStack(spacing: 6) {
                T3LogoView(size: 28)
                    .opacity(0.8)
                Text("T3 Code (\(build)) isn't running")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                Button("Launch T3 Code") {
                    manager.launchDesktop()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .tint(.gray)
            }
            .padding(.horizontal, 24)
        case .unpaired:
            emptyState(
                icon: "link.badge.plus",
                title: "Pair with T3 Code",
                subtitle: "Run `t3 pair` and paste the link in Settings → T3 Code.",
                showsSettings: true
            )
        case .tokenExpired:
            emptyState(
                icon: "clock.badge.exclamationmark",
                title: "Pairing expired",
                subtitle: "Re-pair in Settings → T3 Code.",
                showsSettings: true
            )
        }
    }

    @ViewBuilder
    private func emptyState(
        icon: String?, title: String, subtitle: String, showsSettings: Bool = false
    ) -> some View {
        VStack(spacing: 6) {
            if let icon {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(.gray)
            } else {
                T3LogoView(size: 28)
                    .opacity(0.8)
            }
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
            Text(subtitle)
                .font(.caption)
                .foregroundStyle(.gray)
                .multilineTextAlignment(.center)
            if showsSettings {
                Button("Open Settings") {
                    DispatchQueue.main.async {
                        SettingsWindowController.shared.showWindow()
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .tint(.gray)
            }
        }
        .padding(.horizontal, 24)
    }
}

struct T3ThreadRowView: View {
    let row: T3SessionsManager.ThreadRow

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: row.phase.systemImage)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(row.phase.tint)
                .frame(width: 22)
                .symbolEffect(.pulse, isActive: row.phase == .running || row.phase == .starting)

            VStack(alignment: .leading, spacing: 1) {
                Text(row.thread.title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                HStack(spacing: 4) {
                    Text(row.projectTitle)
                    if let branch = row.thread.branch {
                        Text("·")
                        Text(branch)
                    }
                    if let model = row.thread.modelSelection?.model {
                        Text("·")
                        if let asset = T3Branding.providerAsset(
                            providerName: row.thread.session?.providerName, model: model
                        ) {
                            Image(asset)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 9, height: 9)
                        }
                        Text(model)
                    }
                }
                .font(.caption2)
                .foregroundStyle(.gray)
                .lineLimit(1)
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 1) {
                Text(statusLabel)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(row.phase.tint)
                    .lineLimit(1)
                Text(T3ISODate.relative(row.thread.updatedAt))
                    .font(.caption2)
                    .foregroundStyle(.gray)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(nsColor: .quaternarySystemFill).opacity(0.6))
        )
    }

    private var statusLabel: String {
        if row.phase == .running, let progress = row.thread.planProgress,
           progress.totalSteps > 0
        {
            return "Step \(progress.completedSteps + 1)/\(progress.totalSteps)"
        }
        return row.detail ?? row.phase.headline
    }
}
