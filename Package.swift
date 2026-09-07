// swift-tools-version: 5.9
import PackageDescription

// Runs the non-UI feature tests on macOS without requiring an iOS simulator.
// The iOS app still compiles these same source files through its Xcode project.
let package = Package(
    name: "QarjyFlowChecks",
    platforms: [.macOS(.v14)],
    targets: [
        .target(
            name: "CategoriesCore", path: "QarjyFlow",
            exclude: [
                "App", "Assets.xcassets", "ContentView.swift", "QarjyFlowApp.swift",
                "Features/Home/Views", "Features/Home/PreviewData", "Features/Settings", "Features/Categories/Views", "Features/Categories/PreviewData",
                "Features/Goals/Views",
                "Shared/UI", "Shared/Formatting",
                "Features/Plan/Views",
                "Features/Transactions/Views", "Features/Transactions/PreviewData"
            ]
        ),
        .testTarget(name: "CategoriesCoreTests", dependencies: ["CategoriesCore"])
    ]
)
