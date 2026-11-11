# Embedded CI image: arm-none-eabi GCC 13 + newlib-nano, QEMU system (mps2-an385, mps2-an505),
# QEMU user for a big-endian host (s390x) and its cross g++, avr-gcc 7.3 + avr-libc. ESP-IDF
# builds use the official espressif/idf image (docker-compose.test.yml service cpp-embedded-esp).
FROM ubuntu:24.04

ARG DEBIAN_FRONTEND=noninteractive
# A name lookup or a download that fails once on a shared runner is tried again (AZ-4191): the job
# failed three times in a row on "Could not resolve archive.ubuntu.com" with this Dockerfile unchanged.
# The cause is not known and was not reproduced (_docs/06_metrics/embedded-arm-dns_2026-11-11.md, AZ-4198).
RUN printf 'Acquire::Retries "5";\nAcquire::http::Timeout "30";\n' > /etc/apt/apt.conf.d/80-packbin-retries
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
