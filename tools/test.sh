#!/usr/bin/env bash
# Build the watch face with its unit tests and run them in the Connect IQ simulator.
#   ./tools/test.sh            -> venux1
#   ./tools/test.sh fenix7     -> another device id from the manifest
#
# The tests live in source/tests/ as (:test) functions; a normal build ignores them.
# Running them needs the simulator (`connectiq`) and `monkeydo`, which are GUI-based:
# on a headless machine this script uses xvfb-run if it is installed.
#
# NOTE: written without access to the Connect IQ SDK, so this script has not been run.
set -euo pipefail

cd "$(dirname "$0")/.."

DEVICE="${1:-venux1}"
OUT="bin/bmw-m-watchface-test.prg"

if [ ! -f developer_key.der ]; then
    echo "developer_key.der missing. See ./build.sh for how to generate one." >&2
    exit 1
fi

mkdir -p bin
monkeyc -f monkey.jungle -o "$OUT" -y developer_key.der -d "$DEVICE" --unit-test --warn
echo "Built $OUT with unit tests for $DEVICE."

if ! command -v connectiq >/dev/null 2>&1 || ! command -v monkeydo >/dev/null 2>&1; then
    echo "connectiq / monkeydo are not on PATH, so the tests were built but not run." >&2
    echo "Start the simulator, then run: monkeydo $OUT $DEVICE -t" >&2
    exit 2
fi

RUN=()
if [ -z "${DISPLAY:-}" ] && command -v xvfb-run >/dev/null 2>&1; then
    RUN=(xvfb-run -a)       # headless: give the simulator a virtual display
fi

# Start the simulator if one is not already running, and stop it again afterwards.
STARTED=0
if ! pgrep -f "simulator" >/dev/null 2>&1; then
    "${RUN[@]}" connectiq &
    SIM_PID=$!
    STARTED=1
    sleep 8
fi
trap '[ "$STARTED" = 1 ] && kill "$SIM_PID" 2>/dev/null || true' EXIT

"${RUN[@]}" monkeydo "$OUT" "$DEVICE" -t
