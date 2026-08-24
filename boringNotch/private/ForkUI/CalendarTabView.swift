//
//  CalendarTabView.swift
//  boringNotch
//
//  Fork feature: a dedicated full-width calendar tab. Reuses the home-slot
//  calendar's building blocks (WheelPicker, EventListView, CalendarManager)
//  without its 215pt sidebar constraints.
//

import Defaults
import SwiftUI

extension Defaults.Keys {
    /// Show the dedicated Calendar tab in the notch (between Home and T3).
    static let calendarTab = Key<Bool>("calendarTab", default: true)
}

struct CalendarTabView: View {
    @EnvironmentObject var vm: BoringViewModel
    @ObservedObject private var calendarManager = CalendarManager.shared
    @State private var selectedDate = Date()

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            // Left rail: selected date at a glance + jump-to-today.
            VStack(alignment: .leading, spacing: 2) {
                Text(selectedDate.formatted(.dateTime.weekday(.wide)))
                    .font(.caption)
                    .foregroundColor(Color(white: 0.65))
                Text("\(Calendar.current.component(.day, from: selectedDate))")
                    .font(.system(size: 34, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                Text(selectedDate.formatted(.dateTime.month(.wide).year()))
                    .font(.caption)
                    .foregroundColor(Color(white: 0.65))
                Spacer(minLength: 0)
                if !Calendar.current.isDateInToday(selectedDate) {
                    Button("Today") {
                        withAnimation { selectedDate = Date() }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.mini)
                    .tint(.gray)
                }
            }
            .frame(width: 90, alignment: .leading)

            // Right side: full-width date wheel over the day's events.
            VStack(spacing: 2) {
                ZStack(alignment: .top) {
                    WheelPicker(
                        selectedDate: $selectedDate,
                        config: Config(past: 14, future: 30, offset: 5)
                    )
                    HStack(alignment: .top) {
                        LinearGradient(
                            colors: [Color.black, .clear], startPoint: .leading, endPoint: .trailing
                        )
                        .frame(width: 24)
                        Spacer()
                        LinearGradient(
                            colors: [.clear, Color.black], startPoint: .leading, endPoint: .trailing
                        )
                        .frame(width: 24)
                    }
                }
                .frame(height: 50)

                let filteredEvents = EventListView.filteredEvents(events: calendarManager.events)
                if filteredEvents.isEmpty {
                    Spacer(minLength: 0)
                    EmptyEventsView(selectedDate: selectedDate)
                    Spacer(minLength: 0)
                } else {
                    EventListView(events: calendarManager.events)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onChange(of: selectedDate) {
            Task {
                await calendarManager.updateCurrentDate(selectedDate)
            }
        }
        .onChange(of: vm.notchState) { _, _ in
            Task {
                await calendarManager.updateCurrentDate(Date.now)
                selectedDate = Date.now
            }
        }
        .onAppear {
            Task {
                await calendarManager.updateCurrentDate(Date.now)
                selectedDate = Date.now
            }
        }
    }
}
