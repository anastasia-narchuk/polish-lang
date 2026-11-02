// swift-tools-version: 5.9
// Everything in the app that does not need SwiftUI or UIKit: models, prompts, parsers,
// the Claude API client, stores and screen models.
// The same sources are compiled into the iOS target; this package exists to run
// the unit tests with `swift test` on macOS or Linux without a simulator.
import PackageDescription

let package = Package(
    name: "PolishCore",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [
        .library(name: "PolishCore", targets: ["PolishCore"]),
    ],
    targets: [
        .target(name: "PolishCore", path: "PolishLang/Core"),
        .testTarget(name: "PolishCoreTests", dependencies: ["PolishCore"], path: "PolishCoreTests"),
    ]
)
