"""Checks the structure of publish.yml and test.yml (AZ-2095, AZ-3383) and the tag-run flow.

Usage: python3 -I publish-workflow-structure.py <test.yml> <publish.yml>
Prints one line per error on stdout; exit 0 with none, 1 with errors, 2 when the YAML cannot be read (yaml_get).

`if` expressions are checked by their truth table over every result a needed job can have, not by their text.
The evaluator is a tokenizer and a recursive-descent parser over a closed token set. No workflow text is ever run
as code. Values are booleans and strings; `&&`, `||` and `!` treat every string, including "", as true (as the
evaluator this replaced did); the two real `if` expressions only compare values, so they do not depend on it.
"""
import itertools
import pathlib
import re
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[2] / "scripts" / "ci"))
import yaml_get  # noqa: E402

WHITESPACE = " \t\n\r\f\v"
NEEDS_OUTPUT = r"needs\.([A-Za-z_-]+)\.outputs\.([A-Za-z_-]+)"
NEEDS_RESULT = r"needs\.([A-Za-z_-]+)\.result"
WORD = r"[A-Za-z0-9_]+"
OPERATORS = ("==", "!=", "&&", "||")
SINGLE_OPERATORS = "()!=&|"
RESULTS = ["success", "failure", "cancelled", "skipped"]
GREENS = ["true", "false", ""]
READ_ONLY = {"contents": "read"}


class Unsupported(Exception):
    """A term outside the supported set, found while reading the characters."""


class NotEvaluable(Exception):
    """The terms are supported but do not form an expression."""


def truthy(value):
    return value is not None and value is not False


def text(value):
    if value is None:
        return ""
    if isinstance(value, bool):
        return "true" if value else "false"
    return str(value)


def as_list(value):
    if isinstance(value, list):
        return value
    return [] if value is None else [value]


def get(mapping, key):
    return mapping.get(key) if isinstance(mapping, dict) else None


def has(mapping, key):
    return isinstance(mapping, dict) and key in mapping


def tokenize(expression, variables):
    """Tokens are ("val", bool|str) and ("op", symbol). Any other character or word is Unsupported."""
    tokens = []
    i = 0
    while i < len(expression):
        char = expression[i]
        rest = expression[i:]
        if char in WHITESPACE:
            i += 1
        elif char in "'\"":
            end = expression.find(char, i + 1)
            if end < 0:
                raise Unsupported
            tokens.append(("val", expression[i + 1:end]))
            i = end + 1
        elif rest[:2] in OPERATORS:
            tokens.append(("op", rest[:2]))
            i += 2
        elif char in SINGLE_OPERATORS:
            tokens.append(("op", char))
            i += 1
        elif char.isascii() and (char.isalnum() or char == "_"):
            i = read_word(expression, i, variables, tokens)
        else:
            raise Unsupported
    return tokens


def read_word(expression, i, variables, tokens):
    rest = expression[i:]
    for pattern in (NEEDS_OUTPUT, NEEDS_RESULT):
        match = re.match(pattern, rest)
        if match:
            key = match.group(0)
            if key not in variables:
                raise Unsupported
            tokens.append(("val", variables[key]))
            return i + match.end()
    for call, name in (("cancelled()", "cancelled"), ("always()", "always")):
        if rest.startswith(call):
            tokens.append(("val", True if name == "always" else variables[name]))
            return i + len(call)
    word = re.match(WORD, rest).group(0)
    if word not in ("true", "false"):
        raise Unsupported
    tokens.append(("val", word == "true"))
    return i + len(word)


class Parser:
    """or := and ('||' and)*; and := eq ('&&' eq)*; eq := unary (('==' | '!=') unary)?; unary := '!' unary | atom."""

    def __init__(self, tokens):
        self.tokens = tokens
        self.pos = 0

    def peek(self):
        return self.tokens[self.pos] if self.pos < len(self.tokens) else None

    def take(self, *symbols):
        token = self.peek()
        if token is not None and token[0] == "op" and token[1] in symbols:
            self.pos += 1
            return token[1]
        return None

    def parse(self):
        value = self.parse_or()
        token = self.peek()
        if token is not None:
            raise NotEvaluable(f"unexpected {describe(token)}")
        return value

    def parse_or(self):
        left = self.parse_and()
        while self.take("||"):
            right = self.parse_and()
            left = left if truthy(left) else right
        return left

    def parse_and(self):
        left = self.parse_eq()
        while self.take("&&"):
            right = self.parse_eq()
            left = right if truthy(left) else left
        return left

    def parse_eq(self):
        left = self.parse_unary()
        symbol = self.take("==", "!=")
        if symbol:
            left = (left == self.parse_unary()) == (symbol == "==")
            token = self.peek()
            if token is not None and token[0] == "op" and token[1] in ("==", "!="):
                raise NotEvaluable("chained comparison")
        return left

    def parse_unary(self):
        if self.take("!"):
            return not truthy(self.parse_unary())
        return self.parse_atom()

    def parse_atom(self):
        token = self.peek()
        if token is None:
            raise NotEvaluable("unexpected end")
        if token[0] == "val":
            self.pos += 1
            return token[1]
        if self.take("("):
            value = self.parse_or()
            if not self.take(")"):
                raise NotEvaluable("unbalanced parenthesis")
            return value
        raise NotEvaluable(f"unexpected {describe(token)}")


def describe(token):
    return "value" if token[0] == "val" else f"'{token[1]}'"


def evaluate(expression, variables):
    """(value, None) or (None, why). variables: needs.<job>.result, needs.<job>.outputs.<name>, cancelled."""
    e = text(expression).strip()
    if e.startswith("${{") and e.endswith("}}"):
        e = e[3:-2].strip()
    if not e:
        return None, "no if expression"
    try:
        tokens = tokenize(e, variables)
    except Unsupported:
        return None, f"unsupported term in [{e}]"
    try:
        return truthy(Parser(tokens).parse()), None
    except NotEvaluable as err:
        return None, f"[{e}] does not evaluate ({err})"
    except RecursionError:
        return None, f"[{e}] does not evaluate (nested too deeply)"


def check_test_workflow(test_wf, errors):
    on = yaml_get.triggers(test_wf)
    errors_if(errors, not (isinstance(on, dict) and "workflow_call" in on), "test.yml has no workflow_call")
    errors_if(errors, not (isinstance(on, dict) and "pull_request" in on), "test.yml has no pull_request")
    push = get(on, "push")
    if not (isinstance(push, dict) and as_list(push.get("branches")) and not has(push, "tags")
            and not has(push, "tags-ignore")):
        errors.append("test.yml push is not limited to branches")
    errors_if(errors, test_wf.get("permissions") != READ_ONLY, "test.yml permissions are not contents: read")
    jobs = get(test_wf, "jobs")
    if not isinstance(jobs, dict):
        errors.append("test.yml has no jobs")
        jobs = {}
    # The gate and embedded jobs are the publish-gate-* and embedded-* jobs (publish-jobs.test.sh holds their groups).
    prefixed = [n for n in jobs if isinstance(n, str) and n.startswith(("publish-gate-", "embedded-"))]
    for name in ["scaffold", "suites"] + prefixed:
        job = jobs.get(name)
        errors_if(errors, job is None, f"test.yml has no {name} job")
        errors_if(errors, job is not None and not has(job, "timeout-minutes"),
                  f"test.yml {name} has no timeout-minutes")


def errors_if(errors, condition, message):
    if condition:
        errors.append(message)


def check_precheck(precheck, errors):
    if precheck is None:
        errors.append("publish.yml has no precheck job")
        return
    errors_if(errors, get(precheck, "permissions") != {"contents": "read", "actions": "read"},
              "precheck permissions are not exactly contents: read and actions: read")
    errors_if(errors, has(precheck, "secrets"), "precheck passes secrets")
    errors_if(errors, not has(precheck, "timeout-minutes"), "precheck has no timeout-minutes")
    outputs = get(precheck, "outputs")
    errors_if(errors, not (isinstance(outputs, dict) and "steps.proof.outputs.green" in text(outputs.get("green"))),
              "precheck has no green output")
    steps = get(precheck, "steps")
    proof = next((s for s in steps if get(s, "id") == "proof"), None) if isinstance(steps, list) else None
    run_lines = [line.strip() for line in text(get(proof, "run")).split("\n")]
    errors_if(errors, proof is None or "bash .github/workflows/publish-precheck.sh" not in run_lines,
              "precheck has no proof step that runs publish-precheck.sh")
    errors_if(errors, proof is not None and (has(proof, "if") or has(proof, "continue-on-error")),
              "the proof step has an if or continue-on-error")


def check_test_call(test_job, errors):
    for green in GREENS:
        variables = {"needs.precheck.result": "success", "needs.precheck.outputs.green": green, "cancelled": False}
        runs, why = evaluate(test_job.get("if"), variables)
        if runs is None:
            errors.append(f"test call if: {why}")
            break
        if runs != (green != "true"):
            errors.append(f"test call runs={text(runs)} for green [{green}]; "
                          "it must run exactly when there is no green proof")
    errors_if(errors, re.search(r"always\(\)|cancelled\(\)|failure\(\)|success\(\)", text(test_job.get("if"))),
              "the test call if has a status function")


def check_publish_if(publish, errors):
    if not re.search(r"\b(cancelled|always)\(\)", text(publish.get("if"))):
        errors.append("publish has no cancelled() or always() in its if, so a skipped test would skip the publish")
        return
    for pre, tst, green, cancelled in itertools.product(RESULTS, RESULTS, GREENS, [True, False]):
        variables = {"needs.precheck.result": pre, "needs.test.result": tst,
                     "needs.precheck.outputs.green": green, "cancelled": cancelled}
        runs, why = evaluate(publish.get("if"), variables)
        if runs is None:
            message = f"publish if: {why}"
            if message not in errors:
                errors.append(message)
            continue
        wanted = (not cancelled) and pre == "success" and (tst == "success" or (green == "true" and tst == "skipped"))
        if runs != wanted:
            errors.append(f"publish runs={text(runs)} for precheck {pre}, test {tst}, green [{green}], "
                          f"cancelled {text(cancelled)}; wanted {text(wanted)}")
            break


def holds_write(job):
    permissions = get(job, "permissions")
    if isinstance(permissions, dict):
        return "write" in permissions.values()
    return permissions == "write-all"


def check_publish_workflow(publish_wf, errors):
    on = yaml_get.triggers(publish_wf)
    push = get(on, "push")
    tags = as_list(push.get("tags")) if isinstance(push, dict) else []
    errors_if(errors, "v*" not in tags, "publish.yml does not trigger on v* tags")
    errors_if(errors, isinstance(push, dict) and "branches" in push, "publish.yml triggers on branches")
    errors_if(errors, publish_wf.get("permissions") != READ_ONLY,
              "publish.yml workflow permissions are not contents: read")
    jobs = get(publish_wf, "jobs")
    if not isinstance(jobs, dict):
        errors.append("publish.yml has no jobs")
        jobs = {}
    test_ids = [name for name, job in jobs.items() if get(job, "uses") == "./.github/workflows/test.yml"]
    errors_if(errors, len(test_ids) != 1, "publish.yml must call ./.github/workflows/test.yml exactly once")
    test_job = jobs.get(test_ids[0]) if test_ids else None
    if test_job is not None:
        errors_if(errors, get(test_job, "permissions") != READ_ONLY, "test call permissions are not contents: read")
        errors_if(errors, has(test_job, "secrets"), "test call passes secrets")
        errors_if(errors, "precheck" not in as_list(get(test_job, "needs")), "the test call does not need precheck")
    check_precheck(jobs.get("precheck"), errors)
    if test_job is not None:
        check_test_call(test_job, errors)
    publish = jobs.get("publish")
    if publish is None:
        errors.append("publish.yml has no publish job")
    else:
        needs = as_list(get(publish, "needs"))
        errors_if(errors, any(t not in needs for t in test_ids), "publish does not need the test call")
        errors_if(errors, "precheck" not in needs, "publish does not need precheck")
        check_publish_if(publish, errors)
        errors_if(errors, get(publish, "permissions") != {"contents": "write", "id-token": "write"},
                  "publish permissions are not contents: write and id-token: write")
        errors_if(errors, not has(publish, "timeout-minutes"), "publish has no timeout-minutes")
    check_concurrency(publish_wf, publish, errors)
    for name, job in jobs.items():
        errors_if(errors, name != "publish" and holds_write(job), f"{name} holds a write permission")


def check_concurrency(publish_wf, publish, errors):
    concurrency = publish_wf.get("concurrency")
    if not truthy(concurrency):
        concurrency = get(publish, "concurrency")
    if not isinstance(concurrency, dict):
        errors.append("publish.yml has no concurrency group")
        return
    errors_if(errors, "github.ref" not in text(concurrency.get("group")),
              "publish concurrency group is not keyed by the ref")
    errors_if(errors, truthy(concurrency.get("cancel-in-progress")), "publish concurrency cancels a run in progress")


def main(argv):
    if len(argv) != 3:
        print("usage: publish-workflow-structure.py <test.yml> <publish.yml>", file=sys.stderr)
        return 2
    errors = []
    test_wf = yaml_get.load(argv[1])
    publish_wf = yaml_get.load(argv[2])
    for name, workflow in (("test.yml", test_wf), ("publish.yml", publish_wf)):
        if not isinstance(workflow, dict):
            print(f"{name} is not a YAML mapping")
            return 1
    check_test_workflow(test_wf, errors)
    check_publish_workflow(publish_wf, errors)
    for error in errors:
        print(error)
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
