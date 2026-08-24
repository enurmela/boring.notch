//
//  HomeSettings.swift
//  boringNotch
//
//  Fork feature: a "Home" settings pane owning the home-tab layout. One picker
//  decides what sits beside the music player (calendar, T3 sessions, nothing),
//  replacing the two competing toggles that lived in the Calendar and T3 panes.
//

import Defaults
import SwiftUI

enum HomeWidget: String, CaseIterable, Identifiable, Defaults.Serializable {
    case calendar
    case t3Sessions
    case nothing

    var id: String { rawValue }

    var label: String {
        switch self {
        case .calendar: return "Calendar"
        case .t3Sessions: return "T3 Code sessions"
        case .nothing: return "Nothing"
        }
    }
}

extension Defaults.Keys {
    /// nil = not chosen yet; resolved from the legacy keys on first read.
    static let homeWidget = Key<HomeWidget?>("homeWidget", default: nil)
}

enum HomeWidgetPreference {
    /// The effective choice, deriving a default from the legacy
    /// showCalendar / t3ReplaceCalendar keys for existing installs.
    static var current: HomeWidget {
        if let choice = Defaults[.homeWidget] { return choice }
        if Defaults[.enableT3Sessions] && Defaults[.t3ReplaceCalendar] { return .t3Sessions }
        return Defaults[.showCalendar] ? .calendar : .nothing
    }

    /// Store the choice and keep the legacy keys coherent — upstream code
    /// (camera edge-hiding, calendar settings enablement) reads showCalendar.
    static func set(_ choice: HomeWidget) {
        Defaults[.homeWidget] = choice
        Defaults[.showCalendar] = choice == .calendar
        Defaults[.t3ReplaceCalendar] = choice == .t3Sessions
    }
}

struct HomeSettings: View {
    @ObservedObject private var manager = T3SessionsManager.shared
    @State private var selection: HomeWidget = HomeWidgetPreference.current

    var body: some View {
        Form {
            Section {
                Picker("Beside the music player", selection: $selection) {
                    ForEach(HomeWidget.allCases) { choice in
                        Text(choice.label).tag(choice)
                    }
                }
                .pickerStyle(.inline)
                .onChange(of: selection) {
                    HomeWidgetPreference.set(selection)
                }
            } header: {
                Text("Home tab layout")
            } footer: {
                Text("The Home tab always shows the music player. This picks what fills the right side. The full calendar keeps its own tab regardless (Settings → Calendar), and T3 Code sessions keep theirs.")
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Home")
    }
}
