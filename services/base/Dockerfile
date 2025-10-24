FROM ubuntu:20.04

LABEL maintainer="SWIM EUROCONTROL <http://www.eurocontrol.int>" \
      org.opencontainers.image.source="https://github.com/MulvadT/SWIM-TI-YP-prototype" \
      org.opencontainers.image.title="swim-base" \
      org.opencontainers.image.description="Base image for SWIM services (Ubuntu 20.04)"

ENV DEBIAN_FRONTEND=noninteractive

# Keep upgrade to preserve current behavior, but reduce size with no-recommends and cleanup
RUN set -eux; \
    apt-get update --fix-missing; \
    apt-get upgrade -y; \
    apt-get install -y --no-install-recommends \
      gcc g++ cmake cmake-curses-gui uuid-dev \
      libssl-dev libsasl2-2 libsasl2-dev libsasl2-modules swig \
      python3 python3-dev python3-pip python3-qpid-proton \
      ruby-dev \
      build-essential vim tree netcat pkg-config openssl \
      libffi-dev python3-gevent gunicorn git \
      ca-certificates gettext-base \
    ; \
    rm -rf /var/lib/apt/lists/*

# Interpolation helper (kept at same path for compatibility)
COPY env_update.sh /usr/bin/env_update
RUN chmod +x /usr/bin/env_update