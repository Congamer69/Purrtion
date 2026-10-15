#!/bin/zsh
# Build Purrtion for Android and launch it on the running emulator / connected phone.
# Build output lives in $TMPDIR (see build.gradle.kts) because the project sits in an iCloud-synced folder.
set -e
cd "$(dirname "$0")"
export JAVA_HOME="${JAVA_HOME:-/opt/homebrew/opt/openjdk@21/libexec/openjdk.jdk/Contents/Home}"
export ANDROID_HOME="${ANDROID_HOME:-/opt/homebrew/share/android-commandlinetools}"
[ -f local.properties ] || echo "sdk.dir=$ANDROID_HOME" > local.properties
./gradlew -q :app:installDebug
"$ANDROID_HOME/platform-tools/adb" shell am start -n de.purrtion.app/.MainActivity "$@" >/dev/null
