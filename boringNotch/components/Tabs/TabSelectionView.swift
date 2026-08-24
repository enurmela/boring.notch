//
//  TabSelectionView.swift
//  boringNotch
//
//  Created by Hugo Persson on 2024-08-25.
//

import Defaults
import SwiftUI

struct TabModel: Identifiable {
    let id = UUID()
    let label: String
    let icon: String
    let view: NotchViews
}

// Stable instances: TabModel.id is a fresh UUID per init, so building models
// inside the computed tab list would churn ForEach identity every render.
let homeTab = TabModel(label: "Home", icon: "house.fill", view: .home)
let calendarTab = TabModel(label: "Calendar", icon: "calendar", view: .calendar)
let t3SessionsTab = TabModel(label: "T3", icon: T3Branding.tabIconToken, view: .t3Sessions)
let shelfTab = TabModel(label: "Shelf", icon: "tray.fill", view: .shelf)

let tabs = [homeTab, shelfTab]

struct TabSelectionView: View {
    @ObservedObject var coordinator = BoringViewCoordinator.shared
    @Default(.enableT3Sessions) var enableT3Sessions
    @Default(.calendarTab) var showCalendarTab
    @Namespace var animation
    var availableTabs: [TabModel] {
        var list = [homeTab]
        if showCalendarTab { list.append(calendarTab) }
        if enableT3Sessions { list.append(t3SessionsTab) }
        list.append(shelfTab)
        return list
    }
    var body: some View {
        HStack(spacing: 0) {
            ForEach(availableTabs) { tab in
                    TabButton(label: tab.label, icon: tab.icon, selected: coordinator.currentView == tab.view) {
                        withAnimation(.smooth) {
                            coordinator.currentView = tab.view
                        }
                    }
                    .frame(height: 26)
                    .foregroundStyle(tab.view == coordinator.currentView ? .white : .gray)
                    .background {
                        if tab.view == coordinator.currentView {
                            Capsule()
                                .fill(coordinator.currentView == tab.view ? Color(nsColor: .secondarySystemFill) : Color.clear)
                                .matchedGeometryEffect(id: "capsule", in: animation)
                        } else {
                            Capsule()
                                .fill(coordinator.currentView == tab.view ? Color(nsColor: .secondarySystemFill) : Color.clear)
                                .matchedGeometryEffect(id: "capsule", in: animation)
                                .hidden()
                        }
                    }
            }
        }
        .clipShape(Capsule())
    }
}

#Preview {
    BoringHeader().environmentObject(BoringViewModel())
}
