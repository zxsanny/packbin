#!/usr/bin/env python3
"""Reads one registry answer saved by publish-query.sh and prints `yes` or `no`.

Usage: publish-published.py <mode> <json file> <version> [file name...]
Modes: nuget, maven, platformio, esp-idf, pypi (every given file name must be listed), pio-owner.
A body that does not have the expected shape raises, so the caller stops instead of guessing.
"""
import json
import sys
from pathlib import Path

mode, path, version = sys.argv[1:4]
names = sys.argv[4:]
data = json.loads(Path(path).read_text())

if mode == "nuget":
    found = version.lower() in [v.lower() for v in data["versions"]]
elif mode == "maven":
    found = data["published"] is True
elif mode == "platformio":
    found = any(v["name"] == version for v in data["versions"])
elif mode == "esp-idf":
    found = any(v["version"] == version for v in data["versions"])
elif mode == "pypi":
    listed = {u["filename"] for u in data["urls"]}
    found = bool(names) and all(name in listed for name in names)
elif mode == "pio-owner":
    print(data["profile"]["username"])
    sys.exit(0)
else:
    sys.exit(f"unknown mode: {mode}")

print("yes" if found else "no")
