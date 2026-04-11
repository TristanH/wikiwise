import SwiftUI
import AppKit

extension Notification.Name {
    static let openFolder = Notification.Name("openFolder")
    static let goBack = Notification.Name("goBack")
    static let goForward = Notification.Name("goForward")
    static let refreshWiki = Notification.Name("refreshWiki")
}

enum AppearanceMode: String, CaseIterable {
    case auto = "Auto"
    case light = "Light"
    case dark = "Dark"

    var nsAppearance: NSAppearance? {
        switch self {
        case .auto:  return nil              // follow system
        case .light: return NSAppearance(named: .aqua)
        case .dark:  return NSAppearance(named: .darkAqua)
        }
    }
}

@main
struct WikiwiseApp: App {
    @AppStorage("appearanceMode") private var appearanceMode: String = AppearanceMode.auto.rawValue

    init() {
        NSApplication.shared.setActivationPolicy(.regular)
        NSApplication.shared.activate(ignoringOtherApps: true)
        let mode = AppearanceMode(rawValue: UserDefaults.standard.string(forKey: "appearanceMode") ?? "Auto") ?? .auto
        NSApplication.shared.appearance = mode.nsAppearance

        // Set app icon from bundled .icns
        if let icnsURL = wikiwiseBundle.url(forResource: "Wikiwise", withExtension: "icns"),
           let icon = NSImage(contentsOf: icnsURL) {
            NSApplication.shared.applicationIconImage = icon
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .onChange(of: appearanceMode) { _, newValue in
                    let mode = AppearanceMode(rawValue: newValue) ?? .auto
                    NSApplication.shared.appearance = mode.nsAppearance
                }
        }
        .windowStyle(.titleBar)
        .defaultSize(width: 1330, height: 930)
        .commands {
            CommandGroup(after: .newItem) {
                Divider()

                Button("Go Back") {
                    NotificationCenter.default.post(name: .goBack, object: nil)
                }
                .keyboardShortcut("[", modifiers: .command)

                Button("Go Forward") {
                    NotificationCenter.default.post(name: .goForward, object: nil)
                }
                .keyboardShortcut("]", modifiers: .command)

                Divider()

                Button("Refresh Page") {
                    NotificationCenter.default.post(name: .refreshWiki, object: nil)
                }
                .keyboardShortcut("r", modifiers: .command)
            }
        }
    }
}
