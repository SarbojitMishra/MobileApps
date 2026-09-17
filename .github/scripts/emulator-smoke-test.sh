#!/usr/bin/env bash
# Installs app-release.apk on the emulator booted by
# reactivecircus/android-emulator-runner, launches it, and fails if the
# process dies or logcat shows a fatal exception shortly after launch.
#
# This lives in its own file (rather than inline in the workflow's `script:`
# block) because that action runs each line of a multi-line `script:` value
# as its own separate shell invocation — any multi-line construct like
# `if ... fi` breaks across those invocations. A single `bash thisfile.sh`
# call is one shell invocation, so normal control flow works.
set -e

adb wait-for-device
adb shell wm dismiss-keyguard || true

adb install -r "$GITHUB_WORKSPACE/apks/app-release.apk"

# Pre-grant the runtime permissions the app would otherwise prompt for, so
# a permission dialog doesn't get mistaken for a hang, then launch it.
adb shell pm grant com.sarbojit.shankhalarm android.permission.ACCESS_FINE_LOCATION || true
adb shell pm grant com.sarbojit.shankhalarm android.permission.ACCESS_COARSE_LOCATION || true
adb shell pm grant com.sarbojit.shankhalarm android.permission.POST_NOTIFICATIONS || true

adb shell am start -n com.sarbojit.shankhalarm/.MainActivity
sleep 15

adb logcat -d > "$GITHUB_WORKSPACE/logcat.txt"

if ! adb shell pidof com.sarbojit.shankhalarm > /dev/null; then
  echo "::error::App process is not running 15s after launch — it likely crashed on startup."
  tail -n 200 "$GITHUB_WORKSPACE/logcat.txt"
  exit 1
fi

if grep -q "FATAL EXCEPTION" "$GITHUB_WORKSPACE/logcat.txt"; then
  echo "::error::FATAL EXCEPTION found in logcat during launch."
  grep -A 30 "FATAL EXCEPTION" "$GITHUB_WORKSPACE/logcat.txt"
  exit 1
fi

echo "app-release.apk installed and launched without crashing."
