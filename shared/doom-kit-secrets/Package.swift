// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "doom-kit-secrets",
    platforms: [.macOS(.v15), .iOS(.v26)],
    products: [.library(name: "DoomKitSecrets", targets: ["DoomKitSecrets"])],
    targets: [.target(name: "DoomKitSecrets"),
              .testTarget(name: "DoomKitSecretsTests", dependencies: ["DoomKitSecrets"])],
    swiftLanguageModes: [.v6]
)
