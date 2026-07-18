// swift-tools-version: 6.3

import PackageDescription

/// Pins XcodeGen for `make generate-project` /
/// `swift run --package-path tools/projectgen xcodegen …`
let package = Package(
  name: "projectgen",
  platforms: [
    .macOS(.v13)
  ],
  dependencies: [
    .package(
      url: "https://github.com/yonaskolb/XcodeGen.git",
      revision: "8445e778451c7e44237b90281bde622d764b0084"
    )
  ],
  targets: [
    .target(
      name: "ProjectGenPin",
      dependencies: [
        .product(name: "XcodeGenKit", package: "XcodeGen")
      ],
      path: "Sources/ProjectGenPin"
    )
  ],
  swiftLanguageModes: [.v6]
)
