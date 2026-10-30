"""Wiring check of the cross-language ring (AZ-2193 AC-1, AC-6), run by ring-wiring.test.sh as
`python3 -I ring-wiring-check.py <test.yml> <docker-compose.test.yml>`.

Prints one violation per line; exit 0 when there are none, 1 when there are any (2: the YAML could not be read,
reported by yaml_get). The helpers below keep the semantics of the shell-embedded program this file replaced: a missing key
reads as None, an absent value as "", and a step or job of the wrong shape is a violation, not a traceback.
"""
import pathlib
import re
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[2] / "scripts" / "ci"))
import yaml_get  # noqa: E402
from workflow_yaml import (  # noqa: E402
    CACHE_USES, FLAGS, SHA_PIN, code_lines, dig, first_set, inspect, runs, steps_of, to_s)

# The exact call, the script as the command word in any other form (|| true, a pipe, &), a set line.
CALL = re.compile(r"(?:bash )?(?:\./)?\.github/workflows/language-pair\.sh", FLAGS)
INVOKES = re.compile(r"(?:(?:bash|sh) )?(?:\./)?\.github/workflows/language-pair\.sh\b", FLAGS)
TOOLCHAINS = re.compile(r"(?:bash )?(?:\./)?\.github/workflows/ring-toolchains\.sh", FLAGS)
SHELL_OPTIONS = re.compile(r"set -[euo]+( pipefail)?", FLAGS)
WRAPPER = re.compile(r"/\.github/workflows/ring-cxx\.sh\Z", FLAGS)
GO_BUILD = re.compile(r"bash \.github/workflows/ring-(?:go\.sh|prepare\.sh build) \S+", FLAGS)
# The workflow and job env versions and the suite images they copy (docker-compose.test.yml service => RING_ variable).
SUITES = {"RING_DOTNET": "csharp", "RING_NODE": "typescript", "RING_PYTHON": "python",
          "RING_RUST": "rust", "RING_GCC": "cpp", "RING_JDK": "java", "RING_GO": "go"}
SCAFFOLD_SCRIPTS = {"cpp/embedded/lib.test.sh": "the embedded harness self-test",
                    ".github/workflows/ring-wiring.test.sh": "the ring wiring check",
                    ".github/workflows/ring-wiring-rows.test.sh": "the ring row wiring check",
                    "scripts/ci/yaml_get.test.sh": "the CI YAML reader self-test",
                    "scripts/ci/workflow_yaml.test.sh": "the CI workflow helpers self-test"}


def as_list(value) -> list:
    if isinstance(value, list):
        return value
    return [] if value is None else [value]


def index_of(items, predicate):
    return next((i for i, item in enumerate(items) if predicate(item)), None)


def trigger_errors(on) -> list:
    errors = []
    if not (isinstance(on, dict) and "push" in on and "pull_request" in on):
        return ["test.yml does not run on both push and pull_request"]
    push = on["push"]
    if isinstance(push, dict):
        for key in push:
            if key not in ("branches", "paths-ignore"):
                errors.append(f"push has the filter {to_s(key)}")
        # The one filter the owner allows (2026-10-23): a push that touches only _docs/ starts no run.
        if as_list(push.get("paths-ignore")) != ["_docs/**"]:
            errors.append(f"push ignores the paths {inspect(as_list(push.get('paths-ignore')))}, not exactly _docs/**")
        if "branches" in push and as_list(push.get("branches")) != ["**"]:
            errors.append(f"push is limited to the branches {inspect(as_list(push.get('branches')))}")
    if isinstance(on["pull_request"], dict):
        for key in on["pull_request"]:
            errors.append(f"pull_request has the filter {to_s(key)}")
    return errors


def python_errors(name, steps) -> list:
    return [f"the setup-python step of job {name} does not take python-version from RING_PYTHON"
            for step in steps
            if to_s(step.get("uses")).startswith("actions/setup-python@")
            and to_s(dig(step, "with", "python-version")) != "${{ env.RING_PYTHON }}"]


def go_errors(name, steps) -> list:
    errors = []
    # Go: setup-go pinned to a commit SHA at RING_GO; the driver built by ring-go.sh or ring-prepare.sh build (calls it).
    setup_go = next((s for s in steps if to_s(s.get("uses")).startswith("actions/setup-go@")), None)
    if setup_go is None:
        errors.append(f"job {name} has no actions/setup-go step")
    else:
        if not SHA_PIN.search(to_s(setup_go["uses"])):
            errors.append(f"the setup-go step of job {name} is not pinned to a commit SHA")
        if to_s(dig(setup_go, "with", "go-version")) != "${{ env.RING_GO }}":
            errors.append(f"the setup-go step of job {name} does not take go-version from RING_GO")
    if not any(runs(s, GO_BUILD) for s in steps):
        errors.append(f"job {name} does not build the Go driver through ring-go.sh")
    return errors


def suite_errors(name, job, steps, compose, workflow_env) -> list:
    errors = []
    services = compose.get("services") if isinstance(compose, dict) else None
    services = services if isinstance(services, dict) else {}
    used = "\n".join(str([s.get("with"), s.get("run")]) for s in steps)
    job_env = {**workflow_env, **(job.get("env") if isinstance(job.get("env"), dict) else {})}
    for key, service in SUITES.items():
        image = to_s(dig(services, service, "image"))
        parts = image.split(":", 1)
        version = re.sub(r"-jdk\Z", "", parts[1] if len(parts) > 1 else "", count=1)
        have = to_s(job_env.get(key)) if job_env else ""
        if not version or have != version:
            errors.append(f"{key} is '{have}' in job {name}, the {service} suite image '{image}' has the version '{version}'")
        if key not in used:
            errors.append(f"{key} is not used by any step of job {name}")
    return errors


def ring_job_errors(name, jobs, ring_steps, compose, workflow_env) -> list:
    errors = []
    job = jobs[name]
    steps = steps_of(job)
    if "if" in job:
        errors.append(f"job {name} has an if condition")
    if "needs" in job:
        errors.append(f"job {name} needs another job, so it does not run in parallel")
    if "timeout-minutes" not in job:
        errors.append(f"job {name} has no timeout-minutes")
    if "continue-on-error" in job:
        errors.append(f"job {name} has continue-on-error")
    checks_at = index_of(steps, lambda s: runs(s, TOOLCHAINS))
    ring_at = index_of(steps, lambda s: s in ring_steps)
    if checks_at is None or checks_at > ring_at:
        errors.append(f"job {name} does not run ring-toolchains.sh before the ring")
    for step in steps:
        label = to_s(first_set(step.get("name"), step.get("uses"), "unnamed"))
        if "continue-on-error" in step:
            errors.append(f"step '{label}' of job {name} has continue-on-error")
        # a cache step runs no check (AZ-2627)
        if "if" in step and not CACHE_USES.fullmatch(to_s(step.get("uses"))):
            errors.append(f"step '{label}' of job {name} has an if condition")
        # The ring and the version check must both compile through the gcc image, not the runner's GCC.
        if not (step in ring_steps or runs(step, TOOLCHAINS)):
            continue
        env = {}
        for part in (job.get("env"), step.get("env")):
            if isinstance(part, dict):
                env.update(part)
        if not WRAPPER.search(to_s(env.get("CXX"))):
            errors.append(f"step '{label}' of job {name} does not compile through ring-cxx.sh (CXX is '{to_s(env.get('CXX'))}')")
    return errors + go_errors(name, steps) + suite_errors(name, job, steps, compose, workflow_env)


def scaffold_errors(jobs) -> list:
    errors = []
    for script, what in SCAFFOLD_SCRIPTS.items():
        step = next((s for s in steps_of(jobs.get("scaffold")) if f"bash {script}" in code_lines(s)), None)
        if step is None:
            errors.append(f"scaffold does not run {what} (bash {script})")
        elif "if" in step or "continue-on-error" in step:
            errors.append(f"the scaffold step for {script} has an if or continue-on-error")
    return errors


def violations(workflow, compose) -> list:
    errors = trigger_errors(yaml_get.triggers(workflow))
    jobs = workflow.get("jobs") if isinstance(workflow.get("jobs"), dict) else {}
    for name, job in jobs.items():
        raw = job.get("steps") if isinstance(job, dict) else None
        if isinstance(raw, list) and any(not isinstance(s, dict) for s in raw):
            errors.append(f"job {name} has a step that is not a mapping")
    callers = {}
    for name, job in jobs.items():
        for step in steps_of(job):
            lines = code_lines(step)
            if any(CALL.fullmatch(line) for line in lines):
                callers.setdefault(name, []).append(step)
                for line in lines:
                    if not (CALL.fullmatch(line) or SHELL_OPTIONS.fullmatch(line)):
                        errors.append(f"the ring step of job {name} runs more than the call, which can skip it: {line}")
            else:
                for line in lines:
                    if INVOKES.match(line):
                        errors.append(f"job {name} runs language-pair.sh in a form that can hide its failure: {line}")
    if not callers:
        errors.append("test.yml has no job that runs .github/workflows/language-pair.sh")
    workflow_env = workflow.get("env") if isinstance(workflow.get("env"), dict) else {}
    for name, ring_steps in callers.items():
        errors += ring_job_errors(name, jobs, ring_steps, compose, workflow_env)
    for name, job in jobs.items():
        errors += python_errors(name, steps_of(job))
    return errors + scaffold_errors(jobs)


def main(argv) -> int:
    if len(argv) != 3:
        print("usage: ring-wiring-check.py <test.yml> <docker-compose.test.yml>", file=sys.stderr)
        return 2
    workflow = yaml_get.load(argv[1])
    compose = yaml_get.load(argv[2])
    if not isinstance(workflow, dict):
        print(f"{argv[1]} is not a YAML mapping")
        return 1
    errors = violations(workflow, compose)
    for error in errors:
        print(error)
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
