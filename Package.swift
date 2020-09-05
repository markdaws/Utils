// swift-tools-version:5.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Utils",
    platforms: [
        .iOS(SupportedPlatform.IOSVersion.v12)
    ],
    products: [
        // Products define the executables and libraries produced by a package, and make them visible to other packages.
        .library(
            name: "Utils",
            type: .dynamic,
            targets: ["Utils"]),
    ],
    dependencies: [
      .package(url: "https://github.com/markdaws/swifter.git", .revision("ca7a1ec09864be922352a2451a43434d5802de11"))
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages which this package depends on.
        .target(
            name: "Utils",
            dependencies: ["Swifter"]),
        .testTarget(
            name: "UtilsTests",
            dependencies: ["Utils", "Swifter"]),
    ]
)
