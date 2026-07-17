// swift-tools-version: 6.3
import PackageDescription

let package = Package(
    name: "projectgen-bootstrap-test",
    platforms: [.macOS(.v26)],
    dependencies: [
        .package(url: "https://github.com/yonaskolb/XcodeGen.git", exact: "2.46.0"),
    ],
    targets: [
        .executableTarget(
            name: "dummy",
            dependencies: [
                .product(name: "XcodeGenKit", package: "XcodeGen"),
            ]
        )
    ]
)
