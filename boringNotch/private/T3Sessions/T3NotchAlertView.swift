//
//  T3NotchAlertView.swift
//  boringNotch
//
//  Closed-notch expanding notification for a T3 thread phase change; lays out
//  like the battery status notification (text left, icon right, notch gap
//  in between).
//

import SwiftUI

struct T3NotchAlertView: View {
    @EnvironmentObject var vm: BoringViewModel
    @ObservedObject var manager = T3SessionsManager.shared

    var body: some View {
        HStack(spacing: 0) {
            HStack(spacing: 6) {
                Text(manager.latestAlert?.phase.headline ?? "")
                    .font(.subheadline)
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text(alertSubtitle)
                    .font(.subheadline)
                    .foregroundStyle(.gray)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .frame(maxWidth: 250, alignment: .trailing)

            Rectangle()
                .fill(.black)
                .frame(width: vm.closedNotchSize.width + 10)

            HStack {
                Image(systemName: manager.latestAlert?.phase.systemImage ?? "sparkles")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(manager.latestAlert?.phase.tint ?? .gray)
            }
            .frame(width: 76, alignment: .leading)
        }
        .frame(height: vm.effectiveClosedNotchHeight, alignment: .center)
    }

    private var alertSubtitle: String {
        guard let alert = manager.latestAlert else { return "" }
        if let server = alert.serverName {
            return "\(alert.threadTitle) · \(server)"
        }
        return alert.threadTitle
    }
}
