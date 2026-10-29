"""The helpers both ring-wiring checkers use to read a workflow (AZ-3388); the standard library only.

They keep the semantics of the shell-embedded programs the checkers replaced: a missing key reads as None, an absent
value as "", and a step of the wrong shape is skipped, not a traceback.
"""
import re

FLAGS = re.ASCII
CACHE_USES = re.compile(r"actions/cache@[0-9a-fA-F]{40}", FLAGS)
SHA_PIN = re.compile(r"@[0-9a-f]{40}\Z", FLAGS)
ASCII_SPACE = "\0\t\n\v\f\r "
STRING_ESCAPES = {'"': '\\"', "\\": "\\\\", "\n": "\\n", "\t": "\\t", "\r": "\\r", "\x1b": "\\e",
                  "\x07": "\\a", "\x08": "\\b", "\x0b": "\\v", "\x0c": "\\f"}


def to_s(value) -> str:
    if value is None:
        return ""
    if isinstance(value, bool):
        return "true" if value else "false"
    return str(value)


def inspect(value) -> str:
    """The quoted form of a value in a violation message: "text", nil, true, [a, b], {"k" => v}."""
    if value is None:
        return "nil"
    if isinstance(value, bool):
        return "true" if value else "false"
    if isinstance(value, str):
        out = []
        for i, ch in enumerate(value):
            if ch in STRING_ESCAPES:
                out.append(STRING_ESCAPES[ch])
            elif ch == "#" and value[i + 1:i + 2] in ("{", "$", "@"):
                out.append("\\#")
            elif ch == "\x7f":
                out.append("\\x7F")
            elif not ch.isprintable():
                out.append(f"\\u{ord(ch):04X}" if ord(ch) <= 0xFFFF else f"\\u{{{ord(ch):X}}}")
            else:
                out.append(ch)
        return '"' + "".join(out) + '"'
    if isinstance(value, list):
        return "[" + ", ".join(inspect(v) for v in value) + "]"
    if isinstance(value, dict):
        return "{" + ", ".join(f"{inspect(k)} => {inspect(v)}" for k, v in value.items()) + "}"
    return str(value)


def first_set(*values):
    """The first value that is neither None nor False (an empty string counts as set)."""
    return next((v for v in values if v is not None and v is not False), None)


def dig(obj, *keys):
    for key in keys:
        obj = obj.get(key) if isinstance(obj, dict) else None
    return obj


def steps_of(job) -> list:
    steps = job.get("steps") if isinstance(job, dict) else None
    return [s for s in steps if isinstance(s, dict)] if isinstance(steps, list) else []


def code_lines(step) -> list:
    lines = (line.strip(ASCII_SPACE) for line in to_s(step.get("run")).split("\n"))
    return [line for line in lines if line and not line.startswith("#")]


def runs(step, pattern) -> bool:
    return any(pattern.fullmatch(line) for line in code_lines(step))
