//
//  T3NotchAlertView.swift
//  boringNotch
//
//  Closed-notch expanding notification for a T3 thread phase change; lays out
//  like the battery status notification (text left, icon right, notch gap
//  in between), with the text using the full available width and a colored
//  status badge on the right.
//

import SwiftUI

struct T3NotchAlertView: View {
    @EnvironmentObject var vm: BoringViewModel
    @ObservedObject var manager = T3SessionsManager.shared

    var body: some View {
        HStack(spacing: 0) {
            HStack(spacing: 6) {
                Text(manager.latestAlert?.phase.headline ?? "")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(alertColor)
                    .lineLimit(1)
                    .fixedSize()
                Text(alertSubtitle)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.7))
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .padding(.trailing, 10)
            .frame(maxWidth: .infinity, alignment: .trailing)

            Rectangle()
                .fill(.black)
                .frame(width: vm.closedNotchSize.width + 10)

            HStack {
                Image(systemName: manager.latestAlert?.phase.systemImage ?? "sparkles")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(alertColor)
                    .frame(width: 26, height: 26)
                    .background(
                        Circle().fill(alertColor.opacity(0.18))
                    )
                    .padding(.leading, 12)
                Spacer(minLength: 0)
            }
            .frame(width: 84, alignment: .leading)
        }
        .frame(height: vm.effectiveClosedNotchHeight, alignment: .center)
    }

    /// Alert-specific color: unlike the tab/live-activity palette (where gray
    /// means "completed" so it doesn't clash with green "active"), a finished
    /// agent reads as a green success here.
    private var alertColor: Color {
        switch manager.latestAlert?.phase {
        case .completed: return .green
        case .failed: return .red
        case .waitingForApproval: return .orange
        case .waitingForInput: return .cyan
        default: return .gray
        }
    }

    private var alertSubtitle: String {
        guard let alert = manager.latestAlert else { return "" }
        if let server = alert.serverName {
            return "\(alert.threadTitle) · \(server)"
        }
        return alert.threadTitle
    }
}
