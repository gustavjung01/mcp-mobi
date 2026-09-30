#!/usr/bin/env bash
set -euo pipefail

if [[ "$#" -lt 1 ]]; then
  echo "Usage: $0 <command> [args...]" >&2
  exit 64
fi

SDK_ROOT="${ANDROID_SDK_ROOT:-${ANDROID_HOME:-}}"
if [[ -z "$SDK_ROOT" ]]; then
  echo "ANDROID_SDK_ROOT/ANDROID_HOME is not configured." >&2
  exit 1
fi

export PATH="$SDK_ROOT/platform-tools:$SDK_ROOT/emulator:$SDK_ROOT/cmdline-tools/latest/bin:$PATH"
command -v sdkmanager >/dev/null
command -v avdmanager >/dev/null
command -v adb >/dev/null
command -v timeout >/dev/null

API_LEVEL="${ANDROID_CI_API_LEVEL:-35}"
ARCH="${ANDROID_CI_ARCH:-x86_64}"
TARGET="${ANDROID_CI_TARGET:-default}"
PROFILE="${ANDROID_CI_PROFILE:-pixel_6}"
PORT="${ANDROID_CI_PORT:-5554}"
AVD_NAME="${ANDROID_CI_AVD_NAME:-mcp-ci}"
AVD_HOME="${ANDROID_CI_AVD_HOME:-${RUNNER_TEMP:-$HOME/.android}/android-avd}"
DEVICE="emulator-$PORT"
SYSTEM_IMAGE="system-images;android-${API_LEVEL};${TARGET};${ARCH}"
LOG_FILE="${RUNNER_TEMP:-/tmp}/mcp-android-emulator-${PORT}.log"
export ANDROID_AVD_HOME="$AVD_HOME"
mkdir -p "$ANDROID_AVD_HOME"

yes | sdkmanager --licenses >/dev/null 2>&1 || true
timeout 10m sdkmanager "platform-tools" "emulator" "platforms;android-${API_LEVEL}" "$SYSTEM_IMAGE"

if [[ -e /dev/kvm ]]; then
  sudo chmod 666 /dev/kvm || true
fi

echo "no" | avdmanager create avd \
  --force \
  --name "$AVD_NAME" \
  --package "$SYSTEM_IMAGE" \
  --device "$PROFILE" \
  --path "$ANDROID_AVD_HOME/$AVD_NAME.avd"
test -f "$ANDROID_AVD_HOME/$AVD_NAME.ini"
"$SDK_ROOT/emulator/emulator" -list-avds | grep -Fxq "$AVD_NAME"

"$SDK_ROOT/emulator/emulator" \
  -avd "$AVD_NAME" \
  -port "$PORT" \
  -no-window \
  -gpu swiftshader_indirect \
  -no-snapshot \
  -noaudio \
  -no-boot-anim \
  >"$LOG_FILE" 2>&1 &
EMULATOR_PID=$!

cleanup() {
  local status=$?
  trap - EXIT INT TERM
  if [[ "$status" -ne 0 && -f "$LOG_FILE" ]]; then
    echo "---- Android emulator log tail ----" >&2
    tail -n 200 "$LOG_FILE" >&2 || true
  fi
  timeout 10s adb -s "$DEVICE" emu kill >/dev/null 2>&1 || true
  if kill -0 "$EMULATOR_PID" >/dev/null 2>&1; then
    kill "$EMULATOR_PID" >/dev/null 2>&1 || true
  fi
  wait "$EMULATOR_PID" >/dev/null 2>&1 || true
  exit "$status"
}
trap cleanup EXIT INT TERM

adb start-server

device_seen=0
for _ in $(seq 1 150); do
  if ! kill -0 "$EMULATOR_PID" >/dev/null 2>&1; then
    echo "Android emulator process exited before ADB detected the device." >&2
    exit 1
  fi
  if adb devices | awk 'NR > 1 {print $1}' | grep -Fxq "$DEVICE"; then
    device_seen=1
    break
  fi
  sleep 2
done

if [[ "$device_seen" -ne 1 ]]; then
  echo "Android emulator was not visible to ADB within 5 minutes." >&2
  adb devices -l >&2 || true
  exit 1
fi

ready=0
for _ in $(seq 1 300); do
  if ! kill -0 "$EMULATOR_PID" >/dev/null 2>&1; then
    echo "Android emulator process exited during framework boot." >&2
    exit 1
  fi
  state="$(timeout 10s adb -s "$DEVICE" get-state 2>/dev/null || true)"
  boot="$(timeout 10s adb -s "$DEVICE" shell getprop sys.boot_completed 2>/dev/null | tr -d "\r" || true)"
  package_service="$(timeout 10s adb -s "$DEVICE" shell service check package 2>/dev/null | tr -d "\r" || true)"
  activity_service="$(timeout 10s adb -s "$DEVICE" shell service check activity 2>/dev/null | tr -d "\r" || true)"
  if [[ "$state" == "device" && "$boot" == "1" && "$package_service" == *"found"* && "$activity_service" == *"found"* ]]; then
    ready=1
    break
  fi
  sleep 2
done

if [[ "$ready" -ne 1 ]]; then
  echo "Android emulator did not reach framework-ready state within 10 minutes." >&2
  adb devices -l >&2 || true
  exit 1
fi

timeout 15s adb -s "$DEVICE" shell settings put global window_animation_scale 0.0 || true
timeout 15s adb -s "$DEVICE" shell settings put global transition_animation_scale 0.0 || true
timeout 15s adb -s "$DEVICE" shell settings put global animator_duration_scale 0.0 || true
timeout 15s adb -s "$DEVICE" shell svc power stayon true || true
adb devices -l

COMMAND_TIMEOUT="${ANDROID_CI_COMMAND_TIMEOUT:-30m}"
status=0
timeout --signal=TERM --kill-after=30s "$COMMAND_TIMEOUT" "$@" || status=$?
if [[ "$status" -ne 0 ]]; then
  if [[ "$status" -eq 124 || "$status" -eq 137 ]]; then
    echo "Android gate command exceeded timeout: $COMMAND_TIMEOUT" >&2
  fi
  exit "$status"
fi
