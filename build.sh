#!/usr/bin/env bash
# Compile the watchface to a .prg for the target device.
#   ./build.sh            -> build for the default device (venux1)
#   ./build.sh fenix7     -> build for another device id from the manifest
set -euo pipefail

cd "$(dirname "$0")"

DEVICE="${1:-venux1}"
OUT="bin/bmw-m-watchface.prg"

if [ ! -f developer_key.der ]; then
    echo "developer_key.der missing. Generate one first:" >&2
    echo "  openssl genrsa -out developer_key.pem 4096" >&2
    echo "  openssl pkcs8 -topk8 -inform PEM -outform DER -in developer_key.pem -out developer_key.der -nocrypt" >&2
    exit 1
fi

mkdir -p bin
monkeyc \
    -f monkey.jungle \
    -o "$OUT" \
    -y developer_key.der \
    -d "$DEVICE" \
    --warn

echo "Built $OUT for $DEVICE"
