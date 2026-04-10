import SwiftUI
import AppKit

extension Notification.Name {
    static let openFolder = Notification.Name("openFolder")
    static let goBack = Notification.Name("goBack")
    static let goForward = Notification.Name("goForward")
    static let refreshWiki = Notification.Name("refreshWiki")
}

@main
struct WikiwiseApp: App {
    init() {
        NSApplication.shared.setActivationPolicy(.regular)
        NSApplication.shared.activate(ignoringOtherApps: true)
        // Force light appearance — the editorial palette doesn't support dark mode
        NSApplication.shared.appearance = NSAppearance(named: .aqua)

        // Set app icon from bundled .icns
        if let icnsURL = wikiwiseBundle.url(forResource: "Wikiwise", withExtension: "icns"),
           let icon = NSImage(contentsOf: icnsURL) {
            NSApplication.shared.applicationIconImage = icon
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .windowStyle(.titleBar)
        .defaultSize(width: 1000, height: 700)
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
