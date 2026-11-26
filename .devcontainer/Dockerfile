# Ubuntu 22.04, not Debian: the Connect IQ simulator is linked against
# libwebkit2gtk-4.0, libsoup2.4 and libjpeg8, which Debian 13 no longer ships.
FROM mcr.microsoft.com/devcontainers/base:jammy

# The connect-iq-sdk feature builds connect-iq-sdk-manager-cli, which needs
# Go 1.25, but it installs jammy's apt Go (1.18), which cannot fetch a newer
# toolchain. Put a current Go first on PATH so that build uses it.
ARG GO_VERSION=1.25.0
RUN arch="$(dpkg --print-architecture)" \
    && curl -fsSL "https://go.dev/dl/go${GO_VERSION}.linux-${arch}.tar.gz" | tar -C /usr/local -xz
ENV PATH=/usr/local/go/bin:${PATH}
