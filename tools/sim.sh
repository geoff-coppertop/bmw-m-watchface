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

cleanup() { kill "$SIM" "$APP" 2>/dev/null; }
trap 'cleanup; exit 0' INT TERM
trap cleanup EXIT

# The 9.2.0 Linux simulator crashes unpredictably (segfault in a worker thread), so keep
# restarting it and reloading the face until you press Ctrl-C.
while true; do
    connectiq &
    SIM=$!
    APP=0

    # The simulator listens on localhost:1234 once it is ready.
    ready=0
    for _ in $(seq 1 60); do
        if (exec 3<>/dev/tcp/127.0.0.1/1234) 2>/dev/null; then ready=1; break; fi
        kill -0 "$SIM" 2>/dev/null || break
        sleep 0.5
    done

    START=$SECONDS
    if [ "$ready" = 1 ]; then
        monkeydo "$PRG" "$DEVICE" &
        APP=$!
    fi

    wait "$SIM"
    echo "Simulator exited after $((SECONDS - START)) s. Restarting (Ctrl-C to stop)..." >&2
    kill "$APP" 2>/dev/null || true
    sleep 1
done
