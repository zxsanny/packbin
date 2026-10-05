#!/usr/bin/env bash
# Fails when compiled main classes reference an API missing from Android API 26.
# Usage: api-check.sh <main-classes-dir>
set -euo pipefail

root="$(cd "$(dirname "$0")" && pwd)"
classes="${1:?main classes dir}"
tools="$root/out/api-tools"
central=https://repo1.maven.org/maven2
sniffer=animal-sniffer-1.28.jar
asm=asm-9.10.1.jar
signature=android-api-level-26-8.0.0_r2.signature

java "$root/tools/Fetch.java" "$tools" \
  "$central/org/codehaus/mojo/animal-sniffer/1.28/$sniffer" 3a4431099611e11514d6985d3bac99e2e50632e7f5c2d72dcc12308a4a709443 "$sniffer" \
  "$central/org/ow2/asm/asm/9.10.1/$asm" ed825d10ab1399c8c0cb669e688cf0c8c82629b4c8399b58352b68e92ca10fcb "$asm" \
  "$central/net/sf/androidscents/signature/android-api-level-26/8.0.0_r2/$signature" 0a66815b03fc99ab4e3deaaf470deeb3799070e373358db166e91d16be5ddd36 "$signature"

java -cp "$tools/$sniffer:$tools/$asm" "$root/tools/ApiCheck.java" \
  "$tools/$signature" "$classes" "$root/src/main/java"
echo "api-check PASS: no main-source API above Android API 26"
