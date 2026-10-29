"""Violations of every workflow file in directory argv[1] (exit 1 when there are any): a non-local `uses:` that is not
owner/repo@<40 lowercase hex>, a pinned one without a `# <tag>` comment, one action with two SHAs across the files, and a
literal `npm@<digit>` in a run step. Run by publish-pins.test.sh as `python3 -I`."""
import collections
import pathlib
import re
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[2] / "scripts" / "ci"))
import yaml_get  # noqa: E402

PINNED = re.compile(r"[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+(/[^@\s]+)?@[0-9a-f]{40}")
USES_LINE = re.compile(r"^\s*(?:-\s+)?uses:\s*(\S+)(.*)$")
TAG_COMMENT = re.compile(r"\s+#\s*\S")


def main(directory):
    folder = pathlib.Path(directory)
    files = sorted(list(folder.glob("*.yml")) + list(folder.glob("*.yaml")))
    errors = []
    if not files:
        errors.append(f"{directory}: no workflow files")
    shas = collections.defaultdict(lambda: collections.defaultdict(list))
    count = 0
    for path in files:
        name = path.name
        workflow = yaml_get.load(str(path))
        raw_jobs = workflow.get("jobs") if isinstance(workflow, dict) else None
        jobs = list(raw_jobs.values()) if isinstance(raw_jobs, dict) else []
        steps = [s for job in jobs for s in (job.get("steps") if isinstance(job.get("steps"), list) else [])]
        for node in jobs + steps:
            ref = node.get("uses")
            if ref is None or ref.startswith("./"):
                continue
            count += 1
            if not PINNED.fullmatch(ref):
                errors.append(f"{name}: uses '{ref}' is not owner/repo@<40 lowercase hex commit>")
        for step in steps:
            literal = re.search(r"npm@\d\S*", str(step.get("run") or ""))
            if literal:
                errors.append(f"{name}: run step installs npm at the literal version '{literal.group(0)}'")
        for number, line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
            match = USES_LINE.match(line)
            if match is None:
                continue
            ref = match.group(1).replace('"', "").replace("'", "")
            if not PINNED.fullmatch(ref):
                continue
            if not TAG_COMMENT.match(match.group(2)):
                errors.append(f"{name}:{number}: uses '{ref}' has no tag comment (# <tag>)")
            action, sha = ref.split("@")
            shas[action][sha].append(name)
    for action, by_sha in shas.items():
        if len(by_sha) > 1:
            errors.append(f"action {action} has {len(by_sha)} different SHAs: {', '.join(by_sha)}")
    for error in errors:
        print(error)
    if not errors:
        print(f"ok: {count} non-local uses, {len(shas)} actions, {len(files)} files")
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1]))
