// swift-tools-version:5.9
// The plugin's Objective-C built against cordova-ios and tested with XCTest on an iOS simulator:
//   cd test/ios && xcodebuild test -scheme SpeechRecognitionTests -destination "platform=iOS Simulator,name=$(node simulator.mjs)"
// (`npm run test:ios`). Sources/SpeechRecognition is a link to src/ios, so the tests build what the plugin ships.
import PackageDescription

let package = Package(
    name: "SpeechRecognitionTests",
    platforms: [.iOS(.v15)],
    dependencies: [
        .package(path: "../../.cordova-headers/node_modules/cordova-ios")
    ],
    targets: [
        .target(
            name: "SpeechRecognition",
            dependencies: [.product(name: "Cordova", package: "cordova-ios")],
            path: "Sources/SpeechRecognition",
            publicHeadersPath: "."
        ),
        .testTarget(
            name: "SpeechRecognitionTests",
            dependencies: ["SpeechRecognition"],
            path: "Tests"
        ),
    ]
)
