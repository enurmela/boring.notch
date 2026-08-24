//
//  CalendarTabView.swift
//  boringNotch
//
//  Fork feature: a dedicated full-width calendar tab. Weekly Mon–Sun strip
//  with chevron week paging over the day's events; reuses the home-slot
//  calendar's EventListView/CalendarManager.
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
        HStack(alignment: .top, spacing: 18) {
            // Left rail: selected date at a glance + jump-to-today.
            VStack(alignment: .leading, spacing: 0) {
                Text(selectedDate.formatted(.dateTime.weekday(.wide)))
                    .font(.subheadline)
                    .foregroundColor(Color(white: 0.65))
                Text("\(Calendar.current.component(.day, from: selectedDate))")
                    .font(.system(size: 52, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .padding(.vertical, -4)
                Text(selectedDate.formatted(.dateTime.month(.wide)))
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.85))
                Text(selectedDate.formatted(.dateTime.year()))
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
            .frame(width: 100, alignment: .leading)

            // Right side: Mon–Sun week strip over the day's events.
            VStack(spacing: 4) {
                WeekStrip(selectedDate: $selectedDate)

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

/// One week, Monday through Sunday, with chevrons to page between weeks.
struct WeekStrip: View {
    @Binding var selectedDate: Date
    @State private var haptics = false

    /// ISO calendar: weeks start on Monday regardless of locale setting.
    private var calendar: Calendar {
        var cal = Calendar(identifier: .iso8601)
        cal.timeZone = .current
        return cal
    }

    private var weekDays: [Date] {
        guard
            let start = calendar.dateInterval(of: .weekOfYear, for: selectedDate)?.start
        else { return [] }
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: start) }
    }

    var body: some View {
        HStack(spacing: 4) {
            chevron("chevron.left", days: -7)

            HStack(spacing: 0) {
                ForEach(weekDays, id: \.self) { day in
                    dayCell(day)
                        .frame(maxWidth: .infinity)
                }
            }

            chevron("chevron.right", days: 7)
        }
        .sensoryFeedback(.alignment, trigger: haptics)
        .frame(height: 52)
    }

    private func chevron(_ symbol: String, days: Int) -> some View {
        Button {
            if let date = calendar.date(byAdding: .day, value: days, to: selectedDate) {
                withAnimation { selectedDate = date }
            }
        } label: {
            Image(systemName: symbol)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(Color(white: 0.65))
                .frame(width: 20, height: 40)
                .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }

    private func dayCell(_ day: Date) -> some View {
        let isSelected = calendar.isDate(day, inSameDayAs: selectedDate)
        let isToday = calendar.isDateInToday(day)
        return Button {
            selectedDate = day
            if Defaults[.enableHaptics] {
                haptics.toggle()
            }
        } label: {
            VStack(spacing: 6) {
                Text(day.formatted(.dateTime.weekday(.abbreviated)))
                    .font(.caption)
                    .foregroundColor(isSelected ? .white : Color(white: 0.65))
                ZStack {
                    Circle()
                        .fill(isToday ? Color.effectiveAccent : .clear)
                        .frame(width: 22, height: 22)
                    Text("\(calendar.component(.day, from: day))")
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundColor(isSelected ? .white : Color(white: isToday ? 0.9 : 0.65))
                }
            }
            .padding(.vertical, 4)
            .padding(.horizontal, 2)
            .background(isSelected ? Color.effectiveAccentBackground : Color.clear)
            .cornerRadius(8)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }
}
