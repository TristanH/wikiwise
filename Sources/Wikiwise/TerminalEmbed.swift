import SwiftUI
import AppKit
import SwiftTerm

/// Holds a terminal session that survives SwiftUI view lifecycle changes.
/// Create once in ContentView as a @StateObject, pass to TerminalEmbed.
class TerminalSession: ObservableObject {
    let terminalView: LocalProcessTerminalView
    private(set) var isStarted = false

    init() {
        self.terminalView = LocalProcessTerminalView(frame: .zero)
    }

    /// Start the shell process. Safe to call multiple times — only starts once.
    func startIfNeeded(workingDirectory: URL?) {
        guard !isStarted else { return }
        isStarted = true

        let tv = terminalView
        tv.autoresizingMask = [.width, .height]

        // Colors matched to Paper design
        tv.nativeBackgroundColor = NSColor(red: 0xF3/255, green: 0xED/255, blue: 0xDE/255, alpha: 1) // #F3EDDE
        tv.nativeForegroundColor = NSColor(red: 0x5B/255, green: 0x52/255, blue: 0x40/255, alpha: 1) // #5B5240

        // JetBrains Mono if available, otherwise system monospaced
        if let jb = NSFont(name: "JetBrains Mono", size: 12) {
            tv.font = jb
        } else {
            tv.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        }

        // Remap ANSI colors to warm editorial palette.
        // SwiftTerm.Color uses UInt16 (0-65535). Convert 8-bit: val * 257.
        let warmColors: [SwiftTerm.Color] = [
            SwiftTerm.Color(red: 0x3A * 257, green: 0x2F * 257, blue: 0x1C * 257),  // 0  black — dark ink
            SwiftTerm.Color(red: 0x9B * 257, green: 0x3D * 257, blue: 0x3D * 257),  // 1  red — muted editorial red
            SwiftTerm.Color(red: 0x6B * 257, green: 0x7F * 257, blue: 0x4A * 257),  // 2  green — olive
            SwiftTerm.Color(red: 0xB8 * 257, green: 0x9B * 257, blue: 0x5A * 257),  // 3  yellow — gold
            SwiftTerm.Color(red: 0x5B * 257, green: 0x6A * 257, blue: 0x8A * 257),  // 4  blue — muted indigo
            SwiftTerm.Color(red: 0x8A * 257, green: 0x5B * 257, blue: 0x7A * 257),  // 5  magenta — dusty rose
            SwiftTerm.Color(red: 0x5B * 257, green: 0x7F * 257, blue: 0x7F * 257),  // 6  cyan — muted teal
            SwiftTerm.Color(red: 0xD9 * 257, green: 0xCF * 257, blue: 0xB9 * 257),  // 7  white — light cream
            SwiftTerm.Color(red: 0x7A * 257, green: 0x6E * 257, blue: 0x54 * 257),  // 8  bright black — muted brown
            SwiftTerm.Color(red: 0xB8 * 257, green: 0x4E * 257, blue: 0x4E * 257),  // 9  bright red
            SwiftTerm.Color(red: 0x7F * 257, green: 0x96 * 257, blue: 0x5B * 257),  // 10 bright green
            SwiftTerm.Color(red: 0xC8 * 257, green: 0xAE * 257, blue: 0x6B * 257),  // 11 bright yellow
            SwiftTerm.Color(red: 0x6B * 257, green: 0x7F * 257, blue: 0xA3 * 257),  // 12 bright blue
            SwiftTerm.Color(red: 0xA3 * 257, green: 0x6B * 257, blue: 0x8F * 257),  // 13 bright magenta
            SwiftTerm.Color(red: 0x6B * 257, green: 0x96 * 257, blue: 0x96 * 257),  // 14 bright cyan
            SwiftTerm.Color(red: 0xF3 * 257, green: 0xED * 257, blue: 0xDE * 257),  // 15 bright white — cream
        ]
        tv.installColors(warmColors)

        let shell = ProcessInfo.processInfo.environment["SHELL"] ?? "/bin/zsh"
        let cwd = workingDirectory?.path ?? FileManager.default.homeDirectoryForCurrentUser.path

        tv.startProcess(
            executable: shell,
            args: [],
            environment: nil,
            execName: "-\((shell as NSString).lastPathComponent)",
            currentDirectory: cwd
        )
    }
}

/// NSViewRepresentable wrapper that displays an existing TerminalSession.
struct TerminalEmbed: NSViewRepresentable {
    let session: TerminalSession

    func makeNSView(context: Context) -> NSView {
        session.terminalView
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}
