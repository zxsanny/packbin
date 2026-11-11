import sys
from packbin import BinaryPacker, Scheme, dict as map_field, u8, utf8

DS = Scheme(1, dict, map_field(lambda r: r["d"], u8(0, lambda r: r["v"])))
SS = Scheme(1, dict, utf8(0, lambda r: r["s"]))

def attempt(label, scheme, row, readback):
    try:
        pk = BinaryPacker.pack(scheme, row)
    except Exception as e:
        print(f"{label}: PACK RAISED {type(e).__module__}.{type(e).__name__}: {e!s}"); return
    print(f"{label}: PACK OK {pk.hex()}")
    res = BinaryPacker.unpack(pk, scheme.on(lambda row: None))
    if res.ok:
        print(f"   UNPACK OK {readback(res.value)!a}")
    else:
        print(f"   UNPACK ERR {res.error!r}")

dk = lambda v: list(v["d"].items())
attempt("A d800+dc00", DS, {"d": {"\ud800": 1, "\udc00": 2}}, dk)
attempt("B fffd+d800", DS, {"d": {"�": 1, "\ud800": 2}}, dk)
attempt("C d800", DS, {"d": {"\ud800": 1}}, dk)
attempt("D text d800", SS, {"s": "\ud800"}, lambda v: v["s"])
# controls
attempt("ctl fffd alone", DS, {"d": {"�": 1}}, dk)
