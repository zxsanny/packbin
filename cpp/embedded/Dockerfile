# Embedded CI image: arm-none-eabi GCC 13 + newlib-nano, QEMU system (mps2-an385 / mps2-an386),
# QEMU user for a big-endian host (s390x) and its cross g++. ESP-IDF builds use the official
# espressif/idf image (docker-compose.test.yml service cpp-embedded-esp).
FROM ubuntu:24.04

ARG DEBIAN_FRONTEND=noninteractive
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      bash ca-certificates make binutils gawk \
      gcc-arm-none-eabi libnewlib-arm-none-eabi libstdc++-arm-none-eabi-newlib \
      qemu-system-arm qemu-user-static \
      g++-s390x-linux-gnu \
 && rm -rf /var/lib/apt/lists/*

WORKDIR /src
