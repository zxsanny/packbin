import traceback
from packbin import BinaryPacker, Scheme, dict as map_field, u8, utf8
DS = Scheme(1, dict, map_field(lambda r: r["d"], u8(0, lambda r: r["v"])))
SS = Scheme(1, dict, utf8(0, lambda r: r["s"]))
for s, r in ((DS, {"d": {"\ud800": 1}}), (DS, {"d": {"\ud800": 1, "\udc00": 2}}), (SS, {"s": "\ud800"})):
    try: BinaryPacker.pack(s, r)
    except Exception: print(traceback.format_exc().splitlines()[-4:-1]); 
