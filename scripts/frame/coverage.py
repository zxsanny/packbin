"""The coverage list of fixtures/frame/vectors.txt (PB-03): the case names the file must hold, and the tables the
generator builds them from. One source for gen_vectors.py and check_vectors.py."""

EPOCHS = (0, 1, 7, 0xFFFF, 0xFFFFFF)
PLAIN_LENS = (0, 1, 12, 42, 63, 64, 65, 128, 192, 236, 251)
CLEAR_LENS = (0, 3, 40)
AD_LENS = (0, 11, 255)
TAG_LENS = (4, 8, 16)
BAD_TAG_LENS = (0, 5, 32)
MSG_LENS = (0, 5, 55, 56, 63, 64, 119, 120, 255)
MAC_NS = (4, 8, 16, 32)
BAD_MAC_NS = (0, 2, 5)
EXAMPLES = ("E1", "E2", "E3")
TAMPER_ALL = ("ad_first", "ad_last", "ct_first", "ct_last", "tag_first", "tag_last", "msgid", "kind", "dir",
              "epoch", "key", "clearlen_up")
TAMPER_E3 = ("clear_first", "clear_last", "clearlen_down")
REFUSALS = ("epoch1000000", "dir0", "dir4", "kind16", "unloaded", "tag0", "tag5", "tag32", "ad256", "body256",
            "outshort")
OPEN_REFUSALS = ("kind16", "unloaded", "short", "buffer")
REPLAY_SEQUENCE = ("check:100", "commit:100", "check:100", "check:99", "commit:99", "check:37", "commit:37",
                   "check:36", "check:37", "check:163", "commit:163", "check:100", "check:99", "check:200",
                   "commit:200", "check:163", "check:100")
# the results of the 12 checks of the sequence, as the PB-03 table gives them (steps 1, 3, 4, 6, 8, 9, 10, 12, 13, 14, 16, 17)
REPLAY_EXPECTED = ("Fresh", "Duplicate", "Fresh", "Fresh", "TooOld", "Duplicate", "Fresh", "Duplicate", "TooOld",
                   "Fresh", "Duplicate", "TooOld")


def tamper_names():
    names = []
    for base in EXAMPLES:
        for variant in TAMPER_ALL + (TAMPER_E3 if base == "E3" else ()):
            names.append("tamper.%s.%s" % (base, variant))
    return names


def required():
    """(case, op) pairs the file must contain."""
    need = []
    for base in ("E1", "E2", "E3"):
        need += [("%s.keys" % base, "keys"), ("%s.seal" % base, "seal"), ("%s.open" % base, "open")]
    need += [("E3.seal16", "seal"), ("E3.open16", "open"), ("E4.keys", "keys"), ("E4.mac", "mac"),
             ("E5.keys", "keys"), ("E5.mac", "mac")]
    for d in (1, 2, 3):
        for e in EPOCHS:
            need.append(("keys.d%d.e%x" % (d, e), "keys"))
    need += [("refuse.seal.%s" % r, "seal") for r in REFUSALS]
    need += [("refuse.open.%s" % r, "open") for r in OPEN_REFUSALS]
    need += [("len.plain%d" % n, "seal") for n in PLAIN_LENS]
    need += [("len.clear%d" % n, "seal") for n in CLEAR_LENS]
    need += [("len.ad%d" % n, "seal") for n in AD_LENS]
    need += [("tag.t%d" % t, "seal") for t in TAG_LENS]
    need += [(n, "open") for n in tamper_names()]
    need += [("prev.ok_previous", "open"), ("prev.no_slot", "open"), ("prev.ok_current", "open")]
    need += [("replay.seq17", "replay"), ("replay.empty0", "replay"), ("replay.max64", "replay")]
    need += [("openwin.duplicate", "open"), ("openwin.tampered", "open"), ("openwin.fresh", "open"),
             ("openwin.tooold", "open")]
    need += [("mac.label1", "mac"), ("mac.label32", "mac"), ("mac.label0", "mac"), ("mac.label33", "mac")]
    need += [("mac.n%d" % n, "mac") for n in MAC_NS] + [("mac.nbad%d" % n, "mac") for n in BAD_MAC_NS]
    for n in MSG_LENS:
        need += [("mac.len%d.parts%d" % (n, p), "mac") for p in (1, 2, 3)]
    need += [("mac.verify_ok", "mac"), ("mac.verify_flip", "mac")]
    return need
