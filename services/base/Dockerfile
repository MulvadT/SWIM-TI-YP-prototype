# FROM ubuntu:19.10
FROM ubuntu:20.04

LABEL maintainer="SWIM EUROCONTROL <http://www.eurocontrol.int>"

RUN apt-get update --fix-missing && apt-get upgrade -y && \
    apt-get install -y dialog apt-utils && DEBIAN_FRONTEND=noninteractive apt-get install -y \
    gcc g++ cmake cmake-curses-gui uuid-dev \
    libssl-dev libsasl2-2 libsasl2-dev libsasl2-modules swig \
    python3 python3-dev python3-pip ruby-dev python3-qpid-proton \
    build-essential vim tree netcat pkg-config openssl libssl-dev \
    libffi-dev python3-gevent gunicorn git

COPY env_update.sh /usr/bin/env_update

RUN chmod +x /usr/bin/env_update
