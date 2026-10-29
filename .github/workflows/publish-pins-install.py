"""Every job of test.yml that runs a script reading the CI YAML installs the pinned PyYAML first (argv[1] = test.yml).

A script reads the CI YAML when it, or a script or checker it names, imports scripts/ci/yaml_get.py. publish-gate.test.sh
names them all, so its jobs are told apart by --groups: the groups that run the ported checkers are GATE_READER_GROUPS.
Prints one violation per line (exit 1 when there is any), else `ok: <n> jobs need PyYAML`. Run as `python3 -I`."""
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "scripts" / "ci"))
import yaml_get  # noqa: E402

GATE = "publish-gate.test.sh"
GATE_READER_GROUPS = {"workflow", "pins"}
SCRIPT_NAME = re.compile(r"[\w./-]+\.(?:sh|py)")


def repo_scripts():
    found = list((ROOT / ".github" / "workflows").glob("*.sh")) + list((ROOT / ".github" / "workflows").glob("*.py"))
    found += list((ROOT / "scripts").rglob("*.sh")) + list((ROOT / "scripts").rglob("*.py"))
    return {path: code_lines(path.read_text(encoding="utf-8")) for path in found}


def code_lines(text):
    """The text without whole-line comments: a script named in a comment is not run by the script that names it."""
    return "\n".join(line for line in text.splitlines() if not line.lstrip().startswith("#"))


def reader_scripts(texts):
    """The scripts that reach yaml_get.py: it is named, directly or through a script that is."""
    reach = {path for path, text in texts.items() if "yaml_get" in text and path.name != "yaml_get.py"}
    while True:
        names = {path.name for path in reach}
        more = {
            path
            for path, text in texts.items()
            if path.name not in (GATE, "loop-tests.sh") and path not in reach and any(name in text for name in names)
        }
        if not more:
            return reach
        reach |= more


def installs_pyyaml(job):
    steps = job.get("steps") or []
    setup = [i for i, s in enumerate(steps) if str(s.get("uses") or "").startswith("actions/setup-python@")]
    pip = [
        i for i, s in enumerate(steps) if "pip install" in str(s.get("run") or "") and "tool-pin.sh pyyaml" in str(s.get("run") or "")
    ]
    return bool(setup and pip and min(setup) < min(pip))


def main(test_yml):
    workflow = yaml_get.load(test_yml)
    users = {path.name: path for path in reader_scripts(repo_scripts())}
    errors, needing = [], 0
    for name, job in (workflow.get("jobs") or {}).items():
        reads = set()
        for step in job.get("steps") or []:
            for line in str(step.get("run") or "").splitlines():
                for script in SCRIPT_NAME.findall(line):
                    base = script.rsplit("/", 1)[-1]
                    if base == GATE:
                        groups = re.search(r"--groups\s+(\S+)", line)
                        if groups and GATE_READER_GROUPS & set(groups.group(1).split(",")):
                            reads.add(GATE)
                    elif base in users:
                        reads.add(base)
        if not reads:
            continue
        needing += 1
        if not installs_pyyaml(job):
            errors.append(f"job {name} runs {', '.join(sorted(reads))}, which read the CI YAML, without setup-python and the pinned PyYAML install")
    for error in errors:
        print(error)
    if not errors:
        print(f"ok: {needing} jobs need PyYAML")
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1]))
