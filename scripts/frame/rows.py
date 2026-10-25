"""Row syntax of fixtures/frame/vectors.txt and the evaluation of a row with the reference (framefmt.py).
One row per line: `op=<op> case=<name> name=value ...`. Hex fields have no separators and `-` is empty;
integer fields (epoch, dir, tag_len, kind, n, clear_len, out_len, counter) are decimal; `window` is `top:bits`
in hex; `steps` is `check:N,commit:N,...` (decimal N); `parts` is hex pieces joined by `|`."""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import framefmt as ff  # noqa: E402

OUTPUTS = {
    "keys": ("k_enc", "k_mac", "k_label"),
    "seal": ("body", "result"),
    "open": ("result", "slot", "plain", "window_after"),
    "mac": ("tag", "valid", "result"),
    "replay": ("results", "states"),
}
INTS = ("epoch", "dir", "tag_len", "kind", "n", "clear_len", "out_len", "counter", "prev_epoch")


def hx(b):
    return b.hex() if b else "-"


def unhex(s):
    return b"" if s == "-" else bytes.fromhex(s)


def parse(line):
    row = {}
    for token in line.split():
        name, _, value = token.partition("=")
        row[name] = value
    return row


def render(row):
    first = ["op", "case"]
    rest = [k for k in row if k not in first]
    return " ".join("%s=%s" % (k, row[k]) for k in first + rest)


def inputs(row):
    out = set(OUTPUTS[row["op"]]) | {"op", "case"}
    return {k: v for k, v in row.items() if k not in out}


def _dirs(row):
    return tuple(int(c) for c in row.get("dirs", "123"))


def _int(row, name, default=None):
    return int(row[name]) if name in row else default


def run(row):
    """The outputs of a row as an ordered dict of name -> text."""
    op = row["op"]
    out = {}
    try:
        if op == "keys":
            key, epoch = unhex(row["key"]), int(row["epoch"])
            if "label" in row:
                out["k_label"] = ff.label_key(key, epoch, unhex(row["label"])).hex()
            else:
                k_enc, k_mac = ff.keys(key, epoch, int(row["dir"]))
                out["k_enc"], out["k_mac"] = k_enc.hex(), k_mac.hex()
        elif op == "seal":
            body = ff.seal(unhex(row["key"]), int(row["epoch"]), int(row["dir"]), int(row["tag_len"]),
                           unhex(row["msg_id"]), int(row["kind"]), unhex(row["ad"]), unhex(row["clear"]),
                           unhex(row["plain"]), _dirs(row), _int(row, "out_len"))
            out["body"] = hx(body)
        elif op == "open":
            prev = None
            if "prev_key" in row:
                prev = (unhex(row["prev_key"]), int(row["prev_epoch"]))
            window = ff.Window.parse(row["window"]) if "window" in row else None
            slot, plain, after = ff.open_frame(
                unhex(row["key"]), int(row["epoch"]), int(row["dir"]), int(row["tag_len"]), unhex(row["msg_id"]),
                int(row["kind"]), unhex(row["ad"]), int(row["clear_len"]), unhex(row["body"]), _dirs(row), prev,
                window, _int(row, "counter"), _int(row, "out_len"))
            out["result"], out["slot"], out["plain"] = "Ok", slot, hx(plain)
            if after is not None:
                out["window_after"] = after
        elif op == "mac":
            key, epoch, label = unhex(row["key"]), int(row["epoch"]), unhex(row["label"])
            parts = [unhex(p) for p in row["parts"].split("|")] if "parts" in row else [unhex(row["message"])]
            if "verify" in row:
                tag = unhex(row["verify"])
                out["valid"] = "true" if ff.mac_verify(key, epoch, label, parts, tag) else "false"
            else:
                out["tag"] = ff.mac_tag(key, epoch, label, int(row["n"]), parts).hex()
        elif op == "replay":
            window, results, states = ff.Window(), [], []
            for step in row["steps"].split(","):
                action, _, number = step.partition(":")
                if action == "check":
                    results.append(window.check(int(number)))
                else:
                    window.commit(int(number))
                    states.append(window.text())
            out["results"], out["states"] = ",".join(results), ",".join(states) if states else "-"
        else:
            raise ValueError("unknown op " + op)
    except ff.Fault as fault:
        out = {"result": fault.kind}
        if op == "open" and "window" in row:
            out["window_after"] = row["window"]
    return out
