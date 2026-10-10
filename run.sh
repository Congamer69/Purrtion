#!/bin/zsh
# Build Purrtion and launch it in the booted simulator.
# DerivedData lives outside ~/Documents because iCloud-synced folders break code signing.
set -e
DD="${TMPDIR:-/tmp}/PurrtionDerivedData"
DEVICE="${1:-iPhone 18 Pro Max}"
xcodebuild -project Purrtion.xcodeproj -scheme Purrtion -destination "platform=iOS Simulator,name=$DEVICE" \
  -derivedDataPath "$DD" build | grep -E "error:|BUILD"
xcrun simctl install booted "$DD/Build/Products/Debug-iphonesimulator/Purrtion.app"
xcrun simctl launch booted com.const.purrtion
