// swift-tools-version:4.0
import PackageDescription

let pkg = Package(name: "XCAssetPacker")
pkg.products = [
    .library(name: "XCAssetPacker", targets: ["XCAssetPacker"]),
]
pkg.dependencies = [
]

let pmk: Target = .target(name: "XCAssetPacker", dependencies: [])
pmk.path = "Sources"

pkg.targets = [
    pmk
]
