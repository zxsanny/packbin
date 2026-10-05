# packbin
Binary packing and unpacking across languages with an optional encryption, declarative mapping, and zero overhead in the binary data.

Both sides keep the same field list. The bytes are only the values. Unpack takes the buffer and handlers. The first byte selects the handler, and that handler's scheme reads the rest.

Can be used for WebSocket, TCP, UDP, and other means of efficient communication

Encryption is optional. `PackSession` hides the packed bytes on one connection and adds 0 bytes to each packet. The only extra send is 16 bytes, once, when the connection opens. It does not detect a changed byte, and anyone holding the 32-byte seed can read every session. See [Encrypted session](#encrypted-session).

## Example

Python → binary → TypeScript

### Python

```python
from packbin import BinaryPacker, Scheme, flags, i16, i32, u8, u16, utf8

class Position:
    def __init__(self):
        self.sid = 1
        self.lat = 500_000_000
        self.lon = 300_000_000
        self.profile = 1
        self.heading = None
        self.speed = None
        self.altitude = None

target = Scheme(
    0x40,
    Position,
    u16(0, lambda row: row.sid),
    i32(1, lambda row: row.lat),
    i32(2, lambda row: row.lon),
    u8(3, lambda row: row.profile),
    flags(
        4,
        u16(4, lambda row: row.heading),
        u8(5, lambda row: row.speed),
        i16(6, lambda row: row.altitude),
    ),
)

raw = BinaryPacker.pack(target, Position())

class Ping:
    def __init__(self):
        self.code = 0

class Note:
    def __init__(self):
        self.id = 0
        self.title = ""

ping = Scheme(2, Ping, u8(0, lambda row: row.code))
note = Scheme(3, Note, u16(0, lambda row: row.id), utf8(1, lambda row: row.title))

got = []
pinged = []
noted = []
BinaryPacker.unpack(raw, target.on(got.append), ping.on(pinged.append), note.on(noted.append))
```

```
40 01 00 00 65 cd 1d 00 a3 e1 11 01 00
```

### TypeScript

```ts
import { BinaryPacker, flags, i16, i32, scheme, u8, u16, utf8 } from "packbin"

class Target {
  sid = 1
  lat = 500_000_000
  lon = 300_000_000
  profile = 1
  heading: number | null = null
  speed: number | null = null
  altitude: number | null = null
}

const target = scheme<Target>(
  0x40,
  u16(0, (x) => x.sid),
  i32(1, (x) => x.lat),
  i32(2, (x) => x.lon),
  u8(3, (x) => x.profile),
  flags(4, [
    u16(4, (x) => x.heading),
    u8(5, (x) => x.speed),
    i16(6, (x) => x.altitude),
  ]),
)

class Ping {
  code = 0
}

class Note {
  id = 0
  title = ""
}

const ping = scheme<Ping>(2, u8(0, (x) => x.code))
const note = scheme<Note>(3, u16(0, (x) => x.id), utf8(1, (x) => x.title))

let got: Target | undefined
let pinged: Ping | undefined
let noted: Note | undefined
BinaryPacker.unpack(
  raw,
  target.on((row) => {
    got = row
  }),
  ping.on((row) => {
    pinged = row
  }),
  note.on((row) => {
    noted = row
  }),
)
```

`flags` is how an optional field takes no space when you have no value for it. `heading`, `speed`, and `altitude` are measurements, so `0` is still a value and has to be written. `None` means the field is not in the packet.

`motion` is always one byte in front of those fields. Bit 0 is `heading`, bit 1 is `speed`, bit 2 is `altitude`. A set bit writes that field next. A clear bit skips it.

| Field | Type | Bytes when present | Values |
|---|---|---|---|
| `heading` | `u16` | 2 | 0 … 65535 |
| `speed` | `u8` | 1 | 0 … 255 |
| `altitude` | `i16` | 2 | −32768 … 32767 |

In this example all three are `None`, so `motion` is `00` and those 5 bytes are absent. The packet is 13 bytes: type number 1, `sid` 2, `lat` 4, `lon` 4, `profile` 1, `motion` 1.

```
40          type
01 00       sid
00 65 cd 1d lat
00 a3 e1 11 lon
01          profile
00          motion
```

`heading = 90` sets bit 0, so `motion` is `01` and `5a 00` follows it. `heading = 0` sets the same bit and writes `00 00`. `speed = 10` sets bit 1 and writes one byte. The present fields are written in the order listed, and only those.

## Example

C# → binary → Rust

### C#

```csharp
using Packbin;

sealed class User
{
    public string Username { get; set; } = "";
    public List<Role> Roles { get; set; } = [];
    public Dictionary<string, ActionList> Access { get; set; } = [];
}

sealed class Role { public string RoleName { get; set; } = ""; }
sealed class ActionName { public string Action { get; set; } = ""; }
sealed class ActionList { public List<ActionName> Actions { get; set; } = []; }

var userScheme = new Scheme<User>(1, f => [
    f.Utf8(0, x => x.Username),
    f.List(x => x.Roles, r => r.Utf8(0, role => role.RoleName)),
    f.Dict(x => x.Access, e => e.List(a => a.Actions, n => n.Utf8(0, action => action.Action)))]);

var raw = BinaryPacker.Pack(userScheme, new User
{
    Username = "ada",
    Roles = [new Role { RoleName = "user" }, new Role { RoleName = "admin" }],
    Access = new()
    {
        ["map"] = new ActionList { Actions = [new ActionName { Action = "read" }, new ActionName { Action = "edit" }] },
        ["store"] = new ActionList { Actions = [new ActionName { Action = "write" }] },
    },
});

sealed class Ping { public byte Code { get; set; } }
sealed class Note
{
    public ushort Id { get; set; }
    public string Title { get; set; } = "";
}

var ping = new Scheme<Ping>(2, f => [f.U8(0, x => x.Code)]);
var note = new Scheme<Note>(3, f => [f.U16(0, x => x.Id), f.Utf8(1, x => x.Title)]);

User? got = null;
Ping? pinged = null;
Note? noted = null;
BinaryPacker.Unpack(
    raw,
    userScheme.On(row => got = row),
    ping.On(row => pinged = row),
    note.On(row => noted = row));
```

```
01 03 00 61 64 61 02 00 04 00 75 73 65 72 05 00 61 64 6d 69 6e
02 00 03 00 6d 61 70 02 00 04 00 72 65 61 64 04 00 65 64 69 74
05 00 73 74 6f 72 65 01 00 05 00 77 72 69 74 65
```

The first byte is the scheme type number.

### Rust

```rust
use packbin::{BinaryPacker, BoundField, Scheme};
use std::collections::BTreeMap;

#[derive(Default)]
struct User {
    username: String,
    roles: Vec<String>,
    access: BTreeMap<String, Vec<String>>,
}

let user = Scheme::new(1, [
    BoundField::utf8(
        0,
        |row: &User| row.username.clone(),
        |row, value| row.username = value,
    )
    .into(),
    BoundField::list_utf8(
        |row: &User| row.roles.clone(),
        |row, value| row.roles = value,
    )
    .into(),
    BoundField::dict_list_utf8(
        |row: &User| row.access.clone(),
        |row, value| row.access = value,
    )
    .into(),
]);

#[derive(Default)]
struct Ping {
    code: u8,
}

#[derive(Default)]
struct Note {
    id: u16,
    title: String,
}

let ping = Scheme::new(2, [
    BoundField::u8(0, |row: &Ping| row.code, |row, value| row.code = value).into(),
]);

let note = Scheme::new(3, [
    BoundField::u16(0, |row: &Note| row.id, |row, value| row.id = value).into(),
    BoundField::utf8(1, |row: &Note| row.title.clone(), |row, value| row.title = value).into(),
]);

let mut got = User::default();
let mut ping_row = Ping::default();
let mut note_row = Note::default();
BinaryPacker::unpack_with(
    &raw,
    &mut [
        &mut user.on(|row| got = row),
        &mut ping.on(|row| ping_row = row),
        &mut note.on(|row| note_row = row),
    ],
)
.unwrap();
```

Schemes built from field lists (`MapScheme`) pack and unpack values keyed by field name with `packbin::pack(&scheme, &values)` and `packbin::unpack(&scheme, &bytes)`. That is the Rust path for the split flag-byte form, which the typed `Scheme` does not have yet.

### C++

The C++ package packs into a buffer you own and reads from one. It throws nothing and allocates nothing, so the same code builds for a server and for a microcontroller (`-fno-exceptions -fno-rtti`). Strings and lists land in caller storage: `View` borrows bytes from the input buffer, `Text<N>` and `Array<T, N>` hold up to N, and more than N is the error `TooMany`, never a cut.

```cpp
#include <packbin/packbin.hpp>

using namespace packbin;

using Actions = Array<View, 8>;

struct User {
    View username;
    Array<View, 8> roles;
    Array<Entry<Actions>, 8> access;  // keys in unsigned byte order
};

struct Ping { std::uint8_t code = 0; };
struct Note { std::uint16_t id = 0; Text<32> title; };

constexpr auto user = scheme<User>(1,
    utf8<&User::username>(0),
    list<&User::roles>(utf8(0)),
    dict<&User::access>(list(utf8(0))));
constexpr auto ping = scheme<Ping>(2, u8<&Ping::code>(0));
constexpr auto note = scheme<Note>(3, u16<&Note::id>(0), utf8<&Note::title>(1));

User row;  // fill it like the C# example: "ada", two roles, map and store
std::uint8_t buf[128];
Result packed = pack(user, row, buf, sizeof(buf));  // packed.offset is the packet length

User got;
Ping pinged;
Note noted;
Result r = unpack(buf, packed.offset,
    on(user, got, [](User const& u) { /* ... */ }),
    on(ping, pinged, [](Ping const& p) { /* ... */ }),
    on(note, noted, [](Note const& n) { /* ... */ }));
```

The first byte picks the scheme; its handler runs only after the whole packet reads. A failure is a value: `r.error` is one of `ShortPacket`, `TrailingBytes`, `TypeMismatch`, `BufferFull`, `TooMany`, `BadValue`, `SchemeInvalid`, with `r.offset` (the byte) and `r.field` (the order id). A `constexpr` scheme with a gap, a repeated id or a wrong anchor does not compile, and the compiler names the id; a scheme built at run time reports it through `validate(scheme)`. A member that may be absent is `Opt<T>`.

#### Microcontrollers

The same package builds for 32-bit microcontrollers — Cortex-M0+/M3/M4/M33, ESP32, RP2040, nRF52, STM32 — with `-std=c++17 -fno-exceptions -fno-rtti`. It references no `malloc`, no `operator new` and no exception runtime, keeps no global state, and the scheme tables live in flash.

| Tool | Add packbin |
|------|-------------|
| PlatformIO | `lib_deps = zxsanny/packbin` and `build_src_flags = -std=gnu++17` in `platformio.ini` |
| Arduino IDE / arduino-cli | Library Manager: `packbin`, then `#include <packbin.h>` |
| ESP-IDF ≥ 5.1 | `idf.py add-dependency "zxsanny/packbin"` |
| CMake / vcpkg (host) | vcpkg port `packbin`, or `add_subdirectory(cpp)` → target `packbin` |

Examples: [`cpp/examples/pico`](cpp/examples/pico) (PlatformIO, Raspberry Pi Pico), [`cpp/examples/esp32_arduino`](cpp/examples/esp32_arduino) (Arduino-ESP32), [`cpp/examples/esp_idf`](cpp/examples/esp_idf) (ESP-IDF with the hardware RNG).

`PackSession::start` takes the board's random source as a `RandomFn` (`bool(std::uint8_t* out, std::size_t n, void* ctx)`): `esp_fill_random` on ESP32, the RNG peripheral on STM32 or nRF52. When it returns false, no session opens. Host programs pass `packbin::os_random`. `f64` needs an 8-byte `double`; where `double` is 4 bytes (avr-gcc), a scheme with `f64` does not compile.

Moving from 0.1.x — the C++ API changed; the bytes did not:

| 0.1.x | Now |
|-------|-----|
| `BinaryPacker::pack(scheme, row)` → `std::vector` | `pack(scheme, row, out, cap)` → `Result` (`offset` = length) |
| `BinaryPacker::unpack(bytes, scheme.on(handler)...)` | `unpack(data, len, on(scheme, row, handler)...)`, or `unpack(scheme, data, len, row)` |
| `Scheme<T>(type, ...)`, `scheme(type, {...})`, `SchemeHandler` | `constexpr auto s = scheme<T>(type, ...)`; `on(s, row, handler)` |
| `Value`, `Values`, `ValueList`, `ValueMap` (map rows) | struct rows with `Opt<T>`, `View`, `Text<N>`, `Blob<N>`, `Array<T, N>`, `Entry<V>` members |
| `u16(0, &T::m)`, `bind_scalar`, `bind_optional`, `bind_accessors`, `BoundField<T>` | `u16<&T::m>(0)` (member binding only; no getter/setter) |
| `std::optional<T>` / `std::string` / `std::vector<T>` members | `Opt<T>` / `View` or `Text<N>` / `Array<T, N>` |
| `flags(id, {a, b})`, `when(id, eq, {a})`, `repeat(id, {a})`, `times(id, n, {a})`, `group(id, {a})` | the same without braces: `flags(id, a, b)` …; `repeat` and `times` bind an `Array<E, N>` member: `repeat<&T::m>(id, ...)` |
| `group(id, "name", {})` | `group<&T::flag>(id)` on a `bool` member |
| `flag_byte()`, `Field::bit(field)` | `flag_byte(n)`, `flag_bit(n, field)` with n = 0..7 |
| `list("name", element)`, `dict("name", element)` | `list<&T::m>(element)`, `dict<&T::m>(element)` |
| `u2({0, 1})`, `sized(id, n)`, `bits(id, n)`, `packed(w, id, n, bias)` | `u2(u8<&T::a>(0), u8<&T::b>(1))`, `sized<&T::m>(id, n)`, `bits<&T::m>(id, n)`, `packed<&T::m>(w, id, n, bias)` |
| `bytes(id, n)` with `std::vector<std::uint8_t>` | `bytes<&T::m>(id)` on `std::uint8_t[n]`, or `bytes<&T::m>(id, n)` on a `View` |
| `eq(id, Value{...})` | `eq(id, number)` |
| `UnpackResult`, `ShortPacket`, `TrailingBytes`, `TypeMismatch`, `std::runtime_error` | `Result` and `Error` |
| `validate_order(fields)` | `validate(scheme)`, or a compile error for a `constexpr` scheme |
| `to_hex`, `mismatched_bytes`, `present`, `motion_field_count`, `id_name`, `pack_body`, `unpack_body`, `Field` | removed |
| `PackSession::load(seed)` → `std::optional` | `PackSession s; s.load(seed, 32)` → `bool` |
| `start()`, `start(nonce)`, `join(nonce)` | `start(os_random, nullptr, nonce_out)` (or your `RandomFn`), `start(nonce, 16)`, `join(nonce, 16)` |
| `session.pack(scheme, row)` → `std::optional<std::vector>` | `session.pack(scheme, row, out, cap)` → `Result` |
| `session.unpack(bytes, handlers...)` | `session.unpack(data, len, ...)`; removes the pad in place |

Two kinds of scheme fail construction (`SchemeInvalid`, or a compile error for a `constexpr` scheme), because neither can round-trip: a `boolean` or an empty `group` anywhere except directly under `flags(...)` or `flag_bit(...)`, and a `u2` with more than 64 children. The wire bytes of every valid scheme are unchanged.

## Encrypted session

One optional session beside clear pack. Load a 32-byte seed on each side. The opener calls start and sends those 16 bytes once. The waiter calls join with them. After that, pack and unpack use the same schemes as clear pack, and the payload stays the same length. A second client is a second session.

The keys come from HKDF-SHA256 over the seed and the 16 bytes, one key per direction. Each packet is XORed with a ChaCha20 stream at the next counter. The counter is not sent, so the connection must deliver packets in order and drop none. Nothing checks that a byte was changed on the way. The seed never leaves the process. Replace it with a software update.

### C#

```csharp
using Packbin;

byte[] seed = /* 32 bytes shared out of band */;

var opener = PackSession.Load(seed)!;
byte[] nonce = opener.Start()!;

var waiter = PackSession.Load(seed)!;
waiter.Join(nonce);

sealed class Ping { public byte Code { get; set; } }
var ping = new Scheme<Ping>(2, f => [f.U8(0, x => x.Code)]);

var payload = opener.Pack(ping, new Ping { Code = 7 })!;

Ping? got = null;
waiter.Unpack(payload, ping.On(row => got = row));
```

The 16 bytes leave once. There is no second handshake on that connection.

### WebSocket: Vue client, C# server

The browser opens the socket, so it is the opener. Its first message is the 16 bytes. The server treats the first message on every socket as those bytes and keeps one session per socket. Every later message in either direction is one packed packet, encrypted.

Both sides share the schemes:

| Type | Scheme | Direction |
|------|--------|-----------|
| `0x40` | position: `sid` u16, `lat` i32, `lon` i32, `profile` u8 | client → server |
| `0x41` | ack: `sid` u16, `accepted` u8 | server → client |

#### Server — ASP.NET Core

```csharp
using System.Net.WebSockets;
using Packbin;

var builder = WebApplication.CreateBuilder(args);
var app = builder.Build();

byte[] seed = Convert.FromHexString(builder.Configuration["Packbin:Seed"]!); // 32 bytes
var position = new Scheme<Position>(0x40, f => [
    f.U16(0, x => x.Sid),
    f.I32(1, x => x.Lat),
    f.I32(2, x => x.Lon),
    f.U8(3, x => x.Profile)]);
var ack = new Scheme<Ack>(0x41, f => [
    f.U16(0, x => x.Sid),
    f.U8(1, x => x.Accepted)]);

app.UseWebSockets();
app.Map("/ws", async context =>
{
    if (!context.WebSockets.IsWebSocketRequest)
    {
        context.Response.StatusCode = StatusCodes.Status400BadRequest;
        return;
    }

    using var socket = await context.WebSockets.AcceptWebSocketAsync();
    var ct = context.RequestAborted;
    var session = PackSession.Load(seed)!;

    var nonce = await ReceiveAsync(socket, ct);
    if (nonce is null || !session.Join(nonce))
    {
        await socket.CloseAsync(WebSocketCloseStatus.PolicyViolation, "handshake", ct);
        return;
    }

    while (await ReceiveAsync(socket, ct) is { } packet)
    {
        Position? got = null;
        var err = session.Unpack(packet, position.On(row => got = row));
        if (err is not null || got is null)
        {
            await socket.CloseAsync(WebSocketCloseStatus.InvalidPayloadData, "packet", ct);
            return;
        }

        var reply = session.Pack(ack, new Ack { Sid = got.Sid, Accepted = 1 })!;
        await socket.SendAsync(reply, WebSocketMessageType.Binary, true, ct);
    }
});

app.Run();

static async Task<byte[]?> ReceiveAsync(WebSocket socket, CancellationToken ct)
{
    var buffer = new byte[4096];
    using var message = new MemoryStream();
    while (true)
    {
        var result = await socket.ReceiveAsync(buffer, ct);
        if (result.MessageType == WebSocketMessageType.Close)
            return null;
        message.Write(buffer, 0, result.Count);
        if (result.EndOfMessage)
            return message.ToArray();
    }
}

sealed class Position
{
    public ushort Sid { get; set; }
    public int Lat { get; set; }
    public int Lon { get; set; }
    public byte Profile { get; set; }
}

sealed class Ack
{
    public ushort Sid { get; set; }
    public byte Accepted { get; set; }
}
```

The `while` loop sends and receives on one task, so the send counter advances once per reply. If several tasks write to the same socket, send through one queue: the packets must leave in the order `Pack` numbered them.

#### Client — Vue 3, TypeScript

`src/live/packets.ts`:

```ts
import { i32, scheme, u16, u8 } from "packbin"

export class Position {
  sid = 0
  lat = 0
  lon = 0
  profile = 0
}

export class Ack {
  sid = 0
  accepted = 0
}

export const position = scheme<Position>(
  0x40,
  u16(0, (x) => x.sid),
  i32(1, (x) => x.lat),
  i32(2, (x) => x.lon),
  u8(3, (x) => x.profile),
)

export const ack = scheme<Ack>(
  0x41,
  u16(0, (x) => x.sid),
  u8(1, (x) => x.accepted),
)
```

`src/live/useLiveSocket.ts`:

```ts
import { onBeforeUnmount, ref } from "vue"
import { PackSession } from "packbin"
import { ack, position, type Ack, type Position } from "./packets"

const seed = Uint8Array.from(
  import.meta.env.VITE_PACKBIN_SEED.match(/../g)!.map((h: string) => parseInt(h, 16)),
)

export function useLiveSocket(url: string) {
  const lastAck = ref<Ack | null>(null)
  const open = ref(false)
  let socket: WebSocket | null = null
  let session: PackSession | null = null
  let retry = 0

  function connect() {
    session = PackSession.load(seed)
    socket = new WebSocket(url)
    socket.binaryType = "arraybuffer"

    socket.onopen = () => {
      socket!.send(session!.start()!)
      open.value = true
    }

    socket.onmessage = (ev: MessageEvent<ArrayBuffer>) => {
      const result = session!.unpack(ev.data, ack.on((row) => (lastAck.value = row)))
      if (!result.ok) socket!.close(4000, "packet")
    }

    socket.onclose = () => {
      open.value = false
      socket = null
      session = null
      retry = window.setTimeout(connect, 1000)
    }
  }

  function sendPosition(row: Position) {
    if (!open.value || !socket || !session) return false
    socket.send(session.pack(position, row)!)
    return true
  }

  connect()
  onBeforeUnmount(() => {
    window.clearTimeout(retry)
    if (socket) {
      socket.onclose = null
      socket.close()
    }
  })

  return { open, lastAck, sendPosition }
}
```

`src/components/LivePosition.vue`:

```vue
<script setup lang="ts">
import { useLiveSocket } from "../live/useLiveSocket"

const { open, lastAck, sendPosition } = useLiveSocket(
  `${location.protocol === "https:" ? "wss" : "ws"}://${location.host}/ws`,
)

function send() {
  sendPosition({ sid: 1, lat: 500_000_000, lon: 300_000_000, profile: 1 })
}
</script>

<template>
  <button :disabled="!open" @click="send">Send position</button>
  <p v-if="lastAck">Server accepted sid {{ lastAck.sid }}</p>
</template>
```

Each new socket needs a new session. `connect` loads a fresh one, because `start` and `join` erase the session's copy of the seed and a session opens only once. A reconnect sends new 16 bytes.

What travels for one position:

| Message | Bytes |
|---------|-------|
| Handshake, once per socket | 16 |
| Position, clear pack | 12 |
| Position, encrypted | 12 |
| Ack, encrypted | 4 |

`VITE_PACKBIN_SEED` is compiled into the JavaScript bundle, so anyone who downloads the app can read it. The session hides packets from a network observer. It does not hide them from a person who has the app. Change the seed with a release, and keep the old value on the server until clients have updated.

## Data types

| Helper | What it writes |
|--------|----------------|
| `u8` `u16` `u32` `u64` | unsigned integer, little-endian |
| `i8` `i16` `i32` `i64` | signed integer, little-endian |
| `f32` `f64` | IEEE 754 float |
| `bytes(n)` | exactly `n` raw bytes |
| `be(field)` | that number, big-endian |
| `utf8` | UTF-8 string, `u16` length |
| `list` | `u16` count, then that many elements |
| `dict` | `u16` pair count; keys in unsigned byte order |
| `flags(anchor, fields)` | one `u8`; bit 0 is the first field; a clear bit omits that field; at most 8 fields; the anchor is not written |
| `bool` | a flag bit with no payload; set only for `true`; allowed only directly under `flags` or a flag-byte bit |
| `when(anchor, eq(id, value), fields)` | the group only when an earlier field equals `value`; the anchor is not written |
| `repeat(anchor, fields)` | the group until the buffer ends; no count; the anchor is not written |
| `sized` | raw bytes whose length is an earlier integer |
| `u2` | fixed 2-bit slots, low bits first |
| `bits` | 1-bit list; the count is an earlier integer |
| `packed` | 1-bit or 2-bit list; the count is an earlier integer plus a bias |
| `times(anchor, count, fields)` | the inner fields exactly N times, then the next field; the anchor is not written |

Field numbers are the order in the scheme, starting at 0. They are not written. A gap, a repeated id, or an anchor that is not the next value id fails construction. The anchor is not written, repeat still has no count, and a list, a dict, and a nested group still start at 0. The snippets below are Python. The other languages use the same order and produce the same bytes. The first byte of every packet is the scheme type number.

### Integers

Little-endian. `u16` 1 is `01 00`. `i16` −2 is `fe ff`.

```python
row = Scheme(1, dict, u16(0, lambda row: row["n"]), i16(1, lambda row: row["d"]))
BinaryPacker.pack(row, {"n": 1, "d": -2})
```

```
01 01 00 fe ff
```

`0` is a value and is written. A missing optional field is absence, which only `flags` can express.

### Floats

IEEE 754, little-endian. `f32` 1.5 is `00 00 c0 3f`.

```python
row = Scheme(1, dict, f32(0, lambda row: row["x"]))
BinaryPacker.pack(row, {"x": 1.5})
```

```
01 00 00 c0 3f
```

`f64` is the same layout in eight bytes.

### Fixed bytes

`bytes(n)` writes exactly `n` bytes and no length. `b"abc"` with `n = 3` is the three characters.

```python
row = Scheme(1, dict, bytes(0, lambda row: row["b"], 3))
BinaryPacker.pack(row, {"b": b"abc"})
```

```
01 61 62 63
```

A shorter or longer value is rejected.

### Big-endian

`be` flips one number. The rest of the scheme stays little-endian. `u16` 1 becomes `00 01`.

```python
row = Scheme(1, dict, be(u16(0, lambda row: row["n"])))
BinaryPacker.pack(row, {"n": 1})
```

```
01 00 01
```

### UTF-8

A `u16` byte count, then the UTF-8 bytes. `"zxsanny"` is 7 bytes. An empty string is `00 00`. More than 65535 bytes is rejected.

```python
row = Scheme(1, dict, utf8(0, lambda row: row["name"]))
BinaryPacker.pack(row, {"name": "zxsanny"})
```

```
01 07 00 7a 78 73 61 6e 6e 79
```

### List

A `u16` count, then that many elements. The element is one field, and its id restarts at 0 inside the list. `[1, 2]` of `u16` is count 2, then `01 00`, then `02 00`. An empty list is `00 00` and still leaves the next scheme field readable.

```python
row = Scheme(1, dict, list(lambda row: row["xs"], u16(0, lambda row: row)))
BinaryPacker.pack(row, {"xs": [1, 2]})
```

```
01 02 00 01 00 02 00
```

### Dictionary

A `u16` pair count. Each pair is a UTF-8 key, then one element. Keys are written in unsigned byte order, so insert order does not change the packet. `"a"` then `"b"`:

```python
from packbin import dict as map_field

row = Scheme(1, dict, map_field(lambda row: row["m"], u8(0, lambda row: row)))
BinaryPacker.pack(row, {"m": {"b": 1, "a": 2}})
```

```
01 02 00 01 00 61 02 01 00 62 01
```

`02 00` is two pairs. `01 00 61` is the key `"a"`, then value `02`. `01 00 62` is `"b"`, then value `01`.

### Flags

One byte in front of the fields. Bit 0 is the first field. A set bit writes that field next. A clear bit skips it, so the field takes no space. `0` is still present: it sets the bit and writes a zero. `None` leaves the bit clear.

`heading = 90` sets bit 0 and writes `5a 00`. `speed` is absent, so bit 1 stays clear.

```python
row = Scheme(
    1,
    dict,
    flags(
        0,
        u16(0, lambda row: row["heading"]),
        u8(1, lambda row: row["speed"]),
    ),
)
BinaryPacker.pack(row, {"heading": 90})
```

```
01 01 5a 00
```

`group` gathers several fields under one bit. The bit is set when any of them is present, and those fields are written in order.

### Bool

A `bool` inside `flags` sets its bit and writes nothing after it. Here bit 0 is the bool and bit 1 is a `u8` of 7, so the flags byte is `03` and the only payload is `07`.

The bit is set only for `true`; `false` and a missing value leave it clear, and unpack gives `true` only when the bit is set. A `bool` anywhere except directly under `flags` or a flag-byte bit fails scheme construction, because it has no bit to live in. So does a ninth bit in one flags byte.

```python
row = Scheme(
    1,
    dict,
    flags(
        0,
        bool(0, lambda row: row["on"]),
        u8(1, lambda row: row["n"]),
    ),
)
BinaryPacker.pack(row, {"on": True, "n": 7})
```

```
01 03 07
```

### When

The group is written only when an earlier field equals the given value. The tested field must already have been read. `profile == 0` writes `shape`. Any other profile writes nothing after the profile byte.

```python
row = Scheme(
    1,
    dict,
    u8(0, lambda row: row["profile"]),
    when(1, eq(0, 0), u8(1, lambda row: row["shape"])),
)
BinaryPacker.pack(row, {"profile": 0, "shape": 9})
```

```
01 00 09
```

`profile = 1` is `01 01`.

### Repeat

The group is repeated until the buffer ends. There is no count. Unpack stops on the last complete group. One leftover byte is a short packet: it names the field, the bytes needed, and the bytes left, and returns no row. A group that reads no bytes at all ends the repeat, and the bytes left are trailing bytes.

Two points, `(10, 20)` then `(30, 40)`:

```python
row = Scheme(
    1,
    dict,
    repeat(0, i32(0, lambda row: row["lat"]), i32(1, lambda row: row["lon"])),
)
BinaryPacker.pack(row, {"lat": [10, 30], "lon": [20, 40]})
```

```
01 0a 00 00 00 14 00 00 00 1e 00 00 00 28 00 00 00
```

A field after `repeat` is eaten as another point. Use `times` when something follows the group.

### Sized

Raw bytes whose length is an earlier integer. No length of its own. The list must be that many bytes. Count 3 and `75 61 76`:

```python
row = Scheme(
    1,
    dict,
    u16(0, lambda row: row["n"]),
    sized(1, lambda row: row["payload"], 0),
)
BinaryPacker.pack(row, {"n": 3, "payload": b"uav"})
```

```
01 03 00 75 61 76
```

A short buffer names the field, the bytes needed, and the bytes left, and returns no row.

### Two-bit slots

`u2` packs a fixed list of named slots, four values per byte, low bits first. Each value is 0 … 3. Slots `0, 1, 2, 3` are the single byte `e4`.

```python
row = Scheme(
    1,
    dict,
    u2(
        (0, lambda row: row["a"]),
        (1, lambda row: row["b"]),
        (2, lambda row: row["c"]),
        (3, lambda row: row["d"]),
    ),
)
BinaryPacker.pack(row, {"a": 0, "b": 1, "c": 2, "d": 3})
```

```
01 e4
```

One slot whose value is 1 is `01 01`. Unused bits in the last byte are 0.

### Bits

A list of 0 and 1. The item count is an earlier integer, as stored. Eight 1-bits are `ff`. Nine spill into a second byte whose low bit is 1 and whose other bits are 0.

```python
row = Scheme(1, dict, u8(0, lambda row: row["n"]), bits(1, lambda row: row["segs"], 0))
BinaryPacker.pack(row, {"n": 8, "segs": [1, 1, 1, 1, 1, 1, 1, 1]})
```

```
01 08 ff
```

The list length must equal that count. `bits` cannot mean "one less than the count". That is `packed`.

### Packed

A list of small integers, width 1 or 2, with no length of its own. The item count is an earlier integer plus a bias of 0 or −1. Width 2 stores 0 … 3, four per byte, low bits first. Width 1 stores 0 or 1, eight per byte. Values `0, 1, 2, 3` are `e4`.

```python
kinds = Scheme(
    1,
    dict,
    u8(0, lambda row: row["n"]),
    packed(2, 1, lambda row: row["kinds"], 0),
)
BinaryPacker.pack(kinds, {"n": 4, "kinds": [0, 1, 2, 3]})
```

```
01 04 e4
```

Bias −1 is the count minus one. A count of 9 and eight 1-bits is `ff`. A count of 1 writes no bitset bytes.

```python
legs = Scheme(
    1,
    dict,
    u8(0, lambda row: row["n"]),
    packed(1, 1, lambda row: row["legs"], 0, -1),
)
BinaryPacker.pack(legs, {"n": 9, "legs": [1, 1, 1, 1, 1, 1, 1, 1]})
```

```
01 09 ff
```

A list whose length is not that count is rejected, and the error names the field.

### Times

The inner fields, exactly N times. N is an earlier integer. The next scheme field is then read as itself. `repeat` would keep going until the buffer ends.

Count 2, points `(10, 20)` and `(30, 40)`, then a trailing `u8` of 7:

```python
row = Scheme(
    1,
    dict,
    u8(0, lambda row: row["n"]),
    times(1, 0, i32(1, lambda row: row["lat"]), i32(2, lambda row: row["lon"])),
    u8(3, lambda row: row["tail"]),
)
BinaryPacker.pack(row, {"n": 2, "lat": [10, 30], "lon": [20, 40], "tail": 7})
```

```
01 02 0a 00 00 00 14 00 00 00 1e 00 00 00 28 00 00 00 07
```

`packed` and `times` together are how one scheme holds a route: a header, N two-bit point kinds, N latitude/longitude pairs, then N−1 straight-leg bits only when a flag is set. That packet is

```
34 10 00 15 00 06 2d 00 02 0d 00 65 cd 1d 00 a3 e1 11 10 8c cd 1d 10 ca e1 11 01
```

[`_docs/01_solution/schema.md`](_docs/01_solution/schema.md)

## Untrusted input

Unpack reads bytes from the network, so a packet may be built to hurt. In C#, TypeScript, Python, Rust and Java, `unpack` answers every packet it cannot read with an error value and no row. It does not throw, and it stops within time and memory set by the length of the packet. The cases it refuses:

- a count that is negative, or larger than the bytes left
- a count whose field is absent because its flag bit was clear
- invalid UTF-8 in a string or a dictionary key
- a `times` round, or a `list` or `dict` element, that reads no bytes. A `repeat` round that reads none ends the repeat, and the bytes left are trailing bytes

The kind of error for these is not settled yet. Today they come back as a short-packet-style error, so test for failure, not for its exact kind. The C++ package already reports every failure as a `Result`; it does not check that a string is valid UTF-8.

These mistakes in a scheme are refused when you build it, not when a packet arrives:

- A split-form flag bit must come after its flag byte, in the same place: the top level, one `repeat` or `times` round, or one `list` or `dict` element. A flag byte read inside a `when` is not visible after it. TypeScript, C#, Java and Rust refuse a violation at construction; Python does not check yet.
- In Rust and Java, a `when` or a count may name only a field read earlier in its own place: the top level, one `repeat` or `times` round, one `list` or `dict` element, or (Java) one nested row. A field inside a `repeat` or `times` is not visible after it, and an outer field is not visible inside it. In Java the named field must be an integer or a `bool`.
- A `bool` stands only directly under `flags` or a flag-byte bit, and one flags byte holds at most 8 bits. An empty group follows the same rule when something carries its `true` (its own value in TypeScript and Rust, a `bool` member in C# and C++, a nested-row accessor in Java, where the nested row carries presence only: `{g: {x: 1}}` comes back as `{g: {}}`). An empty group that could never set its bit (Python and Java `group(anchor)` with no fields, a C# empty group bound to a non-`bool` member) fails construction wherever it stands. Every package refuses a violation at construction; in TypeScript `new Scheme(...)` checks the same as `scheme(...)`.

If you upgrade, three schemes that built before now do not (the first two in TypeScript, C#, Java and Rust): a flag byte in one `when` with its bit in another `when`, a flag byte outside a `list`, `repeat` or `times` with its bit inside it, and (Rust) a reference from inside a `repeat` or `times` to a field outside it. Packet bytes do not change. A `times`, `list` or `dict` element that reads nothing used to unpack as an empty item and is now an error.

The `bool` rule changes more when you upgrade. A `bool` that is `false` now packs a clear bit (`01 00`) in C#, TypeScript and Rust, as Java, Python and C++ already did, so mixed versions read that row differently until both sides upgrade. A `bool` or empty group outside `flags`, an empty group that could never set its bit, and a ninth flag bit now fail at construction. In C#, packing a flags group whose bit is on throws when one of its values is missing, instead of writing a packet that cannot be read, and a group whose only values are `u2`, `sized`, `bits`, `packed` or a nested group now sets its bit. In C# and TypeScript, a value other than `true` (for example `1`) leaves a bool's bit clear. In TypeScript, `new Scheme(...)` now refuses everything `scheme(...)` refuses (a type number above 255, a wrong field id, a split bit outside its scope, a bool outside flags) instead of building it, and its `fields` come back flattened (`flagByte` / `flagBit` in place of `flags`), as `scheme(...)` already returned them. In Java, a `when` or a count that names a later field, a field outside its round, or a field that is not an integer or a `bool` now fails at construction, a `repeat` or `times` nested inside a `repeat` or `times` round fails at construction, and unpacking a `repeat` or `times` gives every field one list entry per round, `null` where the round skipped it. In Rust, `packbin::pack` and `packbin::unpack` for map schemes are now public, a map bool value other than 0 or 1 or a `__repeat__` value that is not groups fails pack, a `repeat` inside a `repeat` or `times` round and a `times` inside a `times` round fail at construction (a `times` inside a `repeat` round still works), a `FlagByte` handle no longer counts bits across schemes, and a second read of a flag byte with the same name starts its own bits, as in C++.

Limits to keep in mind:

- Unpack has no packet-size budget. Time and memory grow with the length of the packet, so cap the packet length where you read it from the network.
- In TypeScript a decoded dictionary keeps a key named `__proto__` as an ordinary own entry. Copy or merge decoded dictionaries with care: `Object.assign({}, dict)` sets the target's prototype from that entry. Read them with `Object.hasOwn`.
- In C# a `u64` or `i64` field arrives in `UnpackResult.Values` as `ulong` or `long`. Read through the row type and nothing changes for you; code that reads those two kinds straight from `Values` as `double` must change.
- A session packs from several threads safely in C# and Java (each packet gets its own number). Unpacking on one session must be called in packet order, one caller at a time.

## License

MIT
