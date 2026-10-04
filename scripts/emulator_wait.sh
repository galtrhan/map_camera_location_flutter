#!/usr/bin/env bash
# Wait until an Android emulator is booted and idle enough to install apps.
set -euo pipefail

ANDROID_SDK_ROOT="${ANDROID_SDK_ROOT:-/opt/android-sdk}"
export PATH="$ANDROID_SDK_ROOT/platform-tools:$PATH"
TIMEOUT_SEC="${1:-180}"

if ! command -v adb >/dev/null 2>&1; then
  echo "adb not found. Set ANDROID_SDK_ROOT (current: $ANDROID_SDK_ROOT)"
  exit 1
fi

echo "Waiting for emulator device (timeout ${TIMEOUT_SEC}s)..."
deadline=$((SECONDS + TIMEOUT_SEC))

# Block until adb sees a device, then poll boot_completed only.
timeout "$TIMEOUT_SEC" adb wait-for-device >/dev/null 2>&1 || true

while [ "$SECONDS" -lt "$deadline" ]; do
  serial="$(adb devices | awk '/^emulator-/{print $1; exit}')"
  if [ -n "$serial" ]; then
    boot="$(adb -s "$serial" shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')"
    if [ "$boot" = "1" ]; then
      echo "Emulator ready: $serial"
      exit 0
    fi
  fi
  sleep 2
done

echo "Timed out waiting for emulator boot"
adb devices || true
exit 1
