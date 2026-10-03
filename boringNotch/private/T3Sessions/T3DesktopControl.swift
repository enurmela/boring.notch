//
//  T3DesktopControl.swift
//  boringNotch
//
//  Navigates the T3 Code desktop app to a specific thread. The app ships no
//  deep-link handling (t3code:// URLs are dropped), but its Electron build
//  leaves DevTools arguments enabled — so when it runs with
//  --remote-debugging-port we can ask its renderer to navigate over CDP.
//  boring.notch launches it with the flag when it isn't running; an already-
//  running instance without the flag needs one relaunch (settings button).
//

import AppKit
import Foundation

enum T3DesktopControl {
    static let debugPort = 9223

    private static let appCandidates = [
        "/Applications/T3 Code.app",
        "/Applications/T3 Code (Nightly).app",
    ]

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

    static func activate() {
        runningApp()?.activate()
    }

    /// True when the app is up with its CDP control channel listening.
    static func isControlAvailable() async -> Bool {
        (try? await debugTargets()) != nil
    }

    /// Points the app's main window at the thread route. The desktop
    /// renderer routes in the URL HASH (`#/threads/{env}/{thread}` in v2 — the pathname is
    /// only the restored initial URL), so this sets location.hash for an
    /// instant in-app navigation; a full Page.navigate reloads and loses to
    /// the app's own state restore. Returns false when the control channel
    /// is unavailable or no app window target exists.
    static func navigate(route: String) async -> Bool {
        guard let targets = try? await debugTargets(),
              let target = targets.first(where: { $0.url.hasPrefix("t3code://app") }),
              let wsURL = URL(string: target.webSocketDebuggerUrl)
        else { return false }

        let task = URLSession.shared.webSocketTask(with: wsURL)
        task.resume()
        defer { task.cancel(with: .normalClosure, reason: nil) }

        do {
            let hashJSON = try JSONEncoder().encode("#\(route)")
            let expression = "location.hash = \(String(decoding: hashJSON, as: UTF8.self))"
            let command = try JSONSerialization.data(withJSONObject: [
                "id": 1, "method": "Runtime.evaluate", "params": ["expression": expression],
            ])
            try await task.send(.string(String(decoding: command, as: UTF8.self)))
            let message = try await task.receive()
            let data: Data
            switch message {
            case .data(let value): data = value
            case .string(let value): data = Data(value.utf8)
            @unknown default: return false
            }
            guard let response = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  response["error"] == nil,
                  let result = response["result"] as? [String: Any]
            else { return false }
            return result["exceptionDetails"] == nil
        } catch {
            return false
        }
    }

    /// Launches the desktop app with the control flag and waits for the
    /// channel to come up. Only call when the app is not already running.
    static func launchWithControl() async -> Bool {
        guard let appURL = installedAppURL else { return false }
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.arguments = ["--remote-debugging-port=\(debugPort)"]
        guard (try? await NSWorkspace.shared.openApplication(at: appURL, configuration: configuration)) != nil else {
            return false
        }
        for _ in 0..<30 {
            try? await Task.sleep(for: .milliseconds(500))
            if await isControlAvailable() { return true }
        }
        return false
    }

    /// Gracefully quits a running instance (so its server child shuts down
    /// cleanly) and relaunches with the control flag.
    static func relaunchWithControl() async -> Bool {
        if let app = runningApp() {
            app.terminate()
            for _ in 0..<20 where !app.isTerminated {
                try? await Task.sleep(for: .milliseconds(500))
            }
            if !app.isTerminated {
                return false
            }
            try? await Task.sleep(for: .seconds(1))
        }
        return await launchWithControl()
    }

    // MARK: - CDP plumbing

    private struct DebugTarget: Decodable {
        let type: String
        let url: String
        let webSocketDebuggerUrl: String
    }

    private static func debugTargets() async throws -> [DebugTarget] {
        var request = URLRequest(url: URL(string: "http://127.0.0.1:\(debugPort)/json/list")!)
        request.timeoutInterval = 1.5
        let (data, _) = try await URLSession.shared.data(for: request)
        return try JSONDecoder().decode([DebugTarget].self, from: data)
            .filter { $0.type == "page" }
    }
}
