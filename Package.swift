// swift-tools-version: 6.0
import PackageDescription

let package = Package(
  name: "swift-dictionary-coder",
  platforms: [.macOS(.v15), .iOS(.v17)],
  products: [.library(name: "DictionaryCoder", targets: ["DictionaryCoder"])],
  targets: [
    .target(name: "DictionaryCoder"),
    .executableTarget(name: "Benchmarking", dependencies: ["DictionaryCoder"]),
    .testTarget(
      name: "DictionaryCoderTests",
      dependencies: ["DictionaryCoder"]
    ),
  ],
  swiftLanguageVersions: [.v6]
)
