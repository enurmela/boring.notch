//
//  T3SessionsView.swift
//  boringNotch
//
//  The "T3" notch tab: live agent threads from the local T3 Code server.
//

import Defaults
import SwiftUI

struct T3SessionsView: View {
    @ObservedObject var manager = T3SessionsManager.shared

    var body: some View {
        Group {
            switch manager.status {
            case .connected:
                if manager.rows.isEmpty {
                    emptyState(
                        icon: "moon.zzz",
                        title: "No active sessions",
                        subtitle: "Threads appear here as soon as an agent runs."
                    )
                } else {
                    threadList
                }
            case .disabled:
                emptyState(
                    icon: "sparkles.rectangle.stack",
                    title: "T3 Code integration is off",
                    subtitle: "Enable it in Settings → T3 Code.",
                    showsSettings: true
                )
            case .notDetected:
                emptyState(
                    icon: "questionmark.app.dashed",
                    title: "T3 Code not detected",
                    subtitle: "Install T3 Code or start it with `npx t3`.",
                    showsSettings: true
                )
            case .installedNotRunning(let build):
                emptyState(
                    icon: "power",
                    title: "T3 Code (\(build)) isn't running",
                    subtitle: "Launch the app and sessions will show up here."
                )
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
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var threadList: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 6) {
                ForEach(manager.rows) { row in
                    T3ThreadRowView(row: row)
                }
            }
            .padding(.top, 4)
            .padding(.bottom, 8)
        }
    }

    @ViewBuilder
    private func emptyState(
        icon: String, title: String, subtitle: String, showsSettings: Bool = false
    ) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(.gray)
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
