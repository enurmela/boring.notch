//
//  T3HomeWidget.swift
//  boringNotch
//
//  Compact T3 sessions feed for the notch home tab — sits in the calendar's
//  slot when the user opts in. Most recent threads first; tapping one opens
//  its chat in T3 Code.
//

import Defaults
import SwiftUI

struct T3HomeWidget: View {
    @ObservedObject var manager = T3SessionsManager.shared

    private var rows: [T3SessionsManager.ThreadRow] {
        Array(manager.recentRows.prefix(3))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 5) {
                T3GlyphView(size: 12)
                Text("T3 Code")
                    .font(.caption2.weight(.semibold))
                    .textCase(.uppercase)
                Spacer()
                if manager.actionableCount > 0 {
                    Text("\(manager.actionableCount)")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(Capsule().fill(Color.orange))
                }
            }
            .foregroundStyle(.gray)

            if rows.isEmpty {
                Spacer()
                HStack {
                    Spacer()
                    VStack(spacing: 4) {
                        Image(systemName: "moon.zzz")
                            .foregroundStyle(.gray)
                        Text(manager.localStatus.isReachable ? "No sessions" : "T3 Code offline")
                            .font(.caption2)
                            .foregroundStyle(.gray)
                    }
                    Spacer()
                }
                Spacer()
            } else {
                ForEach(rows) { row in
                    Button {
                        manager.openThread(row)
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: row.phase.systemImage)
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(row.phase.tint)
                                .frame(width: 13)
                            VStack(alignment: .leading, spacing: 0) {
                                Text(row.thread.title)
                                    .font(.caption2.weight(.medium))
                                    .foregroundStyle(.white)
                                    .lineLimit(1)
                                Text(row.projectTitle)
                                    .font(.system(size: 9))
                                    .foregroundStyle(.gray)
                                    .lineLimit(1)
                            }
                            Spacer(minLength: 4)
                            Text(T3ISODate.relative(row.thread.updatedAt))
                                .font(.system(size: 9))
                                .foregroundStyle(.gray)
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color(nsColor: .quaternarySystemFill).opacity(0.55))
                        )
                        .contentShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                Spacer(minLength: 0)
            }
        }
        .padding(.top, 2)
    }
}
