// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Reeeead",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "Reeeead", targets: ["Reeeead"])],
    targets: [
        .executableTarget(name: "Reeeead"),
        .testTarget(name: "ReeeeadTests", dependencies: ["Reeeead"])
    ]
)
