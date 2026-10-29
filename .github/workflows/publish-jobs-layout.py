"""The job layout rules of test.yml (AZ-2564, AZ-2600, AZ-2607, AZ-2625, AZ-2626, AZ-2627).

Usage: python3 -I publish-jobs-layout.py <test.yml> <publish-gate.test.sh>

Prints one line per violation on stdout and exits 1 when there is one, 0 when there is none; a file that cannot be
read exits 2 with the cause on stderr (scripts/ci/yaml_get.py). The rules are described in publish-jobs.test.sh.
"""
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "scripts" / "ci"))
import yaml_get  # noqa: E402

LANGUAGES = "csharp typescript python rust cpp java go swift".split()
BUILT = "csharp typescript python rust java".split()
# The suite images each group starts (traced in the code, AZ-2626): the golden gate and the read-only probes run all
# eight; the nojava gate copy has no java; the phase scenarios, the build of readonly-full and the pins build start
# the five that publish-build.sh runs in containers (cpp builds on the host); the other groups start none. A job
# pulls exactly the union for its groups: a missing image would be pulled on first use, inside a timed group, and an
# extra one costs the pull (swift is 4 GB).
GROUP_IMAGES = {
    "gate": LANGUAGES, "readonly": LANGUAGES, "readonly-gate-good": LANGUAGES, "readonly-gate-bad": LANGUAGES,
    "readonly-gate-nojava": [lang for lang in LANGUAGES if lang != "java"], "phases": BUILT, "phases-rerun": BUILT,
    "readonly-full": BUILT, "pins": ["python"],
}
PULL_LINE = re.compile(r"docker compose .*docker-compose\.publish\.yml.* pull\b")
CACHE_USES = re.compile(r"actions/cache@[0-9a-f]{40}")
GATE_CMD = "bash .github/workflows/publish-gate.test.sh"
EMBEDDED_CMDS = ["bash cpp/embedded/run.sh host arm", "bash cpp/embedded/run.sh host esp core",
                 "bash cpp/embedded/run.sh host esp packages"]
SUITE_BODY = ('docker compose -f docker-compose.test.yml run --rm "${kept[@]}" -e PACKBIN_SWIFT_PART "$suite"'
              ' || failed="$failed $suite"')
SWIFT_CACHE_IF = "${{ matrix.part != '' && !startsWith(github.ref, 'refs/tags/') }}"
STATIC = """
  .github/workflows/report-row.test.sh fixtures/hostile/cases.test.sh .github/workflows/run-suite.test.sh
  cpp/embedded/lib.test.sh cpp/embedded/run-parts.test.sh .github/workflows/ring-wiring.test.sh scripts/loop-tests.test.sh
  .github/workflows/ring-wiring-rows.test.sh
  .github/workflows/ring-wiring-swift.test.sh .github/workflows/ring-prepare.test.sh
  fixtures/text/check-vectors.test.sh scripts/text/check-emitted.test.sh scripts/text/check-emitted.sh
  fixtures/crypto/check-vectors.test.sh fixtures/frame/check-vectors.test.sh fixtures/ecc/check-vectors.test.sh
  fixtures/ecc/check-contract.sh .github/workflows/ring-ecc.test.sh .github/workflows/ring-frame.test.sh
""".split()

_ESCAPES = {'"': '\\"', "\\": "\\\\", "\n": "\\n", "\t": "\\t", "\r": "\\r", "\x1b": "\\e"}


def inspect(value):
    """The messages quote workflow values as {"k" => "v"}, ["a", nil], "text", nil, true (the form of the earlier checker)."""
    if value is None:
        return "nil"
    if isinstance(value, bool):
        return "true" if value else "false"
    if isinstance(value, str):
        out = []
        for i, ch in enumerate(value):
            if ch in _ESCAPES:
                out.append(_ESCAPES[ch])
            elif ch == "#" and value[i + 1:i + 2] in ("{", "$", "@"):
                out.append("\\#")
            else:
                out.append(ch)
        return '"' + "".join(out) + '"'
    if isinstance(value, (list, tuple)):
        return "[" + ", ".join(inspect(v) for v in value) + "]"
    if isinstance(value, dict):
        return "{" + ", ".join(f"{inspect(k)} => {inspect(v)}" for k, v in value.items()) + "}"
    return str(value)


def to_s(value):
    if value is None:
        return ""
    return value if isinstance(value, str) else inspect(value)


def first_set(*values):
    """The first value that is neither None nor False (an empty string counts)."""
    return next((v for v in values if v is not None and v is not False), None)


def dig(value, *keys):
    for key in keys:
        if not isinstance(value, dict):
            return None
        value = value.get(key)
    return value


def split_commas(text):
    """Split at commas, dropping trailing empty strings ("a," is ["a"], "," is [])."""
    parts = text.split(",")
    while parts and parts[-1] == "":
        parts.pop()
    return parts


def uniq(items):
    return list(dict.fromkeys(items))


def twice(items):
    """The items that occur more than once, each once, in order of first occurrence."""
    return [i for i in uniq(items) if items.count(i) > 1]


def steps_of(job):
    return job["steps"] if isinstance(job, dict) and isinstance(job.get("steps"), list) else []


def lines_of(step):
    return [line for line in (raw.strip() for raw in to_s(step.get("run")).split("\n")) if line]


def label_of(step):
    return to_s(first_set(step.get("name"), step.get("uses"), "unnamed"))


def cache_step(step):
    """A cache step restores and saves build output only, it runs no check: the one kind of step that may have an if."""
    return CACHE_USES.fullmatch(to_s(step.get("uses"))) is not None


def runs(jobs, name, wanted):
    return [s for s in steps_of(jobs.get(name)) if wanted in lines_of(s)]


def all_runs(jobs, wanted):
    return [name for name in jobs for _ in runs(jobs, name, wanted)]


def job_flags(name, job, errors):
    if "timeout-minutes" not in job:
        errors.append(f"job {name} has no timeout-minutes")
    for key in ("if", "needs", "continue-on-error"):
        if key in job:
            errors.append(f"job {name} has {key}, so it does not run beside the others")


def check_jobs(jobs, errors, gate_jobs, embedded_jobs):
    if not gate_jobs:
        errors.append("test.yml has no publish-gate-* job")
    if not embedded_jobs:
        errors.append("test.yml has no embedded-* job")
    if "embedded" in jobs:
        errors.append("a job named embedded is left: the embedded targets are the embedded-* jobs")
    for name in ["scaffold", "suites", "ring"] + gate_jobs + embedded_jobs:
        if not isinstance(jobs.get(name), dict):
            errors.append(f"test.yml has no {name} job")
    for name in ["scaffold", "suites"] + gate_jobs:
        job = jobs.get(name)
        if not isinstance(job, dict):
            continue
        job_flags(name, job, errors)
        for step in steps_of(job):
            if ("if" in step and not cache_step(step)) or "continue-on-error" in step:
                errors.append(f"step '{label_of(step)}' of job {name} has an if or continue-on-error")
    if "publish-gate" in jobs:
        errors.append("a job named publish-gate is left: the gate is the publish-gate-* jobs")
    # The free plan runs 20 jobs at once: with more, some start late, and a late long job sets the wall (AZ-2627).
    count = 0
    for job in jobs.values():
        include = dig(job, "strategy", "matrix", "include") if isinstance(job, dict) else None
        count += len(include) if isinstance(include, list) else 1
    if count > 20:
        errors.append(f"test.yml makes {count} jobs, more than the 20 the free plan runs at once")


def check_embedded(jobs, errors, embedded_jobs):
    """No job-level if, needs or continue-on-error, a timeout; the only step with an if is the report (if: always()),
    and every part of cpp/embedded/run.sh is called by exactly one job, once."""
    for name in embedded_jobs:
        job = jobs.get(name)
        if not isinstance(job, dict):
            continue
        job_flags(name, job, errors)
        for step in steps_of(job):
            label = label_of(step)
            if "continue-on-error" in step:
                errors.append(f"step '{label}' of job {name} has continue-on-error")
            if "if" in step and not (label == "embedded report" and step["if"] == "always()"):
                errors.append(f"step '{label}' of job {name} has an if (only the embedded report has if: always())")
    ran = [(name, line) for name in jobs for step in steps_of(jobs[name]) for line in lines_of(step)
           if line.startswith("bash cpp/embedded/run.sh")]
    for cmd in EMBEDDED_CMDS:
        found = [name for name, line in ran if line == cmd]
        if len(found) != 1:
            errors.append(f"the embedded part '{cmd}' runs in {len(found)} jobs, not exactly one")
        else:
            if found[0] not in embedded_jobs:
                errors.append(f"the embedded part '{cmd}' runs in {found[0]}, which is not an embedded-* job")
    for name, line in ran:
        if line not in EMBEDDED_CMDS:
            errors.append(f"job {name} runs {line}, which is not one of the embedded parts")
    for name in embedded_jobs:
        n = sum(1 for job, _ in ran if job == name)
        if n != 1:
            errors.append(f"job {name} runs {n} embedded parts, not one")


def check_matrix(errors, suites):
    """One job per matrix entry, whose lang lists the suites it runs one after the other (AZ-2627); every language in
    exactly one entry, Swift as its three parts, each alone in its entry; nothing else."""
    strategy = suites.get("strategy") if isinstance(suites, dict) else None
    matrix = strategy.get("matrix") if isinstance(strategy, dict) else None
    entries = matrix["include"] if isinstance(matrix, dict) and isinstance(matrix.get("include"), list) else []
    if not entries:
        errors.append("the suites job has no matrix of included entries")
    if isinstance(matrix, dict) and list(matrix) != ["include"]:
        errors.append("the suites matrix has keys besides include (an exclude or a product would change the set)")
    if not (isinstance(strategy, dict) and strategy.get("fail-fast") is False):
        errors.append("the suites matrix stops the other suites at the first failure (fail-fast is not false)")
    hashes = [e for e in entries if isinstance(e, dict)]
    got = [(lang, e.get("part")) for e in hashes for lang in to_s(e.get("lang")).split()]
    for e in hashes:
        if not to_s(e.get("lang")).split():
            errors.append(f"the suites matrix entry {inspect(e)} names no suite")
    for e in hashes:
        if first_set(e.get("part")) is not None and len(to_s(e.get("lang")).split()) > 1:
            errors.append(f"the suites matrix entry {inspect(e)} runs a Swift part beside other suites")
    want = [(lang, None) for lang in LANGUAGES if lang != "swift"] + [("swift", p) for p in ("tests", "gates", "speed")]
    for e in want:
        if e not in got:
            errors.append(f"the suites matrix has no entry for {parts_of(e)}")
    for e in got:
        if e not in want:
            errors.append(f"the suites matrix has an unknown entry {inspect(e)}")
    for e in twice(got):
        errors.append(f"the suites matrix runs {parts_of(e)} twice")
    for e in hashes:
        if [k for k in e if k not in ("lang", "part")]:
            errors.append(f"the suites matrix entry {inspect(e)} has keys besides lang and part")


def parts_of(entry):
    return " ".join(to_s(x) for x in entry if x is not None)


def check_suites(jobs, errors):
    suites = jobs.get("suites")
    check_matrix(errors, suites)
    ran_in = all_runs(jobs, SUITE_BODY)
    if ran_in != ["suites"]:
        errors.append(f"the suites run in {inspect(ran_in)}, not only in the suites job")
    if any("docker-compose.test.yml run" in line for name in jobs if name != "suites"
           for step in steps_of(jobs[name]) for line in lines_of(step)):
        errors.append("a job other than suites runs a suite through compose")
    steps = steps_of(suites)
    suites_step = next((st for st in steps if SUITE_BODY in lines_of(st)), None)
    suite_lines = lines_of(suites_step) if suites_step is not None else []
    if suite_lines[:1] != ["set -euo pipefail"]:
        errors.append("the suites step does not start with set -euo pipefail, so a failing suite can pass")
    if not (suites_step is not None and dig(suites_step, "env", "SUITE") == "${{ matrix.lang }}"):
        errors.append("the suites step does not take its language from the matrix")
    if not (suites_step is not None and dig(suites_step, "env", "PACKBIN_SWIFT_PART") == "${{ matrix.part }}"):
        errors.append("the suites step does not take its Swift part from the matrix")
    # Each suite of an entry runs although one before it failed, and the step then fails naming the failed ones.
    order = ["for suite in $SUITE; do", SUITE_BODY, "done", 'if [ -n "$failed" ]; then',
             'echo "::error title=suites failed::$failed"', "exit 1"]
    at = [suite_lines.index(line) if line in suite_lines else None for line in order]
    if None in at or at != sorted(at):
        errors.append("the suites step does not run each suite of its entry, keep going after a failed one and fail"
                      " naming it")
    check_swift_cache(errors, steps, suites_step)


def check_swift_cache(errors, steps, suites_step):
    """C3 (AZ-2627): a Swift part restores its kept build output by exact key (the part, the swift image tag, the
    package manifests and run-suite.sh, which sets the build), before the suite step, and never on a tag run; the
    suite step learns from it whether it hit."""
    cache_at = next((i for i, st in enumerate(steps) if cache_step(st)), None)
    cache = steps[cache_at] if cache_at is not None else None
    pin = next((st for st in steps if st.get("id") == "swift-pin"), None)
    if not (pin is not None and lines_of(pin) == ['echo "tag=$(bash .github/workflows/tool-pin.sh swift)"'
                                                  ' >> "$GITHUB_OUTPUT"']):
        errors.append("the suites job reads no swift image tag for the cache key (a swift-pin step running"
                      " tool-pin.sh swift)")
    suite_at = steps.index(suites_step) if suites_step is not None and suites_step in steps else 0
    if cache is None or cache_at > suite_at:
        errors.append("the suites job has no Swift build cache step before the suite step")
        return
    if cache.get("if") != SWIFT_CACHE_IF:
        errors.append("the Swift build cache step runs for more than the Swift parts or on a tag run:"
                      f" {inspect(cache.get('if'))}")
    key = to_s(dig(cache, "with", "key"))
    for part in ("${{ matrix.part }}", "${{ steps.swift-pin.outputs.tag }}",
                 "hashFiles('Package.swift', 'Package.resolved', '.github/workflows/run-suite.sh')"):
        if part not in key:
            errors.append(f"the Swift build cache key {inspect(key)} does not name {part}")
    if isinstance(cache.get("with"), dict) and "restore-keys" in cache["with"]:
        errors.append("the Swift build cache restores by a prefix (restore-keys): a hit must be the exact key")
    if dig(cache, "with", "path") != "${{ runner.temp }}/swift-cache":
        errors.append("the Swift build cache path is not the runner's swift-cache directory")
    cid = to_s(cache.get("id"))
    state = (f"${{{{ steps.{cid}.conclusion == 'success' && (steps.{cid}.outputs.cache-hit == 'true' && 'hit'"
             " || 'miss') || '' }}")
    if not (suites_step is not None and dig(suites_step, "env", "PACKBIN_SWIFT_CACHE") == state):
        errors.append("the suites step does not take the cache state from the cache step")


def check_gate(jobs, errors, gate_jobs, gate_source):
    """Every group of publish-gate.test.sh runs in exactly one job, and no group name is made up."""
    found = re.search(r'^gate_groups="([^"]*)"$', gate_source, re.M)
    all_groups = found.group(1).split() if found else []
    if not all_groups:
        errors.append("publish-gate.test.sh has no gate_groups list")
    ran = []
    for name in gate_jobs:
        steps = steps_of(jobs[name])
        mine = [line for st in steps for line in lines_of(st) if line.startswith(GATE_CMD)]
        if len(mine) != 1:
            errors.append(f"job {name} runs the publish gate {len(mine)} times, not once")
            continue
        m = re.fullmatch(re.escape(GATE_CMD) + r" --groups (\S+)", mine[0])
        if m is None:
            errors.append(f"job {name} does not run the gate with --groups <list>: {mine[0]}")
            continue
        groups = split_commas(m.group(1))
        if not groups:
            errors.append(f"job {name} names no group")
        ran.extend(groups)
        check_pulls(errors, name, steps, groups)
    for g in all_groups:
        if g not in ran:
            errors.append(f"the gate group {g} runs in no job")
    for g in uniq(ran):
        if g not in all_groups:
            errors.append(f"the gate group {g} is not a group of publish-gate.test.sh")
    for g in twice(ran):
        errors.append(f"the gate group {g} runs in more than one job")
    if any(name not in gate_jobs and any("publish-gate.test.sh" in line for st in steps_of(jobs[name])
                                         for line in lines_of(st)) for name in jobs):
        errors.append("a job other than the publish-gate-* jobs runs the publish gate")


def check_pulls(errors, name, steps, groups):
    """A job pulls exactly the images its groups start, once, before the gate."""
    gate_at = next(i for i, st in enumerate(steps) if any(line.startswith(GATE_CMD) for line in lines_of(st)))
    pulls = [(i, line) for i, st in enumerate(steps) for line in lines_of(st) if PULL_LINE.match(line)]
    want = uniq([img for g in groups for img in GROUP_IMAGES.get(g, [])])
    if not want:
        if pulls:
            errors.append(f"job {name} pulls images, but none of its groups starts a container")
        return
    if len(pulls) != 1 or pulls[0][0] > gate_at:
        errors.append(f"job {name} runs a group that starts containers without pulling its images once before the gate")
        return
    words = pulls[0][1].split()
    while words and words[0] != "pull":
        words.pop(0)
    have = [w for w in words[1:] if not w.startswith("-")]
    for img in want:
        if img not in have:
            starts = ", ".join(g for g in groups if img in GROUP_IMAGES.get(g, []))
            errors.append(f"job {name} does not pull {img}, which {starts} starts")
    for img in have:
        if img not in want:
            errors.append(f"job {name} pulls {img}, which none of its groups ({', '.join(groups)}) starts")
    for img in twice(have):
        errors.append(f"job {name} pulls {img} twice")


def check_static(jobs, errors):
    for script in STATIC:
        found = all_runs(jobs, f"bash {script}")
        if found != ["scaffold"]:
            errors.append(f"the static check bash {script} runs in {inspect(found)}, not only in scaffold")
    # The reference codec's seeded bounds (AZ-2689) are a python check, not a bash one; the ring run itself is in the
    # ring job.
    found = all_runs(jobs, "python3 -I scripts/ecc/fuzz_reference.py")
    if found != ["scaffold"]:
        errors.append(f"the message ECC reference bounds run in {inspect(found)}, not only in scaffold")
    for what, cmd in (("the message ECC ring", "bash .github/workflows/ring-ecc.sh"),
                      ("the frame ring", "bash .github/workflows/ring-frame.sh"),
                      ("the frame driver check", "bash .github/workflows/ring-frame-drivers.test.sh")):
        found = all_runs(jobs, cmd)
        if found != ["ring"]:
            errors.append(f"{what} runs in {inspect(found)}, not only in ring")


def main():
    if len(sys.argv) != 3:
        print("usage: publish-jobs-layout.py <test.yml> <publish-gate.test.sh>", file=sys.stderr)
        return 2
    wf = yaml_get.load(sys.argv[1])
    try:
        gate_source = Path(sys.argv[2]).read_text(encoding="utf-8")
    except OSError as err:
        print(f"publish-jobs-layout: cannot read {sys.argv[2]}: {err.strerror}", file=sys.stderr)
        return 2
    jobs = wf["jobs"] if isinstance(wf, dict) and isinstance(wf.get("jobs"), dict) else {}
    gate_jobs = [n for n in jobs if n.startswith("publish-gate-")]
    embedded_jobs = [n for n in jobs if n.startswith("embedded-")]
    errors = []
    check_jobs(jobs, errors, gate_jobs, embedded_jobs)
    check_embedded(jobs, errors, embedded_jobs)
    check_suites(jobs, errors)
    check_gate(jobs, errors, gate_jobs, gate_source)
    check_static(jobs, errors)
    for error in errors:
        print(error)
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())
