#!/bin/sh
# Provision only disposable GitHub-hosted runners; never alter local devices.
set -eu
[ "${GITHUB_ACTIONS:-}" = true ] || { echo 'This helper is for CI runners only.'; exit 1; }
case "$(uname -s)" in
  Darwin)
    device_id=$(xcrun simctl list devices available --json | python3 -c 'import json,sys; d=json.load(sys.stdin); print(next(x["udid"] for group in d["devices"].values() for x in group if x["name"].startswith("iPhone")))')
    xcrun simctl boot "$device_id" || true
    xcrun simctl bootstatus "$device_id" -b
    flutter test integration_test/app_test.dart -d "$device_id" --dart-define-from-file=config/development.json
    ;;
  Linux)
    sudo chmod a+rw /dev/kvm
    sdkmanager 'system-images;android-35;google_apis;x86_64' 'emulator'
    echo no | avdmanager create avd --name syskata-ci --package 'system-images;android-35;google_apis;x86_64'
    "$ANDROID_HOME/emulator/emulator" -avd syskata-ci -no-window -no-audio -no-boot-anim -no-snapshot -gpu swiftshader_indirect >/tmp/syskata-emulator.log 2>&1 &
    emulator_pid=$!
    trap 'kill "$emulator_pid" 2>/dev/null || true' EXIT
    adb wait-for-device
    count=0
    until [ "$(adb shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')" = 1 ]; do
      count=$((count + 1))
      [ "$count" -lt 90 ] || { echo 'Emulator boot timed out'; exit 1; }
      sleep 2
    done
    adb shell input keyevent 82
    flutter test integration_test/app_test.dart -d emulator-5554 --dart-define-from-file=config/development.json
    ;;
  *) exit 1 ;;
esac
