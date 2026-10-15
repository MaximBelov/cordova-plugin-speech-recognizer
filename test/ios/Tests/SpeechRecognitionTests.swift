import AVFoundation
import Cordova
import XCTest
import SpeechRecognition

/// Records what the plugin sends back, and runs background work at once.
final class RecordingDelegate: NSObject, CDVCommandDelegate {
    var results: [(result: CDVPluginResult, callbackId: String)] = []

    var settings: CDVSettingsDictionary { [:] }

    func send(_ result: CDVPluginResult, callbackId: String) {
        results.append((result, callbackId))
    }

    func evalJs(_ js: String) {}
    func evalJs(_ js: String, scheduledOnRunLoop: Bool) {}
    func path(forResource resourcepath: String) -> String { resourcepath }
    func getCommandInstance(_ pluginName: String) -> CDVPlugin? { nil }
    func run(inBackground block: @escaping () -> Void) { block() }
}

final class SpeechRecognitionTests: XCTestCase {
    private var plugin: SpeechRecognition!
    private var delegate: RecordingDelegate!

    override func setUp() {
        super.setUp()
        plugin = SpeechRecognition()
        delegate = RecordingDelegate()
        plugin.commandDelegate = delegate
    }

    func testAnInputWithoutAFormatIsNotUsable() {
        XCTAssertFalse(SRInputFormatIsUsable(nil))
    }

    func testAnInputWithAFormatIsUsable() throws {
        let format = try XCTUnwrap(AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1))
        XCTAssertTrue(SRInputFormatIsUsable(format))
    }

    func testStartListeningWithoutPermissionReportsItAndStartsNothing() {
        // The test host has never been asked for speech recognition, so the plugin refuses before any audio is touched.
        plugin.startListening(command(method: "startListening", arguments: ["en-GB", 3, "", true, false]))

        XCTAssertEqual(delegate.results.count, 1)
        XCTAssertEqual(delegate.results[0].callbackId, "callback-1")
        XCTAssertEqual(delegate.results[0].result.status.uintValue, CDVCommandStatus_ERROR.rawValue)
        XCTAssertEqual(delegate.results[0].result.message as? String, "Missing permission")
    }

    func testRecognitionIsAvailableOnAnyIOSThatHasTheFramework() {
        plugin.isRecognitionAvailable(command(method: "isRecognitionAvailable", arguments: []))

        XCTAssertEqual(delegate.results.count, 1)
        XCTAssertEqual(delegate.results[0].result.status.uintValue, CDVCommandStatus_OK.rawValue)
        XCTAssertEqual(delegate.results[0].result.message as? NSNumber, true)
    }

    func testHasPermissionAnswersFalseWithoutSpeechAuthorizationAndAsksNothing() {
        // Without speech authorization the answer is immediate; the microphone prompt is only reached after it.
        plugin.hasPermission(command(method: "hasPermission", arguments: []))

        XCTAssertEqual(delegate.results.count, 1)
        XCTAssertEqual(delegate.results[0].result.status.uintValue, CDVCommandStatus_OK.rawValue)
        XCTAssertEqual(delegate.results[0].result.message as? NSNumber, false)
    }

    func testStopListeningAnswersOkWhenNothingIsRunning() {
        plugin.stopListening(command(method: "stopListening", arguments: []))

        XCTAssertEqual(delegate.results.count, 1)
        XCTAssertEqual(delegate.results[0].result.status.uintValue, CDVCommandStatus_OK.rawValue)
    }

    func testTheSupportedLanguagesAreSent() {
        plugin.getSupportedLanguages(command(method: "getSupportedLanguages", arguments: []))

        XCTAssertEqual(delegate.results.count, 1)
        XCTAssertEqual(delegate.results[0].result.status.uintValue, CDVCommandStatus_OK.rawValue)
        XCTAssertTrue(delegate.results[0].result.message is NSArray)
    }

    private func command(method: String, arguments: [Any]) -> CDVInvokedUrlCommand {
        CDVInvokedUrlCommand(arguments: arguments, callbackId: "callback-1", className: "SpeechRecognition", methodName: method)
    }
}
