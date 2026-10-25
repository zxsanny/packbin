#!/usr/bin/env python3
"""Re-derives every row of fixtures/frame/vectors.txt with the reference (framefmt.py) and checks the coverage list
of PB-03. Exit 1 names the failing row. Python 3.9+, standard library only."""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import coverage as cov  # noqa: E402
import rows  # noqa: E402

DEFAULT = os.path.join(HERE, "..", "..", "fixtures", "frame", "vectors.txt")

# The published worked examples of the contract (computed by meshbell with an independent implementation).
KNOWN = {
    "E1.keys": {"k_enc": "2a26f46689797b89a46c24bb1d7d31876ffd6fe68f86b04bb32a1c62061437ce",
                "k_mac": "8147b3e3c2a5feed9cd4a5167169c48a1fc898e03b9cfa48e4144efd6a5601e3"},
    "E1.seal": {"body": "53e9dc75fb459d775e6205661cdf37ff"},
    "E2.keys": {"k_enc": "f421aaa83c48b853e9977379c0958c58f83e2fc72d590a57b1a8910b6802a93e",
                "k_mac": "7f16afe6559313e8a883f384de44370e1b223a6de2a2252427f8da5833236063"},
    "E2.seal": {"body": "7f711291e9a9ebb93760ac8b851f2a29c46a3b70f6a447b62ddbc159ddfba687109cc6d02d5e509bb9bd00b7da70"},
    "E3.keys": {"k_enc": "0a26995c011a4e87d1a327986b6b086202045544d3ab0a8fbcd681be1286bb05",
                "k_mac": "190bb28d43cdff7805ef628706256badfec84c30fd15f4e426b048768a8431aa"},
    "E3.seal": {"body": "a1b2c34f51e601a79e78a25a9bf5bb74206019f1d769783cbc82b7"},
    "E3.seal16": {"body": "a1b2c34f51e601a79e78a25a9bf5bb74206019f1d769783cbc82b7c519c38115025b8cd5b5f82b"},
    "E4.keys": {"k_label": "dc5966ac393a983cec3f48ee16233b4b06b468d720732abdd8e91ae116bd4a93"},
    "E4.mac": {"tag": "56db9bec"},
    "E5.keys": {"k_label": "8faf8eec4c65f8c69dcfb879368d4b6e47580569fb93d175a60fdc351752af80"},
    "E5.mac": {"tag": "3cf8e8c5"},
}


def load(path):
    parsed = []
    with open(path) as handle:
        for number, line in enumerate(handle, 1):
            if line.strip() and not line.startswith("#"):
                parsed.append((number, rows.parse(line)))
    return parsed


def check(path):
    problems = []
    parsed = load(path)
    seen = {}
    for number, row in parsed:
        case, op = row.get("case"), row.get("op")
        if case is None or op not in rows.OUTPUTS:
            problems.append("line %d: row without case or with an unknown op" % number)
            continue
        if case in seen:
            problems.append("line %d: duplicate case %s" % (number, case))
        seen[case] = row
        stored = {k: v for k, v in row.items() if k in rows.OUTPUTS[op]}
        derived = rows.run(dict(rows.inputs(row), op=op, case=case))
        if stored != derived:
            problems.append("FAIL line %d %s %s: stored %s, derived %s" % (number, op, case, stored, derived))
    for case, op in cov.required():
        if case not in seen:
            problems.append("coverage: missing case %s" % case)
        elif seen[case]["op"] != op:
            problems.append("coverage: case %s is %s, expected %s" % (case, seen[case]["op"], op))
    for case, want in KNOWN.items():
        row = seen.get(case)
        if row is not None:
            for name, value in want.items():
                if row.get(name) != value:
                    problems.append("FAIL known answer %s %s: file %s, contract %s" % (case, name, row.get(name), value))
    seq = seen.get("replay.seq17")
    if seq is not None and seq.get("results", "").split(",") != list(cov.REPLAY_EXPECTED):
        problems.append("FAIL replay.seq17: results differ from the PB-03 table")
    kinds = {(r["op"], r.get("result")) for r in seen.values()}
    for need in (("seal", "BadValue"), ("seal", "TooLong"), ("seal", "BufferFull"), ("open", "ShortPacket"),
                 ("open", "BufferFull"), ("open", "TagMismatch"), ("open", "Duplicate"), ("open", "TooOld"),
                 ("open", "Ok"), ("open", "BadValue"), ("mac", "BadValue")):
        if need not in kinds:
            problems.append("coverage: no row gives %s %s" % need)
    return problems, len(parsed)


def main():
    path = sys.argv[1] if len(sys.argv) > 1 else DEFAULT
    problems, count = check(path)
    for problem in problems:
        print(problem)
    if problems:
        sys.exit(1)
    print("frame vectors ok: %d rows, coverage complete" % count)


if __name__ == "__main__":
    main()
