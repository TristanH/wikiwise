import Foundation

// Custom resource bundle accessor that works both in SwiftPM development
// and when packaged as a macOS .app bundle.
//
// SwiftPM's auto-generated Bundle.module checks Bundle.main.bundleURL
// which is the .app root — but code signing requires resources to be
// inside Contents/Resources/. This accessor checks both locations.
private class BundleLocator {}

let wikiwiseBundle: Bundle = {
    let bundleName = "Wikiwise_Wikiwise"

    let candidates: [URL] = [
        // Standard .app layout: Contents/Resources/
        Bundle.main.resourceURL,
        // SwiftPM development: adjacent to executable
        Bundle.main.bundleURL,
        // Fallback: same directory as this code's bundle
        Bundle(for: BundleLocator.self).resourceURL,
        Bundle(for: BundleLocator.self).bundleURL,
    ].compactMap { $0?.appendingPathComponent(bundleName + ".bundle") }

    for candidate in candidates {
        if let bundle = Bundle(path: candidate.path) {
            return bundle
        }
    }

    fatalError("Could not find resource bundle '\(bundleName)' in: \(candidates.map(\.path))")
}()
