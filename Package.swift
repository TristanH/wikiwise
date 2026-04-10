// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "Wikiwise",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(url: "https://github.com/migueldeicaza/SwiftTerm.git", from: "1.2.0"),
    ],
    targets: [
        .executableTarget(
            name: "Wikiwise",
            dependencies: [
                .product(name: "SwiftTerm", package: "SwiftTerm"),
            ],
            resources: [
                .copy("Resources/markdown-it.min.js"),
                .copy("Resources/style.css"),
                .copy("Resources/build.js"),
                .copy("Resources/app.js"),
                .copy("Resources/graph.js"),
                .copy("Resources/map.html"),
                .copy("Resources/map-3d.html"),
                .copy("Resources/codemirror-bundle.js"),
                .copy("Resources/editor.html"),
                .copy("Resources/scaffold"),
                .copy("Resources/Wikiwise.icns"),
            ]
        ),
    ]
)
