#!/usr/bin/env bash
# Start the Connect IQ simulator, wait until it accepts connections, then load the watch face.
#   ./tools/sim.sh            -> venux1
#   ./tools/sim.sh fenix7     -> another device id
#
# Stays in the foreground; Ctrl-C stops the simulator.
#
# The simulator runs in a network namespace with only loopback. With real network access the
# 9.2.0 Linux simulator segfaults in a worker thread after ~20 s (cause unknown; it is stable
# without it). monkeydo talks to it over localhost, so it runs in the same namespace.
set -uo pipefail

cd "$(dirname "$0")/.."

DEVICE="${1:-venux1}"
PRG="bin/bmw-m-watchface.prg"

if [ -z "${SIM_ISOLATED:-}" ]; then
    ./build.sh "$DEVICE" || exit 1
    exec unshare -rn env SIM_ISOLATED=1 bash "$0" "$@"
fi
ip link set lo up

connectiq &
SIM=$!
trap 'kill "$SIM" 2>/dev/null' EXIT

# The simulator listens on localhost:1234 once it is ready.
for _ in $(seq 1 60); do
    if (exec 3<>/dev/tcp/127.0.0.1/1234) 2>/dev/null; then break; fi
    if ! kill -0 "$SIM" 2>/dev/null; then echo "Simulator exited before it was ready." >&2; exit 1; fi
    sleep 0.5
done

START=$SECONDS
monkeydo "$PRG" "$DEVICE" &
APP=$!

wait "$SIM"
echo "Simulator exited after $((SECONDS - START)) s with the app loaded." >&2
kill "$APP" 2>/dev/null || true
