// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "TometoClock",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "TometoClock", targets: ["TometoClock"])],
    targets: [
        .target(name: "TimerCore"),
        .executableTarget(name: "TometoClock", dependencies: ["TimerCore"]),
        .testTarget(name: "TimerCoreTests", dependencies: ["TimerCore"])
    ]
)
