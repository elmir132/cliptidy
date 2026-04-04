// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "ClipTidy",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "ClipTidyCore", targets: ["ClipTidyCore"]),
        .executable(name: "ClipTidyApp", targets: ["ClipTidyApp"]),
        .executable(name: "cliptidy", targets: ["ClipTidyCLI"]),
    ],
    targets: [
        .target(name: "ClipTidyCore"),
        .executableTarget(name: "ClipTidyApp", dependencies: ["ClipTidyCore"]),
        .executableTarget(name: "ClipTidyCLI", dependencies: ["ClipTidyCore"]),
        .testTarget(name: "ClipTidyCoreTests", dependencies: ["ClipTidyCore"]),
    ]
)
