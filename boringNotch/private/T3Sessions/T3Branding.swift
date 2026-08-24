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

    /// Sentinel `TabModel.icon` value telling TabButton to draw the T3 glyph
    /// instead of an SF Symbol.
    static let tabIconToken = "t3.glyph"

    /// Template asset name for the thread's model provider mark (svgl.app
    /// logos in Assets.xcassets), nil when we don't have one.
    static func providerAsset(providerName: String?, model: String?) -> String? {
        let haystack = "\(providerName ?? "") \(model ?? "")".lowercased()
        if haystack.contains("claude") || haystack.contains("anthropic") {
            return "T3ProviderAnthropic"
        }
        if haystack.contains("codex") || haystack.contains("gpt") || haystack.contains("openai") {
            return "T3ProviderOpenAI"
        }
        return nil
    }

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

/// Monochrome "T3" badge drawn natively — matches SF Symbol template styling
/// (inherits foreground color), for places like the settings sidebar where the
/// full-color app icon clashes.
struct T3GlyphView: View {
    var size: CGFloat = 16

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.24)
                .strokeBorder(lineWidth: max(1, size * 0.08))
            Text("T3")
                .font(.system(size: size * 0.5, weight: .heavy, design: .rounded))
        }
        .frame(width: size, height: size)
    }
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
