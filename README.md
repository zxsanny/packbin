# packbin

[![npm](https://img.shields.io/npm/v/packbin)](https://www.npmjs.com/package/packbin)
[![nuget](https://img.shields.io/nuget/v/Packbin)](https://www.nuget.org/packages/Packbin)
[![pypi](https://img.shields.io/pypi/v/packbin)](https://pypi.org/project/packbin/)
[![crates.io](https://img.shields.io/crates/v/packbin)](https://crates.io/crates/packbin)
[![maven-central](https://img.shields.io/maven-central/v/io.github.zxsanny/packbin)](https://central.sonatype.com/artifact/io.github.zxsanny/packbin)
[![license](https://img.shields.io/github/license/zxsanny/packbin)](LICENSE)

[![build (dev)](https://img.shields.io/github/actions/workflow/status/zxsanny/packbin/test.yml?branch=dev&label=build%20(dev))](https://github.com/zxsanny/packbin/actions/workflows/test.yml?query=branch%3Adev)
[![build (main)](https://img.shields.io/github/actions/workflow/status/zxsanny/packbin/test.yml?branch=main&label=build%20(main))](https://github.com/zxsanny/packbin/actions/workflows/test.yml?query=branch%3Amain)
[![publish](https://img.shields.io/github/actions/workflow/status/zxsanny/packbin/publish.yml?label=publish)](https://github.com/zxsanny/packbin/actions/workflows/publish.yml)

Binary packing and unpacking across languages with an optional encryption, declarative mapping, and zero overhead in the binary data.

Both sides keep the same field list. The bytes are only the values. Unpack takes the buffer and handlers. The first byte selects the handler, and that handler's scheme reads the rest.

Can be used for WebSocket, TCP, UDP, and other means of efficient communication

Encryption is optional. `PackSession` hides the packed bytes on one connection and adds 0 bytes to each packet. The only extra send is 16 bytes, once, when the connection opens. It does not detect a changed byte, and anyone holding the 32-byte seed can read every session. See [Encrypted session](#encrypted-session).

Java: Java 17+, Android API 26+.

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

Schemes built from field lists (`MapScheme`) pack and unpack values keyed by field name with `packbin::pack(&scheme, &values)` and `packbin::unpack(&scheme, &bytes)`. That is the Rust path for the split flag-byte form, which the typed `Scheme` does not have yet. The typed `Scheme` has no `repeat` or `u2` either.

#### Times

A typed `times` binds a `Vec<E>` of element rows. `get` lends the elements, `set` takes the ones unpacked (one `E::default()` per round, filled by the members), and the members are items on `E`, numbered from the anchor on. The count is an earlier integer field of the row. Pack fails with a `PackError::Type` that names the `times` when the count differs from the number of elements: `times at id 1: count 3, 2 rounds`.

```rust
use packbin::{BinaryPacker, BoundField, Scheme, SchemeItem};

#[derive(Default, Debug, PartialEq)]
struct Point {
    lat: i32,
    lon: i32,
}

#[derive(Default, Debug, PartialEq)]
struct Route {
    n: u8,
    points: Vec<Point>,
    tail: u8,
}

let route = Scheme::new(1, [
    BoundField::u8(0, |row: &Route| row.n, |row, value| row.n = value).into(),
    SchemeItem::times(
        1,
        0,
        |row: &Route| &row.points[..],
        |row, value| row.points = value,
        [
            BoundField::i32(1, |p: &Point| p.lat, |p, value| p.lat = value).into(),
            BoundField::i32(2, |p: &Point| p.lon, |p, value| p.lon = value).into(),
        ],
    ),
    BoundField::u8(3, |row: &Route| row.tail, |row, value| row.tail = value).into(),
]);

let row = Route {
    n: 2,
    points: vec![Point { lat: 10, lon: 20 }, Point { lat: 30, lon: 40 }],
    tail: 7,
};
let raw = BinaryPacker::pack(&route, &row).unwrap();

let mut got = Route::default();
BinaryPacker::unpack_with(&raw, &mut [&mut route.on(|row| got = row)]).unwrap();
assert_eq!(got, row);
```

```
01 02 0a 00 00 00 14 00 00 00 1e 00 00 00 28 00 00 00 07
```

An optional member of `E` (a `BoundField::opt_u16` under `SchemeItem::flags`, or a `SchemeItem::when`) keeps its own round. The three-argument form `SchemeItem::times(anchor, count_id, members)` and the `SchemeItem::Times { .. }` struct variant are removed. The old form bound each member to one scalar of the row, so it lost every round after the first.

In a `MapScheme`, `times` unpacks to the per-name lists and also to the rounds, as `Value::Groups` under `__times_<anchor>` (present, and empty for a count of 0). A list holds only the rounds that read its name, so the rounds tell which round a value belongs to. `repeat` gives its rounds under `__repeat__`. Pack reads the rounds, and it fails with `PackError::Type("times at id 1: list for '1' disagrees with its rounds")` when a per-name list differs from them. To change a value, edit the rounds and drop or rewrite the per-name lists, or edit the lists and remove the `__times_<anchor>` key.

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
| `when(anchor, eq(id, value), fields)` | the group only when an earlier field of the same scope equals `value`; the anchor is not written |
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

Pack refuses a value that does not fit. TypeScript takes an integer `number` or a `bigint` and throws a `RangeError` that names the member: `n: 300 does not fit in u8` for a value out of range, a fraction or `NaN`, and `n: expected a number for u8, got string` for anything else. It used to wrap 300 to `2c` and cut 1.5 to 1. Pass a `bigint` for a 64-bit value: a `number` that is not a safe integer is refused even where the width could hold it (`n: 9007199254740992 does not fit in u64; pass a bigint`). A row that unpack returned packs again.

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

TypeScript pack takes only a `number` for a float. A `bigint` or a numeric string throws a `RangeError` (`x: expected a number for f64, got string`), and so does a finite value too large for `f32` (`x: 1e+39 does not fit in f32`). `NaN` and the infinities are written as given.

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

A `when` that tests a bool matches only when the bit is set, so test it with `eq(id, true)`. A clear bit is absent when a packet is read, so `eq(id, false)` never matches. C# pack agrees. TypeScript pack and Rust pack (map form) still write the `when` body for `eq(id, false)` on a clear bit, and their own unpack then rejects the packet.

### When

The group is written only when an earlier field equals the given value. The tested field must already have been read, and it must be in the same scope. The top level, the body of a `repeat` or `times`, a `list` or `dict` element and a nested row are separate scopes, and a `when` sees only the fields before it in its own. A field that was skipped (inside a `when` that did not match, or behind a clear flag bit) is absent, so a `when` that tests it does not match when a packet is read. `profile == 0` writes `shape`. Any other profile writes nothing after the profile byte.

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

A scheme whose `when` names a later field, an id that does not exist, or a field of another scope fails when you build it (every package but Python; see [Untrusted input](#untrusted-input)). C# pack decides every `when` from the fields it wrote, as unpack does from the fields it read. TypeScript pack still tests the row you give it, so a `when` on a field that another `when` skipped can write a body its own unpack rejects. Do not test a field that something else can skip.

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

A round can hold more than plain fields: a `when`, `flags` or a group. Give every name the round holds one list. Entry `i` is the value for round `i`, and `repeat` runs as many rounds as its longest list. `repeat(k, when(k == 1, v))` with `k = [1, 2]` and `v = [9]` packs `01 01 09 02`. Unpack gives the same shape: every name a round can hold has one entry per round, and a round that skipped the name has `null` (`undefined` in TypeScript), so a row packs again to the same bytes. TypeScript, C# and Java do this. Python lists only the rounds that read a name. Rust and C++ keep each round as a row: a `Vec<E>` for a typed Rust `times`, `Value::Groups` in the map form of Rust (see Times under Rust), and an `Array<E, N>` in C++. TypeScript rows are flat, so give a group's members as lists under their own names: the nested form `{mark: {v: [7, undefined, 9]}}` throws `missing v`.

A `repeat` or `times` cannot sit inside a `repeat` or `times` round, directly or under a `when`, `flags` or group. TypeScript, C# and Java refuse the scheme when you build it. Rust refuses all of these but a `times` inside a `repeat`. Python does not check yet. A `list` or `dict` element starts outside any round.

C# packs such a row from a dictionary of lists (`BinaryPacker.Pack(scheme, IReadOnlyDictionary<string, object?>)`). It has no public call that reads one yet: a typed `Unpack` of a packet that holds a `repeat` or `times` round throws `InvalidCastException`.

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

The rules of Repeat hold for the rounds of `times`: one list per name, entry `i` for round `i`, `null` (`undefined` in TypeScript) for a round that skipped the name, and no `repeat` or `times` inside a round. The count is the number of rounds. C# refuses a list longer than the count (`'V' holds 2 items, but the times count is 1`) and a list too short for a round that walks the field. Rust binds a `Vec<E>`; see Times under Rust.

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
- A `when` or a count may name only a field read earlier in its own place: the top level, one `repeat` or `times` round, one `list` or `dict` element, or (C#, TypeScript, Java) one nested row. A field inside a `repeat` or `times` is not visible after it, and an outer field is not visible inside it. C#, TypeScript, Java and C++ refuse a violation at construction. Rust does too for a numeric id that names a later field or an outer field from inside a round; it does not check yet a field inside an earlier `repeat` or `times` body, or a name the scheme never declares. Python does not check yet. TypeScript refuses a count that names a `bool` or a float. In Java the named field of a `when` or a count must be an integer or a `bool`.
- A `bool` stands only directly under `flags` or a flag-byte bit, and one flags byte holds at most 8 bits. An empty group follows the same rule when something carries its `true` (its own value in TypeScript and Rust, a `bool` member in C# and C++, a nested-row accessor in Java, where the nested row carries presence only: `{g: {x: 1}}` comes back as `{g: {}}`). An empty group that could never set its bit (Python and Java `group(anchor)` with no fields, a C++ `group(id)` with no fields and no member, a C# empty group bound to a non-`bool` member) fails construction wherever it stands. Every package refuses a violation at construction; in TypeScript `new Scheme(...)` checks the same as `scheme(...)`.
- A `repeat` or `times` inside a `repeat` or `times` round, directly or under a `when`, `flags` or group. C#, TypeScript and Java refuse it at construction (`repeat 1 is inside a repeat or times round; a round cannot hold another repeat or times`). Rust refuses all of these but a `times` inside a `repeat`. Python does not check yet. A `list` or `dict` element starts outside any round.
- In TypeScript, a member name that group flattening would overwrite: a name declared inside an unanchored group and also outside it or in another unanchored group, or a group named like one of its own members (`member sid: declared inside a group and outside it; a group's members are flattened into the row, so one would overwrite the other`).
- In C#, a field declared for another row type, such as `Field.U16<Other>` in a `Scheme<Row>`: `'Q' is declared for row type Other, but this scheme is for R`. A field of a nested row goes inside its `Group`, not in the parent scheme.
- In Rust, a `when` on a field that is not an integer or a `bool`, or compared with a value that is not an integer; and a `list` or `dict` element that is a group, `flags`, `when`, `repeat`, `times`, `sized`, `bits`, `packed` or a `u2` with more than one name, which could not round-trip.

If you upgrade, three schemes that built before now do not (the first two in TypeScript, C#, Java and Rust): a flag byte in one `when` with its bit in another `when`, a flag byte outside a `list`, `repeat` or `times` with its bit inside it, and (Rust) a reference from inside a `repeat` or `times` to a field outside it. Packet bytes do not change. A `times`, `list` or `dict` element that reads nothing used to unpack as an empty item and is now an error.

The `bool` rule changes more when you upgrade. A `bool` that is `false` now packs a clear bit (`01 00`) in C#, TypeScript and Rust, as Java, Python and C++ already did, so mixed versions read that row differently until both sides upgrade. A `bool` or empty group outside `flags`, an empty group that could never set its bit, and a ninth flag bit now fail at construction. In C#, packing a flags group whose bit is on throws when one of its values is missing, instead of writing a packet that cannot be read, and a group whose only values are `u2`, `sized`, `bits`, `packed` or a nested group now sets its bit. In C# and TypeScript, a value other than `true` (for example `1`) leaves a bool's bit clear. In TypeScript, `new Scheme(...)` now refuses everything `scheme(...)` refuses (a type number above 255, a wrong field id, a split bit outside its scope, a bool outside flags) instead of building it, and its `fields` come back flattened (`flagByte` / `flagBit` in place of `flags`), as `scheme(...)` already returned them. In Java, a `when` or a count that names a later field, a field outside its round, or a field that is not an integer or a `bool` now fails at construction, a `repeat` or `times` nested inside a `repeat` or `times` round fails at construction, and unpacking a `repeat` or `times` gives every field one list entry per round, `null` where the round skipped it. In Rust, `packbin::pack` and `packbin::unpack` for map schemes are now public, a map bool value other than 0 or 1 or a `__repeat__` value that is not groups fails pack, a `repeat` inside a `repeat` or `times` round and a `times` inside a `times` round fail at construction (a `times` inside a `repeat` round still works), a `FlagByte` handle no longer counts bits across schemes, and a second read of a flag byte with the same name starts its own bits, as in C++.

Reference scope is now checked in C# and TypeScript too, as it already was in Java, Rust (numeric ids) and C++. If you upgrade, a `when` or a count that names a later field, an id that does not exist, or a field of another scope throws at construction: `ArgumentException` in C# (`when 0 names field id 1, which is not an earlier field in the same scope ...`), `RangeError` in TypeScript (`when 0: eq names field id 1, which is not declared earlier in the same scope`). C# used to resolve a later id and pack a packet its own unpack rejected. TypeScript used to search the whole scheme for the id, so a `when` inside an unanchored group could match a field outside it that had the same id; it now reads its own scope. A `sized`, `bits` or `packed` counted by a field of the same `repeat` round now unpacks in TypeScript (it was an error). Python still builds these schemes. A `repeat` or `times` inside a `repeat` or `times` round now fails at construction in C# and TypeScript, as in Java.

TypeScript pack throws where it used to write wrong bytes. A `RangeError` names the member for an integer out of range (`n: 300 does not fit in u8`; it wrote `2c`), a fraction or `NaN` in an integer field (1.5 was cut to 1), a value that is not a number (`n: expected a number for u8, got string`), a `bigint` or a numeric string in a float field, a finite value too large for an `f32` (`x: 1e+39 does not fit in f32`; it wrote an infinity), and a 64-bit `number` that is not a safe integer (`n: 9007199254740992 does not fit in u64; pass a bigint`). A field under `flags` inside a group is now written: a group of `u8 a` and `flags(u8 c, u8 d)` with `{g: {a: 7, c: 2}}` packed `01 07 00` and packs `01 07 01 02`. A member name that group flattening would overwrite fails at construction. These checks run in `new Scheme(...)` too. `eq` compares numbers and bigints by value, so a `when` on a `u64` field matches on pack and on unpack. `Scheme.fields` holds copies of the `when`, `sized`, `bits`, `packed` and `times` fields with the name they refer to filled in, not the objects you passed in.

TypeScript unpacked rows changed. The flag-byte value is no longer a member (`flags` used to add a `""` key, and `flagByte("m")` added `m`). In a `repeat` or `times` round every name the round can hold is a list with one entry per round, `undefined` where the round skipped it (a `bool` under `flags` is `true` or `undefined`); the list used to hold only the rounds that read the name. Pack reads these lists by round index, so a row packs again to the same bytes, and a `when`, `flags` or group inside a round packs. `repeat(k, when(k == 1, v))` with `{k: [1, 2], v: [9]}` packs `01 01 09 02`; it threw `expected number`.

C# pack no longer drops data. `Pack` throws `ArgumentException` where a value is missing outside a flag bit (`'N' (field id 1) has no value; a field that may be absent belongs in Flags`). It used to write a shorter packet that the peer misread, or throw `KeyNotFoundException` for an absent list, dictionary or `Sized`. The same error comes when a round runs out of list, and when a `times` list is shorter than its count. A longer one throws `'V' holds 2 items, but the times count is 1`. A count whose field pack did not write (a `when` or a clear flag bit skipped it) throws `InvalidOperationException`: `D: count 'N' is missing`. A scheme that holds a field declared for another row type throws `ArgumentException` at construction: `Field.U16<Other>` in a `Scheme<Row>` used to leave its value out, and a child row's field used directly in the parent scheme, which packed, now goes inside its `Group`. Pack decides every `when` from what it wrote, as unpack does from what it read. A `when` on a field that an earlier `when` or a clear flag bit skipped no longer matches (a row that packed `01 01 04` now packs `01 01`), and `Eq(bool, false)` on a clear bit no longer matches. A float `when` follows Java's `Double.compare`: NaN equals NaN and -0.0 differs from 0.0. Give an `f32` field a `float` in `Eq` (`Eq(0, 0.1f)`): `Eq(0, 0.1)` matches nothing now. A scheme owns a copy of its fields, so one `Field` or `Condition` can be used in several schemes (a second scheme with the same `Condition` used to rebind the first). A `FlagByte` handle is still shared: add all its bits before you build the scheme. In a round, pack reads values under `when`, `flags` and groups by round index, and a read gives aligned lists with `null` for a skipped round; there is no public call that returns such a row yet (see Repeat).

Rust `times` and `when` changed. A typed `times` is now `SchemeItem::times(anchor, count_id, get, set, members)` and binds a `Vec<E>` (see Times under Rust). The three-argument form and the `SchemeItem::Times { .. }` struct variant are removed, so typed code that used them does not compile. A scheme that built before can now fail at construction: a `when` on a float, utf8 or bytes field or compared with a value that is not an integer (`when at id 1 tests field "0", which is not an integer or bool`), and a `list` or `dict` element that is a group, `flags`, `when`, `repeat`, `times`, `sized`, `bits`, `packed` or a `u2` with more than one name. A `when` now compares by integer value at any width; `eq` of a `u8` against a `u16` field used to never match. Two bound lists or dicts in one typed scheme now keep their own members; the second used to overwrite the first, and pack wrote it twice. The map form of `times` also returns its rounds under `__times_<anchor>`, and pack refuses a list that disagrees with them: `times at id 1: list for '1' disagrees with its rounds`. Edit the rounds and drop or rewrite the per-name lists, or edit the lists and remove the `__times_<anchor>` key.

Limits to keep in mind:

- Unpack has no packet-size budget. Time and memory grow in a straight line with the length of the packet, never with a count the packet states, so cap the packet length where you read it from the network. The constant depends on the scheme. A `repeat` or `times` round keeps a slot for every name it can hold, even where it read nothing, so the cost grows with the names in the body. Peak memory (resident set, runtime included) for a 1 MB packet of 1-byte rounds: a 36-name `when` body takes about 400 MB in TypeScript (about 130 MB before this release), about 530 MB in C# (about 100 MB before) and about 570 MB in Java (unchanged); a Rust `times` of 1-byte rounds takes about 310 MB (about 37 MB before), and about 1.4 GB when each round sets eight flag bits. The C# packet takes about 1.4 seconds to read.
- In C#, a typed `Unpack` of a packet that holds a `repeat` or `times` round throws `InvalidCastException` instead of returning an error value: the row type has no member that can hold a list per round, and no public C# call returns one yet.
- In TypeScript a decoded dictionary keeps a key named `__proto__` as an ordinary own entry. Copy or merge decoded dictionaries with care: `Object.assign({}, dict)` sets the target's prototype from that entry. Read them with `Object.hasOwn`.
- In C# a `u64` or `i64` field arrives in `UnpackResult.Values` as `ulong` or `long`. Read through the row type and nothing changes for you; code that reads those two kinds straight from `Values` as `double` must change.
- A session packs from several threads safely in C# and Java (each packet gets its own number). Unpacking on one session must be called in packet order, one caller at a time.

## License

MIT
