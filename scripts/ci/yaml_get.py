"""Reads the workflow and compose YAML for the CI scripts.

Callers run under `python3 -I` and add this directory to sys.path themselves. Every failure to read (no PyYAML,
no file, not YAML) prints the cause and exits 2, so a script never goes on with an empty value.
"""
import sys

try:
    import yaml
except ImportError:
    print("PyYAML is required to parse the workflow YAML", file=sys.stderr)
    sys.exit(2)


def load(path):
    try:
        with open(path, encoding="utf-8") as handle:
            return yaml.safe_load(handle)
    except OSError as err:
        print(f"yaml_get: cannot read {path}: {err.strerror}", file=sys.stderr)
        sys.exit(2)
    except yaml.YAMLError as err:
        print(f"yaml_get: {path} is not valid YAML: {err}", file=sys.stderr)
        sys.exit(2)


def triggers(workflow):
    """`on:` is read as the boolean key True by YAML 1.1 (PyYAML); a quoted "on" stays a string."""
    return workflow["on"] if "on" in workflow else workflow.get(True)
