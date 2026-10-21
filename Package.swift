// swift-tools-version: 6.0
import PackageDescription
let package = Package(name: "PipeCut", platforms: [.macOS(.v14)], products: [.executable(name: "PipeCut", targets: ["PipeCut"])], targets: [.target(name: "PipeCutCore"), .executableTarget(name: "PipeCut", dependencies: ["PipeCutCore"]), .testTarget(name: "PipeCutCoreTests", dependencies: ["PipeCutCore"])])
