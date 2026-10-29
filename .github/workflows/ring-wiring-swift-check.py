"""Wiring check of the Swift pieces of the ring job of test.yml (AZ-2522 AC-3), run by ring-wiring-swift.test.sh as
`python3 -I ring-wiring-swift-check.py <test.yml> <swift pin of tool-pins.txt> <docker-compose.test.yml>`.

Prints one violation per line; exit 0 when there are none, 1 when there are any (2: the YAML could not be read,
reported by yaml_get). The helpers keep the semantics of the shell-embedded program this file replaced: a missing key
reads as None, an absent value as "", and an index of 0 is a found step.
"""
import pathlib
import re
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[2] / "scripts" / "ci"))
import yaml_get  # noqa: E402
from workflow_yaml import (  # noqa: E402
    CACHE_USES, FLAGS, SHA_PIN, code_lines, dig, first_set, inspect, runs, steps_of, to_s)

RING = re.compile(r"bash \.github/workflows/language-pair\.sh", FLAGS)
WIRING = re.compile(r"bash \.github/workflows/ring-wiring-swift\.test\.sh", FLAGS)
CACHE_KEY_PARTS = (
    "${{ env.RING_SWIFT }}",
    "hashFiles('Package.swift', 'Package.resolved', '.github/workflows/drivers/handoff-swift/Package.swift', "
    "'.github/workflows/drivers/handoff-swift/Package.resolved', '.github/workflows/ring-swift.sh')",
)
CACHE_IF = "${{ !startsWith(github.ref, 'refs/tags/') }}"


def prepare(sub):
    """ring-prepare.sh <sub> <state dir>; the start line also carries the images to pull."""
    rest = r"((?: \S+)+)" if sub == "start" else ""
    return re.compile(rf"bash \.github/workflows/ring-prepare\.sh {sub} (\S+){rest}", FLAGS)


def prepare_errors(name, steps, at, ring_at) -> tuple:
    """The Swift drivers are built by ring-prepare.sh start in the background, after its pull of "swift:$RING_SWIFT" (it
    calls ring-swift.sh: ring-prepare.test.sh), and waited for on the same state dir before the ring; else the ring
    would start a second build (AZ-2626). Returns the errors and the index of the start step."""
    start_at, wait_at, build_at = (at(prepare(sub)) for sub in ("start", "wait", "build"))

    def arg_of(index, sub, group):
        found = (m.group(group) for m in (prepare(sub).fullmatch(line) for line in code_lines(steps[index])) if m)
        return next(found, None)

    dirs = {arg_of(i, sub, 1) for i, sub in ((start_at, "start"), (build_at, "build"), (wait_at, "wait")) if i is not None}
    dirs.discard(None)
    if start_at is None or wait_at is None or start_at > wait_at or wait_at > ring_at or len(dirs) != 1:
        return [f"job {name} does not start the Swift driver build (ring-prepare.sh start) and wait for it on the same dir before the ring"], start_at
    if build_at is not None and (build_at > wait_at or not prepare("wait").fullmatch(code_lines(steps[wait_at])[-1])):
        return [f"the ring-prepare.sh wait of job {name} is not the last line after build, so a failed build could go unreported"], start_at
    if '"swift:$RING_SWIFT"' not in arg_of(start_at, "start", 2).split():
        return [f"the ring-prepare.sh start line of job {name} does not pull \"swift:$RING_SWIFT\" before the Swift driver build"], start_at
    return [], start_at


def cache_errors(name, steps, start_at) -> tuple:
    """C3 (AZ-2627): the Swift drivers' build output (ring-swift.sh's scratch dir, ring-prepare.sh's default) is kept
    between runs: restored by exact key before the start step, never on a tag run, and the start step learns hit or
    miss. That cache step is the only step of the job with an if: any other could skip a check."""
    cache_at = next((i for i, s in enumerate(steps) if CACHE_USES.fullmatch(to_s(s.get("uses")))), None)
    cache = steps[cache_at] if cache_at is not None else None
    if cache is None or start_at is None or cache_at > start_at:
        return [f"job {name} restores no Swift driver build cache before the ring-prepare.sh start step"], cache
    errors = []
    key = to_s(dig(cache, "with", "key"))
    for part in CACHE_KEY_PARTS:
        if part not in key:
            errors.append(f"the Swift driver build cache key {inspect(key)} does not name {part}")
    if isinstance(cache.get("with"), dict) and "restore-keys" in cache["with"]:
        errors.append("the Swift driver build cache restores by a prefix (restore-keys): a hit must be the exact key")
    if dig(cache, "with", "path") != "/tmp/packbin-ring-swift":
        errors.append("the Swift driver build cache is not ring-swift.sh's scratch dir /tmp/packbin-ring-swift")
    if cache.get("if") != CACHE_IF:
        errors.append(f"the Swift driver build cache also runs on a tag run: {inspect(cache.get('if'))}")
    cache_id = to_s(cache.get("id"))
    state = (f"${{{{ steps.{cache_id}.conclusion == 'success' && "
             f"(steps.{cache_id}.outputs.cache-hit == 'true' && 'hit' || 'miss') || '' }}}}")
    if dig(steps[start_at], "env", "PACKBIN_SWIFT_CACHE") != state:
        errors.append("the ring-prepare.sh start step does not take the cache state from the cache step")
    return errors, cache


def violations(workflow, pin, compose) -> list:
    jobs = workflow.get("jobs") if isinstance(workflow.get("jobs"), dict) else {}
    name, job = next(((n, j) for n, j in jobs.items() if any(runs(s, RING) for s in steps_of(j))), (None, None))
    if job is None:
        return ["test.yml has no job that runs .github/workflows/language-pair.sh"]
    steps = steps_of(job)
    errors = []
    if any(not isinstance(s, dict) for s in job["steps"]):
        errors.append(f"job {name} has a step that is not a mapping")
    have = to_s(dig(job, "env", "RING_SWIFT"))
    image = to_s(dig(compose, "services", "swift", "image"))
    if have != pin:
        errors.append(f"RING_SWIFT is '{have}' in job {name}, tool-pins.txt has swift=={pin}")
    if image != f"swift:{have}":
        errors.append(f"RING_SWIFT is '{have}' in job {name}, the swift suite image is '{image}'")

    def at(pattern):
        return next((i for i, s in enumerate(steps) if runs(s, pattern)), None)

    found, start_at = prepare_errors(name, steps, at, at(RING))
    errors += found
    found, cache = cache_errors(name, steps, start_at)
    errors += found
    for s in steps:
        if "if" in s and s is not cache:
            errors.append(f"step '{to_s(first_set(s.get('name'), s.get('uses')))}' of job {name} has an if (only the cache step may)")
    if at(WIRING) is not None:
        errors.append(f"job {name} runs ring-wiring-swift.test.sh, which belongs in scaffold (off the ring's critical path)")
    check = next((s for s in steps_of(jobs.get("scaffold")) if runs(s, WIRING)), None)
    if check is None:
        errors.append("scaffold does not run ring-wiring-swift.test.sh")
    elif "if" in check or "continue-on-error" in check:
        errors.append("the ring-wiring-swift.test.sh step of scaffold has an if or continue-on-error")
    for s in steps:
        if "uses" in s and not SHA_PIN.search(to_s(s["uses"])):
            errors.append(f"{to_s(s['uses'])} in job {name} is not pinned to a commit SHA")
    return errors


def main(argv) -> int:
    if len(argv) != 4:
        print("usage: ring-wiring-swift-check.py <test.yml> <swift pin> <docker-compose.test.yml>", file=sys.stderr)
        return 2
    workflow = yaml_get.load(argv[1])
    compose = yaml_get.load(argv[3])
    if not isinstance(workflow, dict):
        print(f"{argv[1]} is not a YAML mapping")
        return 1
    errors = violations(workflow, argv[2], compose)
    for error in errors:
        print(error)
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
