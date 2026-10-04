#!/usr/bin/env bash
# Create Android Virtual Devices for phone and tablet testing.
set -euo pipefail

ANDROID_SDK_ROOT="${ANDROID_SDK_ROOT:-/opt/android-sdk}"
SYSTEM_IMAGE="system-images;android-33;google_apis_playstore;x86_64"
AVDMANAGER="$ANDROID_SDK_ROOT/cmdline-tools/latest/bin/avdmanager"
EMULATOR="$ANDROID_SDK_ROOT/emulator/emulator"

if [ ! -x "$AVDMANAGER" ]; then
  echo "avdmanager not found at $AVDMANAGER"
  echo "   Set ANDROID_SDK_ROOT to your Android SDK path."
  exit 1
fi

create_avd() {
  local name="$1"
  local device="$2"
  local label="$3"

  if [ -d "$HOME/.android/avd/${name}.avd" ]; then
    echo "$name already exists ($label)"
    return 0
  fi

  echo "Creating $name ($label)..."
  echo no | "$AVDMANAGER" create avd -n "$name" -d "$device" -k "$SYSTEM_IMAGE" --force
  echo "Created $name"
}

create_avd Test pixel_6 "Pixel 6 phone"
create_avd Tablet7 "Nexus 7" '7" tablet'
create_avd Tablet10 pixel_tablet '10" tablet'

echo ""
echo "Available AVDs:"
"$EMULATOR" -list-avds
echo ""
echo "Start one with: make emulator-start AVD=Tablet7"
