// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "doom-kit-services",
    platforms: [.macOS(.v15), .iOS(.v26)],
    products: [.library(name: "DoomKitServices", targets: ["DoomKitServices"])],
    dependencies: [.package(path: "../doom-kit-location"), .package(path: "../doom-kit-network"), .package(path: "../doom-kit-tools")],
    targets: [
        .target(name: "DoomKitServices", dependencies: [
        .product(name: "DoomKitLocation", package: "doom-kit-location"),
        .product(name: "DoomKitNetwork", package: "doom-kit-network"),
        .product(name: "DoomKitTools", package: "doom-kit-tools")
        ]),
        .testTarget(name: "DoomKitServicesTests", dependencies: ["DoomKitServices"])
    ],
    swiftLanguageModes: [.v6]
)
