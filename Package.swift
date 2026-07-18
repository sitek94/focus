// swift-tools-version: 6.3

import PackageDescription

let package = Package(
  name: "Focus",
  platforms: [
    .iOS(.v26),
    .macOS(.v26),
  ],
  products: [
    .library(name: "FocusSession", targets: ["FocusSession"]),
    .library(name: "FocusPersistence", targets: ["FocusPersistence"]),
    .library(name: "FocusControl", targets: ["FocusControl"]),
    .executable(name: "focus", targets: ["FocusCLI"]),
  ],
  targets: [
    .systemLibrary(
      name: "CSQLite",
      path: "Sources/CSQLite",
      pkgConfig: "sqlite3",
      providers: [
        .apt(["libsqlite3-dev"]),
        .brew(["sqlite"]),
      ]
    ),
    .target(
      name: "FocusSession",
      path: "Sources/FocusSession"
    ),
    .target(
      name: "FocusPersistence",
      dependencies: [
        "FocusSession",
        "CSQLite",
      ],
      path: "Sources/FocusPersistence"
    ),
    .target(
      name: "FocusControl",
      dependencies: ["FocusSession"],
      path: "Sources/FocusControl"
    ),
    .executableTarget(
      name: "FocusCLI",
      dependencies: [
        "FocusControl",
        "FocusSession",
      ],
      path: "CLI/FocusCLI"
    ),
    .testTarget(
      name: "FocusSessionTests",
      dependencies: ["FocusSession"],
      path: "Tests/FocusSessionTests"
    ),
    .testTarget(
      name: "FocusPersistenceIntegrationTests",
      dependencies: ["FocusPersistence", "FocusSession"],
      path: "Tests/FocusPersistenceIntegrationTests"
    ),
    .testTarget(
      name: "FocusControlTests",
      dependencies: ["FocusControl", "FocusSession"],
      path: "Tests/FocusControlTests"
    ),
    .testTarget(
      name: "FocusCLIIntegrationTests",
      dependencies: ["FocusControl", "FocusSession"],
      path: "Tests/FocusCLIIntegrationTests"
    ),
    .testTarget(
      name: "FocusPlatformGatingTests",
      dependencies: ["FocusSession", "FocusControl", "FocusPersistence"],
      path: "Tests/FocusPlatformGatingTests"
    ),
  ],
  swiftLanguageModes: [.v6]
)
