#!/usr/bin/env bash
# C# probe of AZ-4251 (see ../README.md). Probe.csproj compiles the package sources by their path, and
# bin and obj go to a temporary directory that is removed on exit; nothing is written into the
# repository. Build messages and the lines of the dictionary form go to stderr; stdout holds one probe
# line per shape. Exit 0 when the probe ran, whatever it found; non-zero when the build or the run failed.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

command -v dotnet >/dev/null || { echo "dotnet not found" >&2; exit 1; }

out="$(mktemp -d)"
trap 'rm -rf "$out"' EXIT

# No MSBuild node and no compiler server stay behind (and dotnet hangs on the project's Mac with node reuse on).
env MSBUILDDISABLENODEREUSE=1 DOTNET_NOLOGO=1 DOTNET_CLI_TELEMETRY_OPTOUT=1 \
  dotnet build "$here/Probe.csproj" -c Release --nologo -v quiet \
  -o "$out/bin" \
  -p:BaseIntermediateOutputPath="$out/obj/" \
  -p:MSBuildProjectExtensionsPath="$out/obj/" \
  -p:UseSharedCompilation=false >&2 </dev/null
env DOTNET_NOLOGO=1 DOTNET_CLI_TELEMETRY_OPTOUT=1 dotnet "$out/bin/Probe.dll" </dev/null
