// swift-tools-version: 5.9
import PackageDescription

let package = Package(name: "MiaotouDesktop", platforms: [.macOS(.v14)], products: [
    .executable(name: "MiaotouMac", targets: ["MiaotouMac"])
], targets: [
    .target(name: "MiaotouCore"),
    .executableTarget(name: "MiaotouMac", dependencies: ["MiaotouCore"], resources: [.process("Resources")]),
    .testTarget(name: "MiaotouCoreTests", dependencies: ["MiaotouCore"])
])
