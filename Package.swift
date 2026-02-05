// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "MyShoppingHelp",
    platforms: [.iOS(.v17)],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(name: "MyShoppingHelp", targets: ["MyShoppingHelp"]),
    ],
    dependencies: [
        .package(url: "https://www.github.com/openid/AppAuth-iOS.git", .upToNextMajor(from: "1.7.5")),
        .package(url: "https://www.github.com/auth0/JWTDecode.swift.git", .upToNextMajor(from: "3.2.0")),
        .package(url: "https://www.github.com/evgenyneu/keychain-swift.git", .upToNextMajor(from: "24.0.0"))
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(name: "MyShoppingHelp", dependencies: [
            .product(name: "AppAuth", package: "AppAuth-iOS"),
            .product(name: "JWTDecode", package: "JWTDecode.swift"),
            .product(name: "KeychainSwift", package: "keychain-swift")
        ])

    ]
)
