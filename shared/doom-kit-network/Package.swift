// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "doom-kit-network",
    platforms: [.macOS(.v15), .iOS(.v26)],
    products: [.library(name: "DoomKitNetwork", targets: ["DoomKitNetwork"])],
    targets: [.target(name: "DoomKitNetwork"),
              .testTarget(name: "DoomKitNetworkTests", dependencies: ["DoomKitNetwork"])],
    swiftLanguageModes: [.v6]
)
