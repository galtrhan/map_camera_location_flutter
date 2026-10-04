#!/usr/bin/env bash
# Start a named Android emulator in the background with a light config.
set -euo pipefail

ANDROID_SDK_ROOT="${ANDROID_SDK_ROOT:-/opt/android-sdk}"
EMULATOR="$ANDROID_SDK_ROOT/emulator/emulator"
AVD="${1:-Test}"

# Keep the emulator small enough that Cursor stays responsive.
EMULATOR_MEMORY_MB="${EMULATOR_MEMORY_MB:-2048}"
EMULATOR_CORES="${EMULATOR_CORES:-2}"

VALID_AVDS=(Test Tablet7 Tablet10)
is_valid=false
for candidate in "${VALID_AVDS[@]}"; do
  if [ "$candidate" = "$AVD" ]; then
    is_valid=true
    break
  fi
done

if [ "$is_valid" = false ]; then
  echo "Unknown AVD: $AVD"
  echo "   Valid options: ${VALID_AVDS[*]}"
  exit 1
fi

if [ ! -d "$HOME/.android/avd/${AVD}.avd" ]; then
  echo "AVD '$AVD' is not installed. Run: make emulator-setup"
  exit 1
fi

if pgrep -f "emulator.*-avd $AVD" >/dev/null 2>&1; then
  echo "Emulator '$AVD' is already running"
  exit 0
fi

echo "Starting Android emulator ($AVD)..."
echo "  memory=${EMULATOR_MEMORY_MB}MB cores=${EMULATOR_CORES}"
# Snapshots on, no audio, capped CPU/RAM. Avoids cold-boot storms that freeze the IDE.
nohup "$EMULATOR" -avd "$AVD" \
  -memory "$EMULATOR_MEMORY_MB" \
  -cores "$EMULATOR_CORES" \
  -no-audio \
  -no-metrics \
  -no-boot-anim \
  -gpu auto \
  >/tmp/map-camera-emulator-${AVD}.log 2>&1 &

sleep 2
echo "Emulator starting (log: /tmp/map-camera-emulator-${AVD}.log)"
echo "  Wait until boot finishes: make emulator-wait"
echo "  Then run the app: make run"
