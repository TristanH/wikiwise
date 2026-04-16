import Foundation

struct PublishResult {
    let url: URL
    let isFirstPublish: Bool
    let fileCount: Int
}

struct PublishConfig: Codable {
    var subdomain: String
    var token: String
    var lastPublishedAt: String?
    var url: String
}

enum PublishError: LocalizedError {
    case tokenMismatch
    case subdomainTaken
    case tooLarge(String)
    case rateLimited
    case corruptConfig
    case networkError(String)
    case serverError(Int, String)

    var errorDescription: String? {
        switch self {
        case .tokenMismatch:
            return "Token doesn't match. Check your publish.json."
        case .subdomainTaken:
            return "That subdomain is already taken. Edit the subdomain in publish.json and try again."
        case .tooLarge(let msg):
            return msg
        case .rateLimited:
            return "Too many publishes. Try again in a few minutes."
        case .corruptConfig:
            return "publish.json exists but is malformed. Delete it to start fresh, or fix its contents."
        case .networkError(let msg):
            return msg
        case .serverError(let code, let msg):
            return "Server error (\(code)): \(msg)"
        }
    }
}

enum SubdomainAvailability {
    case available
    case taken
    case owned    // taken but by this user's token
    case invalid
    case checking
    case unknown  // not yet checked
}

final class Publisher {
    static let endpoint = URL(string: "https://publish.wiki-wise.com/_publish")!
    static let checkEndpoint = URL(string: "https://publish.wiki-wise.com/_check")!

    /// Load an existing publish config, or nil if the file doesn't exist.
    /// Throws if the file exists but is malformed.
    static func loadConfig(projectRoot: URL) throws -> PublishConfig? {
        let configURL = projectRoot.appendingPathComponent("publish.json")
        guard let data = FileManager.default.contents(atPath: configURL.path) else {
            return nil
        }
        guard let config = try? JSONDecoder().decode(PublishConfig.self, from: data) else {
            throw PublishError.corruptConfig
        }
        return config
    }

    /// Check whether a subdomain is available, taken, or owned by the given token.
    static func checkAvailability(subdomain: String, token: String? = nil) async -> SubdomainAvailability {
        var components = URLComponents(url: checkEndpoint, resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "subdomain", value: subdomain)]
        guard let url = components.url else { return .invalid }

        var request = URLRequest(url: url)
        if let token = token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let http = response as? HTTPURLResponse, http.statusCode == 200,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let reason = json["reason"] as? String else {
            return .unknown
        }

        switch reason {
        case "free": return .available
        case "owned": return .owned
        case "taken": return .taken
        case "invalid": return .invalid
        default: return .unknown
        }
    }

    /// Publish the wiki, optionally overriding the subdomain.
    static func publish(siteFolder: URL, projectRoot: URL, subdomain: String? = nil) async throws -> PublishResult {
        let configURL = projectRoot.appendingPathComponent("publish.json")

        var config: PublishConfig
        var isFirstPublish = false

        if let existing = try loadConfig(projectRoot: projectRoot) {
            config = existing
            // Override subdomain if the user chose a custom one
            if let sub = subdomain, sub != config.subdomain {
                config.subdomain = sub
                config.url = "https://\(sub).wiki-wise.com"
            }
        } else {
            let sub = subdomain ?? randomSubdomain(wikiName: projectRoot.lastPathComponent)
            config = PublishConfig(
                subdomain: sub,
                token: "ww_" + randomHex(32),
                url: "https://\(sub).wiki-wise.com"
            )
            isFirstPublish = true
        }

        var files = try enumerateFiles(in: siteFolder)
        // For web hosting, copy home.html → index.html so the root URL serves home.
        // Rename the original index.html (catalog) → catalog.html to avoid collision,
        // and rewrite all internal links so href="index.html" → href="catalog.html".
        if let home = files.first(where: { $0.relativePath == "home.html" }) {
            files = files.map { entry in
                if entry.relativePath == "index.html" {
                    return FileEntry(relativePath: "catalog.html", data: entry.data)
                }
                // Rewrite links in HTML files: index.html → catalog.html
                if entry.relativePath.hasSuffix(".html"),
                   let html = String(data: entry.data, encoding: .utf8) {
                    let rewritten = html
                        .replacingOccurrences(of: "href=\"index.html\"", with: "href=\"catalog.html\"")
                        .replacingOccurrences(of: "href=\"index.html#", with: "href=\"catalog.html#")
                    if rewritten != html, let data = rewritten.data(using: .utf8) {
                        return FileEntry(relativePath: entry.relativePath, data: data)
                    }
                }
                return entry
            }
            // Also rewrite links in the home.html copy that becomes index.html
            var homeData = home.data
            if let html = String(data: home.data, encoding: .utf8) {
                let rewritten = html
                    .replacingOccurrences(of: "href=\"index.html\"", with: "href=\"catalog.html\"")
                    .replacingOccurrences(of: "href=\"index.html#", with: "href=\"catalog.html#")
                if let data = rewritten.data(using: .utf8) {
                    homeData = data
                }
            }
            files.append(FileEntry(relativePath: "index.html", data: homeData))
        }
        let result = try await upload(config: &config, files: files, isFirstPublish: isFirstPublish)

        config.lastPublishedAt = ISO8601DateFormatter().string(from: Date())
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(config).write(to: configURL)

        return result
    }

    // MARK: - Private

    private struct FileEntry {
        let relativePath: String
        let data: Data
    }

    private static func enumerateFiles(in folder: URL) throws -> [FileEntry] {
        let fm = FileManager.default
        guard let enumerator = fm.enumerator(
            at: folder,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            throw PublishError.networkError("Cannot read site folder")
        }

        var entries: [FileEntry] = []
        for case let fileURL as URL in enumerator {
            let values = try fileURL.resourceValues(forKeys: [.isRegularFileKey])
            guard values.isRegularFile == true else { continue }

            let relativePath = fileURL.path.replacingOccurrences(of: folder.path + "/", with: "")
            entries.append(FileEntry(relativePath: relativePath, data: try Data(contentsOf: fileURL)))
        }
        return entries
    }

    private static func upload(config: inout PublishConfig, files: [FileEntry], isFirstPublish: Bool, attempt: Int = 0) async throws -> PublishResult {
        let payload: [String: Any] = [
            "files": files.map { [
                "path": $0.relativePath,
                "data": $0.data.base64EncodedString()
            ] }
        ]
        let jsonData = try JSONSerialization.data(withJSONObject: payload)

        var request = URLRequest(url: endpoint)
        request.httpMethod = "PUT"
        request.setValue("Bearer \(config.token)", forHTTPHeaderField: "Authorization")
        request.setValue(config.subdomain, forHTTPHeaderField: "X-Subdomain")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = jsonData

        let (responseData, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw PublishError.networkError("Invalid response")
        }

        switch http.statusCode {
        case 200:
            return PublishResult(url: URL(string: config.url)!, isFirstPublish: isFirstPublish, fileCount: files.count)
        case 403:
            throw PublishError.tokenMismatch
        case 409:
            guard isFirstPublish, attempt < 3 else { throw PublishError.subdomainTaken }
            config.subdomain = randomSubdomain()
            config.url = "https://\(config.subdomain).wiki-wise.com"
            return try await upload(config: &config, files: files, isFirstPublish: true, attempt: attempt + 1)
        case 413:
            throw PublishError.tooLarge(String(data: responseData, encoding: .utf8) ?? "Upload too large")
        case 429:
            throw PublishError.rateLimited
        default:
            let msg = String(data: responseData, encoding: .utf8) ?? "Unknown error"
            throw PublishError.serverError(http.statusCode, msg)
        }
    }

    static func randomSubdomain(wikiName: String? = nil) -> String {
        let chars = "abcdefghijklmnopqrstuvwxyz0123456789"
        let suffix = String((0..<6).map { _ in chars.randomElement()! })
        if let name = wikiName, !name.isEmpty {
            let slug = name.lowercased()
                .replacingOccurrences(of: " ", with: "-")
                .filter { $0.isLetter || $0.isNumber || $0 == "-" }
                .prefix(20)
            return "\(slug)-\(suffix)"
        }
        return suffix
    }

    private static func randomHex(_ length: Int) -> String {
        let chars = "0123456789abcdef"
        return String((0..<length).map { _ in chars.randomElement()! })
    }
}
