//
//  T3Branding.swift
//  boringNotch
//
//  The real T3 Code icon, read at runtime from the installed app bundle so we
//  don't have to vendor trademark assets into the fork. Falls back to an SF
//  Symbol when no build is installed.
//

import AppKit
import SwiftUI

enum T3Branding {
    static let fallbackSymbol = "sparkles.rectangle.stack"

    static let appIcon: NSImage? = {
        let candidates = [
            "/Applications/T3 Code.app",
            "/Applications/T3 Code (Nightly).app",
        ]
        for path in candidates where FileManager.default.fileExists(atPath: path) {
            return NSWorkspace.shared.icon(forFile: path)
        }
        return nil
    }()
}

/// T3 Code logo at a given point size, SF Symbol fallback when not installed.
struct T3LogoView: View {
    var size: CGFloat = 18

    var body: some View {
        if let icon = T3Branding.appIcon {
            Image(nsImage: icon)
                .resizable()
                .interpolation(.high)
                .scaledToFit()
                .frame(width: size, height: size)
        } else {
            Image(systemName: T3Branding.fallbackSymbol)
                .font(.system(size: size * 0.8))
        }
    }
}
