//
//  T3DesktopControl.swift
//  boringNotch
//
//  Opens threads in the T3 Code desktop app through its t3code:// URL
//  scheme. The app routes `t3code://threads/{env}/{thread}` to the thread,
//  launching itself first when it isn't running.
//

import AppKit
import Foundation

enum T3DesktopControl {
    private static let appCandidates = [
        "/Applications/T3 Code.app",
        "/Applications/T3 Code (Nightly).app",
    ]

    /// The running app wins when stable and nightly are both installed,
    /// since both register the t3code scheme.
    static var installedAppURL: URL? {
        if let url = runningApp()?.bundleURL { return url }
        for path in appCandidates where FileManager.default.fileExists(atPath: path) {
            return URL(fileURLWithPath: path)
        }
        return nil
    }

    static func runningApp() -> NSRunningApplication? {
        for path in appCandidates {
            guard let bundleId = Bundle(path: path)?.bundleIdentifier else { continue }
            if let app = NSRunningApplication.runningApplications(withBundleIdentifier: bundleId).first {
                return app
            }
        }
        return nil
    }

    /// Hands the thread link to the desktop app. Returns false when no app
    /// is installed or Launch Services refuses the open.
    static func open(environmentId: String, threadId: String) async -> Bool {
        guard let appURL = installedAppURL,
              let link = T3ThreadRoute.appURL(environmentId: environmentId, threadId: threadId)
        else { return false }
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        return (try? await NSWorkspace.shared.open([link], withApplicationAt: appURL, configuration: configuration)) != nil
    }

    /// Starts the app, or brings it forward when it's already running.
    static func launch() async {
        guard let appURL = installedAppURL else { return }
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        _ = try? await NSWorkspace.shared.openApplication(at: appURL, configuration: configuration)
    }
}
