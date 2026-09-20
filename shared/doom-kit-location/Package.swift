// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "doom-kit-location",
    platforms: [.macOS(.v15), .iOS(.v26)],
    products: [.library(name: "DoomKitLocation", targets: ["DoomKitLocation"])],
    targets: [.target(name: "DoomKitLocation"),
              .testTarget(name: "DoomKitLocationTests", dependencies: ["DoomKitLocation"])],
    swiftLanguageModes: [.v6]
)
