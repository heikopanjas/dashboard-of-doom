// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "doom-kit-process",
    platforms: [.macOS(.v15), .iOS(.v26)],
    products: [.library(name: "DoomKitProcess", targets: ["DoomKitProcess"])],
    dependencies: [.package(path: "../doom-kit-location"), .package(path: "../doom-kit-network")],
    targets: [.target(name: "DoomKitProcess", dependencies: [
        .product(name: "DoomKitLocation", package: "doom-kit-location"),
        .product(name: "DoomKitNetwork", package: "doom-kit-network")
    ]),
              .testTarget(name: "DoomKitProcessTests", dependencies: ["DoomKitProcess"])],
    swiftLanguageModes: [.v6]
)
