#!/usr/bin/env bash
# Installs an APK on the running emulator, launches the game and checks that it stays up with the
# Rust hint engine loaded and no script errors. Usage: tools/emulator_smoke.sh <apk>
set -euo pipefail
apk=$1
package=com.mahiron.merge2048
adb wait-for-device
adb install -r "$apk"
adb logcat -c
adb shell am start -n "$package/com.godot.game.GodotAppLauncher"
sleep 25
adb logcat -d > logcat.txt
grep " godot " logcat.txt || true
if ! adb shell pidof "$package" > /dev/null; then
  echo "::error::the game is not running 25 seconds after launch"
  exit 1
fi
if ! grep -q "hints on the native engine" logcat.txt; then
  echo "::error::the Rust hint engine did not load"
  exit 1
fi
if grep -E " godot .*(SCRIPT ERROR|USER ERROR|GDExtension)" logcat.txt; then
  echo "::error::the game logged errors on start"
  exit 1
fi
echo "the game started on the emulator with the hint engine loaded"
