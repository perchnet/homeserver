FROM ghcr.io/ublue-os/ccos:latest AS base

COPY build.sh /tmp/build.sh

COPY etc /etc

RUN mkdir -p /var/lib/alternatives && \
    /tmp/build.sh

FROM base AS container

COPY scripts /tmp/scripts

RUN cd /tmp/scripts/komodo && \
./bootstrap_komodo.sh

RUN bootc container lint

# Komodo
