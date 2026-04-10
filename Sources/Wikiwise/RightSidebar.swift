import SwiftUI

enum RightSidebarTab: String, CaseIterable {
    case info = "INFO"
    case terminal = "TERMINAL"
}

struct RightSidebar: View {
    @Binding var activeTab: RightSidebarTab
    @Binding var isVisible: Bool
    @Binding var width: CGFloat
    @State private var dragStartWidth: CGFloat? = nil
    let selectedFileURL: URL?
    let rootURL: URL?
    let terminalSession: TerminalSession

    var body: some View {
        VStack(spacing: 0) {
            Rectangle().fill(Color.sidebarRule).frame(height: 1)
            tabBar
            Rectangle().fill(Color.sidebarRule).frame(height: 1)

            ZStack {
                infoTab
                    .opacity(activeTab == .info ? 1 : 0)
                    .allowsHitTesting(activeTab == .info)
                terminalTab
                    .opacity(activeTab == .terminal ? 1 : 0)
                    .allowsHitTesting(activeTab == .terminal)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.sidebarBg)
        // Drag handle overlaid on left edge so dividers span full width
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(Color.clear)
                .frame(width: 5)
                .contentShape(Rectangle())
                .onHover { hovering in
                    if hovering {
                        NSCursor.resizeLeftRight.push()
                    } else {
                        NSCursor.pop()
                    }
                }
                .gesture(
                    DragGesture(coordinateSpace: .global)
                        .onChanged { value in
                            if dragStartWidth == nil {
                                dragStartWidth = width
                            }
                            let newWidth = (dragStartWidth ?? width) - value.translation.width
                            width = max(newWidth, 200) // max clamped by parent to half window
                        }
                        .onEnded { _ in
                            dragStartWidth = nil
                        }
                )
        }
    }

    // MARK: - Tab Bar

    /// Pill-style tab switcher: container #E3D9C2, active tab #F6F1E7 with shadow.
    /// Sidebar toggle icon on far right (Paper node 17B-0).
    private var tabBar: some View {
        HStack {
            HStack(spacing: 0) {
                ForEach(RightSidebarTab.allCases, id: \.self) { tab in
                    Button {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            activeTab = tab
                        }
                    } label: {
                        Text(tab.rawValue)
                            .font(.system(size: 10, weight: .regular, design: .monospaced))
                            .tracking(0.8)
                            .foregroundStyle(
                                activeTab == tab
                                    ? Color(red: 0x1A/255, green: 0x17/255, blue: 0x14/255)  // #1A1714
                                    : Color(red: 0x7A/255, green: 0x6E/255, blue: 0x54/255)  // #7A6E54
                            )
                            .padding(.horizontal, 14)
                            .padding(.vertical, 3)
                            .background(
                                activeTab == tab
                                    ? RoundedRectangle(cornerRadius: 4)
                                        .fill(Color(red: 0xF6/255, green: 0xF1/255, blue: 0xE7/255)) // #F6F1E7
                                        .shadow(color: .black.opacity(0.1), radius: 0.5, y: 0.5)
                                    : nil
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(2)
            .background(
                RoundedRectangle(cornerRadius: 5)
                    .fill(Color(red: 0xE3/255, green: 0xD9/255, blue: 0xC2/255)) // #E3D9C2
            )

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    // MARK: - Info Tab

    private var infoTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // About this document
                if let file = selectedFileURL {
                    infoSection("ABOUT THIS DOCUMENT") {
                        VStack(alignment: .leading, spacing: 6) {
                            infoRow("PATH", value: file.lastPathComponent)
                            infoRow("EDITED", value: formattedModDate(file))
                            infoRow("WORDS", value: formattedWordCount(file))
                        }
                    }
                }

                // Directions — gold callout from frontmatter
                if let file = selectedFileURL, let directions = parseDirections(from: file) {
                    VStack(alignment: .leading, spacing: 10) {
                        sectionHeader("DIRECTIONS")
                        Text(directions)
                            .font(.custom("Fraunces", size: 12))
                            .italic()
                            .foregroundStyle(Color(red: 0x3A/255, green: 0x2F/255, blue: 0x1C/255)) // #3A2F1C
                            .lineSpacing(3)
                            .padding(.vertical, 10)
                            .padding(.horizontal, 12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(red: 0xC2/255, green: 0xA9/255, blue: 0x6B/255).opacity(0.12))
                            .overlay(alignment: .leading) {
                                Rectangle()
                                    .fill(Color(red: 0xC2/255, green: 0xA9/255, blue: 0x6B/255)) // #C2A96B
                                    .frame(width: 2)
                            }
                    }
                    .padding(.top, 18)
                    .overlay(alignment: .top) {
                        Rectangle().fill(Color.sidebarRule).frame(height: 1)
                    }
                }

                // Linked — wikilinks found in the file
                if let file = selectedFileURL, !wikilinkTargets(in: file).isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        sectionHeader("LINKED")
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(wikilinkTargets(in: file), id: \.self) { link in
                                Text("\u{2197} \(link)")
                                    .font(.custom("Fraunces", size: 13))
                                    .foregroundStyle(Color(red: 0x5B/255, green: 0x52/255, blue: 0x40/255)) // #5B5240
                            }
                        }
                    }
                    .padding(.top, 18)
                    .overlay(alignment: .top) {
                        Rectangle().fill(Color.sidebarRule).frame(height: 1)
                    }
                }

                Spacer()
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Section helpers

    @ViewBuilder
    private func infoSection(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader(title)
            content()
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.custom("JetBrains Mono", size: 9))
            .tracking(1.6)
            .textCase(.uppercase)
            .foregroundStyle(Color(red: 0xA8/255, green: 0x9A/255, blue: 0x7C/255)) // #A89A7C
    }

    private func infoRow(_ label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.custom("JetBrains Mono", size: 10))
                .foregroundStyle(Color(red: 0xA8/255, green: 0x9A/255, blue: 0x7C/255)) // #A89A7C
            Spacer()
            Text(value)
                .font(.custom("Fraunces", size: 12))
                .foregroundStyle(Color(red: 0x3A/255, green: 0x2F/255, blue: 0x1C/255)) // #3A2F1C
        }
    }

    // MARK: - Terminal Tab

    private var terminalTab: some View {
        TerminalEmbed(session: terminalSession)
            .padding(.leading, 8)
            .padding(.top, 4)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Helpers

    private func formattedModDate(_ url: URL) -> String {
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
              let date = attrs[.modificationDate] as? Date else { return "\u{2014}" }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    private func formattedWordCount(_ url: URL) -> String {
        guard let text = try? String(contentsOf: url, encoding: .utf8) else { return "\u{2014}" }
        let words = text.split { $0.isWhitespace || $0.isNewline }
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: words.count)) ?? "\(words.count)"
    }

    private func wikilinkTargets(in url: URL) -> [String] {
        guard let text = try? String(contentsOf: url, encoding: .utf8) else { return [] }
        var targets: [String] = []
        var scanner = text[...]
        while let open = scanner.range(of: "[[") {
            scanner = scanner[open.upperBound...]
            guard let close = scanner.range(of: "]]") else { break }
            let target = String(scanner[..<close.lowerBound])
            if !target.isEmpty && !targets.contains(target) {
                targets.append(target)
            }
            scanner = scanner[close.upperBound...]
        }
        return targets
    }

    private func parseDirections(from url: URL) -> String? {
        guard let text = try? String(contentsOf: url, encoding: .utf8) else { return nil }
        guard text.hasPrefix("---") else { return nil }
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false)
        guard lines.count > 1 else { return nil }
        var inFrontmatter = false
        for line in lines {
            if line == "---" {
                if inFrontmatter { return nil }
                inFrontmatter = true
                continue
            }
            if inFrontmatter && line.hasPrefix("directions:") {
                let value = line.dropFirst("directions:".count).trimmingCharacters(in: .whitespaces)
                return value.isEmpty ? nil : value
            }
        }
        return nil
    }
}
