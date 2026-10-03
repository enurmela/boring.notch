//
//  SoftwareUpdater.swift
//  boringNotch
//
//  Created by Richard Kunkli on 09/08/2024.
//

import SwiftUI
import Sparkle

enum ForkUpdates {
    static var isT3Fork: Bool { Bundle.main.object(forInfoDictionaryKey: "BNT3Fork") as? Bool == true }
    static let repositoryURL = URL(string: "https://github.com/enurmela/boring.notch")!
}

final class CheckForUpdatesViewModel: ObservableObject {
    @Published var canCheckForUpdates = false

    init(updater: SPUUpdater) {
        updater.publisher(for: \.canCheckForUpdates)
            .assign(to: &$canCheckForUpdates)
    }
}

struct CheckForUpdatesView: View {
    @ObservedObject private var checkForUpdatesViewModel: CheckForUpdatesViewModel
    private let updater: SPUUpdater
    
    init(updater: SPUUpdater) {
        self.updater = updater
        
        // Create our view model for our CheckForUpdatesView
        self.checkForUpdatesViewModel = CheckForUpdatesViewModel(updater: updater)
    }
    
    var body: some View {
        if ForkUpdates.isT3Fork {
            Link("View Fork Updates…", destination: ForkUpdates.repositoryURL)
        } else {
            Button("Check for Updates…", action: updater.checkForUpdates)
                .disabled(!checkForUpdatesViewModel.canCheckForUpdates)
        }
    }
}

struct UpdaterSettingsView: View {
    private let updater: SPUUpdater
    
    @State private var automaticallyChecksForUpdates: Bool
    @State private var automaticallyDownloadsUpdates: Bool
    
    init(updater: SPUUpdater) {
        self.updater = updater
        self.automaticallyChecksForUpdates = updater.automaticallyChecksForUpdates
        self.automaticallyDownloadsUpdates = updater.automaticallyDownloadsUpdates
    }
    
    var body: some View {
        Section {
            if ForkUpdates.isT3Fork {
                Text("This build includes the T3 Code integration. Install fork updates to keep it.")
                    .foregroundStyle(.secondary)
                Link("View fork updates", destination: ForkUpdates.repositoryURL)
            } else {
                Toggle("Automatically check for updates", isOn: $automaticallyChecksForUpdates)
                    .onChange(of: automaticallyChecksForUpdates) { _, newValue in
                        updater.automaticallyChecksForUpdates = newValue
                    }
            
                Toggle("Automatically download updates", isOn: $automaticallyDownloadsUpdates)
                    .disabled(!automaticallyChecksForUpdates)
                    .onChange(of: automaticallyDownloadsUpdates) { _, newValue in
                        updater.automaticallyDownloadsUpdates = newValue
                    }
            }
        } header: {
            HStack {
                Text("Software updates")
            }
        }
    }
}
