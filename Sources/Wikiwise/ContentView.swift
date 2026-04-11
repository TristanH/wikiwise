import SwiftUI
import AppKit

// MARK: - Folder icon (matches Paper's SVG exactly)

/// Draws a folder icon from Paper's SVG path.
/// `isSpecial` = true uses brown tones + center dot (for raw/ and site/ folders).
/// `isSpecial` = false uses olive tones, no dot (all other folders).
struct FolderIcon: View {
    var size: CGFloat = 12
    var isSpecial: Bool = false

    private var strokeColor: Color { isSpecial ? .folderRawStroke : .folderStroke }
    private var fillColor: Color { (isSpecial ? Color.folderRawStroke : Color.folderStroke).opacity(isSpecial ? 0.3 : 0.25) }

    var body: some View {
        Canvas { context, canvasSize in
            let s = canvasSize.width / 14.0
            var path = Path()
            path.move(to: CGPoint(x: 0.5 * s, y: 2.5 * s))
            path.addCurve(
                to: CGPoint(x: 2.5 * s, y: 0.5 * s),
                control1: CGPoint(x: 0.5 * s, y: 1.4 * s),
                control2: CGPoint(x: 1.4 * s, y: 0.5 * s)
            )
            path.addLine(to: CGPoint(x: 5.0 * s, y: 0.5 * s))
            path.addLine(to: CGPoint(x: 6.5 * s, y: 2.5 * s))
            path.addLine(to: CGPoint(x: 11.5 * s, y: 2.5 * s))
            path.addCurve(
                to: CGPoint(x: 13.5 * s, y: 4.5 * s),
                control1: CGPoint(x: 12.6 * s, y: 2.5 * s),
                control2: CGPoint(x: 13.5 * s, y: 3.4 * s)
            )
            path.addLine(to: CGPoint(x: 13.5 * s, y: 9.5 * s))
            path.addCurve(
                to: CGPoint(x: 11.5 * s, y: 11.5 * s),
                control1: CGPoint(x: 13.5 * s, y: 10.6 * s),
                control2: CGPoint(x: 12.6 * s, y: 11.5 * s)
            )
            path.addLine(to: CGPoint(x: 2.5 * s, y: 11.5 * s))
            path.addCurve(
                to: CGPoint(x: 0.5 * s, y: 9.5 * s),
                control1: CGPoint(x: 1.4 * s, y: 11.5 * s),
                control2: CGPoint(x: 0.5 * s, y: 10.6 * s)
            )
            path.closeSubpath()

            context.fill(path, with: .color(fillColor))
            context.stroke(path, with: .color(strokeColor), lineWidth: 0.8 * s)

            // Center dot — only for special folders (raw, site)
            if isSpecial {
                let dotRect = CGRect(
                    x: (7.0 - 1.5) * s, y: (7.0 - 1.5) * s,
                    width: 3.0 * s, height: 3.0 * s
                )
                context.fill(
                    Path(ellipseIn: dotRect),
                    with: .color(Color.folderRawStroke.opacity(0.5))
                )
            }
        }
        .frame(width: size, height: size * (12.0 / 14.0))
    }
}

// Paper design palette — warm editorial tones from the Marginalia mockup.
// Each color adapts to light/dark appearance via NSColor's dynamic provider.
extension Color {
    private static func adaptive(light: (CGFloat, CGFloat, CGFloat), dark: (CGFloat, CGFloat, CGFloat), alpha: CGFloat = 1) -> Color {
        Color(NSColor(name: nil, dynamicProvider: { appearance in
            let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            let c = isDark ? dark : light
            return NSColor(red: c.0/255, green: c.1/255, blue: c.2/255, alpha: alpha)
        }))
    }

    //                                          Light           Dark
    static let sidebarBg         = adaptive(light: (0xF3, 0xED, 0xDE), dark: (0x0E, 0x0C, 0x08))
    static let sidebarText       = adaptive(light: (0x7A, 0x6E, 0x54), dark: (0xA8, 0x9A, 0x7C))
    static let sidebarTextMuted  = adaptive(light: (0xA8, 0x9A, 0x7C), dark: (0x6F, 0x64, 0x50))
    static let toolbarDisabled   = adaptive(light: (0xD4, 0xC9, 0xAB), dark: (0x3A, 0x34, 0x28))
    static let sidebarHeader     = adaptive(light: (0x9A, 0x8C, 0x6E), dark: (0x6F, 0x64, 0x50))
    static let sidebarFolderName = adaptive(light: (0x3A, 0x2F, 0x1C), dark: (0xA8, 0x9A, 0x7C))
    static let toolbarText       = adaptive(light: (0x5B, 0x52, 0x40), dark: (0x8A, 0x7D, 0x62))
    static let sidebarSelectedBg = adaptive(light: (0xC2, 0xA9, 0x6B), dark: (0xC2, 0xA9, 0x6B), alpha: 0.16)
    static let sidebarSelectedText = adaptive(light: (0x1A, 0x17, 0x14), dark: (0xF4, 0xEA, 0xCF))
    static let sidebarRule       = adaptive(light: (0xD9, 0xCF, 0xB9), dark: (0x2A, 0x24, 0x19))
    static let contentBg         = adaptive(light: (0xF9, 0xF6, 0xF0), dark: (0x1E, 0x1B, 0x14))
    static let dividerGray       = adaptive(light: (0xD9, 0xCF, 0xB9), dark: (0x2A, 0x24, 0x19))
    static let accentGold        = Color(red: 0xC2/255, green: 0xA9/255, blue: 0x6B/255)
    static let accentPrimary     = adaptive(light: (0x7A, 0x1F, 0x1F), dark: (0xC2, 0xA9, 0x6B))
    static let accentPrimaryText = adaptive(light: (0xFF, 0xFF, 0xFF), dark: (0x1A, 0x17, 0x14))
    static let infoValue         = adaptive(light: (0x3A, 0x2F, 0x1C), dark: (0xCF, 0xC3, 0xA3))
    static let linkedText        = adaptive(light: (0x5B, 0x52, 0x40), dark: (0x8A, 0x7D, 0x62))
    static let folderStroke      = adaptive(light: (0x9A, 0x8C, 0x6E), dark: (0x8A, 0x7D, 0x62))
    static let folderRawStroke   = adaptive(light: (0x8A, 0x5C, 0x30), dark: (0xA8, 0x7A, 0x50))
    static let tabActive         = adaptive(light: (0x1A, 0x17, 0x14), dark: (0xF4, 0xEA, 0xCF))
    static let tabInactive       = adaptive(light: (0x7A, 0x6E, 0x54), dark: (0x6F, 0x64, 0x50))
    static let tabActiveBg       = adaptive(light: (0xF6, 0xF1, 0xE7), dark: (0x2A, 0x24, 0x19))
    static let tabBarBg          = adaptive(light: (0xE3, 0xD9, 0xC2), dark: (0x1E, 0x1B, 0x14))
}

enum DetailMode: String, CaseIterable {
    case raw = "File"
    case compiled = "Wiki"
}

struct ContentView: View {
    init() {
        ContentView.instanceCount += 1
        isFirstInstance = ContentView.instanceCount == 1
    }

    @AppStorage("lastFolderPath") private var lastFolderPath: String = ""
    @AppStorage("appearanceMode") private var appearanceMode: String = AppearanceMode.auto.rawValue
    @State private var rootURL: URL? = nil
    @State private var tree: [FileNode] = []
    @State private var selectedFileURL: URL? = nil
    @State private var fileContent: String = ""
    @State private var compiledFileURL: URL? = nil
    @State private var detailMode: DetailMode = .compiled
    @State private var compiler: Compiler? = nil
    @State private var backHistory: [URL] = []
    @State private var forwardHistory: [URL] = []
    @State private var expandedFolders: Set<URL> = []
    @State private var sidebarVisibility: NavigationSplitViewVisibility = .all
    @State private var showNewWikiSheet = false
    @State private var newWikiName = ""
    @State private var newWikiLocation: URL? = nil
    @State private var showPostCreateGuide = false
    @State private var backgroundTimer: Timer? = nil
    @State private var fileWatcher: FileWatcher? = nil
    @State private var webViewReloadToken: Int = 0
    @State private var rightSidebarTab: RightSidebarTab = .terminal
    @State private var showRightSidebar: Bool = true
    @State private var showLeftSidebar: Bool = true
    @State private var rightSidebarWidth: CGFloat = 360
    @State private var leftSidebarWidth: CGFloat = 260
    @StateObject private var terminalSession = TerminalSession()
    @State private var isPublishing = false
    @State private var showPublishConfirm = false
    @State private var pendingSubdomain = ""
    @State private var subdomainAvailability: SubdomainAvailability = .unknown
    @State private var availabilityCheckWork: DispatchWorkItem? = nil
    @State private var publishResult: PublishResult? = nil
    @State private var publishError: String? = nil
    @State private var publishConfig: PublishConfig? = nil

    private var folderDisplayName: String {
        rootURL?.lastPathComponent ?? "WikiWise"
    }

    /// Whether the user has a wiki open (vs. the welcome screen).
    private var hasFolder: Bool { rootURL != nil }

    var body: some View {
        Group {
            if hasFolder {
                wikiView
            } else {
                welcomeView
            }
        }
        .frame(minWidth: 800, minHeight: 500)
        .onAppear {
            restoreLastFolder()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                for window in NSApp.windows {
                    window.titlebarSeparatorStyle = .none
                    window.title = ""
                }
            }
        }
        .onDisappear {
            backgroundTimer?.invalidate()
            backgroundTimer = nil
            fileWatcher?.stop()
            fileWatcher = nil
        }
        .onReceive(NotificationCenter.default.publisher(for: .openFolder)) { _ in
            openFolder()
        }
        .onReceive(NotificationCenter.default.publisher(for: .goBack)) { _ in
            goBack()
        }
        .onReceive(NotificationCenter.default.publisher(for: .goForward)) { _ in
            goForward()
        }
        .onReceive(NotificationCenter.default.publisher(for: .refreshWiki)) { _ in
            if let c = compiler {
                recompileCurrentPage(c)
            }
        }
        .onChange(of: appearanceMode) { _, _ in
            // Force webview reload so CSS prefers-color-scheme picks up the new appearance
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                webViewReloadToken += 1
                terminalSession.updateAppearance()
            }
        }
        .sheet(isPresented: $showNewWikiSheet) {
            newWikiSheet
        }
        .sheet(isPresented: $showPublishConfirm) {
            publishConfirmSheet
        }
        .alert("Publish Error", isPresented: Binding(
            get: { publishError != nil },
            set: { if !$0 { publishError = nil } }
        )) {
            Button("OK") { publishError = nil }
        } message: {
            Text(publishError ?? "")
        }
        .alert("Published!", isPresented: Binding(
            get: { publishResult != nil },
            set: { if !$0 { publishResult = nil } }
        )) {
            Button("Open in Browser") {
                if let url = publishResult?.url { NSWorkspace.shared.open(url) }
                publishResult = nil
            }
            Button("OK") { publishResult = nil }
        } message: {
            if let result = publishResult {
                Text(result.isFirstPublish
                    ? "Your wiki is live at \(result.url.absoluteString)\n\nA publish.json file has been saved to your project. Keep it safe \u{2014} it\u{2019}s your key to update this site."
                    : "Updated \(result.url.absoluteString)")
            }
        }
    }

    // MARK: - Welcome (no folder open)

    @ViewBuilder
    private var welcomeView: some View {
        VStack(spacing: 0) {
            // Welcome content
            VStack(spacing: 32) {
                Spacer()

                VStack(spacing: 12) {
                    Text("W")
                        .font(.system(size: 48, weight: .light, design: .serif))
                        .italic()
                        .foregroundStyle(Color.sidebarSelectedText)

                    Text("WikiWise helps you turn any folder\nof markdown files into a browsable,\npublishable wiki.")
                        .font(.system(size: 15, weight: .regular))
                        .foregroundStyle(Color.sidebarText)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                }

                VStack(spacing: 12) {
                    Button {
                        showNewWikiSheet = true
                        newWikiName = ""
                        newWikiLocation = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("wikis")
                    } label: {
                        HStack {
                            Image(systemName: "plus.circle")
                            Text("Create a New Wiki")
                        }
                        .foregroundStyle(Color.accentPrimaryText)
                        .frame(width: 220)
                        .padding(.vertical, 8)
                        .background(Color.accentPrimary)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)

                    Button {
                        openFolder()
                    } label: {
                        HStack {
                            Image(systemName: "folder")
                            Text("Open Existing Folder")
                        }
                        .foregroundStyle(Color.sidebarSelectedText)
                        .frame(width: 220)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.sidebarRule, lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }

                Text("Don't have a wiki yet? Create one above and\nuse Claude Code, Codex, or Cursor to build it out.")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.sidebarTextMuted)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)

                Spacer()
            }
            .frame(maxWidth: .infinity)
            .background(Color.contentBg)
        }
        .navigationTitle("")
        .toolbarBackground(Color.sidebarBg, for: .windowToolbar)
        .toolbarBackground(.visible, for: .windowToolbar)
        .toolbar {
            ToolbarItem(placement: .navigation) {
                HStack(spacing: 10) {
                    Text("W")
                        .font(.system(size: 18, weight: .medium, design: .serif))
                        .italic()
                        .foregroundStyle(Color.sidebarSelectedText)
                    Text("WikiWise")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color.sidebarText)
                }
            }
        }
    }

    // MARK: - New Wiki Sheet

    @ViewBuilder
    private var newWikiSheet: some View {
        VStack(spacing: 20) {
            Text("Create a New Wiki")
                .font(.system(size: 16, weight: .semibold))

            VStack(alignment: .leading, spacing: 6) {
                Text("Name")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.sidebarText)
                TextField("My Wiki", text: $newWikiName)
                    .textFieldStyle(.roundedBorder)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Location")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.sidebarText)
                HStack {
                    Text(newWikiLocation?.path ?? "~/wikis")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.sidebarTextMuted)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Spacer()
                    Button("Choose…") {
                        let panel = NSOpenPanel()
                        panel.canChooseDirectories = true
                        panel.canChooseFiles = false
                        panel.canCreateDirectories = true
                        panel.message = "Choose where to create your wiki"
                        if panel.runModal() == .OK, let url = panel.url {
                            newWikiLocation = url
                        }
                    }
                }
            }

            HStack {
                Button("Cancel") {
                    showNewWikiSheet = false
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button("Create") {
                    createNewWiki()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(newWikiName.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(24)
        .frame(width: 400)
    }

    // MARK: - Wiki View (folder is open)

    @ViewBuilder
    private var wikiView: some View {
        GeometryReader { geo in
            HStack(spacing: 0) {
                navSplitContent
                    .frame(width: showRightSidebar
                           ? geo.size.width - rightSidebarWidth - 1
                           : geo.size.width)

                if showRightSidebar {
                    Rectangle().fill(Color.dividerGray).frame(width: 1)
                    RightSidebar(
                        activeTab: $rightSidebarTab,
                        isVisible: $showRightSidebar,
                        width: Binding(
                            get: { min(rightSidebarWidth, geo.size.width / 2) },
                            set: { rightSidebarWidth = min($0, geo.size.width / 2) }
                        ),
                        selectedFileURL: selectedFileURL,
                        rootURL: rootURL,
                        terminalSession: terminalSession
                    )
                }
            }
        }
        .background(Color.sidebarBg)
    }

    /// The NavigationSplitView with its toolbar modifiers — extracted so the
    /// GeometryReader in `wikiView` can size it explicitly.
    @ViewBuilder
    private var navSplitContent: some View {
        NavigationSplitView(columnVisibility: $sidebarVisibility) {
            sidebar
                .navigationSplitViewColumnWidth(min: 110, ideal: 260, max: 360)
                .overlay(alignment: .top) {
                    Rectangle().fill(Color.dividerGray).frame(height: 1)
                }
                .overlay(alignment: .trailing) {
                    Rectangle().fill(Color.dividerGray).frame(width: 1)
                }
                .background(GeometryReader { geo in
                    Color.clear.onAppear { leftSidebarWidth = geo.size.width }
                        .onChange(of: geo.size.width) { _, w in leftSidebarWidth = w }
                })
        } detail: {
            detail
                .overlay(alignment: .top) {
                    Rectangle().fill(Color.dividerGray).frame(height: 1)
                }
        }
        .navigationTitle("")
        .toolbar {
            ToolbarItem(placement: .navigation) {
                HStack(spacing: 14) {
                    // Show our custom toggle only when sidebar is closed
                    // (the native one shows when sidebar is open)
                    if sidebarVisibility != .all {
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                sidebarVisibility = .all
                            }
                        } label: {
                            Image(systemName: "sidebar.left")
                                .font(.system(size: 14))
                                .foregroundStyle(Color.toolbarDisabled)
                        }
                        .buttonStyle(.plain)
                        .help("Show Sidebar")
                    }

                    HStack(spacing: 0) {
                        let fileShape = UnevenRoundedRectangle(
                            topLeadingRadius: 3, bottomLeadingRadius: 3,
                            bottomTrailingRadius: 0, topTrailingRadius: 0
                        )
                        let wikiShape = UnevenRoundedRectangle(
                            topLeadingRadius: 0, bottomLeadingRadius: 0,
                            bottomTrailingRadius: 3, topTrailingRadius: 3
                        )

                        Button { detailMode = .raw } label: {
                            Text("FILE")
                                .font(.system(size: 10, weight: .regular, design: .monospaced))
                                .tracking(0.8)
                                .foregroundStyle(detailMode == .raw ? Color.sidebarSelectedText : Color.sidebarTextMuted)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(fileShape.fill(detailMode == .raw ? Color.sidebarSelectedBg : Color.clear))
                                .overlay(fileShape.strokeBorder(Color.sidebarRule, lineWidth: 1))
                        }
                        .buttonStyle(.plain)

                        Button { detailMode = .compiled } label: {
                            Text("WIKI")
                                .font(.system(size: 10, weight: .regular, design: .monospaced))
                                .tracking(0.8)
                                .foregroundStyle(detailMode == .compiled ? Color.sidebarSelectedText : Color.sidebarTextMuted)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(wikiShape.fill(detailMode == .compiled ? Color.sidebarSelectedBg : Color.clear))
                                .overlay(wikiShape.strokeBorder(Color.sidebarRule, lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                    }
                    .fixedSize()

                    Button { goBack() } label: {
                        Text("\u{2190}")
                            .font(.system(size: 16, weight: .regular, design: .monospaced))
                            .foregroundStyle(backHistory.isEmpty ? Color.toolbarDisabled : Color.toolbarText)
                    }
                    .buttonStyle(.plain)
                    .disabled(backHistory.isEmpty)
                    .help("Go Back (\u{2318}[)")

                    Button { goForward() } label: {
                        Text("\u{2192}")
                            .font(.system(size: 16, weight: .regular, design: .monospaced))
                            .foregroundStyle(forwardHistory.isEmpty ? Color.toolbarDisabled : Color.toolbarText)
                    }
                    .buttonStyle(.plain)
                    .disabled(forwardHistory.isEmpty)
                    .help("Go Forward (\u{2318}])")
                }
            }

            // Folder name — centered in toolbar, offset to compensate for right sidebar
            ToolbarItem(placement: .principal) {
                Text(folderDisplayName)
                    .font(.system(size: 13, weight: .regular, design: .serif))
                    .italic()
                    .foregroundStyle(Color.toolbarText)
                    .offset(x: sidebarVisibility == .all ? -(leftSidebarWidth / 2) : 0)
            }

            ToolbarItem(placement: .primaryAction) {
                HStack(spacing: 10) {
                    let currentMode = AppearanceMode(rawValue: appearanceMode) ?? .auto
                    Button {
                        let all = AppearanceMode.allCases
                        let idx = all.firstIndex(of: currentMode) ?? 0
                        appearanceMode = all[(idx + 1) % all.count].rawValue
                    } label: {
                        Image(systemName: currentMode == .dark ? "moon.fill" : currentMode == .light ? "sun.max.fill" : "circle.lefthalf.filled")
                            .font(.system(size: 13))
                            .foregroundStyle(Color.toolbarText)
                    }
                    .buttonStyle(.plain)
                    .help("Appearance: \(currentMode.rawValue)")

                    Button {
                        // Navigate to 3D map
                        if let c = compiler {
                            let mapFile = c.outputDir.appendingPathComponent("map-3d.html")
                            if FileManager.default.fileExists(atPath: mapFile.path) {
                                if let current = selectedFileURL {
                                    backHistory.append(current)
                                    forwardHistory = []
                                } else if let compiled = compiledFileURL {
                                    backHistory.append(compiled)
                                    forwardHistory = []
                                }
                                selectedFileURL = nil
                                fileContent = ""
                                compiledFileURL = mapFile
                                webViewReloadToken += 1
                            }
                        }
                    } label: {
                        Image(systemName: "map")
                            .font(.system(size: 12))
                            .foregroundStyle(Color.toolbarText)
                    }
                    .buttonStyle(.plain)
                    .help("Open 3D Map")

                    Button {
                        if publishConfig == nil {
                            // First publish — show sheet to pick subdomain
                            showPublishConfirm = true
                        } else {
                            // Already published — show sheet with current subdomain
                            pendingSubdomain = publishConfig?.subdomain ?? ""
                            subdomainAvailability = .owned
                            showPublishConfirm = true
                        }
                    } label: {
                        Group {
                            if isPublishing {
                                ProgressView()
                                    .controlSize(.small)
                                    .frame(width: 12, height: 12)
                                Text("PUBLISHING\u{2026}")
                            } else {
                                Text("PUBLISH \u{2191}")
                            }
                        }
                        .font(.system(size: 10, weight: .regular, design: .monospaced))
                        .tracking(0.8)
                        .foregroundStyle(Color.sidebarSelectedText)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 3)
                                .fill(Color.sidebarSelectedBg)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 3)
                                .strokeBorder(Color.sidebarRule, lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(isPublishing || compiler == nil)
                    .help(publishConfig.map { "Last published: \($0.lastPublishedAt ?? "never")\n\($0.url)\n\u{2325}-click to change URL" } ?? "Publish wiki to wiki-wise.com")

                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showRightSidebar.toggle()
                        }
                    } label: {
                        Image(systemName: "sidebar.right")
                            .font(.system(size: 16))
                            .foregroundStyle(showRightSidebar ? Color.toolbarText : Color.toolbarDisabled)
                    }
                    .buttonStyle(.plain)
                    .help(showRightSidebar ? "Hide Right Sidebar" : "Show Right Sidebar")
                }
            }
        }
        .toolbarBackground(Color.sidebarBg, for: .windowToolbar)
        .toolbarBackground(.visible, for: .windowToolbar)
    }

    // MARK: - Sidebar

    @ViewBuilder
    private var sidebar: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text("FILES")
                    .font(.system(size: 9, weight: .regular, design: .monospaced))
                    .tracking(1.6)
                    .foregroundStyle(Color.sidebarHeader)
                    .padding(.horizontal, 18)
                    .padding(.top, 6)
                    .padding(.bottom, 10)

                ForEach(tree) { node in
                    fileTreeRow(node, depth: 0)
                }
            }
            .padding(.bottom, 20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(minWidth: 110, idealWidth: 260)
        .background(Color.sidebarBg)
    }

    private func folderTooltip(_ name: String) -> String {
        switch name {
        case "wiki": return "Wiki pages — your editable knowledge base"
        case "sources": return "Source summaries — one page per ingested source"
        case "raw": return "Raw source documents — read-only originals"
        case "site": return "Build tooling and compiled HTML output"
        default: return name
        }
    }

    private func fileTreeRow(_ node: FileNode, depth: Int) -> AnyView {
        let indent = CGFloat(depth) * 16 + 18

        if node.isDirectory {
            let isExpanded = expandedFolders.contains(node.url)

            return AnyView(VStack(alignment: .leading, spacing: 0) {
                // Folder row
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        if isExpanded {
                            expandedFolders.remove(node.url)
                        } else {
                            expandedFolders.insert(node.url)
                            if let kids = node.children, kids.isEmpty {
                                expandNode(node)
                                let snapshot = tree; tree = []; tree = snapshot
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 5) {
                        Text(isExpanded ? "▾" : "▸")
                            .font(.system(size: 11, weight: .regular))
                            .foregroundStyle(Color.sidebarTextMuted)
                            .frame(width: 10)

                        FolderIcon(size: 13, isSpecial: node.name == "raw" || node.name == "site")

                        Text(node.name)
                            .font(.system(size: 13, weight: .regular, design: .serif))
                            .foregroundStyle(Color.sidebarFolderName)
                    }
                    .padding(.leading, indent)
                    .padding(.vertical, 5)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help(folderTooltip(node.name))

                // Children (when expanded)
                if isExpanded, let children = node.children {
                    ForEach(children) { child in
                        fileTreeRow(child, depth: depth + 1)
                    }
                }
            })
        } else {
            let isSelected = selectedFileURL == node.url
            let specialFiles: Set<String> = ["home.md", "index.md", "log.md"]
            let isSpecialFile = specialFiles.contains(node.name)

            return AnyView(
                Button {
                    navigateTo(node.url)
                } label: {
                    HStack(spacing: 0) {
                        Text(node.name)
                            .font(.system(size: 13, weight: isSpecialFile ? .medium : .regular, design: .serif))
                            .italic(isSelected)
                            .foregroundStyle(isSelected ? Color.sidebarSelectedText : Color.sidebarText)
                            .lineLimit(1)
                    }
                    .padding(.leading, indent + 15)
                    .padding(.vertical, 5)
                    .padding(.trailing, 8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        isSelected
                            ? Color.sidebarSelectedBg
                                .overlay(alignment: .leading) {
                                    Rectangle()
                                        .fill(Color.sidebarSelectedText)
                                        .frame(width: 2)
                                        .padding(.leading, indent + 4)
                                }
                            : nil
                    )
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            )
        }
    }

    // MARK: - Detail

    @ViewBuilder
    private var detail: some View {
        if showPostCreateGuide, let root = rootURL {
            postCreateGuide(wikiURL: root)
        } else if selectedFileURL == nil && compiledFileURL == nil {
            VStack(spacing: 8) {
                Image(systemName: "doc.text")
                    .font(.system(size: 32, weight: .light))
                    .foregroundStyle(Color.sidebarTextMuted)
                Text("Select a file to read")
                    .font(.system(size: 13))
                    .foregroundStyle(Color.sidebarTextMuted)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.contentBg)
        } else if let url = selectedFileURL, url.pathExtension.lowercased() != "md" {
            // Non-markdown files (CSS, JS, JSON) always use the code editor
            EditorWebView(fileURL: url, fileContent: $fileContent)
        } else {
            switch detailMode {
            case .raw:
                if let url = selectedFileURL {
                    EditorWebView(fileURL: url, fileContent: $fileContent)
                }
            case .compiled:
                if let url = compiledFileURL, let c = compiler {
                    WebView(
                        fileURL: url,
                        allowingReadAccessTo: c.outputDir,
                        onNavigate: { htmlURL in
                            handleWikilink(htmlURL)
                        },
                        reloadToken: webViewReloadToken
                    )
                } else if let url = selectedFileURL {
                    // No compiled HTML (e.g. raw/ files) — show editor instead
                    EditorWebView(fileURL: url, fileContent: $fileContent)
                }
            }
        }
    }

    // MARK: - Navigation

    private func navigateTo(_ url: URL) {
        if let current = selectedFileURL, current != url {
            backHistory.append(current)
            forwardHistory = []
        } else if selectedFileURL == nil, let compiled = compiledFileURL {
            // Coming from a generated page (map/graph) — save it for back nav
            backHistory.append(compiled)
            forwardHistory = []
        }
        selectedFileURL = url
        loadFile(url)
        // Force WebView to load the new page (critical when navigating
        // from a generated page like graph/map where the URL must change)
        webViewReloadToken += 1
    }

    private func goBack() {
        guard let previous = backHistory.popLast() else { return }
        if let current = selectedFileURL {
            forwardHistory.append(current)
        } else if let compiled = compiledFileURL {
            forwardHistory.append(compiled)
        }
        // If going back to a generated page (.html), load it directly
        if previous.pathExtension == "html" {
            selectedFileURL = nil
            fileContent = ""
            compiledFileURL = previous
            webViewReloadToken += 1
        } else {
            selectedFileURL = previous
            loadFile(previous)
            webViewReloadToken += 1
        }
    }

    private func goForward() {
        guard let next = forwardHistory.popLast() else { return }
        if let current = selectedFileURL {
            backHistory.append(current)
        } else if let compiled = compiledFileURL {
            backHistory.append(compiled)
        }
        if next.pathExtension == "html" {
            selectedFileURL = nil
            fileContent = ""
            compiledFileURL = next
            webViewReloadToken += 1
        } else {
            selectedFileURL = next
            loadFile(next)
            webViewReloadToken += 1
        }
    }

    private func slug(for url: URL) -> String {
        url.deletingPathExtension().lastPathComponent
            .lowercased().replacingOccurrences(of: " ", with: "-")
    }

    /// Map an HTML URL from the compiled wiki back to its markdown source file,
    /// then navigate to it so the back/forward history stays in sync.
    private func handleWikilink(_ htmlURL: URL) {
        guard let root = rootURL else { return }
        let pageSlug = slug(for: htmlURL)
        // Search wiki/ and raw/ (and root) for a .md file matching this slug
        if let mdURL = findMarkdownFile(slug: pageSlug, in: root) {
            navigateTo(mdURL)
        } else if let c = compiler {
            // Generated pages (graph, map) have no markdown source —
            // load the HTML directly from the output directory.
            let htmlFile = c.outputDir.appendingPathComponent("\(pageSlug).html")
            if FileManager.default.fileExists(atPath: htmlFile.path) {
                if let current = selectedFileURL {
                    backHistory.append(current)
                    forwardHistory = []
                }
                selectedFileURL = nil
                fileContent = ""
                compiledFileURL = htmlFile
                webViewReloadToken += 1
            }
        }
    }

    /// Find a .md file whose slugified name matches the given slug.
    private func findMarkdownFile(slug: String, in dir: URL) -> URL? {
        let fm = FileManager.default
        // Check common locations: wiki/, raw/, then root
        let searchDirs = [
            dir.appendingPathComponent("wiki"),
            dir.appendingPathComponent("raw"),
            dir
        ]
        for searchDir in searchDirs {
            guard let files = try? fm.contentsOfDirectory(at: searchDir, includingPropertiesForKeys: nil) else { continue }
            for file in files where file.pathExtension == "md" {
                if self.slug(for: file) == slug {
                    return file
                }
            }
        }
        return nil
    }

    // MARK: - Actions

    func openFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.folder, .plainText]
        panel.allowsMultipleSelection = false
        panel.message = "Choose a markdown file or a folder"

        guard panel.runModal() == .OK, let url = panel.url else { return }
        openURL(url)
    }

    private func openURL(_ url: URL) {
        var isDir: ObjCBool = false
        FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir)

        if isDir.boolValue {
            backgroundTimer?.invalidate()
            backgroundTimer = nil
            fileWatcher?.stop()
            fileWatcher = nil
            rootURL = url
            tree = scanOneLevel(at: url)
            selectedFileURL = nil
            fileContent = ""
            compiledFileURL = nil
            backHistory = []
            forwardHistory = []
            lastFolderPath = url.path

            // Auto-expand top-level folders except site/
            expandedFolders = Set(tree.filter { $0.isDirectory && $0.name != "site" }.map { $0.url })
            // Lazy-load children for expanded folders
            for node in tree where node.isDirectory {
                if let kids = node.children, kids.isEmpty {
                    expandNode(node)
                }
            }
            let snapshot = tree; tree = []; tree = snapshot

            terminalSession.startIfNeeded(workingDirectory: url)

            let c = Compiler(sourceDir: url)
            compiler = c
            loadPublishConfig()
            // scanPages is fast (~150ms) and JSContext isn't thread-safe,
            // so run it on the main thread to avoid racing with Timer/FileWatcher.
            c.scanPages()
            let home = url.appendingPathComponent("wiki/home.md")
            if FileManager.default.fileExists(atPath: home.path) {
                selectedFileURL = home
                loadFile(home)
            }
            // Background drip: compile remaining pages a few at a time
            startBackgroundCompilation(c)
            // Watch for file changes (CSS, markdown, new/deleted files)
            startFileWatcher(directory: url, compiler: c)
        } else {
            rootURL = url.deletingLastPathComponent()
            tree = []
            selectedFileURL = url
            loadFile(url)
        }
    }

    private func createNewWiki() {
        guard let location = newWikiLocation else { return }
        let name = newWikiName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }

        let slug = name.lowercased()
            .replacingOccurrences(of: " ", with: "-")
            .filter { $0.isLetter || $0.isNumber || $0 == "-" }
        let wikiURL = location.appendingPathComponent(slug)

        do {
            try WikiScaffold.create(at: wikiURL, name: name)
            showNewWikiSheet = false
            showPostCreateGuide = true
            openURL(wikiURL)
        } catch {
            print("[scaffold] Error creating wiki: \(error)")
            // Still dismiss the sheet and show an error
            showNewWikiSheet = false
        }
    }

    /// Tracks how many ContentViews have been created.
    /// The first one restores the last folder; subsequent ones show welcome.
    private static var instanceCount = 0
    private let isFirstInstance: Bool

    private func restoreLastFolder() {
        // Only the first window restores — subsequent windows show welcome
        guard isFirstInstance else { return }
        guard !lastFolderPath.isEmpty else { return }
        let url = URL(fileURLWithPath: lastFolderPath)
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        openURL(url)
    }

    private func loadFile(_ url: URL) {
        fileContent = (try? String(contentsOf: url, encoding: .utf8))
            ?? "Could not read file."

        if let c = compiler {
            let pageSlug = slug(for: url)
            let htmlFile = c.outputDir.appendingPathComponent("\(pageSlug).html")
            // Compile on demand if not yet rendered
            if !FileManager.default.fileExists(atPath: htmlFile.path) {
                if !c.compileSingle(slug: pageSlug) {
                    // Not in the wiki scan — ad-hoc compile (e.g. raw/ files)
                    c.compileAdhoc(filePath: url.path, outputPath: htmlFile.path)
                }
            }
            compiledFileURL = FileManager.default.fileExists(atPath: htmlFile.path) ? htmlFile : nil
        } else {
            compiledFileURL = nil
        }

        writeActiveFile(url)
    }

    /// Write the currently open file path to .claude/active-file so Claude Code
    /// can see which page the user is viewing.
    private func writeActiveFile(_ url: URL) {
        guard let root = rootURL else { return }
        let relativePath = url.path.replacingOccurrences(of: root.path + "/", with: "")
        let activeFile = root.appendingPathComponent(".claude/active-file")
        try? relativePath.write(to: activeFile, atomically: true, encoding: .utf8)
    }

    /// Drip-compile remaining pages in the background so everything is
    /// eventually built without freezing the UI.
    private func startBackgroundCompilation(_ c: Compiler) {
        backgroundTimer?.invalidate()
        backgroundTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { timer in
            let remaining = c.compileNextBatch(size: 3)
            if remaining == 0 {
                timer.invalidate()
                backgroundTimer = nil
                print("[compiler] Background compilation complete")
            }
        }
    }

    /// Watch the source directory for file changes and react:
    /// - CSS change → reload CSS, recompile current page, invalidate rest
    /// - Markdown change → recompile current page (if it changed)
    /// - Structure change (add/delete) → full rescan + restart background drip
    private func startFileWatcher(directory: URL, compiler c: Compiler) {
        let watcher = FileWatcher(directory: directory, outputDir: c.outputDir) { kind in
            switch kind {
            case .css:
                print("[watcher] CSS changed — reloading")
                c.reloadCSS()
                c.invalidateAll()
                // Only reload if viewing a markdown-sourced page
                if selectedFileURL != nil {
                    recompileCurrentPage(c)
                }
                startBackgroundCompilation(c)

            case .markdown(let changedPaths):
                print("[watcher] Markdown changed: \(changedPaths.count) file(s)")
                c.rescan()
                // Only reload if the currently viewed file was one that changed
                if let current = selectedFileURL,
                   changedPaths.contains(current.path) {
                    recompileCurrentPage(c)
                }
                startBackgroundCompilation(c)

            case .rebuild:
                print("[watcher] Rebuild triggered — full recompile")
                // Delete trigger file first so a second touch during rebuild is not lost
                if let root = rootURL {
                    try? FileManager.default.removeItem(at: root.appendingPathComponent(".rebuild"))
                }
                c.rescan()
                c.invalidateAll()
                if selectedFileURL != nil {
                    recompileCurrentPage(c)
                }
                refreshTree()
                startBackgroundCompilation(c)

            case .structure:
                print("[watcher] Files added/deleted — rescanning")
                c.rescan()
                refreshTree()
                // Don't recompile current page on structure changes —
                // new/deleted files don't affect the page being viewed
                startBackgroundCompilation(c)
            }
        }
        watcher.start()
        fileWatcher = watcher
    }

    /// Rescan the sidebar file tree, preserving which folders are expanded.
    private func refreshTree() {
        guard let root = rootURL else { return }
        let previousExpanded = expandedFolders
        tree = scanOneLevel(at: root)
        let newFolderURLs = Set(tree.filter { $0.isDirectory }.map { $0.url })
        expandedFolders = previousExpanded.intersection(newFolderURLs)
        for node in tree where node.isDirectory {
            if expandedFolders.contains(node.url) {
                if let kids = node.children, kids.isEmpty {
                    expandNode(node)
                }
            }
        }
        let snapshot = tree; tree = []; tree = snapshot
    }

    /// Force-recompile and reload the currently displayed page.
    private func recompileCurrentPage(_ c: Compiler) {
        guard let url = selectedFileURL else { return }
        c.invalidateSingle(slug: slug(for: url))
        loadFile(url)
        webViewReloadToken += 1
    }

    // MARK: - Publish

    private func loadPublishConfig() {
        guard let root = rootURL else { publishConfig = nil; return }
        publishConfig = try? Publisher.loadConfig(projectRoot: root)
    }

    private func performPublish(subdomain: String? = nil) {
        guard let root = rootURL, let c = compiler else { return }
        isPublishing = true
        publishError = nil
        publishResult = nil

        Task {
            do {
                // Recompile to ensure output is fresh
                c.compileAll()
                let result = try await Publisher.publish(siteFolder: c.outputDir, projectRoot: root, subdomain: subdomain)
                await MainActor.run {
                    isPublishing = false
                    publishResult = result
                    loadPublishConfig()
                }
            } catch {
                await MainActor.run {
                    isPublishing = false
                    publishError = error.localizedDescription
                }
            }
        }
    }

    @ViewBuilder
    private var publishConfirmSheet: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Publish your wiki")
                .font(.system(size: 18, weight: .medium, design: .serif))

            Text("Your wiki will be available at:")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)

            // Editable subdomain field
            HStack(spacing: 0) {
                Text("https://")
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundStyle(.secondary)
                TextField("subdomain", text: $pendingSubdomain)
                    .font(.system(size: 13, design: .monospaced))
                    .textFieldStyle(.plain)
                    .frame(maxWidth: 200)
                    .onChange(of: pendingSubdomain) { _, newValue in
                        // Sanitize: lowercase, only alphanumeric and hyphens
                        let sanitized = newValue.lowercased()
                            .filter { $0.isLetter || $0.isNumber || $0 == "-" }
                        if sanitized != newValue {
                            pendingSubdomain = sanitized
                            return
                        }
                        checkSubdomainAvailability(sanitized)
                    }
                Text(".wiki-wise.com")
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundStyle(.secondary)

                Spacer()

                // Availability indicator
                Group {
                    switch subdomainAvailability {
                    case .checking:
                        ProgressView()
                            .controlSize(.small)
                    case .available:
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    case .owned:
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.blue)
                    case .taken:
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.red)
                    case .invalid:
                        Image(systemName: "exclamationmark.circle.fill")
                            .foregroundStyle(.orange)
                    case .unknown:
                        EmptyView()
                    }
                }
                .frame(width: 16, height: 16)
            }
            .padding(8)
            .background(RoundedRectangle(cornerRadius: 4).fill(Color.sidebarBg))

            // Availability hint text
            Group {
                switch subdomainAvailability {
                case .taken:
                    Text("This name is already taken. Try another.")
                        .foregroundStyle(.red)
                case .invalid:
                    Text("3\u{2013}48 characters, letters, numbers, and hyphens only.")
                        .foregroundStyle(.orange)
                case .owned:
                    Text("You already own this name.")
                        .foregroundStyle(.blue)
                default:
                    Text("Anyone with this link can view your wiki.")
                        .foregroundStyle(.secondary)
                }
            }
            .font(.system(size: 12))

            Text("A publish.json file will be saved in your project \u{2014} it contains your publish token. Treat it like a password: if you lose it, you won\u{2019}t be able to update this site.")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .lineSpacing(2)

            HStack {
                Spacer()
                Button("Cancel") {
                    showPublishConfirm = false
                }
                .keyboardShortcut(.cancelAction)
                Button("Publish") {
                    showPublishConfirm = false
                    performPublish(subdomain: pendingSubdomain)
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!canPublish)
            }
        }
        .padding(24)
        .frame(width: 480)
        .onAppear {
            if pendingSubdomain.isEmpty {
                let wikiName = rootURL?.lastPathComponent
                pendingSubdomain = Publisher.randomSubdomain(wikiName: wikiName)
            }
        }
    }

    private var canPublish: Bool {
        switch subdomainAvailability {
        case .available, .owned: return true
        default: return false
        }
    }

    private func checkSubdomainAvailability(_ subdomain: String) {
        availabilityCheckWork?.cancel()
        guard subdomain.count >= 3 else {
            subdomainAvailability = subdomain.isEmpty ? .unknown : .invalid
            return
        }
        subdomainAvailability = .checking
        let work = DispatchWorkItem {
            Task {
                let token = publishConfig?.token
                let result = await Publisher.checkAvailability(subdomain: subdomain, token: token)
                await MainActor.run {
                    // Only update if the subdomain hasn't changed while we were checking
                    if pendingSubdomain == subdomain {
                        subdomainAvailability = result
                    }
                }
            }
        }
        availabilityCheckWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4, execute: work)
    }

    // MARK: - Post-Creation Guide

    @ViewBuilder
    private func postCreateGuide(wikiURL: URL) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Your wiki is ready")
                        .font(.system(size: 20, weight: .medium, design: .serif))
                        .foregroundStyle(Color.sidebarSelectedText)

                    Text("WikiWise created the folder structure, build tools, and agent skills. Now seed it with sources.")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.sidebarText)
                        .lineSpacing(3)
                }

                Divider()

                // Agent quick-start
                VStack(alignment: .leading, spacing: 12) {
                    Text("OPEN YOUR AGENT")
                        .font(.system(size: 10, weight: .semibold))
                        .tracking(1.5)
                        .foregroundStyle(Color.sidebarHeader)

                    Text("Use the built-in terminal in the right sidebar, or open your own terminal:")
                        .font(.system(size: 13))
                        .foregroundStyle(Color.sidebarText)

                    VStack(alignment: .leading, spacing: 8) {
                        agentCommand(
                            agent: "Claude Code",
                            command: "cd \(wikiURL.path) && claude"
                        )
                        agentCommand(
                            agent: "Codex",
                            command: "cd \(wikiURL.path) && codex"
                        )
                        agentCommand(
                            agent: "Cursor",
                            command: "Open \(wikiURL.path) in Cursor"
                        )
                    }
                }

                Divider()

                // Seed options
                VStack(alignment: .leading, spacing: 12) {
                    Text("SEED YOUR WIKI")
                        .font(.system(size: 10, weight: .semibold))
                        .tracking(1.5)
                        .foregroundStyle(Color.sidebarHeader)

                    Text("Once your agent is running, try:")
                        .font(.system(size: 13))
                        .foregroundStyle(Color.sidebarText)

                    VStack(alignment: .leading, spacing: 10) {
                        seedOption(
                            icon: "book",
                            title: "Import from Readwise",
                            command: "/import-readwise"
                        )
                        seedOption(
                            icon: "link",
                            title: "Ingest an article",
                            command: "Ingest this article: [paste URL]"
                        )
                        seedOption(
                            icon: "folder",
                            title: "Import existing files",
                            command: "Ingest the files in ~/my-notes/ into this wiki"
                        )
                        seedOption(
                            icon: "text.bubble",
                            title: "Start from a topic",
                            command: "Start a wiki about [your topic]"
                        )
                    }
                }

                Divider()

                Text("This is your project. You can change anything about it with your agent — the styles, the structure of your wiki pages, the build pipeline. Make it your own.")
                    .font(.system(size: 13))
                    .foregroundStyle(Color.sidebarText)
                    .lineSpacing(2)

                Button("Got it — start reading") {
                    showPostCreateGuide = false
                    // Select home.md if it exists
                    if let root = rootURL {
                        let home = root.appendingPathComponent("wiki/home.md")
                        if FileManager.default.fileExists(atPath: home.path) {
                            selectedFileURL = home
                            loadFile(home)
                        }
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.accentPrimary)
            }
            .padding(40)
            .frame(maxWidth: 560, alignment: .leading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.contentBg)
    }

    @ViewBuilder
    private func agentCommand(agent: String, command: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(agent)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.sidebarText)
            Text(command)
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(Color.sidebarTextMuted)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.sidebarBg)
                .clipShape(RoundedRectangle(cornerRadius: 4))
                .textSelection(.enabled)
        }
    }

    @ViewBuilder
    private func seedOption(icon: String, title: String, command: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 13))
                .foregroundStyle(Color.accentPrimary)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.sidebarSelectedText)
                Text(command)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(Color.sidebarTextMuted)
            }
        }
    }
}
