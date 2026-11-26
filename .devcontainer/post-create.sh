#!/usr/bin/env bash
# Runs once after the container is created. The connect-iq-sdk feature has
# already installed the SDK (anonymous download). The two things left need a
# Garmin login: the per-device compiler files, and a signing key for builds.
set -euo pipefail

cd "$(dirname "$0")/.."

# --- Simulator libraries ---------------------------------------------------
# The Connect IQ simulator (and so the unit tests) is a GTK3/WebKit GUI binary;
# xvfb lets it run headless for tools/test.sh.
if ! dpkg -s libwebkit2gtk-4.0-37 >/dev/null 2>&1; then
    echo "Installing Connect IQ simulator libraries..."
    sudo apt-get update
    sudo apt-get install -y --no-install-recommends \
        libsecret-1-0 libusb-1.0-0 libxext6 libx11-6 libxkbcommon0 libxxf86vm1 \
        libsm6 libatk1.0-0 libgtk-3-0 libfreetype6 libpng16-16 libcairo2 \
        libpango-1.0-0 libpangocairo-1.0-0 libpangoft2-1.0-0 libgdk-pixbuf-2.0-0 \
        libfontconfig1 libwebkit2gtk-4.0-37 libsoup2.4-1 libjavascriptcoregtk-4.0-18 \
        libjpeg-turbo8 xvfb xauth
fi

# --- Developer signing key (monkeyc -y) -------------------------------------
# Private key; never committed. Generated once per container.
if [ ! -f developer_key.der ]; then
    echo "Generating Connect IQ developer signing key..."
    openssl genrsa -out developer_key.pem 4096
    openssl pkcs8 -topk8 -inform PEM -outform DER \
        -in developer_key.pem -out developer_key.der -nocrypt
    rm -f developer_key.pem
fi

# --- Per-device compiler files (needs Garmin login) -------------------------
if [ -n "${GARMIN_USERNAME:-}" ] && [ -n "${GARMIN_PASSWORD:-}" ]; then
    echo "Logging in to Garmin and downloading device files for the manifest..."
    connect-iq-sdk-manager login
    connect-iq-sdk-manager device download --manifest manifest.xml
    echo "Device files ready. Build with: ./build.sh"
else
    cat >&2 <<'EOF'

  GARMIN_USERNAME / GARMIN_PASSWORD are not set, so device files were not
  downloaded and the app cannot be built yet.

  Export them on the host (or add them as Codespaces/repo secrets) and rebuild
  the container, or run inside the container:

      export GARMIN_USERNAME=you@example.com GARMIN_PASSWORD=...
      connect-iq-sdk-manager login
      connect-iq-sdk-manager device download --manifest manifest.xml

  Then: ./build.sh

EOF
fi
