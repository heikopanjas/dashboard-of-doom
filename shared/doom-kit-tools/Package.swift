// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "doom-kit-tools",
    platforms: [.macOS(.v15), .iOS(.v26)],
    products: [.library(name: "DoomKitTools", targets: ["DoomKitTools"])],
    dependencies: [.package(path: "../doom-kit-location")],
    targets: [
        .target(name: "DoomKitTools", dependencies: [
        .product(name: "DoomKitLocation", package: "doom-kit-location")
        ]),
        .testTarget(name: "DoomKitToolsTests", dependencies: ["DoomKitTools"])
    ],
    swiftLanguageModes: [.v6]
)
