"""Wiring check of the Dart pieces of the ring job of test.yml (AZ-4146 AC-6), run by ring-wiring-dart.test.sh as
`python3 -I ring-wiring-dart-check.py <test.yml> <dart pin of tool-pins.txt> <docker-compose.test.yml>`.

Prints one violation per line; exit 0 when there are none, 1 when there are any (2: the YAML could not be read,
reported by yaml_get). RING_DART against the suite image is also checked by ring-wiring-check.py (SUITES); this adds the
tool pin, the driver build cache, the image pull, the cache state of the build step and the scaffold step.
"""
import pathlib
import re
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[2] / "scripts" / "ci"))
import yaml_get  # noqa: E402
from workflow_yaml import CACHE_USES, FLAGS, code_lines, dig, inspect, runs, steps_of, to_s  # noqa: E402

RING = re.compile(r"bash \.github/workflows/language-pair\.sh", FLAGS)
START = re.compile(r"bash \.github/workflows/ring-prepare\.sh start (\S+)((?: \S+)+)", FLAGS)
BUILD = re.compile(r"bash \.github/workflows/ring-prepare\.sh build \S+", FLAGS)
WIRING = re.compile(r"bash \.github/workflows/ring-wiring-dart\.test\.sh", FLAGS)
# The manifests the driver build reads, and the script that sets the build.
CACHE_KEY = ("dart-v1-ring-${{ env.RING_DART }}-${{ hashFiles('dart/pubspec.yaml', "
             "'.github/workflows/drivers/handoff-dart/pubspec.yaml', '.github/workflows/ring-dart.sh') }}")
CACHE_IF = "${{ !startsWith(github.ref, 'refs/tags/') }}"


def cache_errors(name, steps, start_at, build_at) -> list:
    """The Dart driver build output (ring-dart.sh's scratch dir) is restored by exact key before the start step, never
    on a tag run, and the build step that runs ring-dart.sh learns hit or miss."""
    cache_at = next((i for i, s in enumerate(steps) if s.get("id") == "ring-dart-cache"), None)
    if cache_at is None or not CACHE_USES.fullmatch(to_s(steps[cache_at].get("uses"))):
        return [f"job {name} has no actions/cache step with the id ring-dart-cache"]
    cache, errors = steps[cache_at], []
    if start_at is None or cache_at > start_at:
        errors.append(f"job {name} restores the Dart driver build cache after the ring-prepare.sh start step")
    if dig(cache, "with", "key") != CACHE_KEY:
        errors.append(f"the Dart driver build cache key {inspect(dig(cache, 'with', 'key'))} is not {inspect(CACHE_KEY)}")
    if isinstance(cache.get("with"), dict) and "restore-keys" in cache["with"]:
        errors.append("the Dart driver build cache restores by a prefix (restore-keys): a hit must be the exact key")
    if dig(cache, "with", "path") != "/tmp/packbin-ring-dart":
        errors.append("the Dart driver build cache is not ring-dart.sh's scratch dir /tmp/packbin-ring-dart")
    if cache.get("if") != CACHE_IF:
        errors.append(f"the Dart driver build cache also runs on a tag run: {inspect(cache.get('if'))}")
    state = ("${{ steps.ring-dart-cache.conclusion == 'success' && (steps.ring-dart-cache.outputs.cache-hit == 'true' "
             "&& 'hit' || 'miss') || '' }}")
    if build_at is None or dig(steps[build_at], "env", "PACKBIN_DART_CACHE") != state:
        errors.append("the step that runs ring-prepare.sh build does not take the cache state from the Dart cache step")
    return errors


def violations(workflow, pin, compose) -> list:
    jobs = workflow.get("jobs") if isinstance(workflow.get("jobs"), dict) else {}
    name, job = next(((n, j) for n, j in jobs.items() if any(runs(s, RING) for s in steps_of(j))), (None, None))
    if job is None:
        return ["test.yml has no job that runs .github/workflows/language-pair.sh"]
    steps = steps_of(job)
    errors = []
    have = to_s(dig(job, "env", "RING_DART"))
    if have != pin:
        errors.append(f"RING_DART is '{have}' in job {name}, tool-pins.txt has dart=={pin}")
    image = to_s(dig(compose, "services", "dart", "image"))
    if image != f"dart:{have}":
        errors.append(f"RING_DART is '{have}' in job {name}, the dart suite image is '{image}'")

    def at(pattern):
        return next((i for i, s in enumerate(steps) if runs(s, pattern)), None)

    start_at, build_at = at(START), at(BUILD)
    pulled = next((m.group(2).split() for m in (START.fullmatch(line) for line in code_lines(steps[start_at])) if m), []) \
        if start_at is not None else []
    if '"dart:$RING_DART"' not in pulled:
        errors.append(f"the ring-prepare.sh start line of job {name} does not pull \"dart:$RING_DART\"")
    errors += cache_errors(name, steps, start_at, build_at)
    if at(WIRING) is not None:
        errors.append(f"job {name} runs ring-wiring-dart.test.sh, which belongs in scaffold (off the ring's critical path)")
    check = next((s for s in steps_of(jobs.get("scaffold")) if runs(s, WIRING)), None)
    if check is None:
        errors.append("scaffold does not run ring-wiring-dart.test.sh")
    elif "if" in check or "continue-on-error" in check:
        errors.append("the ring-wiring-dart.test.sh step of scaffold has an if or continue-on-error")
    return errors


def main(argv) -> int:
    if len(argv) != 4:
        print("usage: ring-wiring-dart-check.py <test.yml> <dart pin> <docker-compose.test.yml>", file=sys.stderr)
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
