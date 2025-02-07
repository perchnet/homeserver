FROM ghcr.io/ublue-os/ccos:latest

COPY build.sh /tmp/build.sh

COPY scripts /tmp/scripts

COPY etc /etc

RUN mkdir -p /var/lib/alternatives && \
    /tmp/build.sh && \
    bootc container lint
