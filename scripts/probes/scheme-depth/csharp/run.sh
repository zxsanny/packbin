#!/usr/bin/env bash
# C# probe of AZ-4291 (scheme depth; see Program.cs). Probe.csproj compiles the package sources by their path,
# and bin and obj go to a temporary directory that is removed on exit; nothing is written into the repository.
# Each shape and depth runs in its own process through ../case.sh with a 60 s limit, so a stack overflow (which
# kills a .NET process) or a hang is one line. Build messages go to stderr; stdout holds one line per case.
# Exit 0 when the probe ran, whatever it found; non-zero when the build failed.
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

for shape in when group; do
  for depth in 1000 5000 50000; do
    env DOTNET_NOLOGO=1 DOTNET_CLI_TELEMETRY_OPTOUT=1 \
      bash "$here/../case.sh" csharp "$shape-$depth" 60 dotnet "$out/bin/Probe.dll" "$shape" "$depth"
  done
done
