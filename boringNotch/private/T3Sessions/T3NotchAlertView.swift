//
//  T3NotchAlertView.swift
//  boringNotch
//
//  Closed-notch expanding notification for a T3 thread phase change. The
//  chin is centered on the hardware notch, so both wings get the same width
//  and the black gap lands exactly over the camera housing: status on the
//  left, thread title on the right.
//

import SwiftUI

struct T3NotchAlertView: View {
    @EnvironmentObject var vm: BoringViewModel
    @ObservedObject var manager = T3SessionsManager.shared

    /// Chin width while the alert shows; ContentView sizes the notch with it.
    /// The notch window is only `windowSize.width` wide and the closed shape
    /// pads its content on both sides, so anything wider gets squeezed.
    static let chinWidth: CGFloat = windowSize.width - 2 * cornerRadiusInsets.closed.bottom
    private static let notchClearance: CGFloat = 8

    private var gapWidth: CGFloat { vm.closedNotchSize.width + 2 * Self.notchClearance }
    private var wingWidth: CGFloat { max(0, (Self.chinWidth - gapWidth) / 2) }

    var body: some View {
        HStack(spacing: 0) {
            HStack(spacing: 7) {
                Image(systemName: manager.latestAlert?.phase.systemImage ?? "sparkles")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(alertColor)
                    .frame(width: 22, height: 22)
                    .background(Circle().fill(alertColor.opacity(0.18)))
                Text(manager.latestAlert?.phase.headline ?? "")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(alertColor)
                    .lineLimit(1)
            }
            .frame(width: wingWidth, alignment: .trailing)

            Rectangle()
                .fill(.black)
                .frame(width: gapWidth)

            // Long titles take a second line; the notch is tall enough for
            // two, and Text drops the second where it isn't.
            Text(alertSubtitle)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.85))
                .lineLimit(2)
                .lineSpacing(-1)
                .truncationMode(.tail)
                .padding(.trailing, 4)
                .frame(width: wingWidth, height: vm.effectiveClosedNotchHeight, alignment: .leading)
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
