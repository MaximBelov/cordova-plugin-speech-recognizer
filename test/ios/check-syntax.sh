#!/bin/sh
# Compiles the plugin's Objective-C against the iOS simulator SDK with the Cordova headers from
# cordova-ios. Catches typos and wrong API use; it cannot show runtime behaviour, which needs a device.
set -e
ROOT=$(cd "$(dirname "$0")/../.." && pwd)
CORDOVA_HEADERS=${CORDOVA_HEADERS:-$ROOT/node_modules/cordova-ios/CordovaLib/include/Cordova}
TMP=$(mktemp -d)
mkdir -p "$TMP/Cordova"
cp "$CORDOVA_HEADERS"/*.h "$TMP/Cordova/"
xcrun --sdk iphonesimulator clang -fsyntax-only -fobjc-arc -Wno-#warnings \
  -isysroot "$(xcrun --sdk iphonesimulator --show-sdk-path)" \
  -target arm64-apple-ios15.0-simulator \
  -I"$TMP" -I"$ROOT/src/ios" \
  "$ROOT/src/ios/SpeechRecognition.m"
rm -rf "$TMP"
echo "iOS syntax check: ok"
