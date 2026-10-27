"""Replays the rows of `fixtures/frame/vectors.txt` through the public API (contract pack-session 3.0.0, frame mode).

A row's input fields build the call and every output field of the row is compared with what the call gave (the row syntax is
in `fixtures/frame/README.md`)."""

from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path

from packbin import (
    BadValue,
    BufferFull,
    Duplicate,
    FrameConfig,
    FrameDirections,
    FrameOpened,
    FrameSession,
    MacKey,
    MsgContext,
    ReplayWindow,
    ShortPacket,
    TagMismatch,
    TooLong,
    TooOld,
)

FIXTURE = Path(__file__).resolve().parents[2] / "fixtures" / "frame" / "vectors.txt"
SENTINEL = 0xA5
KINDS = {
    BadValue: "BadValue",
    TooLong: "TooLong",
    BufferFull: "BufferFull",
    ShortPacket: "ShortPacket",
    TagMismatch: "TagMismatch",
    Duplicate: "Duplicate",
    TooOld: "TooOld",
}
OUTPUTS = {
    "keys": ("k_enc", "k_mac", "k_label"),
    "seal": ("body", "result"),
    "open": ("result", "slot", "plain", "window_after"),
    "mac": ("tag", "valid", "result"),
    "replay": ("results", "states"),
}


@dataclass(frozen=True)
class Row:
    fields: dict[str, str]

    @property
    def op(self) -> str:
        return self.fields["op"]

    @property
    def case(self) -> str:
        return self.fields["case"]

    def __getitem__(self, name: str) -> str:
        return self.fields[name]

    def has(self, name: str) -> bool:
        return name in self.fields

    def number(self, name: str) -> int:
        return int(self.fields[name])

    def data(self, name: str) -> bytes:
        return hex_bytes(self.fields[name])


def hex_bytes(text: str) -> bytes:
    return b"" if text == "-" else bytes.fromhex(text)


def unhex(data: bytes | bytearray) -> str:
    return bytes(data).hex() if len(data) else "-"


def load(path: Path = FIXTURE) -> list[Row]:
    rows = []
    for line in path.read_text().splitlines():
        if not line or line.startswith("#"):
            continue
        rows.append(Row(dict(token.split("=", 1) for token in line.split(" "))))
    return rows


def kind_name(result: object) -> str:
    if isinstance(result, (FrameOpened, int)):
        return "Ok"
    return KINDS.get(type(result), "other:" + type(result).__name__)


def directions(row: Row) -> FrameDirections:
    chosen = FrameDirections.NONE
    for c in row["dirs"] if row.has("dirs") else "123":
        chosen |= FrameDirections(1 << (int(c) - 1))
    return chosen


def load_session(row: Row) -> FrameSession | BadValue:
    return FrameSession.load(row.data("key"), row.number("epoch"), FrameConfig(row.number("tag_len") if row.has("tag_len") else 4, directions(row)))


def context(row: Row) -> MsgContext:
    return MsgContext(row.data("msg_id"), row.number("kind"))


def window_text(window: ReplayWindow) -> str:
    return f"{window.top:x}:{window.bits:x}"


def run(row: Row) -> dict[str, str]:
    """The output fields the call gave for the row; a row with an error result gives `result` only."""
    return {"keys": _keys, "seal": _seal, "open": _open, "mac": _mac, "replay": _replay}[row.op](row)


def mismatches(rows: list[Row]) -> list[str]:
    """Every mismatch of every row, as `case field: expected X, got Y`."""
    problems = []
    for row in rows:
        got = run(row)
        for name in OUTPUTS[row.op]:
            if not row.has(name):
                continue
            if name not in got:
                problems.append(f"{row.case} {name}: the row has it and the call gave none")
            elif got[name] != row[name]:
                problems.append(f"{row.case} {name}: expected {row[name]}, got {got[name]}")
    return problems


def _keys(row: Row) -> dict[str, str]:
    epoch = row.number("epoch")
    if row.has("label"):
        mac = MacKey.derive(row.data("key"), epoch, row.data("label"))
        return {"k_label": "BadValue" if isinstance(mac, BadValue) else unhex(mac._key)}
    direction = row.number("dir")
    session = FrameSession.load(row.data("key"), epoch, FrameConfig(4, FrameDirections(1 << (direction - 1))))
    if isinstance(session, BadValue):
        return {"k_enc": "BadValue", "k_mac": "BadValue"}
    return {"k_enc": unhex(session._current.enc(direction)), "k_mac": unhex(session._current.mac(direction))}


def _seal(row: Row) -> dict[str, str]:
    session = load_session(row)
    if isinstance(session, BadValue):
        return {"result": "BadValue"}
    buffer = bytearray([SENTINEL]) * (row.number("out_len") if row.has("out_len") else 300)
    result = session.seal(row.number("dir"), context(row), row.data("ad"), row.data("clear"), row.data("plain"), buffer)
    if not isinstance(result, int):
        touched = any(b != SENTINEL for b in buffer)
        return {"result": kind_name(result) + (" (a refused seal wrote bytes)" if touched else "")}
    return {"body": unhex(buffer[:result])}


def _open(row: Row) -> dict[str, str]:
    window = None
    if row.has("window"):
        top, bits = row["window"].split(":")
        window = ReplayWindow(int(top, 16), int(bits, 16))
    before = window_text(window) if window else None
    session = load_session(row)
    if not isinstance(session, BadValue) and row.has("prev_key") and not session.set_previous(row.data("prev_key"), row.number("prev_epoch")):
        session = BadValue("previous key")
    got: dict[str, str] = {}
    if isinstance(session, BadValue):
        got["result"] = "BadValue"
    else:
        with session:
            buffer = bytearray([SENTINEL]) * (row.number("out_len") if row.has("out_len") else 300)
            counter = row.number("counter") if row.has("counter") else 0
            result = session.open(row.number("dir"), context(row), row.data("ad"), row.data("body"), row.number("clear_len"), buffer, window, counter)
            got["result"] = kind_name(result)
            if isinstance(result, FrameOpened):
                got["slot"] = result.slot.value
                got["plain"] = unhex(buffer[: result.plain_length])
            else:
                if any(b != SENTINEL for b in buffer):
                    got["result"] += " (a refused open wrote bytes)"
                if window is not None and window_text(window) != before:
                    got["result"] += " (a refused open changed the window)"
    if window is not None:
        got["window_after"] = window_text(window)
    return got


def _mac(row: Row) -> dict[str, str]:
    mac = MacKey.derive(row.data("key"), row.number("epoch"), row.data("label"))
    if isinstance(mac, BadValue):
        return {"result": "BadValue"}
    with mac:
        parts = [hex_bytes(p) for p in row["parts"].split("|")] if row.has("parts") else [row.data("message")]
        if row.has("verify"):
            return {"valid": "true" if mac.verify(parts, row.data("verify")) else "false"}
        tag = mac.tag(parts, row.number("n"))
        return {"result": kind_name(tag)} if isinstance(tag, BadValue) else {"tag": unhex(tag)}


def _replay(row: Row) -> dict[str, str]:
    window = ReplayWindow()
    results, states = [], []
    for step in row["steps"].split(","):
        name, number = step.split(":")
        if name == "check":
            results.append(window.check(int(number)).value)
        else:
            window.commit(int(number))
            states.append(window_text(window))
    return {"results": ",".join(results), "states": ",".join(states) if states else "-"}

