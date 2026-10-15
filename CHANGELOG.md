# Changelog

## v1.3.0

- iOS: a microphone that is held by another app no longer crashes the plugin: `startListening` refuses with `Audio input unavailable` before it taps the input, and an audio engine or session that fails to start is reported as an error
- Android: `startListening` takes `completeSilenceMs`, `possiblyCompleteSilenceMs` and `minimumLengthMs`, so the recognizer does not end a sentence early (values of 0 or less leave the platform default)
- Tests: JavaScript bridge, Robolectric on the JVM, XCTest on an iOS simulator, and cordova-paramedic on an iOS simulator and an Android emulator, each with a coverage floor

## v1.2.0

- Android: add `stopListening` [by Simone Compagnone]
- Android: enable partial results [by Simone Compagnone]

## v1.1.2

- iOS: `startListening` do not run in background
- iOS: `startListening` check existing process

## v1.1.1

- Android: use Cordova Permissions API
- Android: drop Android Support Library requirement

## v1.1.0

- Android: recognition is runnable in the background without popup window ( option `showPopup` )
- modify signature of function `startListening`
- Android: real callbacks for `requestPermission`

## v1.0.5

- iOS: use `AVAudioSessionCategoryPlayAndRecord` mode
- iOS: run `startListening` and `stopListening` in the background

## v1.0.4

- iOS: return partial results ( option `showPartial` )

## v1.0.3

- initial release of `cordova-plugin-speechrecognition`
