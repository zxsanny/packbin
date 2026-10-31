# Embedded CI image: arm-none-eabi GCC 13 + newlib-nano, QEMU system (mps2-an385 / mps2-an386),
# QEMU user for a big-endian host (s390x) and its cross g++, avr-gcc 7.3 + avr-libc. ESP-IDF
# builds use the official espressif/idf image (docker-compose.test.yml service cpp-embedded-esp).
FROM ubuntu:24.04

ARG DEBIAN_FRONTEND=noninteractive
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      bash ca-certificates make binutils gawk \
      gcc-arm-none-eabi libnewlib-arm-none-eabi libstdc++-arm-none-eabi-newlib \
      qemu-system-arm qemu-user-static \
      g++-s390x-linux-gnu \
 && rm -rf /var/lib/apt/lists/*

# AVR (ATmega328P, Arduino Uno): avr-gcc 7.3 with avr-libc, no C++ library (AZ-2068), and the simavr
# emulator that runs the chacha20_xor check image (AZ-3452). A layer of its own so the toolchain layer
# above stays cached.
RUN apt-get update \
 && apt-get install -y --no-install-recommends gcc-avr avr-libc binutils-avr simavr \
 && rm -rf /var/lib/apt/lists/*

WORKDIR /src
