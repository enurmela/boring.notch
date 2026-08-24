//
//  T3LiveActivityView.swift
//  boringNotch
//
//  Closed-notch live status for T3 Code, mirroring the music live activity's
//  layout: T3 glyph left of the notch, compact phase counts right of it.
//  Shown while agents are running, waiting on the user, or freshly finished
//  (and music is idle — music keeps priority over the closed notch).
//

import SwiftUI

struct T3LiveActivityView: View {
    @EnvironmentObject var vm: BoringViewModel
    @ObservedObject var manager = T3SessionsManager.shared

    /// Width reserved right of the notch; ContentView's chin math must match.
    static let trailingWidth: CGFloat = 56

    var body: some View {
        HStack(spacing: 0) {
            HStack {
                T3GlyphView(size: max(0, vm.effectiveClosedNotchHeight - 14))
                    .foregroundStyle(.white)
            }
            .frame(
                width: max(0, vm.effectiveClosedNotchHeight - 12),
                height: max(0, vm.effectiveClosedNotchHeight - 12)
            )

            Rectangle()
                .fill(.black)
                .frame(width: vm.closedNotchSize.width - cornerRadiusInsets.closed.top)

            T3LiveBadges()
                .frame(width: Self.trailingWidth, alignment: .center)
        }
        .frame(height: vm.effectiveClosedNotchHeight, alignment: .center)
    }
}

/// The compact phase counts alone — also docked next to the music visualizer
/// when both live activities are on at once.
struct T3LiveBadges: View {
    @ObservedObject var manager = T3SessionsManager.shared

    /// Width the notch chin reserves when these badges ride along with the
    /// music live activity.
    static let width: CGFloat = 50

    var body: some View {
        HStack(spacing: 5) {
            if manager.waitingCount > 0 {
                countBadge(manager.waitingCount, color: .orange)
            }
            if manager.activeCount > 0 {
                countBadge(manager.activeCount, color: .green)
            }
            if manager.waitingCount == 0, manager.activeCount == 0,
               manager.recentlyCompletedCount > 0
            {
                countBadge(manager.recentlyCompletedCount, color: .gray, symbol: "checkmark")
            }
            // Idle: nothing running/waiting/just-finished — a dim dot so the
            // ambient "T3 connected" indicator still reads as present.
            if manager.waitingCount == 0, manager.activeCount == 0,
               manager.recentlyCompletedCount == 0
            {
                Circle()
                    .fill(Color.gray.opacity(0.55))
                    .frame(width: 5, height: 5)
            }
        }
    }

    @ViewBuilder
    private func countBadge(_ count: Int, color: Color, symbol: String? = nil) -> some View {
        HStack(spacing: 2) {
            if let symbol {
                Image(systemName: symbol)
                    .font(.system(size: 7, weight: .bold))
            } else {
                Circle()
                    .fill(color)
                    .frame(width: 5, height: 5)
            }
            Text("\(count)")
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .monospacedDigit()
        }
        .foregroundStyle(color)
    }
}
