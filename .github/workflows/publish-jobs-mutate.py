"""Writes a changed copy of test.yml for publish-jobs.test.sh.

Usage: python3 -I publish-jobs-mutate.py <test.yml> <out.yml> <edit>...

Each <edit> is Python text written in publish-jobs-mutants.test.sh, a file of this repository, and is run with exec
on the loaded workflow; it is never taken from workflow text. The edit sees `wf` and `jobs` (the loaded dicts),
`step_named(job, name)`, `gate_step(job)`, `deep` (a deep copy), `include` (the suites matrix entries) and the helpers
below. The script exits 1 when an edit fails or leaves the workflow as it was (a mutant that changes nothing would
pass for a refusal), and when the dumped copy does not load back to the edited workflow.
"""
import copy
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "scripts" / "ci"))
import yaml_get  # noqa: E402
import yaml  # noqa: E402


def reject(items, drop):
    items[:] = [item for item in items if not drop(item)]


def main():
    if len(sys.argv) < 4:
        print("usage: publish-jobs-mutate.py <test.yml> <out.yml> <edit>...", file=sys.stderr)
        return 2
    source, out, edits = sys.argv[1], sys.argv[2], sys.argv[3:]
    wf = yaml_get.load(source)
    original = copy.deepcopy(wf)
    jobs = wf["jobs"]

    def step_named(job, name):
        return next((s for s in jobs[job]["steps"] if s.get("name") == name), None)

    def drop_step(job, name):
        reject(jobs[job]["steps"], lambda s: s.get("name") == name)

    def sub(node, key, old, new):
        """Replace the first match only."""
        node[key] = node[key].replace(old, new, 1)

    def resub(node, key, pattern, new):
        """Replace the first regexp match only; `^` matches at every line start."""
        node[key] = re.sub(pattern, new, node[key], count=1, flags=re.M)

    names = {
        "wf": wf, "jobs": jobs, "deep": copy.deepcopy, "re": re, "reject": reject, "step_named": step_named,
        "gate_step": lambda job: step_named(job, "publish gate"), "drop_step": drop_step, "sub": sub, "resub": resub,
        "include": jobs["suites"]["strategy"]["matrix"]["include"],
    }
    for edit in edits:
        exec(edit, names)  # noqa: S102 - repository-owned edit text, see the module docstring
    if wf == original:
        print(f"publish-jobs-mutate: the edit left {source} unchanged", file=sys.stderr)
        return 1
    with open(out, "w", encoding="utf-8") as handle:
        yaml.safe_dump(wf, handle, sort_keys=False, width=1_000_000)
    if yaml_get.load(out) != wf:
        print(f"publish-jobs-mutate: {out} does not load back to the edited workflow", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
