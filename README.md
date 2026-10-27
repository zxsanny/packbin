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

Supported languages:

- Java: Java 17+, Android API 26+.
- C#: .NET 10+, and .NET Standard 2.0 for .NET Framework 4.6.2+, Unity, Mono and Xamarin (the .NET Standard build is tested on the .NET 10 runtime). Typed rows are read and written through accessors that `Expression.Compile` builds once, when each field is created. Under AOT or Unity IL2CPP these expression delegates run through the interpreter: the result is the same but slower, and the package has not been run on Unity. A Unity IL2CPP test run is planned before a release that advertises Unity. Under IL2CPP, keep row types from being stripped (`link.xml` or `[Preserve]`).
- TypeScript: Node.js 22+; browsers through a bundler such as Vite.
- Python: 3.10+.
- Rust: edition 2021.
- C++: C++17; CMake 3.16+ or vcpkg on Linux and macOS (Windows is not supported: the package is not built or tested there); 32-bit microcontrollers (ESP32, RP2040, nRF52, STM32) through PlatformIO, Arduino and ESP-IDF 5.1+.
- Go: Go 1.26+; `go get github.com/zxsanny/packbin/go@vX.Y.Z`, fetched from the repository by version tag (no registry). The standard library and `golang.org/x/crypto` (the session only); no cgo. See [Go](#go).
- Swift: Swift 6.0+ (Xcode 16+; a 6.0 consumer and an Xcode 16.0 build are unproven, only Swift 6.3.3 is built in CI), iOS 15+, macOS 12+ and Linux; `.package(url: "https://github.com/zxsanny/packbin", from: "X.Y.Z")`, fetched from the repository by the `vX.Y.Z` tag (no registry, no Swift tag). One dependency, `swift-crypto`, linked only off Apple platforms (the session's HKDF). See [Swift](#swift).

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
import { BinaryPacker, flags, i16, i32, scheme, u8, u16, utf8, type SchemeHandler } from "packbin"

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
  u16(0, (x: Target) => x.sid),
  i32(1, (x: Target) => x.lat),
  i32(2, (x: Target) => x.lon),
  u8(3, (x: Target) => x.profile),
  flags(4, [
    u16(4, (x: Target) => x.heading),
    u8(5, (x: Target) => x.speed),
    i16(6, (x: Target) => x.altitude),
  ]),
)

class Ping {
  code = 0
}

class Note {
  id = 0
  title = ""
}

const ping = scheme<Ping>(2, u8(0, (x: Ping) => x.code))
const note = scheme<Note>(3, u16(0, (x: Note) => x.id), utf8(1, (x: Note) => x.title))

let got: Target | undefined
let pinged: Ping | undefined
let noted: Note | undefined
BinaryPacker.unpack(
  raw,
  target.on((row) => {
    got = row
  }) as SchemeHandler<any>,
  ping.on((row) => {
    pinged = row
  }) as SchemeHandler<any>,
  note.on((row) => {
    noted = row
  }) as SchemeHandler<any>,
)
```

The npm package ships compiled ES-module JavaScript and `.d.ts` files (`dist/`, built when the package is published), so plain Node 22+ and `tsc` projects import `packbin` without flags. Only the `packbin` entry point is exported: a `packbin/src/...` import no longer resolves. Versions published before this change ship `.ts` sources, which plain Node cannot import from `node_modules`. A TypeScript consumer needs TypeScript 5.0 or newer unless it sets `skipLibCheck`: the `.d.ts` files keep `./x.ts` import specifiers, which TypeScript 4.9 rejects (TS2691). The accessor helpers do not infer the row type, so in a TypeScript project give the accessor parameter its type, `u16(0, (x: Target) => x.sid)`: written as `(x) => x.sid`, `x` is `unknown` (TS18046 under `strict`, TS2339 without it). Under `strict`, `BinaryPacker.unpack` and `PackSession.unpack` also take handlers typed for `object`, so a handler of a typed row is passed `as SchemeHandler<any>` (TS2345 otherwise); both are as the examples here write them, and neither is decided yet.

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
01 03 a9 28 80 02 00 03 0b a8 18 04 89 29 75 60 02 00 03 6a e9 c8
02 00 03 2b 01 28 03 48 51 64 04 ca 25 f0 00 01 00 04 8b bc 2c 80
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

In a `MapScheme`, `times` unpacks to the per-name lists and also to the rounds, as `Value::Groups` under `__times_<anchor>` (present, and empty for a count of 0). A list holds only the rounds that read its name, so the rounds tell which round a value belongs to. `repeat` gives its rounds under `__repeat__` (since loop 23 a per-name value kept beside them is checked against them as below, `repeat at id 0: list for 'x' disagrees with its rounds`). Pack reads the rounds, and it fails with `PackError::Type("times at id 1: list for '1' disagrees with its rounds")` when a per-name list differs from them. To change a value, edit the rounds and drop or rewrite the per-name lists, or edit the lists and remove the `__times_<anchor>` key. The second way does not work for a member below a `when`: a list cannot say which round holds it, so pack without the `__times_<anchor>` key fails with `PackError::Type("times at id 1: '1' is under a flags or when; give its values per round under '__times_1'")` when a non-empty list or a single value is kept under that member. Edit its rounds instead (an empty list still packs). A member below a `flags` or a flag bit takes a list one entry per round since loop 22, as in TypeScript, Python, Java and C#: item `i` is round `i`, and a short or empty list reads as absent for the rounds it does not reach (`u8 c; times(c, flags(1, u8(1, v)))` with `c` = 2 and `v` = [5] packs `01 02 01 05 00`). Unpack gives a list that holds only the rounds that read the name, so a value of round 3 sits at item 2 of `v`. Do not drop the `__times_<anchor>` rounds and pack from that list: the value moves to an earlier round with no error (`v` = [5, 7] from rounds 1 and 3 repacks as `01 03 01 05 01 07 00`). Edit and pack the rounds instead.

#### Heap-free API for firmware (`packbin::nostd`)

The same crate has a second API for devices with no heap: plain-data schemes, caller buffers and errors as values. It builds with `#![no_std]` and no allocator when you turn the default features off, and the bytes are those of the map API above.

```toml
packbin = { version = "0.1", default-features = false, features = ["text", "ecc", "session"] }
```

| Feature | Adds |
|---------|------|
| `std` (default, implies `alloc`) | the map API, `PackSession`, `Vec` results |
| `alloc` | `nostd::pack_vec` |
| `text` | strings (`utf8`) and dictionaries (`dict`) in the compact text format; `pack_with` takes the encoder's working words |
| `ecc` | parity bytes after every packet (`Scheme::with_parity`, `unpack_repair`, the codec in `nostd::ecc`) |
| `session` | `nostd::Session`: a seed, a nonce you supply, `pack` and `unpack` of padded packets in your buffers |

```rust
use packbin::nostd::{i32, pack, u16, u8, unpack, Fault, Num, Row, Scheme};

#[derive(Default)]
struct Position { sid: u16, lat: i32, profile: u8 }

impl Row for Position {
    fn num(&self, id: u16) -> Option<Num> {
        match id { 0 => Some(Num::U16(self.sid)), 1 => Some(Num::I32(self.lat)), 2 => Some(Num::U8(self.profile)), _ => None }
    }
    fn bytes(&self, _id: u16) -> Option<&[u8]> { None }
    fn set_num(&mut self, id: u16, value: Num) -> bool {
        match (id, value) {
            (0, Num::U16(v)) => { self.sid = v; true }
            (1, Num::I32(v)) => { self.lat = v; true }
            (2, Num::U8(v)) => { self.profile = v; true }
            _ => false,
        }
    }
    fn set_bytes(&mut self, _id: u16, _value: &[u8]) -> bool { false }
}

const SCHEME: Scheme = Scheme::new(0x40, &[u16(0), i32(1), u8(2)]);

fn main() -> Result<(), Fault> {
    let mut out = [0u8; 16];
    let n = pack(&SCHEME, &Position { sid: 1, lat: 500_000_000, profile: 1 }, &mut out)?;
    let mut back = Position::default();
    unpack(&SCHEME, &out[..n], &mut back)?;
    Ok(())
}
```

A session between two nodes: `let mut node = Session::load(&seed)?; node.start(&nonce)?;` (the peer calls `join(&nonce)`), then `node.pack(&scheme, &row, &mut out)` and `peer.unpack(&scheme, &mut data, &mut row)` (`unpack_repair` with `ecc`). The nonce is yours to generate and must not open two sessions under one seed. Every call returns a `Result`; no path reachable from untrusted bytes panics. The CI job `embedded-arm` links the library for a Cortex-M4F, runs it in QEMU and fails when a heap or panic symbol is linked (`rust/embedded/`).

### C++

The C++ package packs into a buffer you own and reads from one. It throws nothing and allocates nothing, so the same code builds for a server and for a microcontroller (`-fno-exceptions -fno-rtti`). Strings and lists land in caller storage: `Text<N>` (a decoded copy of up to N UTF-8 bytes) and `Array<T, N>` hold up to N, and more than N is the error `TooMany`, never a cut. A string is compact text (see [UTF-8](#utf-8)), which has to be decoded, so a string member is a `Text<N>` (or a `Packed`, below); a `View` cannot hold one and is a compile error on a `utf8` field. Pack of a string needs working memory for the encoder: pass a `Scratch<Chars>` as the last argument (12 bytes per character of the longest string in the packet); a string that needs more returns `ScratchTooSmall` naming the field and writes nothing for it, never different bytes. A `Scratch` for a long string is large (`Scratch<65535>` is 786 KB): declare it `static` or on the heap, never as a local; the repository's own build refuses a stack frame over 64 KB. Packets without strings need no scratch.

```cpp
#include <packbin/packbin.hpp>

using namespace packbin;

using Name = Text<16>;
using Actions = Array<Name, 8>;

struct User {
    Name username;
    Array<Name, 8> roles;
    Array<Entry<Actions, Name>, 8> access;  // keys in unsigned byte order
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
Scratch<16> scratch;  // 12 bytes per character of the longest string
Result packed = pack(user, row, buf, sizeof(buf), scratch);  // packed.offset is the packet length

User got;
Ping pinged;
Note noted;
Result r = unpack(buf, packed.offset,
    on(user, got, [](User const& u) { /* ... */ }),
    on(ping, pinged, [](Ping const& p) { /* ... */ }),
    on(note, noted, [](Note const& n) { /* ... */ }));
```

The first byte picks the scheme; its handler runs only after the whole packet reads. A failure is a value: `r.error` is one of `ShortPacket`, `TrailingBytes`, `TypeMismatch`, `BufferFull`, `TooMany`, `BadValue`, `SchemeInvalid`, with `r.offset` (the byte) and `r.field` (the order id). A `constexpr` scheme with a gap, a repeated id or a wrong anchor does not compile, and the compiler names the id; a scheme built at run time reports it through `validate(scheme)`. A member that may be absent is `Opt<T>`.

#### Strings without the codec: `Packed` and `PACKBIN_NO_TEXT`

A board that only carries packets does not need the text codec. Define `PACKBIN_NO_TEXT` (the embedded builds of this repository do) and the codec is not linked: a field list that binds a `utf8` field to `Text<N>` is refused when it is built, a `utf8` field bound to `Packed` (`data`, `len`: a borrowed view of the payload after the count, valid while the input lives) is skipped by its count header, so the fields after it still read, and the bytes can be forwarded or stored without decoding. Pack of a `Packed` member writes its count and bytes as given and does not decode or validate them. A dictionary key must be a `Text<N>` (it needs the order check), so a bound dictionary of strings needs the codec; an unbound `utf8` is skipped by its count.

#### Microcontrollers

The same package builds for 32-bit microcontrollers — Cortex-M0+/M3/M4/M33, ESP32, RP2040, nRF52, STM32 — with `-std=c++17 -fno-exceptions -fno-rtti`. It references no `malloc`, no `operator new` and no exception runtime, keeps no global state, and the scheme tables live in flash.

The core also builds for 8-bit AVR (ATmega328P, Arduino Uno) with avr-gcc 7.3 and avr-libc, which ship no C++ library: CI compiles it with 0 warnings and links the Uno example, but no AVR image is run. The standard names come from `packbin/platform.hpp`. On AVR constant data, the scheme tables included, sits in RAM, so the example builds with `PACKBIN_NO_TEXT` and `PACKBIN_NO_ECC`, and `double` is 4 bytes, so `f64` does not compile. avr-gcc 7.3 has no `__builtin_is_constant_evaluated`: a constant scheme that breaks a rule is not stopped at compile time there (its `status` is `SchemeInvalid` and `pack`/`unpack` refuse it), and `static_assert(scheme.status.ok())` restores the stop.

| Tool | Add packbin |
|------|-------------|
| PlatformIO | `lib_deps = zxsanny/packbin` and `build_src_flags = -std=gnu++17` in `platformio.ini` |
| Arduino IDE / arduino-cli | Library Manager: `packbin`, then `#include <packbin.h>` |
| ESP-IDF ≥ 5.1 | `idf.py add-dependency "zxsanny/packbin"` |
| CMake / vcpkg (host) | vcpkg port `packbin` (git registry: this repository, branch `vcpkg`): `find_package(packbin CONFIG REQUIRED)`, then `target_link_libraries(app PRIVATE packbin::packbin)`. Or `add_subdirectory(cpp)` and link `packbin` (alias `packbin::packbin`). Linux and macOS only: the port declares `"supports": "linux | osx"`, so vcpkg refuses other triplets (`--allow-unsupported` overrides this at your own risk), and `add_subdirectory` is built and tested only there. Windows is not supported (not built or tested) |

vcpkg finds the port through the project's `vcpkg-configuration.json`, and refuses a git registry unless the default registry has a baseline too. `vcpkg.json` then lists `"dependencies": ["packbin"]`:

```json
{
  "default-registry": { "kind": "builtin", "baseline": "<a microsoft/vcpkg commit>" },
  "registries": [
    {
      "kind": "git",
      "repository": "https://github.com/zxsanny/packbin.git",
      "reference": "vcpkg",
      "baseline": "<a commit of the vcpkg branch>",
      "packages": ["packbin"]
    }
  ]
}
```

The port builds the static library from the vendored sources of the release. Port versions published before this change only copy the headers and the sources and do not link: use the next port version.

While the version is below 1.0, an installed packbin answers `find_package(packbin <major>.<minor> CONFIG)` only for the same minor (`0.9` finds 0.9.x, not 0.8 or 0.10), and a request that names only the major (`find_package(packbin 0 ...)`) finds nothing; from 1.0 the rule is the same major. A request without a version, as in the install row, is unchanged. A version range that spans minors (`0.9...0.10`, `0.9...<1.0`) is refused too, where a range inside one minor (`0.9...0.9.5`) is found.

Examples: [`cpp/examples/pico`](cpp/examples/pico) (PlatformIO, Raspberry Pi Pico), [`cpp/examples/esp32_arduino`](cpp/examples/esp32_arduino) (Arduino-ESP32), [`cpp/examples/esp_idf`](cpp/examples/esp_idf) (ESP-IDF with the hardware RNG), [`cpp/examples/avr_uno`](cpp/examples/avr_uno) (avr-gcc and avr-libc, Arduino Uno, no Arduino core).

`PackSession::start` takes the board's random source as a `RandomFn` (`bool(std::uint8_t* out, std::size_t n, void* ctx)`): `esp_fill_random` on ESP32, the RNG peripheral on STM32 or nRF52. When it returns false, no session opens. Host programs pass `packbin::os_random`. `f64` needs an 8-byte `double`; where `double` is 4 bytes (avr-gcc), a scheme with `f64` does not compile.

Moving from 0.1.x — the C++ API changed; the bytes did not:

| 0.1.x | Now |
|-------|-----|
| `BinaryPacker::pack(scheme, row)` → `std::vector` | `pack(scheme, row, out, cap)` → `Result` (`offset` = length) |
| `BinaryPacker::unpack(bytes, scheme.on(handler)...)` | `unpack(data, len, on(scheme, row, handler)...)`, or `unpack(scheme, data, len, row)` |
| `Scheme<T>(type, ...)`, `scheme(type, {...})`, `SchemeHandler` | `constexpr auto s = scheme<T>(type, ...)`; `on(s, row, handler)` |
| `Value`, `Values`, `ValueList`, `ValueMap` (map rows) | struct rows with `Opt<T>`, `View`, `Text<N>`, `Blob<N>`, `Array<T, N>`, `Entry<V>` members |
| `u16(0, &T::m)`, `bind_scalar`, `bind_optional`, `bind_accessors`, `BoundField<T>` | `u16<&T::m>(0)` (member binding only; no getter/setter) |
| `std::optional<T>` / `std::string` / `std::vector<T>` members | `Opt<T>` / `Text<N>` (a `View` for bytes) / `Array<T, N>` |
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

## Example

Go → binary → TypeScript

### Go

Go has no package registry, so nothing is uploaded: `go get` fetches the module from this repository by version tag. The module is `github.com/zxsanny/packbin/go` and lives in the `go/` folder, which is why Go reads its tag as `go/vX.Y.Z`. The release run pushes that tag at the same commit as the `vX.Y.Z` tag, and only after every language has matched the golden hex (ADR-004: a mismatch publishes no package and no Go tag). Go 1.26 or newer. The package uses the Go standard library and one dependency, `golang.org/x/crypto`, for the ChaCha20 of the session; there is no cgo. A published Go version is never deleted or moved: a bad one is retracted in the `go.mod` of the next version. Go versions start with the first release tag published after the Go package was added.

```
go get github.com/zxsanny/packbin/go@vX.Y.Z
```

The import path ends in `go`, so give the import its name, `packbin "github.com/zxsanny/packbin/go"`. The Go snippets in this README are the bodies of the `Example` tests in [`go/example_test.go`](go/example_test.go), copied unchanged without the function wrapper and with the same imports: `go test` runs them and compares what they print with the output shown under each. A row is a typed struct bound field by field with `Bind`, or a `map[string]any`.

```go
import (
	"fmt"

	packbin "github.com/zxsanny/packbin/go"
)

type Position struct {
	Sid      uint16
	Lat      int32
	Lon      int32
	Profile  uint8
	Heading  *uint16
	Speed    *uint8
	Altitude *int16
}

position, err := packbin.NewScheme(0x40,
	packbin.Bind(packbin.U16(0, "sid"), func(r *Position) uint16 { return r.Sid }, func(r *Position, v uint16) { r.Sid = v }),
	packbin.Bind(packbin.I32(1, "lat"), func(r *Position) int32 { return r.Lat }, func(r *Position, v int32) { r.Lat = v }),
	packbin.Bind(packbin.I32(2, "lon"), func(r *Position) int32 { return r.Lon }, func(r *Position, v int32) { r.Lon = v }),
	packbin.Bind(packbin.U8(3, "profile"), func(r *Position) uint8 { return r.Profile }, func(r *Position, v uint8) { r.Profile = v }),
	packbin.Flags(4,
		packbin.Bind(packbin.U16(4, "heading"), func(r *Position) *uint16 { return r.Heading }, func(r *Position, v *uint16) { r.Heading = v }),
		packbin.Bind(packbin.U8(5, "speed"), func(r *Position) *uint8 { return r.Speed }, func(r *Position, v *uint8) { r.Speed = v }),
		packbin.Bind(packbin.I16(6, "altitude"), func(r *Position) *int16 { return r.Altitude }, func(r *Position, v *int16) { r.Altitude = v }),
	),
)
if err != nil {
	panic(err)
}

raw, err := packbin.Pack(position, &Position{Sid: 1, Lat: 500_000_000, Lon: 300_000_000, Profile: 1})
if err != nil {
	panic(err)
}
fmt.Printf("% x\n", raw)

row, err := packbin.Unpack(raw, position)
if err != nil {
	panic(err)
}
got := row.(*Position)
fmt.Println(got.Lat, got.Heading == nil)
```

```
40 01 00 00 65 cd 1d 00 a3 e1 11 01 00
500000000 true
```

The first line is the 13-byte packet of the first example (Python → binary → TypeScript; `fixtures/golden.hex`, the same bytes without the spaces). `Heading`, `Speed` and `Altitude` are pointers: a nil pointer is no value, so its bit in `motion` stays clear and the field takes no space, and a pointer to 0 is a value and is written. A bound scheme packs a `*Position` or a `Position`, and `Unpack` returns a `*Position`. `NewScheme` returns an error naming the field id for a gap, a repeated id or a wrong anchor, and no input makes `Pack`, `Unpack` or `NewScheme` panic.

The same scheme without a struct reads and writes a `map[string]any` keyed by the field names. An integer field takes any Go integer type that holds the value, so the untyped constants below are fine. `heading`, `speed` and `altitude` are optional under `flags` here too: a key that is missing or `nil` leaves the bit clear, and `"heading": 90` sets bit 0 and writes `5a 00` after `motion`.

```go
position, err := packbin.NewScheme(0x40,
	packbin.U16(0, "sid"),
	packbin.I32(1, "lat"),
	packbin.I32(2, "lon"),
	packbin.U8(3, "profile"),
	packbin.Flags(4,
		packbin.U16(4, "heading"),
		packbin.U8(5, "speed"),
		packbin.I16(6, "altitude")),
)
if err != nil {
	panic(err)
}

raw, err := packbin.Pack(position, map[string]any{"sid": 1, "lat": 500_000_000, "lon": 300_000_000, "profile": 1})
if err != nil {
	panic(err)
}
fmt.Printf("% x\n", raw)

withHeading, err := packbin.Pack(position, map[string]any{"sid": 1, "lat": 500_000_000, "lon": 300_000_000, "profile": 1, "heading": 90})
if err != nil {
	panic(err)
}
fmt.Printf("% x\n", withHeading)

row, err := packbin.UnpackMap(withHeading, position)
if err != nil {
	panic(err)
}
fmt.Printf("%T %v\n", row["heading"], row["heading"])
_, hasSpeed := row["speed"]
fmt.Println(hasSpeed)
```

```
40 01 00 00 65 cd 1d 00 a3 e1 11 01 00
40 01 00 00 65 cd 1d 00 a3 e1 11 01 01 5a 00
uint16 90
false
```

`UnpackMap` gives every value the Go type of its field: `uint8` to `uint64` for `u8` to `u64`, `int8` to `int64`, `float32`, `float64`, `[]byte` for `bytes` and `sized`, `uint8` for a `u2` slot, `[]uint8` for `bits` and `packed`, `true` for a set `bool`, `string`, `[]any` for a list and `map[string]any` for a dict or a group. A skipped field has no key. A row it returned therefore packs again to the same bytes.

#### Go rows

**Where Go differs from TypeScript.** The Go package follows TypeScript row for row and gives the same bytes. The few differences are decisions of the owner, and each one is a refusal or a different row shape, never different bytes. They are listed here and in the Loop 24 notes under [Untrusted input](#untrusted-input).

**No value.** A `nil` value, a nil pointer, a nil slice and a nil map are no value. A stored `0` is a value and is written, an empty slice is a value with 0 items (`00 00` for a list, 0 rounds for a `Times`), and an empty string is `00 00`. A scheme binds every value field to one row type or to none. `Pack` and `UnpackMap` take and give the map form of any scheme, bound or not.

**Groups are nested maps, both ways (owner decision Go-4).** A `Group` is a `map[string]any` under its name in a map row, on pack and on unpack, whether it is anchored or sits under `flags` or a flag bit. TypeScript packs a group's members from the nested object when one is given and from the flat keys of the row around it when not, and unpacks them flat; Go does neither. `u8 a; group(g, u8 b)` packs `{"a": 1, "g": {"b": 2}}` to `01 01 02`, and unpack gives `g` as a map. The flat row `{"a": 1, "b": 2}`, which TypeScript packs to the same bytes, is refused naming `b` and `g`: a flat key that names a member of a group whose map is not given is an error, never a value dropped silently (under `flags` too). The example below packs the nested shape, shows the flat row refused, and packs a group per round:

```go
scheme, err := packbin.NewScheme(1, packbin.U8(0, "a"), packbin.Group(1, "g", packbin.U8(1, "b")))
if err != nil {
	panic(err)
}
raw, err := packbin.Pack(scheme, map[string]any{"a": 1, "g": map[string]any{"b": 2}})
if err != nil {
	panic(err)
}
fmt.Printf("% x\n", raw)

_, err = packbin.Pack(scheme, map[string]any{"a": 1, "b": 2})
fmt.Println(err != nil)

rounds, err := packbin.NewScheme(1, packbin.Repeat(0, packbin.U8(0, "k"), packbin.Group(1, "mark", packbin.U8(1, "v"))))
if err != nil {
	panic(err)
}
perRound, err := packbin.Pack(rounds, map[string]any{
	"k":    []any{1, 2},
	"mark": []any{map[string]any{"v": 7}, map[string]any{"v": 8}},
})
if err != nil {
	panic(err)
}
fmt.Printf("% x\n", perRound)
```

```
01 01 02
true
01 01 07 02 08
```

A group in a `Repeat` or `Times` round takes one map a round, `"mark": []any{map[string]any{"v": 7}, map[string]any{"v": 8}}` above; TypeScript slices the lists inside one group object per round instead (`{k: [1, 2], mark: {v: [7, 8]}}`), and that shape is a Go error. A lone map given once goes to every round when it holds scalars, and a list or dict inside it is refused, because Go cannot slice it per round. A group whose bit is set by being given is on even when a false `when` inside it writes nothing: `u8 mode; flags(group(g, when(mode == 1, u8 speed)), u16 heading)` with `mode` 0 and `heading` 90 packs `{"mode": 0, "g": {"speed": 7}, "heading": 90}` to `01 00 03 5a 00` (as TypeScript's nested form does) and a row with neither `g` nor `speed` to `01 00 02 5a 00`. TypeScript also packs the flat row `{"mode": 0, "speed": 7, "heading": 90}` to `01 00 02 5a 00` and drops `speed`; Go refuses that row naming `speed`. Unpacking `01 00 03 5a 00` gives `g` as an empty map.

**A `Nested` row has a scope of its own.** `Nested(name, members...)` is a row inside the row, a `map[string]any` under its name or a struct bound with `Bind`. Its members have ids, references and names of their own, so a member may repeat a name of the row around it:

```go
scheme, err := packbin.NewScheme(1, packbin.U8(0, "mode"), packbin.Nested("in", packbin.U8(0, "mode"), packbin.U8(1, "x")))
if err != nil {
	panic(err)
}
raw, err := packbin.Pack(scheme, map[string]any{"mode": 1, "in": map[string]any{"mode": 2, "x": 3}})
if err != nil {
	panic(err)
}
fmt.Printf("% x\n", raw)
```

```
01 01 02 03
```

C# gives a nested row its own scope too. TypeScript refuses the same names for its flat, unanchored group (`declared inside a group and outside it`), and the anchored `Group` of Go still refuses a name shared with the row around it, because its members share the scope. The items of a `List` or `Dict` whose element is a `Nested` or `Flags` are `map[string]any` in a map row (TypeScript takes any object).

**Integers, `bool` and floats in a map row.** An integer field refuses a float, a whole `5.0` too (`expected an integer for u8, got float64`), as C# does since loop 21 (owner decision Go-2). TypeScript packs it, because JavaScript cannot tell 5.0 from 5. A map built by `json.Unmarshal` holds every number as `float64`, so it is refused for integer fields: unmarshal into a typed row, or convert the values to integers first. A `Bool` takes a Go `bool` and nothing else: `1` or `"yes"` is refused naming the field (owner decision Go-1; C# and TypeScript leave the bit clear for such a value). A float field takes any Go integer or float. `u64` and `i64` above 2^53 are exact in Go and pack as they are (TypeScript wants a `bigint` there), and a `u64` count above 2^53 is a real count that ends in a short read, where TypeScript calls it unreadable.

**Byte slices.** `Bytes` and `Sized` take a `[]byte`. A `[]byte` is a byte run and never a list: given to a `List` in a map row, or as the list of rounds of a name in a `Repeat` or `Times`, it is refused (a `Uint8Array` is not an Array in TypeScript either), and so is `[]uint8{1, 2}` for a `u8` member of a round; use a `[]any` or a `[]int` there. A typed `[]byte` member bound to `List(U8(...))` works, as it holds the items of the list.

**Typed rounds.** A typed `Repeat` or `Times` binds a `[]E` or `[]*E` of a struct `E` to the round, one element a round, and the members of the round to `E`. A nil slice is no value, an empty slice is 0 rounds, and a typed `Times` refuses a count that differs from the number of elements, naming the member (`the times count is 3, but the row holds 2 rounds`), as C# does. The map form keeps the TypeScript rules (a list longer than the count is refused; a shorter one for a member under `flags` reads as absent for the rounds it does not reach).

**Strings, lists and dicts.** A Go string that is not valid UTF-8 is refused on pack, naming the field (a JavaScript string cannot hold one), and a string over 65,535 bytes or a list or dict over 65,535 items is refused as in the others. In a map row a list is a `[]any` or any slice but `[]byte`, and a dict is a `map[string]any` or any map with string keys; the keys are written in UTF-8 byte order.

**A split flag bit inside a false `when`.** `u8 k; flagbyte m; when(k == 1, bit m { u8 a }); bit m { u8 b }` with `k` = 0, `a` = 5 and `b` = 6 packs `01 00 03 06`: the bit of `a` is set though `a` is not written, and the row that unpack gives back packs to `01 00 02 06`. Go copies TypeScript here (owner decision Go-3), a test pins it, and the other packages are still to be probed for it (loop 24 assessment).

**Limits.** A scheme carries three limits, `MaxRounds` (65,535), `MaxSlots` (1,048,576) and `MaxBytes` (16,777,216), as a `Limits` value: `DefaultLimits()` returns the defaults and `scheme.Limits()` reads the ones of a scheme. `scheme.WithLimits(limits)` returns a copy with them. It takes all three values every time and refuses a field below 1 (`Limits{}` too) with an `InvalidScheme` error, where C#, TypeScript and Python default an omitted value, so start from `DefaultLimits()` and change the one you need. A packet past `MaxRounds`, or past `MaxSlots` in all the rounds of one call, is refused when the round would start, before its bytes are read, with a `TooMany` error. See [Untrusted input](#untrusted-input).

```go
scheme, err := packbin.NewScheme(1, packbin.Repeat(0, packbin.U8(0, "k")))
if err != nil {
	panic(err)
}
limits := packbin.DefaultLimits()
limits.MaxSlots = 16_000_000
raised, err := scheme.WithLimits(limits)
if err != nil {
	panic(err)
}
fmt.Println(raised.Limits())

_, err = scheme.WithLimits(packbin.Limits{MaxRounds: 200_000})
fmt.Println(err != nil)
```

```
{65535 16000000 16777216}
true
```

**Errors are values.** Every error is an `*packbin.Error` with a `Kind` (`ShortPacket`, `TrailingBytes`, `UnknownType`, `BadValue`, `InvalidScheme`, `PackRefused` or `TooMany`) and, where they apply, the field id and name, `Needed`, `Left`, `Actual` and a reason. `errors.Is(err, packbin.ErrShortPacket)` and the other sentinels match by kind. A refused pack returns nil bytes, never part of a packet. Error messages differ in form from the other packages (`1e+20` where C# prints the long integer, Go type names), so test for the kind and not for the text.

**Concurrency.** A built `Scheme` is immutable and safe for concurrent `Pack` and `Unpack` from any number of goroutines. A `PackSession` is safe for concurrent use; payloads are numbered in the order the `Pack` calls take its lock, so the receiver must `Unpack` them in that order (concurrent senders serialise their sending in the same order, or send the position themselves).

**Schemes Go refuses and TypeScript builds.** `NewScheme` reports a ninth member of one `Flags` (TypeScript throws at `flags()`), and it refuses the two hostile schemes `zero_progress_repeat_bool` (a `bool` outside `flags`) and `zero_progress_repeat_when` (a `when` that names a field outside its `repeat`), which TypeScript builds and unpacks to trailing bytes; both hostile cases accept `scheme_error`.

## Example

Swift → binary → TypeScript

### Swift

Swift has no registry upload here: Swift Package Manager fetches the package from this repository by the version tag `vX.Y.Z` and reads the `Package.swift` at its root (SwiftPM drops the `v`). There is no Swift tag and no Swift Package Index listing (ADR-005). After every language has matched the golden hex, the release run checks that a new package resolves and builds that tag (on Linux); a golden mismatch publishes nothing, and a tag that does not resolve and build fails the run. A Swift version is never moved or deleted: a bad one is replaced by the next patch version. Swift versions start with the first release tag published after the Swift package was added.

Add to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/zxsanny/packbin", from: "X.Y.Z"),
],
targets: [
    .target(name: "App", dependencies: [.product(name: "Packbin", package: "packbin")]),
]
```

Swift 6.0 or newer (`swift-tools-version: 6.0`; Xcode 16 or newer on Apple platforms), iOS 15 and macOS 12 or newer, and Linux. The package builds in the Swift 6 language mode. CI runs the Swift suite in the `swift:6.3.3` image on Linux, and the publish position test was also run once in `swift:6.4.1`; no older toolchain is built or tested. Limit: a Swift 6.0 consumer and an Xcode 16.0 build are unproven, because the dependency `swift-asn1` 1.7.3 (pulled in by `swift-crypto`) declares `swift-tools-version: 6.1`, so a 6.0 toolchain may not resolve the newest one and no 6.0 resolve was run; the manifest minimum 6.0 is a declared value, not a tested one. tvOS and watchOS are not built or tested (the session needs tvOS 14 or watchOS 7). The package has one dependency, [`swift-crypto`](https://github.com/apple/swift-crypto) (exactly 4.3.1), for the HKDF-SHA256 of the session where CryptoKit is missing. SwiftPM resolves and clones it, and its dependency `swift-asn1`, on every platform, but links it only on Linux, Android, Windows and WASI; on Apple platforms the session uses CryptoKit. The ChaCha20 of the session is written in the package and checked against RFC 8439.

The module is `Packbin` (`import Packbin`). The Swift snippets in this README are the bodies of the tests in [`swift/Tests/PackbinTests/ReadmeExampleTests.swift`](swift/Tests/PackbinTests/ReadmeExampleTests.swift), copied unchanged without the indentation (the first one with the import): `swift test` runs them, compares what they print with the output shown under each, and fails when a snippet here differs from its test. A row is a typed struct bound field by field with `bind(get:set:)`, or a `[String: Any]`.

```swift
import Packbin

struct Position: PackbinRow {
    var sid: UInt16 = 0
    var lat: Int32 = 0
    var lon: Int32 = 0
    var profile: UInt8 = 0
    var heading: UInt16?
    var speed: UInt8?
    var altitude: Int16?
}

func hex(_ bytes: [UInt8]) -> String {
    bytes.map { $0 < 0x10 ? "0" + String($0, radix: 16) : String($0, radix: 16) }.joined(separator: " ")
}

let position = try Scheme(0x40,
    .u16(0, "sid").bind(get: { (r: Position) in r.sid }, set: { $0.sid = $1 }),
    .i32(1, "lat").bind(get: { (r: Position) in r.lat }, set: { $0.lat = $1 }),
    .i32(2, "lon").bind(get: { (r: Position) in r.lon }, set: { $0.lon = $1 }),
    .u8(3, "profile").bind(get: { (r: Position) in r.profile }, set: { $0.profile = $1 }),
    .flags(4,
        .u16(4, "heading").bind(get: { (r: Position) in r.heading }, set: { $0.heading = $1 }),
        .u8(5, "speed").bind(get: { (r: Position) in r.speed }, set: { $0.speed = $1 }),
        .i16(6, "altitude").bind(get: { (r: Position) in r.altitude }, set: { $0.altitude = $1 })))

let raw = try pack(position, Position(sid: 1, lat: 500_000_000, lon: 300_000_000, profile: 1))
print(hex(raw))

if let got = try unpack(raw, position) as? Position {
    print(got.lat, got.heading == nil)
}
```

```
40 01 00 00 65 cd 1d 00 a3 e1 11 01 00
500000000 true
```

The first line is the 13-byte packet of the first example (Python → binary → TypeScript; `fixtures/golden.hex`, the same bytes without the spaces). `heading`, `speed` and `altitude` are optionals: `nil` is no value, so its bit in `motion` stays clear and the field takes no space, and a stored 0 is a value and is written. A bound scheme packs a `Position`, and `unpack` returns it as `Any`. `Scheme` throws a `PackbinError` naming the field id for a gap, a repeated id or a wrong anchor.

The same scheme without a struct reads and writes a `[String: Any]` keyed by the field names (`hex` is the function above). An integer field takes any Swift integer type that holds the value. `heading`, `speed` and `altitude` are optional under `flags` here too: a key that is missing or `nil` leaves the bit clear, and `"heading": 90` sets bit 0 and writes `5a 00` after `motion`.

```swift
let position = try Scheme(0x40,
    .u16(0, "sid"),
    .i32(1, "lat"),
    .i32(2, "lon"),
    .u8(3, "profile"),
    .flags(4, .u16(4, "heading"), .u8(5, "speed"), .i16(6, "altitude")))

let raw = try pack(position, ["sid": 1, "lat": 500_000_000, "lon": 300_000_000, "profile": 1])
print(hex(raw))

let withHeading = try pack(position, ["sid": 1, "lat": 500_000_000, "lon": 300_000_000, "profile": 1, "heading": 90])
print(hex(withHeading))

let row = try unpackMap(withHeading, position)
if let heading = row["heading"] {
    print(type(of: heading), heading)
}
print(row["speed"] == nil)
```

```
40 01 00 00 65 cd 1d 00 a3 e1 11 01 00
40 01 00 00 65 cd 1d 00 a3 e1 11 01 01 5a 00
UInt16 90
true
```

`unpackMap` gives every value the Swift type of its field: `UInt8` to `UInt64` for `u8` to `u64`, `Int8` to `Int64`, `Float`, `Double`, `[UInt8]` for `bytes`, `sized`, `bits` and `packed`, `UInt8` for a `u2` slot, `true` for a set `bool`, `String`, `[Any]` for a list, `[String: Any]` for a dict or a group, and `[Any?]` with one entry a round for a name in a `repeat` or `times`. A skipped field has no key, so a row it returned packs again to the same bytes.

#### Swift rows

**Where Swift differs from TypeScript.** The Swift package follows TypeScript row for row and gives the same bytes. Where it differs, it follows the owner's Go decisions or Swift's types, and each difference is a refusal or a different row shape, never different bytes. They are listed here and in the Loop 26 notes under [Untrusted input](#untrusted-input).

**No value.** `nil` (a missing key, a boxed `nil`, a getter that returns `nil`) is no value, and only a flag bit can leave a value out. A stored 0 is a value and is written, and an empty array, dictionary or string is a value with count 0 (`00 00` for a list, 0 rounds for a `times`).

**Typed rows.** A typed row conforms to `PackbinRow` (it has an `init()`). Every value field of one row is bound with `bind(get:set:)` to the same row type, or none is. A member type must hold every value of its field (an `Int` for a `u16`, not a `UInt8`), or the scheme is refused when it is built. A group binds a `PackbinRow` (or an optional of one), a list an array, a dict a `[String: E]`, and a `repeat` or `times` an array of a `PackbinRow`, one element a round; a typed `times` refuses a count other than the number of elements, as in C# and Go. `pack` and `unpackMap` take and give the map form of any scheme, bound or not.

**Groups are nested maps, both ways (owner decision Go-4, as Go).** In a map row a group's members are a `[String: Any]` under the group's name, on pack and on unpack: `["a": 1, "g": ["b": 2]]`. TypeScript also packs the members from flat keys of the row around it and unpacks them flat; in Swift a flat key that names a member of a group whose map is not given is refused, never dropped. A group in a `repeat` or `times` round takes one map a round, and a list or dict inside a lone group map given once for every round is refused. `.group(name, members...)` without an anchor is a nested row: its members have ids, references and names of their own, so they may repeat a name of the row around it, as in C# and Go (TypeScript refuses that; the anchored group still does).

**Integers, `Bool` and floats in a map row.** An integer field takes any Swift integer type whose value fits. A `Bool` or a `Double` (a whole `2.0` too) for an integer field, and an integer or a string for a `bool`, are refused naming the field (owner decisions Go-1 and Go-2; TypeScript packs the float and leaves the bit clear). A Swift enum case is refused for an integer field; pass its `rawValue`. A Foundation `NSNumber` (from `JSONSerialization`) is read as the `Bool`, integer or float it was made from. A float field takes any integer or float. `Condition.eq` takes an integer or a `Bool` only.

**Byte arrays.** `.bytes` and `.sized` take a `[UInt8]`. A `[UInt8]` is a byte run and never a list: given to a `.list` in a map row, or as the list of rounds of a name in a `repeat` or `times`, it is refused. A typed `[UInt8]` member bound to a list of `u8` holds the items, and the items of `bits` and `packed` may be given as a `[UInt8]`.

**Dictionaries.** Keys are written in unsigned UTF-8 byte order, not in Swift's `String` order. Swift compares strings by canonical equivalence, so two keys whose bytes differ but that are equal as Swift strings (an NFC and an NFD form) cannot both be in a `[String: Any]`: unpack refuses such a packet (`dict key given twice`), and pack refuses a Foundation dictionary that holds both. TypeScript keeps both. A key that is not in Unicode's stream-safe form (more than 30 combining marks in a row, which Swift would reorder in quadratic time each time it hashes the key) is refused: by unpack as a key that is not UTF-8 is (`.short`, `needed` 0), and by pack naming the dict; the other packages compare key bytes and take it.

**Limits.** A scheme carries `maxRounds` (65,535), `maxSlots` (1,048,576) and `maxBytes` (16,777,216); `Scheme.defaultMaxRounds`, `defaultMaxSlots` and `defaultMaxBytes` are the defaults. `scheme.withLimits(maxRounds:maxSlots:maxBytes:)` returns a copy. A limit left out takes its default, not the scheme's current value, so give every limit you change in one call (as in C#, TypeScript and Python), and a value below 1 throws a `.schemeError`. Unpack refuses a round past a limit when it would start, before its bytes are read, with `.tooMany` and `needed` 0. See [Untrusted input](#untrusted-input).

**Errors are thrown.** Every error is a `PackbinError` with a `kind` (`.short`, `.trailing`, `.unknownType`, `.badValue`, `.tooMany`, `.schemeError` or `.packError`) and, where they apply, `field`, `name`, `needed`, `left`, `actual` and `reason`. The functions are declared `throws` with no error type, so catch it with `catch let error as PackbinError`. A refused pack returns no bytes. Unpack never throws `.badValue`: a value it cannot use (a negative count, invalid UTF-8, a count behind a clear flag bit) is `.short` with `needed` 0, as in TypeScript and Go. No input traps: every read is bounds-checked and every size is computed with checked arithmetic. Messages differ in form from the other packages, so test for the kind and not for the text.

**Concurrency.** A built `Scheme` is immutable and `Sendable`: any number of tasks can pack and unpack with one scheme at once. A `PackSession` is a class and not `Sendable`: it is used by one task at a time.

**Schemes Swift refuses and TypeScript builds.** A `.bytes` with a negative size, a `u2` or a flag byte as a list or dict element, and the two hostile schemes `zero_progress_repeat_bool` and `zero_progress_repeat_when` (both hostile cases accept `scheme_error`). A list or dict whose element writes no byte (`.list("l", .bytes(0, "e", size: 0))`) packs, and unpack refuses the packet, as in TypeScript.

## Error correction

A scheme can declare `n` parity bytes, 0 to 32 (default 0). Pack appends them to the packed message; unpack detects any corruption of up to `n` wrong bytes and can repair up to `t` of them. A wrong byte counts once however many of its bits flipped. The code is Reed-Solomon over GF(256) and also covers the clear length, which is not sent, so a message with one byte more or less is refused. The format is the contract [`message-ecc.md`](_docs/02_document/contracts/library/message-ecc.md) (ADR 007).

- **Off by default.** With `n` = 0 the bytes, the errors and the speed are those of a scheme without the setting.
- **`n` is not on the wire.** Both sides declare the same `n`, as they share the field list.
- **`t` is the receiver's choice, 0 to `n / 2`, default 0 (detect only).** A `t` above `n / 2` is refused before any byte is read. Beyond `t` wrong bytes unpack gives an error that names no field and no row, never a wrong row.
- **Repairing costs detection.** With `t` > 0 corruption of `t + 1` to `n - t` bytes is still refused, but a larger corruption may be repaired to a different message. For the 13-byte fixture with `n` = 4, random bytes pass with a chance of 1 in 4.29e+09 at `t` = 0, 1 in 990,537 at `t` = 1 and 1 in 485 at `t` = 2 (the contract lists every `n` and `t`). Use `t` = 0 unless a lost message costs more than a wrong one.
- **At most 254 bytes per message, parity included.** Pack refuses a clear message above `254 - n` bytes, writes nothing, and names the length and the limit. Unpack refuses a buffer above 254 bytes and a buffer shorter than `n` (a short-packet error naming the field `parity`).
- **One `n` per unpack call.** The handlers (or schemes) of one call must declare the same `n`: the type byte can be one of the wrong bytes, so the message is repaired first and then dispatched. A mix is refused, naming both counts.
- **Sessions.** The parity covers the padded bytes, so a payload is `n` bytes longer than the clear packet and is repaired before the pad is removed. The receive position advances for every payload read, a refused one included. Without parity a session still detects nothing.

`withLimits` / `with_limits` keep a scheme's parity count unless `parity` is given. The packages spell the setting and the result differently:

| Package | Declare `n` | Unpack with `t` | Repaired count | Too many wrong bytes |
|---------|-------------|-----------------|----------------|----------------------|
| Python | `scheme.with_limits(parity=n)`, `scheme.parity` | `BinaryPacker.unpack(data, *handlers, limit=t)`, `PackSession.unpack(..., limit=t)` | `UnpackResult.repaired` | `Uncorrectable()` in `UnpackResult.error` (`TooLong(length, limit)` above 254 bytes) |
| TypeScript | `scheme.withLimits({ parity: n })`, `new Scheme(type, fields, { parity: n })`, `scheme.parity` | `BinaryPacker.unpackRepair(bytes, t, ...handlers)`, `PackSession.unpackRepair` | `repaired` in `{ ok: true, repaired }` (protected schemes only) | `{ ok: false, kind: "uncorrectable" }` (`kind: "too_long"` with `length`, `limit`) |
| C# | `scheme.WithParity(n)`, `scheme.Parity` | `BinaryPacker.Unpack(bytes, t, out repaired, handlers)`, `PackSession.Unpack(bytes, t, out repaired, handlers)` | `out int repaired` | `Uncorrectable` returned (`TooLong` with `Length`, `Limit`) |
| Rust | `scheme.with_parity(n)`, `scheme.parity()`, `MAX_PARITY` | `BinaryPacker::unpack_with_repair(bytes, handlers, t)`, `unpack_repair(&map_scheme, bytes, t)`, `PackSession::unpack_repair` | the `usize` in `Ok` (beside the values for `unpack_repair`) | `UnpackError::Uncorrectable` (`TooLong { len, limit }`, `BadLimit`, `BadParity { parity, max }`, `MixedParity`, `NoHandlers`) |
| Java | `scheme.withParity(n)`, `scheme.parity()` | `BinaryPacker.unpackRepair(bytes, t, handlers...)`, `PackSession.unpackRepair` | `Packbin.Repaired.count` (what `unpackRepair` returns on success) | `Packbin.Uncorrectable` returned (`Packbin.TooLong` with `length`, `limit`) |
| Go | `s.WithParity(n)`, `s.Parity()`, `MaxParity` | `UnpackRepair(buf, t, schemes...)`, `UnpackMapRepair`, and the same on `PackSession` | second return value | `*Error` of kind `Uncorrectable`, `ErrUncorrectable` (above 254 bytes: kind `TooMany`) |
| Swift | `scheme.withLimits(parity: n)`, `scheme.parity` | `unpackRepair(buffer, limit: t, schemes...)`, `unpackMapRepair`, and the same on `PackSession` | `repaired` in the returned tuple | `PackbinError` of kind `.uncorrectable` (above 254 bytes: `.tooMany`) |
| C++ | `parity(scheme<Row>(...), n)`, `scheme.parity` | `unpack_repair(scheme, data, len, row, t)`, `unpack_repair(data, len, t, on(...)...)`, `PackSession::unpack_repair` (the buffer is non-const) | `Result.repaired` | `Error::Uncorrectable` (above 254 bytes: `Error::TooMany`) |

A `parity` outside 0 to 32, a limit above `n / 2` and a mix of counts are refused as the package refuses a bad scheme: a `ValueError` (Python), a `RangeError` (TypeScript), an `ArgumentOutOfRangeException` or `ArgumentException` (C#), a panic for `with_parity` and an `UnpackError` for the limit, the mix and a hand-written handler's count above 32 (`BadParity`) (Rust), an `IllegalArgumentException` (Java), an `InvalidScheme` error (Go), a `.schemeError` (Swift), `Error::SchemeInvalid` for `n` and for a mix of counts and `Error::BadValue` for the limit (C++; a `constexpr` scheme with `n` above 32 does not compile). A clear message above `254 - n` bytes at pack is the package's pack refusal (`PackRefused` in Go, `.packError` in Swift, `PackError::Type` in Rust, `Error::TooMany` in C++, with `offset` the clear length, `needed` the limit and the written bytes zeroed).

Each example packs a 3-byte message (type byte and a `u16`) with `n` = 4, flips one byte and unpacks with `t` = 2. The message is 7 bytes and one byte is repaired.

### Python

```python
from packbin import BinaryPacker, Scheme, u16

class Reading:
    def __init__(self):
        self.level = 0

reading = Scheme(2, Reading, u16(0, lambda row: row.level)).with_limits(parity=4)

row = Reading()
row.level = 7
raw = bytearray(BinaryPacker.pack(reading, row))   # 7 bytes
raw[1] ^= 0x55                                     # one wrong byte

got = []
result = BinaryPacker.unpack(raw, reading.on(got.append), limit=2)
print(result.ok, result.repaired, got[0].level)    # True 1 7
```

### TypeScript

```ts
import { BinaryPacker, scheme, u16, type SchemeHandler } from "packbin"

class Reading {
  level = 0
}

const reading = scheme<Reading>(2, u16(0, (x: Reading) => x.level)).withLimits({ parity: 4 })

const row = new Reading()
row.level = 7
const raw = BinaryPacker.pack(reading, row) // 7 bytes
raw[1]! ^= 0x55 // one wrong byte

let got: Reading | undefined
const result = BinaryPacker.unpackRepair(raw, 2, reading.on((r) => { got = r }) as SchemeHandler<any>)
console.log(result, got?.level) // { ok: true, repaired: 1 } 7
```

### C#

```csharp
using Packbin;

sealed class Reading { public ushort Level { get; set; } }

var reading = new Scheme<Reading>(2, f => [f.U16(0, x => x.Level)]).WithParity(4);

var raw = BinaryPacker.Pack(reading, new Reading { Level = 7 });   // 7 bytes
raw[1] ^= 0x55;                                                     // one wrong byte

Reading? got = null;
var error = BinaryPacker.Unpack(raw, 2, out var repaired, reading.On(row => got = row));
// error is null, repaired is 1, got.Level is 7
```

### Rust

```rust
use packbin::{BinaryPacker, BoundField, Scheme};

#[derive(Default)]
struct Reading {
    level: u16,
}

let reading = Scheme::new(2, [
    BoundField::u16(0, |row: &Reading| row.level, |row, value| row.level = value).into(),
])
.with_parity(4);

let mut raw = BinaryPacker::pack(&reading, &Reading { level: 7 }).unwrap(); // 7 bytes
raw[1] ^= 0x55; // one wrong byte

let mut got = Reading::default();
let repaired =
    BinaryPacker::unpack_with_repair(&raw, &mut [&mut reading.on(|row| got = row)], 2).unwrap();
// repaired is 1, got.level is 7
```

### Java

```java
import packbin.*;

public final class Reading { public int level; }

Scheme<Reading> reading = new Scheme<>(2, Reading.class,
        Packbin.u16(0, Access.get((Reading r) -> r.level), Access.set((Reading r, Object v) -> r.level = ((Number) v).intValue())))
        .withParity(4);

Reading row = new Reading();
row.level = 7;
byte[] raw = BinaryPacker.pack(reading, row);   // 7 bytes
raw[1] ^= 0x55;                                 // one wrong byte

Reading[] got = new Reading[1];
Object result = BinaryPacker.unpackRepair(raw, 2, reading.on(r -> got[0] = r));
// result is a Packbin.Repaired with count 1; got[0].level is 7. A failed unpack returns the error value instead.
```

### Go

```go
reading, err := packbin.NewScheme(2, packbin.U16(0, "level"))
if err != nil {
	panic(err)
}
reading, err = reading.WithParity(4)
if err != nil {
	panic(err)
}

raw, err := packbin.Pack(reading, map[string]any{"level": 7}) // 7 bytes
if err != nil {
	panic(err)
}
raw[1] ^= 0x55 // one wrong byte

row, repaired, err := packbin.UnpackMapRepair(raw, 2, reading)
if err != nil {
	panic(err)
}
fmt.Println(repaired, row["level"]) // 1 7
```

### Swift

```swift
// Packbin is imported as in the examples above.
struct Reading: PackbinRow {
    var level: UInt16 = 0
}

let reading = try Scheme(2,
    .u16(0, "level").bind(get: { (r: Reading) in r.level }, set: { $0.level = $1 })).withLimits(parity: 4)

var raw = try pack(reading, Reading(level: 7))   // 7 bytes
raw[1] ^= 0x55                                   // one wrong byte

let (row, repaired) = try unpackRepair(raw, limit: 2, reading)   // repaired == 1, (row as? Reading)?.level == 7
```

### C++

```cpp
#include <packbin/packbin.hpp>

using namespace packbin;

struct Reading { std::uint16_t level = 0; };

constexpr auto reading = parity(scheme<Reading>(2, u16<&Reading::level>(0)), 4);

Reading row;
row.level = 7;
std::uint8_t raw[16];
Result packed = pack(reading, row, raw, sizeof(raw));  // packed.offset is 7
raw[1] ^= 0x55;                                        // one wrong byte

Reading got;
Result r = unpack_repair(reading, raw, packed.offset, got, 2);
// r.ok(), r.repaired is 1, got.level is 7, and raw is the packed message again
```

With `t` = 0 (`BinaryPacker.unpack` and the other plain unpack calls) the same buffer is refused as uncorrectable. In C++ `unpack(scheme, data, len, row)` and `unpack(data, len, on(...)...)` are those detect-only calls: they take a read-only buffer, never write it, and give `Error::Uncorrectable` for any wrong byte; `unpack_repair` takes a writable buffer and a limit `t` from 0 to `n / 2` (more is `Error::BadValue` before any byte is read). `PACKBIN_NO_ECC` removes the feature and the 511 bytes of tables, and a scheme with `n` above 0 is then `SchemeInvalid`; the Cortex-M4F build defines it, because the tables and about 2.2 KB of code do not fit the 60 bytes of flash it has left (repair uses about 390 bytes of stack at `n` = 32 on a host). Unpack never throws or traps on hostile bytes: its work is at most about 3 x 255 x 32 field operations (under 0.1 ms at 254 bytes and `n` = 32 in the compiled packages) plus the unprotected walk.

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

### Go

```go
ping, err := packbin.NewScheme(2, packbin.U8(0, "code"))
if err != nil {
	panic(err)
}
seed := sharedSeed()

opener, err := packbin.LoadSession(seed)
if err != nil {
	panic(err)
}
nonce, err := opener.Start()
if err != nil {
	panic(err)
}

waiter, err := packbin.LoadSession(seed)
if err != nil {
	panic(err)
}
if err := waiter.Join(nonce); err != nil {
	panic(err)
}

payload, err := opener.Pack(ping, map[string]any{"code": 7})
if err != nil {
	panic(err)
}
got, err := waiter.UnpackMap(payload, ping)
if err != nil {
	panic(err)
}
fmt.Println(len(nonce), len(payload), got["code"])
```

```
16 2 7
```

`sharedSeed` stands for the 32 bytes both sides hold from the out-of-band exchange (the test fills it with a fixed value); `Start` draws the 16 random bytes, and `StartWith(nonce)` opens the opener side with 16 bytes the caller already holds, for tests. The payload has the length of the clear packet: 2 bytes here. `LoadSession` copies the seed, so the slice you pass is not wiped (as in TypeScript); the internal copy and the derived key block are zeroed once the session opens. A seed or value of the wrong length, a second open and a nil session are `BadValue` errors, `Pack` before `Start` or `Join` is a `PackRefused` error, and `Unpack` before `Join` is a `ShortPacket` error (needed 1, left 0). A `Pack` that fails spends no counter position. An `Unpack` spends one for every payload, readable or not, so the next message still unpacks. A packet over 2^38 bytes is refused, because the ChaCha20 counter would overflow. A `PackSession` is safe for concurrent use: payloads are numbered in the order the `Pack` calls take its lock, so the receiver must `Unpack` them in that order (concurrent senders serialise their sending in the same order, or send the position themselves).

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
  u16(0, (x: Position) => x.sid),
  i32(1, (x: Position) => x.lat),
  i32(2, (x: Position) => x.lon),
  u8(3, (x: Position) => x.profile),
)

export const ack = scheme<Ack>(
  0x41,
  u16(0, (x: Ack) => x.sid),
  u8(1, (x: Ack) => x.accepted),
)
```

`src/live/useLiveSocket.ts`:

```ts
import { onBeforeUnmount, ref } from "vue"
import { PackSession, type SchemeHandler } from "packbin"
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
      const result = session!.unpack(ev.data, ack.on((row) => (lastAck.value = row)) as SchemeHandler<any>)
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

## Frame session

The encrypted session above is a stream: it needs packets in order, none lost, and it does not detect a changed byte. For a radio link (frames are lost, reordered and duplicated, anyone can write to the channel) the session has a second mode, `frame`. Each message carries a caller-supplied 8-byte `msg_id`; the keys come from the caller's 32-byte key and a 24-bit `epoch` with nothing sent first; the body is `clear part, ciphertext, tag` with a tag of 4, 8 or 16 bytes (a truncated HMAC-SHA256, checked before any plaintext is written, with a constant-time compare where the runtime allows); a 64-message replay window the caller owns refuses duplicates and old frames before any hashing; an optional previous key opens frames sealed just before a key change; and a MAC-only call gives a 4-byte tag over a message in parts, for a per-hop check. Stream mode, clear pack and their bytes do not change; only the frame body carries a tag (ADR-008).

**For one key, epoch and direction, never seal two different messages with the same `msg_id`.** A reused `msg_id` breaks the confidentiality of both messages, and packbin cannot check it. meshbell builds `msg_id` from the source (2 bytes), the id field (2 bytes) and the creation wave (4 bytes); sequences restart every wave, waves never repeat and source ids are never reissued, so it is unique. A new epoch derives new keys and nonces.

The byte-for-byte definition, the replay rules and the error kinds (`TagMismatch`, `Duplicate`, `TooOld` besides the existing ones) are in `_docs/02_document/contracts/library/pack-session.md` (2.0.0); the shared test rows are in `fixtures/frame/vectors.txt`. Rust is the first package (Cargo feature `frame`, no heap, no panic path, 20 KB of flash and 2 KB of stack on a Cortex-M4F); C#, Java and Swift follow below with the same bytes (they pass the same `fixtures/frame/vectors.txt`). In those three the frame API is a `FrameSession` type beside `PackSession`, with a `ReplayWindow` you own and a `MacKey`; `Load` and `Derive` return null (C#, Java) or throw `badValue` (Swift) for an out-of-range key, epoch, tag length or label. Keys are wiped when you call `Dispose` (C#) or `close()` (Java, Swift) and, in Swift, when the session is released; C# and Java have no finalizer, so a session you never dispose keeps its keys until the garbage collector reuses the memory, and a managed runtime may keep copies as well, and the tag compare uses the platform's fixed-time compare (C# on .NET 10, Java) or a fold without an early exit, but a JIT is not under the library's control, so both are best effort.

### Rust

```rust
use packbin::nostd::{Direction, Directions, Fault, FrameConfig, MacKey, MsgCtx, ReplayWindow, Session};

fn main() -> Result<(), Fault> {
    let key = [0x11u8; 32];
    let config = FrameConfig { tag_len: 4, directions: Directions::NONE.with(Direction::Up) };
    let node = Session::load_frame(&key, 1, config)?;
    let ctx = MsgCtx { msg_id: [0, 0x30, 0x10, 0x05, 0xe8, 3, 0, 0], kind: 4 };
    let ad = [0u8, 1, 0, 0x30, 0x10, 0x05, 0xe8, 3, 0, 0, 4]; // the header: authenticated, not sent

    let mut body = [0u8; 255];
    let n = node.seal_frame(Direction::Up, &ctx, &ad, &[], b"hello, relay", &mut body)?;
    assert_eq!(n, 12 + 4); // the plaintext and a 4-byte tag

    let mut window = ReplayWindow::new();
    let mut plain = [0u8; 255];
    let opened = node.open_frame(Direction::Up, &ctx, &ad, &body[..n], 0, Some((&mut window, 7)), &mut plain)?;
    assert_eq!(&plain[..opened.plain_len], b"hello, relay");
    // the same frame again is a duplicate: refused before any hashing
    assert!(node.open_frame(Direction::Up, &ctx, &ad, &body[..n], 0, Some((&mut window, 7)), &mut plain).is_err());

    // the MAC-only call: a 4-byte tag over a message in parts
    let mac = MacKey::derive(&[0x22; 32], 7, b"net")?;
    let mut tag = [0u8; 4];
    mac.tag(&[b"wave", b"frame bytes"], &mut tag)?;
    assert!(mac.verify(&[b"wave", b"frame bytes"], &tag));
    Ok(())
}
```

The Cargo feature is `frame` (`packbin = { version = "...", default-features = false, features = ["frame"] }` builds `#![no_std]` with frame mode only). The same example runs as a doc test of the crate. A node that is short of stack declares `Session::frame_unloaded()` where it lives and calls `load_frame_in_place` on it.

### C#

`FrameSession.Seal` and `Open` write into buffers you own and return `null` on success or the error object (`BadValue`, `TooLong`, `BufferFull`, `ShortPacket`, `TagMismatch`, `Duplicate`, `TooOld`). `Seal` is safe from many threads; `SetPrevious`, `ClearPrevious` and `Dispose` must not run beside a `Seal` or `Open`. The library builds for `net10.0` and `netstandard2.0`.

```csharp
// A 32-byte key shared by the nodes, an epoch (0 to 0xFFFFFF) and a tag of 4, 8 or 16 bytes.
byte[] key = new byte[32]; // use a random key from your key store
using var node = FrameSession.Load(key, 1, new FrameConfig(4, FrameDirections.Up | FrameDirections.Down))!;

// msg_id: 8 bytes that are unique per (key, epoch, direction) for every message ever sealed.
var message = new MsgContext(new byte[] { 0, 0x30, 0x10, 0x05, 0xe8, 3, 0, 0 }, kind: 4);
byte[] header = [0, 1, 0, 0x30, 0x10, 0x05, 0xe8, 3, 0, 0, 4]; // authenticated, not sent

var body = new byte[255];
var error = node.Seal(FrameDirection.Up, message, header, [], "hello, relay"u8, body, out var length);
// error is null, or BadValue, TooLong or BufferFull; length is the body length (12 + 4 here)

// The receiver keeps one ReplayWindow per sender and passes a counter that comes from authenticated bytes.
var window = new ReplayWindow();
var plain = new byte[255];
var opened = node.Open(FrameDirection.Up, message, header, body.AsSpan(0, length), 0, plain, out var result, window, counter: 7);
// opened is null, or TagMismatch, Duplicate, TooOld, ShortPacket, TooLong, BufferFull or BadValue
// plain[..result.PlainLength] is the text and result.Slot says which key opened it
var again = node.Open(FrameDirection.Up, message, header, body.AsSpan(0, length), 0, plain, out _, window, counter: 7); // Duplicate

// The MAC-only call: a 4-byte network check over a message given in parts.
using var network = MacKey.Derive(key, 1, "net"u8)!;
var tag = new byte[4];
network.Tag(new ReadOnlyMemory<byte>[] { new byte[] { 1, 2, 3, 4 }, body.AsMemory(0, length) }, tag);
var valid = network.Verify(new ReadOnlyMemory<byte>[] { new byte[] { 1, 2, 3, 4 }, body.AsMemory(0, length) }, tag);
```

### Java

`FrameSession.seal` and `open` return a `Sealed` or `Opened` result, or an error object (`Packbin.BadValue`, `TooLong`, `BufferFull`, `ShortPacket`, `TagMismatch`, `Duplicate`, `TooOld`); `seal` leaves the output untouched on a refusal. The code stays within Android API level 26.

```java
byte[] key = new byte[32]; // the shared 32-byte key, from your key store
byte[] msgId = {0, 0x30, 0x10, 0x05, (byte) 0xe8, 3, 0, 0}; // unique per (key, epoch, direction), never reused
byte[] header = {0, 1, 0, 0x30, 0x10, 0x05, (byte) 0xe8, 3, 0, 0, 4}; // authenticated, not sent

try (FrameSession node = FrameSession.load(key, 1, 4, FrameSession.UP)) { // epoch 1, 4-byte tag; null if out of range
    MsgContext ctx = new MsgContext(msgId, 4);
    byte[] body = new byte[255];
    FrameSession.Sealed sealed = (FrameSession.Sealed) node.seal(FrameSession.UP, ctx, header, null,
            "hello, relay".getBytes(StandardCharsets.US_ASCII), body); // body = ciphertext + 4-byte tag

    ReplayWindow window = new ReplayWindow(); // one per sender, yours to keep
    byte[] plain = new byte[255];
    long counter = 7; // from bytes the tag covers, e.g. the message id
    Object opened = node.open(FrameSession.UP, ctx, header, Arrays.copyOf(body, sealed.length), 0, window, counter, plain);
    int plainLength = ((FrameSession.Opened) opened).plainLength; // plain[0, plainLength) holds the message
    Object again = node.open(FrameSession.UP, ctx, header, Arrays.copyOf(body, sealed.length), 0, window, counter, plain);
    boolean duplicate = again instanceof Packbin.Duplicate; // refused before any MAC; also TagMismatch, TooOld, ...

    try (MacKey net = MacKey.derive(key, 1, "net".getBytes(StandardCharsets.US_ASCII))) { // MAC-only call
        byte[] tag = new byte[4];
        net.tag(tag, new byte[] {1, 0, 0, 0}, body); // the message may be passed in parts
        boolean valid = net.verify(tag, new byte[] {1, 0, 0, 0}, body); // best-effort constant-time compare
    }
}
```

### Swift

`FrameSession.seal` and `open` throw `PackbinError` with the kinds `badValue`, `tooLong`, `short`, `bufferFull`, `tagMismatch`, `duplicate` and `tooOld`; `FrameSession` and `MacKey` are `Sendable` and `seal`, `open`, `tag` and `verify` may run on many threads at once.

```swift
// Load once: the keys of each direction are derived here. One tag length (4, 8 or 16) per key.
let key = [UInt8](repeating: 0x11, count: 32)
let node = try FrameSession.load(key: key, epoch: 1, config: FrameConfig(tagLength: 4))

// A message id that is never sealed twice with other contents under one (key, epoch, direction).
let context = MsgContext(msgID: [0, 0x30, 0x10, 0x05, 0xe8, 3, 0, 0], kind: 4)
let ad: [UInt8] = [0, 1, 0, 0x30, 0x10, 0x05, 0xe8, 3, 0, 0, 4]  // authenticated, not sent

// Seal into your own buffer: clear part, then ciphertext, then the 4-byte tag.
var body = [UInt8](repeating: 0, count: 255)
let length = try node.seal(direction: .up, context: context, ad: ad, clear: [],
                           plain: Array("hello, relay".utf8), into: &body)  // 12 + 4 bytes

// Open with the sender's replay window. The counter must come from bytes the tag covers.
var window = ReplayWindow()
var plain = [UInt8](repeating: 0, count: 255)
let opened = try node.open(direction: .up, context: context, ad: ad, body: Array(body[0..<length]),
                           clearLength: 0, window: &window, counter: 7, into: &plain)
// opened.slot == .current, String(decoding: plain[0..<opened.plainLength], as: UTF8.self) == "hello, relay"

// The same frame again is refused before any MAC is computed.
var replayKind: PackbinError.Kind?
do {
    _ = try node.open(direction: .up, context: context, ad: ad, body: Array(body[0..<length]), clearLength: 0,
                      window: &window, counter: 7, into: &plain)
} catch let error as PackbinError {
    replayKind = error.kind  // .duplicate
}

// MAC-only: a 4-byte network check over a wave number and the frame bytes, hashed in parts.
let net = try MacKey.derive(key: [UInt8](repeating: 0x22, count: 32), epoch: 7, label: Array("net".utf8))
let wave: [UInt8] = [0xe8, 3, 0, 0]
let frame: [UInt8] = Array(0xc0...0xd3)
let tag = try net.tag([wave, frame], length: 4)  // 56db9bec
let valid = net.verify([wave, frame], tag: tag)
```

## Data types

| Helper | What it writes |
|--------|----------------|
| `u8` `u16` `u32` `u64` | unsigned integer, little-endian |
| `i8` `i16` `i32` `i64` | signed integer, little-endian |
| `f32` `f64` | IEEE 754 float |
| `bytes(n)` | exactly `n` raw bytes |
| `be(field)` | that number, big-endian |
| `utf8` | text in the compact text format: a varint payload length, then a bit-packed payload (see [UTF-8](#utf-8)) |
| `list` | `u16` count, then that many elements |
| `dict` | `u16` pair count; keys in strictly ascending unsigned byte order (unpack refuses a repeated or out-of-order key) |
| `flags(anchor, fields)` | one `u8`; bit 0 is the first field; a clear bit omits that field; at most 8 fields; the anchor is not written |
| `bool` | a flag bit with no payload; set only for `true`; allowed only directly under `flags` or a flag-byte bit |
| `when(anchor, eq(id, value), fields)` | the group only when an earlier field of the same scope equals `value`; the anchor is not written |
| `repeat(anchor, fields)` | the group until the buffer ends; no count; the anchor is not written |
| `sized` | raw bytes whose length is an earlier integer |
| `u2` | fixed 2-bit slots, low bits first |
| `bits` | 1-bit list; the count is an earlier integer |
| `packed` | 1-bit or 2-bit list; the count is an earlier integer plus a bias |
| `times(anchor, count, fields)` | the inner fields exactly N times, then the next field; the anchor is not written |

Field numbers are the order in the scheme, starting at 0. They are not written. A gap, a repeated id, or an anchor that is not the next value id fails construction. The anchor is not written, repeat still has no count, and a list, a dict, and a nested group still start at 0. The snippets below are Python; `from packbin import *` leaves out `bool`, `bytes`, `dict` and `list` so that it does not replace the builtins, so the snippets that need them import them by name. The other languages use the same order and produce the same bytes. The first byte of every packet is the scheme type number.

Go spells the helpers as exported functions that take the field id and the name: `U8`, `U16`, `U32`, `U64`, `I8` to `I64`, `F32`, `F64`, `Bytes`, `Be`, `Utf8`, `List`, `Dict`, `Flags`, `Bool`, `When` with `Eq`, `Repeat`, `Sized`, `U2` with `Slot`, `Bits`, `Packed` and `Times`, and `Group`, `Nested` and `FlagByte` with `Bit`. A row is a `map[string]any` keyed by the names, or a struct bound with `Bind`; `None` is a missing key or a `nil` value. The bytes of every snippet below are the bytes Go writes (see [Go rows](#go-rows)).

Swift spells the helpers as static functions of `Field` that take the field id and the name: `.u8`, `.u16`, `.u32`, `.u64`, `.i8` to `.i64`, `.f32`, `.f64`, `.bytes(id, name, size:)`, `.be(field)`, `.utf8`, `.list(name, element)`, `.dict(name, element)`, `.flags(anchor, ...)`, `.bool`, `.when(anchor, .eq(id, value), ...)`, `.repeat(anchor, ...)`, `.sized(id, name, count:)`, `.u2` with `.slot`, `.bits(id, name, count:)`, `.packed(width, id, name, count:, bias:)` and `.times(anchor, count:, ...)`, and `.group(anchor, name, ...)`, `.group(name, ...)` for a nested row, and `FlagByte` with `.flagByte(m)` and `m.bit(field)`. A row is a `[String: Any]` keyed by the names, or a `PackbinRow` bound with `bind(get:set:)`; `None` is a missing key or a `nil` value. The bytes of every snippet below are the bytes Swift writes (see [Swift rows](#swift-rows)).

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

Pack refuses a value that does not fit. TypeScript takes an integer `number` or a `bigint` and throws a `RangeError` that names the member: `n: 300 does not fit in u8` for a value out of range, a fraction or `NaN`, and `n: expected a number for u8, got string` for anything else. It used to wrap 300 to `2c` and cut 1.5 to 1. Pass a `bigint` for a 64-bit value: a `number` that is not a safe integer is refused even where the width could hold it (`n: 9007199254740992 does not fit in u64; pass a bigint`). A row that unpack returned packs again. Java throws an `IllegalArgumentException` that names the field id (`0: 300 does not fit`) for an integer out of range, a `BigInteger` that would wrap, a fraction, a string or a boolean; a `Long` of -1 is still accepted for `u64`, as its bit pattern, so a row that unpack returned packs again. C# checks the dictionary form of a row the same way (`BinaryPacker.Pack(scheme, IReadOnlyDictionary<string, object?>)`; a typed row is held to its member types by the compiler). An integer field takes an integer type that fits its width (`byte` to `ulong`). Since loop 21 it never takes a `float`, `double` or `decimal`, whole or not: `U8: 5 is a Double; u8 takes an integer type, not a float, double or decimal (f32 and f64 take them)` (the slots below and `eq` refused whole floats since loop 20). C# unpack returns the exact integer types, so a row it returned packs again to the same bytes. A number out of range throws an `ArgumentException` that names the member (`U8: 300 does not fit in u8`), and so does a `bool`, string, `char`, enum or other object (`U8: expected a number for u8, got Boolean`). The slots of a `u2` and the items of `bits` and `packed` follow the same rule: an integer in range (0 to 3 for a `u2` slot and a width-2 `packed`, 0 or 1 for `bits` and a width-1 `packed`); a `float`, `double` or `decimal` (a whole `3.0` too, since loop 20), a number out of range, a `bool`, string, `char`, enum, other object or `null` throws an `ArgumentException` that names the member (`A: ...` for a `u2` slot). A `null` item used to pack as 0 and a fraction was rounded. Loop 19 probed the other five packages for a fraction in these slots: TypeScript refuses it (a whole `3.0` or `1.0` passes; C# refuses it since loop 20), Python refuses every fraction, a `Decimal` too, and also the whole floats `3.0` and `1.0` (it accepts an `IntEnum` member, which C# refuses), Rust takes integers only and refuses every float, and C++ cannot express one (the member type refuses it when the scheme is built or compiled). Java refuses a `Double` or `Float`, whole ones too, and since loop 20 a `BigDecimal` with a fraction and a `Long` or `BigInteger` above the slot (it cut `1.5` to 1 and 2^32 + 1 to 1). An enum member is a number only where the language says so: a Python `IntEnum` and a TypeScript numeric enum pack as their integer (`Level.High = 200` in a `u8` packs `01 c8`); a plain Python `Enum`, a TypeScript string enum and a C# or Java enum are refused naming the field, and a Rust enum is not a value (cast it: `Level::High as u8`). A test in each package pins this rule (loop 20).

In Go an integer field takes any Go integer type that holds the value and never a float, a whole `5.0` too (`expected an integer for u8, got float64`, as C# since loop 21; TypeScript packs it). A map from `json.Unmarshal` holds every number as `float64`, so it is refused for integer fields: unmarshal into a typed row, or convert the values to integers first (owner decision Go-2). `u64` and `i64` above 2^53 are exact and pack as they are.

In Swift an integer field takes any Swift integer type that holds the value, and refuses a `Double` (a whole `2.0` too), a `Bool` and an enum case (pass its `rawValue`), naming the field. A Foundation `NSNumber` is read as the integer, float or `Bool` it was made from. `u64` and `i64` are exact.

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

TypeScript pack takes only a `number` for a float. A `bigint` or a numeric string throws a `RangeError` (`x: expected a number for f64, got string`), and so does a finite value too large for `f32` (`x: 1e+39 does not fit in f32`). `NaN` and the infinities are written as given. Python takes only an `int` or a `float`: a `bool`, a string, bytes, a `Decimal` or a `Fraction` raises a `TypeError` that names the field (`0: expected number, got str`), a finite value too large for `f32` raises an `OverflowError` (`0: 1e+39 does not fit in f32`), and a numpy `float32` or integer is refused (convert it with `float(...)`). Java throws an `IllegalArgumentException` that names the field id for a string or a boolean (`0: expected number, got String`) and for a finite value too large for `f32` or `f64` (`0: 1.0E39 does not fit in f32`); only a `Float` or `Double` that is itself infinite is written as an infinity. In the dictionary form of a C# row a float field takes a number of any type. A `bool`, string, `char`, enum or other object throws an `ArgumentException` that names the member (`F64: expected a number for f64, got String`), and so does a finite value too large for `f32` (`... does not fit in f32`). `NaN` and the infinities are written as given.

### Fixed bytes

`bytes(n)` writes exactly `n` bytes and no length. `b"abc"` with `n = 3` is the three characters.

```python
from packbin import bytes as raw_bytes

row = Scheme(1, dict, raw_bytes(0, lambda row: row["b"], 3))
BinaryPacker.pack(row, {"b": b"abc"})
```

```
01 61 62 63
```

A shorter or longer value is rejected.

In Go `Bytes` takes a `[]byte` of exactly `n` bytes. A `[]byte` is a byte run and never a list.

In Swift `.bytes` takes a `[UInt8]` of exactly `size` bytes, and a negative `size` is refused when the scheme is built. A `[UInt8]` is a byte run and never a list.

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

A string is written in the compact text format (loop 35, [ADR 006](_docs/02_document/adr/006_compact-text-format.md); the byte-exact rules are in the [contract](_docs/02_document/contracts/library/compact-text.md)): a varint payload length (1 byte to 127, 2 to 16,383, 3 above), then a bit-packed payload. Ukrainian, Russian and English letters, digits and `, . - : ! ?` are coded with short prefix codes (a table per language and a number mode, a capital shift and a capital lock), anything else is escaped to raw UTF-8, and a payload that would be larger than the plain UTF-8 bytes is written as those bytes. On held-out sentences a Ukrainian string takes about 35 % of the old size, Russian 34 %, English 57 %, coordinates and ids 51 %. `"zxsanny"` is the 7 bytes `06 2b fc fe e1 19 b2` in total (the old format needed 9). The empty string is the single byte `00`. A text of more than 65535 UTF-8 bytes is rejected on pack, naming the field.

The tables are part of the wire format and frozen (`fixtures/text/tables.json`); there is no version byte, so a packet written before this format reads as an error or as other text. A string field is never larger than the old 2-byte count plus UTF-8 up to 126 UTF-8 bytes, and at most 2 bytes larger above that. A flipped bit in the payload damages only the characters of that string (about 7 to 9 % of them on average), never the next field while the count is intact. Unpack refuses a payload that ends inside a code, has a non-zero pad bit, escapes invalid UTF-8, or breaks a capital rule, naming the field. `fixtures/text/vectors.txt` holds the shared test rows that all eight packages pass.

```python
row = Scheme(1, dict, utf8(0, lambda row: row["name"]))
BinaryPacker.pack(row, {"name": "zxsanny"})
```

```
01 06 2b fc fe e1 19 b2
```

In Go pack also refuses a string that is not valid UTF-8, naming the field.

### List

A `u16` count, then that many elements. The element is one field, and its id restarts at 0 inside the list. `[1, 2]` of `u16` is count 2, then `01 00`, then `02 00`. An empty list is `00 00` and still leaves the next scheme field readable.

In a typed C# row the list member is a one-dimensional array, a `List<E>`, an `IList<E>` or a non-generic `IList`, and each element is a row of the element field's type: `List<Role>` for `Utf8<Role>`, as in the first C# example. An element that is a `group` unpacks to one row per item. Unpack creates these rows, so a row type needs a public parameterless constructor, or the scheme fails when you build it. Any other member type, or an element type that cannot hold the field's values, fails when the scheme is built (loop 18, see the C# upgrade notes below): `Stack<int>`, `HashSet<int>`, `IEnumerable<E>`, `ICollection<E>`, `IReadOnlyList<E>`, `Collection<E>` and a class derived from `List<E>` are refused, and so is `List<int>` for a `u32` field. The element type must be `object`, a row type, or hold the whole range of the field (`List<uint>` or `List<long>` for a `u32`; a `float`, `double` or `decimal` element is accepted for an integer field).

```python
from packbin import list as list_field

row = Scheme(1, dict, list_field(lambda row: row["xs"], u16(0, lambda row: row)))
BinaryPacker.pack(row, {"xs": [1, 2]})
```

```
01 02 00 01 00 02 00
```

In Go a list is a `[]any` or any slice but `[]byte` (a byte run is never a list), and a typed row binds a `[]E`: a nil slice is no value, and an empty slice is a list of 0 items (`00 00`). A typed `[]byte` member bound to `List(U8(...))` works.

In Swift a list is any array but a `[UInt8]` (a byte run is never a list), and a typed row binds an array: `nil` is no value, and an empty array is a list of 0 items (`00 00`). A typed `[UInt8]` member bound to a list of `u8` holds the items.

### Dictionary

A `u16` pair count. Each pair is a UTF-8 key, then one element. Keys are written in unsigned byte order, so insert order does not change the packet. `"a"` then `"b"`:

```python
from packbin import dict as map_field

row = Scheme(1, dict, map_field(lambda row: row["m"], u8(0, lambda row: row)))
BinaryPacker.pack(row, {"m": {"b": 1, "a": 2}})
```

```
01 02 00 02 10 61 02 02 10 62 01
```

`02 00` is two pairs. `02 10 61` is the key `"a"` (count 2, then the raw-text byte `10` and `61`; one letter is smaller raw), then value `02`. `02 10 62` is `"b"`, then value `01`.

In a typed C# row the dict member is a `Dictionary<string, E>`, an `IDictionary<string, E>` or a non-generic `IDictionary`, and each value is a row of the element field's type, under the same rules as a list, including the check at construction (`Dictionary<string, ActionList>` in the first C# example).

In Go a dict is a `map[string]any` or any map with string keys, written in UTF-8 byte order, and a typed row binds a `map[string]E`.

In Swift a dict is any dictionary with `String` keys, written in UTF-8 byte order, and a typed row binds a `[String: E]`. Two keys that are equal as Swift strings but differ in bytes (an NFC and an NFD form) are refused on unpack and on pack (see [Swift rows](#swift-rows)).

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

`group` gathers several fields under one bit. The bit is set when any value inside it is present, at any depth: a `u2`, `bits`, `sized`, `packed`, another `flags`, a split flag bit or a nested group counts too (C# counts all of them; it used to ignore a nested `flags`, a split flag bit and a `u2` whose first slot was missing, and a `u2` with any one slot present now sets the bit). A group whose bit is set is written in full, and a required value that is missing fails pack and names it. Those fields are written in order. A `when`, `repeat` or `times` can be a member of `flags`, the field of a flag bit, or sit in a group under them (all six packages since loop 18). It is written like any other value: its bit is set exactly when it writes a value, and the members of one `flags` are decided in order, each against the values written so far in its scope, so a `when` can name an earlier member of the same `flags`. A `when` sets its bit when its condition holds and its body has a value; a `times` when its count is above 0; a `repeat` when at least one round has a value. `u8 mode; flags(when(mode == 1, u8 speed), u16 heading)` with `mode` = 1, `speed` = 7 and `heading` = 90 packs `01 01 03 07 5a 00`; with `mode` = 0 it packs `01 00 02 5a 00`. With `u8 n; flags(times(n, u8 pt), u16 heading)` and `heading` = 90, `n` = 0, 1 and 2 (`pt` = [], [5], [5, 6]) pack `01 00 02 5a 00`, `01 01 03 05 5a 00` and `01 02 03 05 06 5a 00`. With `u8 mode; flags(u16 heading, repeat(u8 pt))`, `mode` = 1 and `heading` = 90, 0, 1 and 2 rounds pack `01 01 01 5a 00`, `01 01 03 5a 00 05` and `01 01 03 5a 00 05 06`. A set bit whose member cannot be written in full (a body value missing, a list shorter than the count) fails pack and names the value, and so does a `times` count of 0 with a non-empty list. One case drops a value with no error in every package, because unpack would not read it either: a `when` whose condition is false (as outside `flags`). A `times` whose count field was itself skipped and that is given values is refused, naming the member, in the combined `flags` form in all six packages (Python and C++ since loop 19, C#, TypeScript, Java and Rust since loop 20; with no values, or an empty list, the bit packs clear as before unless the row gives the count a value above 0, which loop 21 refuses; C++ refuses it only when the count has no value in the row). A split flag byte decides its `when` or `times` bit where the byte is read, so the field the condition or count names must be written before the flag byte. Since loop 19 pack fails, and names the member, when the body would be written and the byte left its bit clear: the `when` source or the `times` count is written after the byte and the condition is true, the count is above 0, or the count is 0 and a list of values is given; or the count is never written and values are given. A false condition packs without a word and leaves the body out, whether its source sits before or after the byte: `u8 mode; flagbyte m; bit m {when(mode == 1, u8 speed)}; bit m {u16 heading}` with `mode` = 0, `speed` = 7 and `heading` = 90 packs `01 00 02 5a 00`. The combined `flags` form is unchanged. Packets written by older versions have the bit clear, still unpack, and repack to different bytes (see the loop 18 and loop 19 notes below). In the split form a `times` count of 0 written after the byte refuses a list of values and packs a lone scalar as zero rounds (`01 00 00`), in all six packages (loop 20). A `when` decided by a split bit whose source is absent from the row stays silent in Rust, as in C#; that is kept as it is (owner decision, loop 20).

Loop 21 aligned four more split-form shapes in the six packages. With `flagbyte fb; u8 n; bit fb { times(n) { u8 pt } }; bit fb { u16 heading }`, a `times` whose count above 0 is written after the byte and whose body is absent (no `pt`, or `pt = []`) packs a clear bit: `n` = 2 and `heading` = 90 pack `01 02 02 5a 00` in TypeScript, Python, Java, C# and Rust (Java refused it before). C++ refuses it, because its rounds are an `Array` member and a count of 2 with an empty `Array` is a count mismatch. A count above 0 that no field wrote, because the `when` that holds it is clear, is refused for a split-bit `times` and for a combined `flags` `times` in all six packages, whether or not `pt` is given: `u8 mode; when(mode == 1) { u8 c }; flagbyte fb; bit fb { times(c) { u8 pt } }; bit fb { u16 heading }` with `mode` = 0, `c` = 1 and `heading` = 90 packed `01 00 02 5a 00` and fails now (TypeScript text: `pt: the count c is 1 in the row, but no field wrote it (the when that holds it is clear), so its times reads no round; give the count 0, leave it out, or make the when hold`). A count of 0, or a row that leaves the count out, still packs `01 00 02 5a 00`. A `bits`, `packed` or `sized` whose count sits behind a clear `when` is refused when a value is given for it, in all six (TypeScript: `v: count c was not written`); with no value, a split bit or a combined `flags` packs a clear bit (`u8 mode; when(mode == 1) { u8 c }; flagbyte fb; bit fb { bits(c) v }` with `mode` = 0 and `c` = 3 packs `01 00 00`), whereas the `times` shape above is refused; whether that row should be refused too is open (loop 22). A late `when` or `times` directly in a bit body (its source written after the flag byte) packs in C++ and Rust, as in the others, when another member of the same bit holds a value: `flagbyte fb; u8 mode; bit fb { group { u8 d; when(mode == 1) { u8 a }; when(mode == 2) { u8 b } } }` with `mode` = 1, `d` = 5 and `a` = 9 packs `01 01 01 05 09`. A body held only by late members is still refused, as above.

### Bool

A `bool` inside `flags` sets its bit and writes nothing after it. Here bit 0 is the bool and bit 1 is a `u8` of 7, so the flags byte is `03` and the only payload is `07`.

The bit is set only for `true`; `false` and a missing value leave it clear, and unpack gives `true` only when the bit is set. A `bool` anywhere except directly under `flags` or a flag-byte bit fails scheme construction, because it has no bit to live in. So does a ninth bit in one flags byte.

```python
from packbin import bool as flag_bool

row = Scheme(
    1,
    dict,
    flags(
        0,
        flag_bool(0, lambda row: row["on"]),
        u8(1, lambda row: row["n"]),
    ),
)
BinaryPacker.pack(row, {"on": True, "n": 7})
```

```
01 03 07
```

A `when` that tests a bool matches only when the bit is set, so test it with `eq(id, true)`. A clear bit is absent when a packet is read, so `eq(id, false)` could never match; since loop 18 every package refuses `eq` of a bool against anything but `true` when the scheme is built (C#: `when 1 tests bool field 0 ('On') against false; a bool is compared only with true`; TypeScript: `when 1: eq names bool field id 0 (on) and accepts only true, not false`). In Rust a bool value is the integer 0 or 1, so an `eq` on a bool must compare with 1 (any other value panics when the scheme is built). In C++ `eq(0, false)` is a compile error, and an `eq` built at run time from another value fails with `SchemeInvalid`.

In Go a bool field takes a Go `bool` and nothing else: `1` or `"yes"` is refused naming the field, where C# and TypeScript leave the bit clear (owner decision Go-1). An empty group binds a `bool` or a `*bool`.

In Swift a bool field takes a `Bool` and nothing else: an integer or a string is refused naming the field, as in Go. An empty group (a mark) binds a `Bool`.

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

A scheme whose `when` names a later field, an id that does not exist, or a field of another scope fails when you build it (see [Untrusted input](#untrusted-input)). Since loop 18 a `when` also fails at construction, in every package, when it names a field that is not an integer (a `u2` slot counts) or a bool: a float, `utf8`, `bytes`, `sized`, `bits` or `packed` source is refused (C#: `when 1 tests 'F' (field id 0), a f32 field; a when names an integer or a bool field`). C#, TypeScript, Python, Java and Rust pack decide every `when` from the fields they wrote, as unpack does from the fields it read, so a `when` on a field that another `when` or a clear flag bit skipped does not match. In Rust a `when` or count that names a `flags` byte or a split flag byte reads the byte pack wrote, not a value kept in the row, and after a `times` the names its rounds wrote are lists, so a `when` on one does not match. Since loop 19 the `eq` value is checked against an integer source when the scheme is built: a value the source can never hold is refused (see the loop 19 notes below).

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

A field after `repeat` is eaten as another point. Use `times` when something follows the group. C#, TypeScript, Java, Rust, Python, Go and Swift refuse a packet with more rounds than the scheme's round limit (`maxRounds`, 65,535 by default); see [Untrusted input](#untrusted-input). Pack refuses a `times` count above the same limit since loop 19, and a `repeat` list above it since loop 20, before it writes a round.

A round can hold more than plain fields: a `when`, `flags` or a group. Give every name the round holds one list. Entry `i` is the value for round `i`, and `repeat` runs as many rounds as its longest list. `repeat(k, when(k == 1, v))` with `k = [1, 2]` and `v = [9]` packs `01 01 09 02` (Python packs it too since loop 22; before that it wanted `v = [9, None]` and raised a `ValueError`, `repeat fields must have equal lengths`, for `v = [9]`). Unpack gives the same shape: every name a round can hold has one entry per round, and a round that skipped the name has `null` (`undefined` in TypeScript), so a row packs again to the same bytes. TypeScript, C#, Java and Python do this. Rust and C++ keep each round as a row: a `Vec<E>` for a typed Rust `times`, `Value::Groups` in the map form of Rust (see Times under Rust), and an `Array<E, N>` in C++. TypeScript rows are flat, so give a group's members as lists under their own names: the nested form `{mark: {v: [7, undefined, 9]}}` throws `missing v`.

Since loop 21 a `repeat` refuses a short list in an optional position. A non-empty list under `flags` or a flag bit (also below a `when` or group inside them) that is shorter than the rounds is refused before any round, naming the first such member, in TypeScript, Python, Java and C#: `repeat { u8 w; flags { u8 v } }` with `w = [1, 2]` and `v = [5]` used to pack `01 01 01 05 02 00`, the second round read as absent by accident, and now fails with `v: 1 items, repeat count 2; give one entry per round, undefined where the member is absent` (TypeScript text; `null` in Java and C#, `None` in Python). `v = [5, undefined]` packs the old bytes. An empty list, no list and a lone value are not short, a required member still fails with `missing w`, and a member under a `when` outside `flags` is not optional (`repeat(k, when(k == 1, v))` above still packs). `times` keeps reading a short list under `flags` as absent for the rounds it does not reach (see Times). Rust and C++ take the rounds of a `repeat` as groups or arrays, one row per round, so the shape does not exist there. Since loop 22 Python has no equal-length rule for `repeat` lists: a lone value goes to every round and a `when` list shorter than the longest packs, as in TypeScript, Java and C# (it raised `repeat fields must have equal lengths` before); a short list for a required member is still refused, naming the member (`KeyError`, `missing field b`). The Rust map form takes the rounds of a `repeat` from `__repeat__` groups only and refuses per-name lists given without them (`repeat at id 0: 'n' is given without '__repeat__' groups; give the rounds of a repeat as '__repeat__' groups, one per round`); before loop 22 it dropped them and packed `01`. Since loop 23 the names of a `times` nested in the body, its `__times_<anchor>` key and the own name of a `flags` in the body count too (`repeat { u8 n; times(n) { u8 w } }` with `w = [1]` and no groups is refused with the same text; it packed `01`), and a value kept beside `__repeat__` groups must be what the rounds hold, as for `times`: `{__repeat__: [{n: 1, x: 5}], n: [2]}` fails with `repeat at id 0: list for 'n' disagrees with its rounds` (it packed `01 01 05`), an empty list beside rounds that hold the name is refused too, and a list that agrees with the rounds still packs. A `repeat` cannot sit inside a `repeat` or `times` in Rust.

A `repeat` or `times` whose body holds no member is refused when the scheme is built, in all six packages (see Untrusted input): `repeat 0: the body holds no member; a round of it would charge no slot and write nothing`.

A `repeat` or `times` cannot sit inside a `repeat` or `times` round, directly or under a `when`, `flags` or group, in TypeScript, C# and Python: they refuse the scheme when you build it. Rust refuses all of these but a `times` inside a `repeat`. Java and C++ allow it. In Java each inner name holds one list per outer round (`null` for an outer round that skipped the group, `[]` for a group that read no round): `repeat(u8 n, times(1, 0, u8 v))` with `n = [1, 1]` and `v = [[5], [7]]` packs `01 01 05 01 07`. A `repeat` has no end marker, so Java pack throws an `IllegalArgumentException` (`1: a repeat has no end marker, so it can be written in one round only`) when one call would write the same inner `repeat` a second time; an inner `times` is fine under any number of outer rounds. Pack still accepts an inner `repeat` that one round reaches while later rounds follow, and a field written after an inner `repeat`, and the packet then reads back differently, so use `times` for an inner group when anything follows it. A `list` or `dict` element starts outside any round.

C# packs such a row from a dictionary of lists (`BinaryPacker.Pack(scheme, IReadOnlyDictionary<string, object?>)`). It has no public call that reads one yet. A typed row binds its rounds to a collection of rows (see Times); a typed `Unpack` of a round whose member cannot hold it returns an error value (loop 20).

In a C# round, a value that is not a list goes to every round. `repeat(x, y)` with `x = 1` and `y = [4, 5]` packs `01 01 04 01 05`, and a scalar under `flags` or a flag bit sets the bit in every round: `repeat(flags(a), b)` with `a = 5` and `b = [1, 2]` packs `01 01 05 01 01 05 02`. A lone string for a `utf8` name goes to every round too. A lone dictionary for a `dict` name is refused since loop 18 (see below). A name that holds a byte run or a list per round (`bytes`, `sized`, `bits`, `packed`) needs a list with one entry per round: a lone `byte[]` or list of numbers for it, an empty `byte[]` included, throws an `ArgumentException` that names the field and says to wrap the value in a list. A typed row's `bytes` member in a round is always refused for that reason.

A lone dictionary for a `dict` name in a `repeat` or `times` round is refused in C#, TypeScript, Python, Java and Rust (loop 18). Give one dictionary per round in a list: `d: [{"a": "x"}, {"b": "y"}]` packs as before. The error names the member (TypeScript: `d: a dictionary in a repeat or times round needs a list with one dictionary per round`; C# `ArgumentException`, Python `TypeError`, Java `IllegalArgumentException`, Rust `PackError::Type`). It used to be copied to every round (C#, Java, and Python and TypeScript under `times`) or read as one round (`repeat`; Python raised `ValueError` for unequal lengths), and the Rust map form packed it for one round and failed with `Missing` for two. C++ has no such value: its rounds are typed arrays. A lone byte buffer for a `bytes` or `sized` name in a round is refused in TypeScript, Python, Java and Rust since loop 19, as C# has refused it since loop 17; they copied it to every round before (see the loop 19 notes). In the Rust map form a lone scalar for a `times` member now goes to every round, as in the other packages (it went to round 0 only): `u8 n; times(n, u8 x, u8 y)` with `n` = 2, `x` = 1 and `y` = [4, 5] packs `01 02 01 04 01 05`; `repeat` has no lone-scalar form in the Rust map API.

In Go the lists of a round are a `[]any` or any slice but `[]byte`, entry `i` for round `i`, and a `nil` entry leaves the name out of that round. A group in a round takes one map a round, and a typed round binds a `[]E` or `[]*E` of a struct (see [Go rows](#go-rows)). Unpack refuses the round past `MaxRounds` or `MaxSlots` with a `TooMany` error, and pack refuses a list above `MaxRounds`.

In Swift each name a round holds takes an array, entry `i` for round `i`, `nil` where the round leaves the name out, and a value that is not an array goes to every round (a `[UInt8]` is a byte run, never the array of rounds). A group in a round takes one `[String: Any]` a round, and a typed round binds an array of a `PackbinRow` (see [Swift rows](#swift-rows)). Unpack refuses the round past `maxRounds` or `maxSlots` with `.tooMany`, and pack refuses a list above `maxRounds`.

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

In C# the count of `sized`, `bits`, `packed` and `times` must name an integer field (`u8` to `i64`) or a `u2` slot. A count that names a float, a `bool`, a string or a byte run fails when the scheme is built, with an `ArgumentException` that names the counted field and the field it counts by. A count that pack did not write (a `when` or a clear flag bit skipped it), or that does not fit an `int`, is an `ArgumentException` too.

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

The rules of Repeat hold for the rounds of `times`: one list per name, entry `i` for round `i`, `null` (`undefined` in TypeScript) for a round that skipped the name, and (except in Java and C++) no `repeat` or `times` inside a round. The count is the number of rounds. In C# it must name an integer field or a `u2` slot (see Sized). Pack refuses a list longer than the count in C# (`'V' holds 2 items, but the times count is 1`), TypeScript (`RangeError`, `x: 3 items, times count 2`), Python (`ValueError`, `1: 3 items, times count is 2`, also for a `bool` or `u2` member) and Java (`IllegalArgumentException`, `1: list has 3 entries for a count of 2`; a member without a field id is named by its kind, `group: ...`). C# also refuses a list too short for a round that walks the field. A list shorter than the count, or empty, is read for a member under `flags` or a flag bit as absent for the rounds it does not reach, in TypeScript, Java, C#, Python and (since loop 22) the Rust map form: `u8 c; times(1, 0, flags(1, bool(1, on)))` with `{c: 2, on: [True]}` packs `01 02 01 00`, and `flags(1, u8(1, v))` with `{c: 2, v: [5]}` packs `01 02 01 05 00`. A forgotten entry is therefore a clear bit with no message (a `repeat` refuses a short list there since loop 21; see Repeat). A plain member, and a member under a `when`, still need an entry for every round that reads them (TypeScript `missing x`, Java `1: expected int, got null`; Python raises a `ValueError` that names the member, `1: 1 items, times count is 2`, since loop 19, where it was a bare `IndexError`). Python `repeat` follows the same rules since loop 22 (see Repeat). Rust binds a `Vec<E>`; see Times under Rust (the map form of Rust refuses a list longer than the count when no rounds are given, before any item error: `PackError::Type`, `times at id 1: '1' has 3 items, count is 2`; the names of a `flags`, a flag byte and a `group` are not checked, and a typed `times` always has one round per element; the Rust map form refuses a list for a member under a `when` with `times at id 1: '1' is under a flags or when; give its values per round under '__times_1'`, where TypeScript, Python, Java and C# pack it; that is a documented Rust difference (owner decision U18, loop 23): give those values per round under `__times_<anchor>`, as for `repeat`). In C++ pack returns `Error::BadValue` when the `Array` member of a `times` holds a number of items other than the count, a non-empty `Array` for a count of 0 included (it skipped the `Array` silently before loop 18). A `times` member of `flags` whose count field was itself skipped writes nothing, and the values given for it are refused in all six packages (see Flags). A count of 0 with a list of values is refused in all six packages, and a lone scalar with a count of 0 packs without a word in all six (`u8 a; times(a, u8 x)` with `a` = 0 and `x` = 5 packs `01 00`). The round limits of Repeat apply to the rounds of `times` as well: unpack refuses the round past the limit when it would start, and since loop 19 pack refuses a count above `maxRounds` before it writes any round (C#, TypeScript, Python, Java, Rust); see [Untrusted input](#untrusted-input).

In C#, a typed `Times` or `Repeat` binds a collection of rows, as the Rust `times` does (loop 21). Give the member that holds the rounds, an `E[]`, a `List<E>` or an `IList<E>` of a row class `E` with a public parameterless constructor, and declare the round's fields for `E`: `Field.Times(anchor, countId, accessor, fields...)` and `Field.Repeat(anchor, accessor, fields...)`, or the same calls on the `Fields<T>` of the `Scheme<T>(type, f => [...])` form. Pack reads one `E` per round and typed `Unpack` makes one per round, so the Rust route above is:

```csharp
sealed class Point { public int Lat { get; set; } public int Lon { get; set; } }
sealed class Route
{
    public byte N { get; set; }
    public List<Point>? Points { get; set; }
    public byte Tail { get; set; }
}

var route = new Scheme<Route>(1, f => [
    f.U8(0, x => x.N),
    f.Times(1, 0, x => x.Points!, p => [p.I32(1, r => r.Lat), p.I32(2, r => r.Lon)]),
    f.U8(3, x => x.Tail)]);

var raw = BinaryPacker.Pack(route, new Route
{
    N = 2,
    Points = [new Point { Lat = 10, Lon = 20 }, new Point { Lat = 30, Lon = 40 }],
    Tail = 7,
});
```

```
01 02 0a 00 00 00 14 00 00 00 1e 00 00 00 28 00 00 00 07
```

Zero rounds unpack to an empty collection, a `null` member packs no rounds, and a `times` whose count differs from the number of rows is refused naming the member (`'Points': the times count is 3, but it holds 2 rounds`; a count of 0 with rows too). The members of `E` are bound inside the round, so a member named like one of the outer row's members stays in its own round. The scheme builds if and only if typed `Unpack` can bind the member: any other member type fails when the scheme is built (`'Points': ... is not a collection of rows a times can bind; use E[], List<E> or IList<E> for a row class E`), and so does an `E` without a public parameterless constructor and a round field declared for another row type (`'Tail' is declared for row type Route, but this scheme is for Point`). The limits apply to the rows: `maxRounds` and `maxSlots` errors name the member (`'Points': the repeat count is 2, above the limit of 1 rounds`). The older bindings, a `List<List<object?>>` or an `object` member for the per-name lists, keep working.

In Go a typed `Times` refuses a count that differs from the number of elements, as C# does (`the times count is 3, but the row holds 2 rounds`). The map form follows TypeScript.

In Swift a typed `.times` refuses a count that differs from the number of elements too, and unpack gives an empty array for 0 rounds. The map form follows TypeScript.

`packed` and `times` together are how one scheme holds a route: a header, N two-bit point kinds, N latitude/longitude pairs, then N−1 straight-leg bits only when a flag is set. That packet is

```
34 10 00 15 00 06 2d 00 02 0d 00 65 cd 1d 00 a3 e1 11 10 8c cd 1d 10 ca e1 11 01
```

[`_docs/01_solution/schema.md`](_docs/01_solution/schema.md)

## Untrusted input

Unpack reads bytes from the network, so a packet may be built to hurt. In C#, TypeScript, Python, Rust, Java and Go, `unpack` answers every packet it cannot read with an error value and no row. It does not throw; a typed C# `Unpack` of a packet that holds a `repeat` or `times` round returns an error value too since loop 20, when the row cannot hold the lists of rounds (see Limits to keep in mind). A typed C# `list` or `dict` member that cannot hold its field, and a `flags` as a direct `list` or `dict` element, no longer throw out of `Unpack`: the first is refused when the scheme is built and the second unpacks (loop 18). Swift `unpack` throws a `PackbinError` for such a packet and gives no row; no input traps (every read is bounds-checked and every size is computed with checked arithmetic). Its time grows with the length of the packet. In C#, TypeScript, Java, Rust, Python, Go and Swift the memory the rounds of a `repeat` or `times` can take is bounded by the scheme's round limits, not by the packet: a packet with more rounds than the limits allow is refused (see Limits to keep in mind). That is the only amplification the limits remove: a `bits` or `packed` count is bounded only by the bytes left, so those items still cost memory in a straight line with the length of the packet (a 1 MiB packet of 8,388,608 `bits` items measured about 38 MB in C# and Java, about 230 MB in TypeScript and about 270 MB in Rust, net of the runtime), and the limits are per call, so concurrent calls add up. Cap the packet length where you read it from the network. C++ needs no round limit; its memory stays small for the reason given there. The cases it refuses:

- a count that is negative, or larger than the bytes left
- a count whose field is absent because its flag bit was clear
- invalid UTF-8 in a string or a dictionary key
- a `times` round, or a `list` or `dict` element, that reads no bytes. A `repeat` round that reads none ends the repeat, and the bytes left are trailing bytes

The kind of error for these is not settled yet. Today they come back as a short-packet-style error, so test for failure, not for its exact kind. Go does the same (a short-packet error with `Needed` 0), and reports a round past a limit as `TooMany`; so does Swift (`.short` with `needed` 0, and `.tooMany`). The C++ package already reports every failure as a `Result`; it does not check that a string is valid UTF-8.

These mistakes in a scheme are refused when you build it, not when a packet arrives:

- A split-form flag bit must come after its flag byte, in the same place: the top level, one `repeat` or `times` round, or one `list` or `dict` element. A flag byte read inside a `when` is not visible after it. TypeScript, C#, Java, Rust and Python refuse a violation at construction. Java and C# refuse a bit that follows a nested row (a `group` with an accessor) whose only flag byte was read inside the row, and a bit inside a nested row whose only flag byte was read outside it (Java: `flag bit U8 0 has no flagByte before it in the same scope`; C#: `flag bit 'A' has no flag byte read before it in its scope`), and C++ refuses a bit whose only flag byte sits inside a `when` that ended before it, inside a `flags` member or inside the child of a flag bit (`SchemeInvalid` naming the bit, or a compile error for a `constexpr` scheme). The ninth bit of one read of a flag byte fails when the scheme is built in TypeScript, Java, Python and C#, not when `.bit(...)` (`.Bit(...)` in C#) is called; the combined C# `Field.Flags(...)` still refuses its ninth member at the call. A bit that is created and never placed in a scheme leaves its bit clear in Python and TypeScript, and takes no number in C#.
- A `when` or a count may name only a field read earlier in its own place: the top level, one `repeat` or `times` round, one `list` or `dict` element, or (C#, TypeScript, Java) one nested row. A field inside a `repeat` or `times` is not visible after it, and an outer field is not visible inside it. C#, TypeScript, Java, C++, Python and Rust refuse a violation at construction. Rust checks names as well as numbers: a later field, an outer field, a field inside an earlier `repeat` or `times` body and a name the scheme never declares are all refused (`when at id 2 names field "1", which is not in the same scope`); a number that matches no field name never matched and is refused too. Python raises a `ValueError` (`when 1: eq names field id 2 is allowed only if declared earlier in the same scope`). Since loop 18 all six packages agree on the kind of the named field: a `when` names an integer field, a `u2` slot or a `bool` (compared only with `true`), and a count (`sized`, `bits`, `packed`, `times`) names an integer field or a `u2` slot. A float, `bool`, string or byte run as a count is refused (C#: `'Out' (field id 1): its count names 'S' (field id 0), a utf8 field; a count must name an integer field`; Java, Rust and C++ used to accept a `bool` count), and so is a `when` on a float, `utf8`, `bytes`, `sized`, `bits` or `packed` field (C# and TypeScript took any value field; the other packages differed in detail).
- A `bool` stands only directly under `flags` or a flag-byte bit, and one flags byte holds at most 8 bits. An empty group follows the same rule when something carries its `true` (its own value in TypeScript and Rust, a `bool` member in C# and C++, a nested-row accessor in Java, where the nested row carries presence only: `{g: {x: 1}}` comes back as `{g: {}}`). An empty group that could never set its bit (Python and Java `group(anchor)` with no fields, a C++ `group(id)` with no fields and no member, a C# empty group bound to a non-`bool` member) fails construction wherever it stands. Every package refuses a violation at construction; in TypeScript `new Scheme(...)` checks the same as `scheme(...)`.
- An `eq` whose value its integer source can never hold (loop 19): out of the source's range (`eq(u8, 300)`, `eq(u64, -1)`, a `u2` slot against 4), a string, `NaN`, a fraction or a `bool`. Every package refuses it at construction; C++ refuses out-of-range integers only (see the loop 19 notes). The condition could never match, so the `when` would never run.
- A `repeat` or `times` inside a `repeat` or `times` round, directly or under a `when`, `flags` or group. C#, TypeScript and Python refuse it at construction (`repeat 1 is inside a repeat or times round; a round cannot hold another repeat or times`). Rust refuses all of these but a `times` inside a `repeat`. Java and C++ allow it. A `list` or `dict` element starts outside any round.
- A `repeat` or `times` whose body holds no member (loop 21), wherever it stands: `repeat 0: the body holds no member; a round of it would charge no slot and write nothing` (`times 1: ...` for a `times`). A round of such a body charges no slot and writes no byte, so neither `maxSlots` nor `maxBytes` bounds how many of them a call walks: a `list` of 65,535 items, each holding a `times` of 65,535 empty rounds, took 93 s to pack in TypeScript (measured). TypeScript, Python, Java and C# raise their usual argument error (`RangeError`, `ValueError`, `IllegalArgumentException`, `ArgumentException`), Rust panics, and C++ fails the scheme check with `SchemeInvalid` (or a compile error for a `constexpr` scheme). A member is any field that is not a container, looking through `when` and groups: a value (a zero-width `bytes` too), a `list`, a `dict`, a `u2`, a flag byte, a flag bit or a `flags` (a `flags` with no member still writes its flag byte), so those bodies still build; a body of only empty `when`s or empty groups holds none. C++ looks at the direct children of the round only, so a body that is a single empty `when` still builds there (open, loop 22). It costs one walk when the scheme is built and nothing per round.
- In TypeScript, a member name that group flattening would overwrite: a name declared inside an unanchored group and also outside it or in another unanchored group, or a group named like one of its own members (`member sid: declared inside a group and outside it; a group's members are flattened into the row, so one would overwrite the other`), and a name declared twice in one scope (`member a: declared twice in one scope; a row holds one value per name, so one would be lost`) unless one of the two sits under a `when`. A `list` or `dict` element is a scope of its own. Python, Java and Rust refuse a repeated name too (the next bullets); none of the four checks two declarations inside one `when` body, and each has a gap of its own, named in its bullet.
- In Python, a member name declared twice in one scope (`member x: declared twice in one scope; a row holds one value per name, so one would be lost`), unless one of the two sits under a `when`. A name is the accessor key: `row["x"]` and `row.x` are different accessors and do not clash, a `list` or `dict` accessor counts, the identity accessor `lambda row: row` has no name, and a flag byte handle is not a name. The top level and each `list` or `dict` element are scopes; `repeat`, `times`, `flags`, `when`, `group` and a flag bit share the scope around them. Use one accessor style for a member.
- In TypeScript, a `list` or `dict` whose element is an anchored `group` (`group(0, ...)`), wherever the list or dict stands: `list g: element is an anchored group (p); use a group without an anchor`. Use a group without an anchor, which packs one object per item. A `when` or `times` as a direct element is refused as before, by its own reference check. Python accepts an anchored group element.
- In Python, a `list` or `dict` element that is a `group`, `flags` or `u2`, or holds one, whose members use attribute accessors (`lambda p: p.x`): `list element: field 0 uses the attribute accessor 'x'; an element row is a dict, so use a key accessor, row['x']` (`dict element: ...`; `a nested list` or `a nested dict` for a container member). Each element is unpacked into a `dict`, so give its members key accessors (`lambda p: p["x"]`). The accessor of the list itself (`lambda row: row.pts`), a leaf element (`u16(0, lambda p: p)`) and an accessor on a `list` or `dict` that is itself an element are not affected.
- In C#, a field declared for another row type, such as `Field.U16<Other>` in a `Scheme<Row>`: `'Q' is declared for row type Other, but this scheme is for R`. A field of a nested row goes inside its `Group`, not in the parent scheme.
- In C#, a nested row type, or a row type used as a `list` or `dict` element, that has no public parameterless constructor: `'Inner': row type NoCtor needs a public parameterless constructor to be unpacked`. Unpack creates these rows, so give the type one.
- In Rust, a `when` on a field that is not an integer or a `bool`, or compared with a value that is not an integer; and a `list` or `dict` element that is a group, `flags`, `when`, `repeat`, `times`, `sized`, `bits`, `packed` or a `u2` with more than one name, which could not round-trip.
- In Rust, a data name declared twice in one scope (`member "a" is declared twice in one scope; a row holds one value per name, so one would be lost`), unless one of the two sits under a `when`: the second `u8("a")`, a name inside and outside a `times` or `repeat` round, a `u2` slot or a `sized`, `bits`, `packed`, `list` or `dict` named like another member. A flag byte read twice, a `flags` byte name, a `group` name and a name inside a `list` or `dict` element are not data names. In the typed `Scheme<T>` a name is the field id, which is already unique, so the check reaches only a raw `SchemeItem::Field`. A data name equal to a flag-byte or `flags` byte name still builds, and one value replaces the other in the unpacked values.
- In Java, a nested row `group(get, set, fields...)` on a typed row (a row class that is not a `Map`) or below a nested row that has a child factory: `nested group on a typed row needs a child factory`; for a list or dict element group, `list element: ...` or `dict element: ...` with the same text. Use `group(get, set, Child::new, fields...)`.
- In Java, a key written twice in one scope: two fields whose setters are `Access.set("x")` (`member x: declared twice in one scope; a row holds one value per name, so one would be lost`), also once outside and once inside a `repeat` or `times` round, unless one of the two sits under a `when`. A nested row and a `list` or `dict` element are scopes of their own (an element is checked even when its list sits under a `when`; a repeated key inside a nested row that sits under a `when` still builds, as in TypeScript), and a nested row's own key is not checked. Only `Access.set("x")` members have a name: a typed accessor (`Access.set(BiConsumer)`) or a hand-written lambda has none, so a repeat there is not seen when the scheme is built.

If you upgrade, three schemes that built before now do not (the first two in TypeScript, C#, Java and Rust): a flag byte in one `when` with its bit in another `when`, a flag byte outside a `list`, `repeat` or `times` with its bit inside it, and (Rust) a reference from inside a `repeat` or `times` to a field outside it. Packet bytes do not change. A `times`, `list` or `dict` element that reads nothing used to unpack as an empty item and is now an error.

The `bool` rule changes more when you upgrade. A `bool` that is `false` now packs a clear bit (`01 00`) in C#, TypeScript and Rust, as Java, Python and C++ already did, so mixed versions read that row differently until both sides upgrade. A `bool` or empty group outside `flags`, an empty group that could never set its bit, and a ninth flag bit now fail at construction. In C#, packing a flags group whose bit is on throws when one of its values is missing, instead of writing a packet that cannot be read, and a group whose only values are `u2`, `sized`, `bits`, `packed` or a nested group now sets its bit. In C# and TypeScript, a value other than `true` (for example `1`) leaves a bool's bit clear. In TypeScript, `new Scheme(...)` now refuses everything `scheme(...)` refuses (a type number above 255, a wrong field id, a split bit outside its scope, a bool outside flags) instead of building it, and its `fields` come back flattened (`flagByte` / `flagBit` in place of `flags`), as `scheme(...)` already returned them. In Java, a `when` or a count that names a later field, a field outside its round, or a field that is not an integer or a `bool` now fails at construction, and unpacking a `repeat` or `times` gives every field one list entry per round, `null` where the round skipped it. In Rust, `packbin::pack` and `packbin::unpack` for map schemes are now public, a map bool value other than 0 or 1 or a `__repeat__` value that is not groups fails pack, a `repeat` inside a `repeat` or `times` round and a `times` inside a `times` round fail at construction (a `times` inside a `repeat` round still works), a `FlagByte` handle no longer counts bits across schemes, and a second read of a flag byte with the same name starts its own bits, as in C++.

Reference scope is now checked in C# and TypeScript too, as it already was in Java, Rust (numeric ids) and C++. If you upgrade, a `when` or a count that names a later field, an id that does not exist, or a field of another scope throws at construction: `ArgumentException` in C# (`when 0 names field id 1, which is not an earlier field in the same scope ...`), `RangeError` in TypeScript (`when 0: eq names field id 1, which is not declared earlier in the same scope`). C# used to resolve a later id and pack a packet its own unpack rejected. TypeScript used to search the whole scheme for the id, so a `when` inside an unanchored group could match a field outside it that had the same id; it now reads its own scope. A `sized`, `bits` or `packed` counted by a field of the same `repeat` round now unpacks in TypeScript (it was an error). A `repeat` or `times` inside a `repeat` or `times` round now fails at construction in C# and TypeScript.

TypeScript pack throws where it used to write wrong bytes. A `RangeError` names the member for an integer out of range (`n: 300 does not fit in u8`; it wrote `2c`), a fraction or `NaN` in an integer field (1.5 was cut to 1), a value that is not a number (`n: expected a number for u8, got string`), a `bigint` or a numeric string in a float field, a finite value too large for an `f32` (`x: 1e+39 does not fit in f32`; it wrote an infinity), and a 64-bit `number` that is not a safe integer (`n: 9007199254740992 does not fit in u64; pass a bigint`). A field under `flags` inside a group is now written: a group of `u8 a` and `flags(u8 c, u8 d)` with `{g: {a: 7, c: 2}}` packed `01 07 00` and packs `01 07 01 02`. A member name that group flattening would overwrite fails at construction. These checks run in `new Scheme(...)` too. `eq` compares numbers and bigints by value, so a `when` on a `u64` field matches on pack and on unpack. `Scheme.fields` holds copies of the `when`, `sized`, `bits`, `packed` and `times` fields with the name they refer to filled in, not the objects you passed in.

TypeScript unpacked rows changed. The flag-byte value is no longer a member (`flags` used to add a `""` key, and `flagByte("m")` added `m`). In a `repeat` or `times` round every name the round can hold is a list with one entry per round, `undefined` where the round skipped it (a `bool` under `flags` is `true` or `undefined`); the list used to hold only the rounds that read the name. Pack reads these lists by round index, so a row packs again to the same bytes, and a `when`, `flags` or group inside a round packs. `repeat(k, when(k == 1, v))` with `{k: [1, 2], v: [9]}` packs `01 01 09 02`; it threw `expected number`.

C# pack no longer drops data. `Pack` throws `ArgumentException` where a value is missing outside a flag bit (`'N' (field id 1) has no value; a field that may be absent belongs in Flags`). It used to write a shorter packet that the peer misread, or throw `KeyNotFoundException` for an absent list, dictionary or `Sized`. The same error comes when a round runs out of list, and when a `times` list is shorter than its count. A longer one throws `'V' holds 2 items, but the times count is 1`. A count whose field pack did not write (a `when` or a clear flag bit skipped it) throws `ArgumentException`: `D: count 'N' is missing` (earlier versions threw `InvalidOperationException`; see the C# counts paragraph below). A scheme that holds a field declared for another row type throws `ArgumentException` at construction: `Field.U16<Other>` in a `Scheme<Row>` used to leave its value out, and a child row's field used directly in the parent scheme, which packed, now goes inside its `Group`. Pack decides every `when` from what it wrote, as unpack does from what it read. A `when` on a field that an earlier `when` or a clear flag bit skipped no longer matches (a row that packed `01 01 04` now packs `01 01`), and `Eq(bool, false)` on a clear bit no longer matches. A float `when` follows Java's `Double.compare`: NaN equals NaN and -0.0 differs from 0.0. Give an `f32` field a `float` in `Eq` (`Eq(0, 0.1f)`): `Eq(0, 0.1)` matches nothing now. A scheme owns a copy of its fields, so one `Field` or `Condition` can be used in several schemes (a second scheme with the same `Condition` used to rebind the first). A `FlagByte` handle no longer holds bits, so it can be used in many schemes (see the split-form paragraph below). In a round, pack reads values under `when`, `flags` and groups by round index, and a read gives aligned lists with `null` for a skipped round; there is no public call that returns such a row yet (see Repeat).

Rust `times` and `when` changed. A typed `times` is now `SchemeItem::times(anchor, count_id, get, set, members)` and binds a `Vec<E>` (see Times under Rust). The three-argument form and the `SchemeItem::Times { .. }` struct variant are removed, so typed code that used them does not compile. A scheme that built before can now fail at construction: a `when` on a float, utf8 or bytes field or compared with a value that is not an integer (`when at id 1 tests field "0", which is not an integer or bool`), and a `list` or `dict` element that is a group, `flags`, `when`, `repeat`, `times`, `sized`, `bits`, `packed` or a `u2` with more than one name. A `when` now compares by integer value at any width; `eq` of a `u8` against a `u16` field used to never match. Two bound lists or dicts in one typed scheme now keep their own members; the second used to overwrite the first, and pack wrote it twice. The map form of `times` also returns its rounds under `__times_<anchor>`, and pack refuses a list that disagrees with them: `times at id 1: list for '1' disagrees with its rounds`. Edit the rounds and drop or rewrite the per-name lists, or edit the lists and remove the `__times_<anchor>` key (not for a member below a `flags` or `when`: edit its rounds).

Round limits change what unpack accepts. If you upgrade C#, TypeScript, Java, Rust or Python, a packet with more than 65,535 rounds in one `repeat` or `times` field, or whose rounds together hold more than 1,048,576 slots (4,194,304 before loop 22), that unpacked before is now refused until its scheme raises the limit; at the new default a round body wider than 16 names can no longer run 65,535 rounds; packet bytes and every result for a smaller packet do not change. In C#, TypeScript and Python, an omitted argument of `WithLimits`, `withLimits` or `with_limits` is the default, not the scheme's current value, so `scheme.WithLimits(maxRounds: 200_000).WithLimits(maxSlots: 16_000_000)` ends with the default `maxRounds` again: give both in one call. Java and Rust take both values every time (Java's `withLimits` also resets `maxBytes` to the default; see the loop 20 notes).

TypeScript pack and construction changed again. A count (`sized`, `packed`, `times`) can come from a `u64` or `i64` field, as `bits` could, so a row that unpack returned packs again; a count above 2^53 or a negative one is refused (an error value on unpack, a `RangeError` on pack). `list` and `dict` accept a `group` or `flags` element: each item is one object, packed from its own members and unpacked to one object, with the same bytes as Python. A dict key or a list item is never merged into the row any more, so a key cannot overwrite or supply a row member; only the declared members of a declared group given as an object are merged (given both flat and inside the group object, the group object wins). `times` pack throws a `RangeError` for a list longer than the count (`x: 3 items, times count 2`); it dropped the extra entries. A member name declared twice in one scope fails at construction (`member a: declared twice in one scope; ...`), unless one of the two sits under a `when`; `u8 a` beside an anchored `group` holding `u8 a`, and `u8 x` beside a `repeat` holding `u8 x`, built before. A `list` or `dict` whose element is an anchored `group` fails when the scheme is built; before, it failed at pack with `missing a`, packed only empty lists or dicts, or dropped the values of items that held only optional members, so a scheme that only ever packed empty lists of it fails at build now too. A `flags` group is on when any value inside it is present at any depth (`u2`, `bits`, `sized`, `packed`, nested `flags` and groups), and a set group that lacks a required member throws and names it; `flags` under a split flag bit and `flags` directly inside `flags` now pack their values (they were dropped). Pack decides each `when` from the fields it wrote, as unpack does from the fields it read: a `when` on a skipped field does not match, `eq(id, undefined)` matches an absent field as on unpack, `eq(bool, false)` on a clear flag bit no longer writes its body, and a count whose field was not written throws (`p: count n was not written`). In calling code, give `times` lists no longer than the count and rename the members that two places declared.

TypeScript packaging changed. The npm package now holds compiled JavaScript and `.d.ts` files in `dist/` and no `.ts` sources, and `package.json` exports only the `packbin` entry point: a `packbin/src/index.ts` import fails with `ERR_PACKAGE_PATH_NOT_EXPORTED`. Plain Node 22+ imports the package without flags, and a `tsc` project no longer needs `allowImportingTsExtensions`; it needs TypeScript 5.0 or newer unless `skipLibCheck` is set. In calling code, import from `packbin` only and annotate the accessor parameters in TypeScript files (`(x: Target) => x.sid`); whether the helpers should default the row type is not decided yet.

TypeScript `PackSession.load` returns `null` for anything that is not a `Uint8Array` or `Buffer` of 32 bytes. A string, a plain array, an object with a `length` of 32, a `Uint16Array`, an `Int8Array` or a `Uint8ClampedArray` used to open a session keyed by zeros or by the low byte of each item (`PackSession.load("a".repeat(32))` was keyed by 32 zero bytes), and `null` or `undefined` threw `TypeError`. In calling code, convert the seed first: `Uint8Array.from(items)`, `new Uint8Array(arrayBuffer)`, `Buffer.from(hex, "hex")`.

Python changed in several places. `PackSession(seed)` raises `ValueError` unless the seed is 32 bytes. `PackSession.load` returns `None` for a seed that is not 32 bytes, and now also for anything that is not a `bytes`, `bytearray` or `memoryview` (a released `memoryview` included), where it opened a session or raised `TypeError`: `PackSession.load(32)` used to open a session keyed by 32 zero bytes, and a list of integers or an `array.array` opened one too, so wrap such a seed in `bytes(...)`. `PackSession.start(nonce)` and `join(nonce)` follow the same rule: a nonce that is not a `bytes`, `bytearray` or `memoryview` of 16 bytes makes `start` return `None` and `join` return `False` and raises nothing, where `start(16)`, a list of 16 integers or an `array.array` opened a session (`start(16)` used 16 zero bytes as the nonce) and a `str`, a float, a released `memoryview` and `join(None)` raised; `start()` and `start(None)` still draw the nonce. `from packbin import *` no longer imports `bool`, `bytes`, `dict` and `list`, which replaced the builtins; import them by name, `from packbin import dict as map_field`, as the examples here do. A `when` or a count that names a later field, an id that does not exist or a field of another scope now raises `ValueError` when the scheme is built, and so does a `repeat` or `times` inside a `repeat` or `times` round. `flag_byte()` and `.bit(...)` now work in a `Scheme`: the flag byte takes no field id, each bit takes the id where it stands, and a bit before its flag byte or outside the scope of its flag byte fails at construction. Bit numbers follow the order in the scheme, as in Rust, C++, TypeScript and Java (see the split-form paragraph below), and a bit that is created and never placed leaves its bit clear. Pack is stricter: a `times` list longer than the count raises `ValueError` (`1: 3 items, times count is 2`; the extra entries were dropped), and a float field takes only an `int` or a `float` (a string raised an unnamed `ValueError` and a `bool` packed as 1.0; both now raise a `TypeError` that names the field, a numpy `float32` is refused too because it is not a Python `float` (convert it with `float(...)`), and a finite value too large for `f32` raises a named `OverflowError`). Unpack of a `repeat` or `times` gives every name one list entry per round, `None` where the round skipped it, and no longer starts from a list the row class carries (it appended to a class-level list in place); pack reads these rows round by round, so `flags`, `when` and a group inside a round pack. A `bool` under `flags` inside a `times` reads its own round (`{"a": 2, "on": [True, False]}` packs `01 02 01 00`; it packed `01 02 00 00`), and a flags group that holds only a `u2` or a nested `flags` now sets its bit (`{"p": 1, "q": 2}` packs `01 01 09`; it packed `01 00`). A member name declared twice in one scope now raises `ValueError` when the scheme is built, unless one of the two sits under a `when`: `u8 x` twice unpacked `01 07 08` to `{x: 8}` and packed it again as `01 08 08`, and `u8 x` beside a `times` holding `u8 x` unpacked to `{x: [7, 8]}` and could not be packed again. A `times` list that is shorter than the count, or empty, now packs for a member under `flags` or a flag bit, a missing entry meaning absent (`{"c": 2, "v": [5]}` packs `01 02 01 05 00`); it raised `IndexError`, and a plain member still does. A `list` or `dict` whose element is a `group`, `flags` or `u2` now raises `ValueError` when the scheme is built if a member uses an attribute accessor; it built before, packed objects, and raised `AttributeError` out of `BinaryPacker.unpack` on a valid packet. Use key accessors in element groups (`lambda p: p["x"]`). This breaks a scheme that only packs, with object elements (`Row.pts = [Pt(1), Pt(2)]` packed to `01 02 00 01 02`): it no longer builds, and must pack `dict` elements instead (`[{"x": 1}, {"x": 2}]` packs the same bytes). In calling code, import the four names explicitly, give `PackSession.load`, `start` and `join` `bytes(...)` values, rename a repeated member, and give element-group members key accessors. The Python session removes the pad of the first byte and checks the type before it removes the rest (one block for an unknown type); the pad is pure Python and linear in the payload, so bound the payload length you read from the network.

Rust `PackSession::pack` returns `Result<Vec<u8>, SessionPackError>` instead of `Option<Vec<u8>>`: `NotOpen` before `start` or `join`, and `Pack(PackError)` when the row cannot be packed (the same `PackError` as `BinaryPacker::pack`); a failed pack does not use a pad position. Code that matched `Some` and `None` no longer compiles. A `when` or a count (`sized`, `bits`, `packed`, `times`) must name a field that its own scope declared earlier. A field outside its `repeat` or `times` body, inside an earlier body, a later field or an undeclared one now panics when the scheme is built, by name as well as by number (`when at id 2 names field "1", which is not in the same scope ...`, `the count of "2" names field "1", ...`); a name that no field of the scope carried used to build and never fire, and a number that matches no field name is refused too. A `packed` or `times` count of 2^63 or more returns `PackError::Type("<label>: item count out of range")` (it reported a negative count, and a debug build panicked at 2^63 with bias -1). A map `times` packed without `__times_<anchor>` returns `PackError::Type` when a non-empty list or a single value is kept under a member below a `flags` or `when`; put those values in the rounds. A `flags` group is on when any value inside it is present at any depth (`u2`, `sized`, `bits`, `packed`, a nested group or `flags` count) and is then written in full; a required value that is missing fails with `PackError::Missing` and names it. Those values were dropped before. Rust pack (map form and typed `Scheme<T>`) decides every `when` from the fields it wrote in the same scope, as unpack does from the fields it read. A `when` on a field that an earlier `when` or a clear flag bit skipped no longer matches (`u8 "0"; when(1, eq("0", 1), [u8 "1"]); when(2, eq("1", 4), [u8 "2"])` with `{"0": 0, "1": 4, "2": 9}` packed `01 00 09` and packs `01 00`), and `eq(bool, false)` on a clear bit no longer writes its body. A count (`sized`, `bits`, `packed`, `times`) that names a skipped field returns `PackError::Missing` with the count's field name. A `when` or count that names a `flags` byte or a split flag byte reads the byte pack wrote, not a value kept in the row. A map `times` packed from per-name lists returns `PackError::Type` (`times at id 1: '1' has 3 items, count is 2`) when a list holds more items than the count, before any item error; the extra items used to be dropped, so give lists no longer than the count. A data member name declared twice in one scope now panics when the scheme is built (`u8("x"), u8("x")` packed `01 05 05` and lost the 7 on unpack; a name outside and inside a `times` could not be packed again; one inside a `repeat` round round-tripped and is refused now too). In calling code, rename the repeated member.

Java typed nested rows work. `group(get, set, create, fields...)` takes a factory for the child row: unpack calls it whenever the member is `null`, in each round of a `repeat` or `times` and for each element of a `list` or `dict` that holds the group (the child of a typed row was a `HashMap`, which threw `ClassCastException` on unpack). The old `group(get, set, fields...)` is for `Map` rows only: on a typed row, or below a group that has a factory, it now throws `IllegalArgumentException("nested group on a typed row needs a child factory")` when the scheme is built, so a typed row with a `Map` member that used it must pass a factory (`group(get, set, HashMap::new, ...)`). A `list` or `dict` whose element is `group(get, set, fields...)` on a typed row, or below a group that has a factory, is refused when the scheme is built too: `list element: nested group on a typed row needs a child factory` (`dict element: ...`; an inner list or dict names the container that holds the element). Pass `group(identity(), ignore(), Item::new, ...)`, or `HashMap::new` for `Map` elements; the bytes are the same. Anchored group and `flags` elements on a typed row still unpack into a `Map`, so typed accessors in them fail with a `ClassCastException` on unpack (not decided yet). The field ids of a nested row live in a scope of their own: `u8 profile(0), group(g, u8 inner(0)), when(1, eq(0, 1), u8 shape)` with `profile` 0 packs `010001` (it packed `01000109`; the other five packages already packed `010001`), and under `flags` a nested row sets its bit when the member is present, not when a field inside it is. A `repeat` or `times` inside a `repeat` or `times` round, which a Java build with the nested-round refusal rejected at construction, now packs and unpacks (see Repeat). `times` pack throws an `IllegalArgumentException` for a list longer than the count (`1: list has 3 entries for a count of 2`); it dropped the extra entries. Pack throws an `IllegalArgumentException` that names the field id where it used to write wrong bytes or throw another type: an integer out of range (it threw `ArithmeticException`), a `BigInteger` that wrapped (2^63 into `i64`), a fractional `BigDecimal` (1.5 was cut to 1), a string or boolean for a float (a `ClassCastException`), and a finite value too large for `f32` or `f64` (an `f32` wrote an infinity); `NaN` and the infinities are written as given, and code that caught `ArithmeticException` around `pack` must catch `IllegalArgumentException`. A `u2`, a nested `flags` and a group holding them under `flags` set the group's bit when any value inside is present (they were dropped, `01 00`), and a set group that lacks a required value fails pack and names it. Pack throws an `IllegalArgumentException` where it used to write bytes that unpack read differently: `missing group` for a nested row member that is `null` or absent wherever pack reaches it, also for a round of a `repeat` or `times` that has no row for it (`{g: [null, null]}` wrote `01`, and `{g: [{v: 1}, null]}` wrote `01 01`, which read back as `[{v: 1}]`); `missing list element 1` for a `null` element of a `list` of nested-row groups, and `missing dict element "b"` for a `null` value of a `dict` of them. `{}`, `{g: null}` and `{g: []}` for a `repeat` of the row still pack `01`: no round is reached, so no row is missing. An optional nested row belongs under `flags` or a flag-byte bit, where a `null` member still clears the bit and writes nothing. A `u2` inside a `repeat` or `times` round now packs the item of each round (`repeat(0, u2(a, b))` with `{a: [1, 2], b: [3, 0]}` packs `01 0d 02`; it threw `0: expected 2-bit int`). Java now refuses a key used twice in one scope when the scheme is built (`u8(0, "x"), u8(1, "x")` packed `01 05 05` and kept only the last value on unpack; a key outside and inside a `times` or `repeat` round could not be packed again, or packed other bytes). It reads the key from `Access.set("x")`; typed accessors and lambdas are not checked. In calling code, rename the repeated member.

Split-form flag bits are numbered by their place in the scheme: bit 0 is the first bit that follows a read of the flag byte, as in Rust and C++ already (AZ-2135). TypeScript, Java, Python and C# used to number a bit when you called `.bit(...)` (`.Bit(...)` in C#) on the handle. A handle shared by two schemes then gave the second scheme the next numbers (`[m, m.bit(x)]` with `x` = 5 packed `01 01 05` in the first scheme and `01 02 05` in the second in TypeScript, `01 03 05` in both in Java and C#), a bit created early but placed late kept its early number, and a flag byte read twice shared the numbers of its first read. A handle now holds no bit, any number of schemes can use it, and a second read of it starts its own bits: `[m, m.bit(a), m, m.bit(b)]` with only `b` set packs `01 00 01 09` (it packed `01 02 02 09`), and `[m, early, late]` with only the late bit set packs `01 02 09` (it packed `01 01 09`). Bits nested in one another number the outer one first. The ninth bit of one read fails when the scheme is built (TypeScript `flag byte "m": ninth bit (f8); a flag byte holds 8 bits`, Java `flags already has 8 bits`, Python `flags already has 8 bits` raised by `Scheme(...)`, C# `flag bit 'A8': one flags byte holds at most 8 bits` raised by `new Scheme<T>(...)`, while `.bit(...)` itself raises nothing; the combined C# `Field.Flags(...)` still refuses its ninth member when it is called). In Java a nested row is a scope of its own for flag bytes: a byte read inside it belongs to that row and is not visible after it, and a byte read before the row is not visible inside it, so the row reads its own byte (`[m, m.bit(a), group(g, m, m.bit(x)), m.bit(b)]` with `{a: 1, g: {x: 2}, b: 3}` packs `01 03 01 01 02 03`). The rule is by scope, not by what the member is: a bit inside a nested row whose only flag byte was read outside it fails when the scheme is built, `flag bit U8 0 has no flagByte before it in the same scope` (`[m, group(g, m.bit(x))]` used to build and pack `01 00 05` for `{g: {x: 5}}`, which unpack read as trailing bytes). `[m, group(identity(), ignore(), m.bit(x))]`, whose member is the row itself, used to pack `01 01 05` and read back, and fails too: read the byte inside the group, `[m, group(identity(), ignore(), m, m.bit(x))]` packs `01 00 01 05`. C# gives a nested row (`Group(x => x.G, ...)`) the same scope: the example above packs the same bytes there, `[m, Group(g, m.Bit(x))]` and `[Group(g, m, ...), m.Bit(x)]` built before and fail now when the scheme is built (`flag bit 'X' has no flag byte read before it in its scope`), and a nested row's members no longer share names with the row around it (see the typed rows paragraph below). C++ binds a split bit only to a flag byte of its own container that was read before it and is not inside a `when` that ended; a scheme whose only flag byte for a bit sits inside such a `when` fails with `SchemeInvalid` naming the bit, and unpack gives the flag byte values back when a taken `when` ends. The bytes of C++ schemes that worked do not change. C++ used to keep a `flags` member and the child of a flag bit visible after they end, as Rust, TypeScript and Java do not; since loop 18 (AZ-2304) a flag byte read inside either is invisible to later bits outside it, and the outer byte binds when one exists. Sibling members of one `flags` are separate flag-byte scopes in C++, TypeScript, Java and, since loop 19, Rust (see the loop 19 notes). Python now numbers its bits the same way (AZ-2230): `Scheme(...)` numbers them, a handle holds no bit and can be a member of any number of schemes, and a bit that is created and never placed leaves its bit clear, where Python used to refuse a flag byte listed without all its bits; the old bytes for a shared handle, a byte read twice or bits created out of scheme order were read as different fields by the other packages. C# numbers its bits the same way now (AZ-2135): `new Scheme<T>(...)` numbers them by their place, a `FlagByte()` handle holds no bit, any number of schemes can share it, one read holds at most eight bits, and a bit that is created and never placed takes no number (it took one when `.Bit(...)` was called, so a bit could be set with no value written after it: `[m, m.Bit(a)]` with `a` = 5, after an `m.Bit(b)` that no scheme placed, packed `01 02 05` and packs `01 01 05` now). A scheme whose bits were built in order on a handle of its own packs the same bytes as before; the three cases above are the ones that change. In calling code, place the bits in the order you want them numbered; a handle no longer has to be rebuilt for each scheme.

C# typed rows bind each nested row, `list` element and `dict` value on its own (AZ-2092). A nested row used to share one set of names with the row around it, so a member named like one of the outer row's members overwrote it: a `Name` on the outer row (1) and on the nested row (2) now pack `01 01 02` and read back as 1 and 2. `list` and `dict` members of rows work in typed `Pack` and `Unpack`: the C# example at the top packs and unpacks the bytes printed there. An element is read through the element field's accessor when the item is of that field's row type; any other item is the element's value itself, so a `List<object>` that holds row objects packs but unpacks as raw values. A collection member unpacks as an array, a `List<E>`, a `Dictionary<string, E>` or a type those can be assigned to; another collection type (`Stack<int>`, or a class derived from `List<E>`) built and threw out of `Unpack` in loop 17 and is refused when the scheme is built since loop 18. A nested row type, and the row type of a `list` or `dict` element, needs a public parameterless constructor, because unpack creates it: a type without one is refused when the scheme is built, with an `ArgumentException`. A flag byte read inside a nested row stays inside it, and a split bit outside it with its byte inside, or the byte outside and the bit inside, is refused at construction (see the split-form paragraph above). Two pack errors changed text and are still `ArgumentException`: an absent nested row outside `flags` says `'Inner' has no value`, and a set `flags` group with a null nested row names the nested row, where it named the group's first member. A typed `times` row packs a scalar member in every round; the rounds after the first threw `has no value`. Typed `Pack` and `Unpack` are faster, about twice as fast for the typed round trip: members are read and written through accessors compiled once, when the field is built, with no reflection per call. In calling code, give a nested row type a public parameterless constructor, and read a nested row's value from its own member, not from a member of the same name on the outer row.

C# counts, numbers and flag groups are stricter. The count of a `sized`, `bits`, `packed` or `times` must name an integer field (`u8` to `i64`) or a `u2` slot: a float, `bool`, string or byte run fails when the scheme is built, with an `ArgumentException` that names the counted field and the field it counts by (AZ-2181); a scheme with such a count built before. Float counts no longer exist, so a hostile float count (`NaN`, an infinity) cannot reach unpack. A count that pack did not write, or that does not fit an `int`, is an `ArgumentException` (`D: count 'N' is missing`); it was an `InvalidOperationException`, and a bare `OverflowException` for a count that did not fit. Dictionary rows pack numbers strictly (AZ-2191): an integer field takes a whole number that fits its width, and anything else throws an `ArgumentException` that names the member (`U8: 300 does not fit in u8`). It used to round a fraction, coerce a `bool` or a string, turn a `char` (`'a'` became 97) or an enum into its number, and throw a bare `OverflowException`, `FormatException` or `InvalidCastException` for the rest. A float field still takes any number, and an `f32` overflow is refused. A flags group is on when any value inside it is present (AZ-2128): a nested `flags`, a split flag bit and a `u2` with any one slot present now count. `flags(group(flags(u8 b)))` with `b` = 5 packs `01 01 01 05` (it packed `01 00` and dropped `b`), a `u2` with only its second slot present fails and names the slot that is missing (it packed `01 00`), and a set group with a required value left out fails and names it. A `when`, `repeat` or `times` directly under `flags` or a flag bit was still ignored in loop 17; it is written since loop 18. In calling code, count by an integer field and give dictionary rows whole numbers.

C# rounds take a lone value (AZ-2182). In a `repeat` or `times` round, a value that is not a list goes to every round. It used to go to round 0 only, so a later round that needed it threw `has no value`, and a round under `flags` or a flag bit left its bit clear: `repeat(flags(a), b)` with `a` = 5 and `b` = [1, 2] packed `01 01 05 01 00 02` and packs `01 01 05 01 01 05 02`. A lone string for a `utf8` name goes to every round too (a lone dictionary for a `dict` name went to every round in loop 17 and is refused since loop 18). A lone `byte[]` or list of numbers for a `bytes`, `sized`, `bits` or `packed` name was read as the list of rounds. It throws an `ArgumentException` that names the field and says to wrap the value in a list, and an empty lone `byte[]`, which meant zero rounds (`01`), is refused too; a typed row's `bytes` member in a round is always refused for that reason. A `list` or `dict` whose element is a `group` now unpacks (AZ-2119); it threw `KeyNotFoundException`. Typed rows get one row per item, for a nested-row group and for an anchored group, and the dictionary form of an unpacked row (no public call returns it yet) holds a row keyed by the member names, as the other packages return it. In calling code, wrap a lone byte run or list in a list, and expect a lone scalar in every round.


Loop 18 (all six packages). These changes break existing code or data: a scheme that built before can fail to build, and a row that packed before can pack to other bytes or fail to pack. Packet bytes of every scheme that does not use the shapes below do not change, `fixtures/golden.hex` and the route packet are unchanged, and every packet an older version wrote still unpacks as it did.

Construction is stricter in every package. A `when` with `eq` of a `bool` against anything but `true` fails when the scheme is built (it could never match on unpack: a clear bit is absent). A `when` that names a field that is not an integer, a `u2` slot or a `bool` fails too (a float, `utf8`, `bytes`, `sized`, `bits` or `packed` field), and a count (`sized`, `bits`, `packed`, `times`) that names a field that is not an integer fails (Java, Rust and C++ used to accept a `bool` count; C# had refused all but integer counts since loop 17). In C#, a `when` on a float field, which AZ-2088 had allowed, is refused now. The errors are each package's own text, so test for the failure and not for its words. If you upgrade, check the schemes that carry a `when` on a bool or on a field that is not an integer.

A `when`, `times` or `repeat` as a member of `flags`, as the field of a flag bit, or in a group under them is written now, in all six packages, and sets its bit when it writes a value (see Flags). Before, these packed with the bit clear and the value dropped, in the same way in every package: `u8 mode; flags(when(mode == 1, u8 speed), u16 heading)` with `mode` = 1, `speed` = 7 and `heading` = 90 packed `01 01 02 5a 00` and packs `01 01 03 07 5a 00`. The changes to watch: pack bytes for this shape change (breaking for any test or fixture that pins these bytes; a peer on either version reads the packets of both, because unpack did not change, but the old version never writes `speed`); a set `when`, `times` or `repeat` whose value cannot be written in full fails pack and names the value; a `times` whose count is 0 and whose list is not empty fails pack (`'V' holds 1 items, but the times count is 0` in C#), outside `flags` as well as inside, and in C++ too; and a row unpacked from an old packet whose bit is clear while its `times` count is above 0 no longer repacks (pack fails naming the missing value; before, it repacked to the old bytes with the body left out). Unpack of old packets (bit clear) is unchanged. C++ also changed here: a group, `when` body or flag bit whose only values sit in a `u2`, a nested `flags` or a `flag_bit` now sets its bit, and a bound `times` or `repeat` with zero rounds under `flags` leaves its bit clear (it set it).

A lone dictionary for a `dict` name in a `repeat` or `times` round is refused in C#, TypeScript, Python, Java and Rust, and a list with one dictionary per round packs as before (see Repeat). A caller that passed one dictionary and relied on it reaching every round must put a dictionary in each round's entry. In the Rust map form, a lone scalar for a `times` member now goes to every round (it went to round 0 only, so a later round failed with `Missing`). TypeScript no longer takes a `Map`, `Set`, `Date` or class instance as a dictionary for a `dict` name: it is refused with `RangeError` `d: expected dictionary` (a `Map` packed as an empty dictionary, `01 00 00`, and lost its entries); a plain object and an object with no prototype still pack as a dictionary outside a round, and a list of them packs in a round. Inside a round a lone `Map`, `Set` or `Date` is refused as a lone dictionary.

C++ changed in three more places. A flag bit does not bind to a flag byte read inside a `flags` member or inside the child of a flag bit; the outer byte binds when one exists, and a scheme whose only byte for a bit sits there fails with `SchemeInvalid` (or a compile error for a `constexpr` scheme). A `times` whose count is 0 and whose `Array` is not empty is `BadValue`, as every other count mismatch was. Zero-round `times` and `repeat` under `flags` leave their bit clear, as above. The unpack path gained one small function, `unpack_scoped`; on the Cortex-M4F target the deepest pack and unpack stack is 456 B of the 512 B budget and the flash 7,992 B of 8,192 B after the change.

C# changed in more places (AZ-2305 to AZ-2310). Typed collection members are checked when `new Scheme<T>` runs. A `list` member must be a one-dimensional array, a `List<E>`, an `IList<E>` or an `IList`; a `dict` member a `Dictionary<string, E>`, an `IDictionary<string, E>` or an `IDictionary`. Refused: `ICollection<E>`, `IReadOnlyList<E>`, `Collection<E>`, `IEnumerable<E>`, `HashSet<E>`, `Stack<E>`, a class derived from `List<E>`, and a `dict` whose keys are not `string`. The element type must be `object`, a row type, or a type that holds the whole range of the field: an integer member type must contain the field's range (`List<int>` for a `u32` is refused, `List<long>` and `List<uint>` are accepted, and so is any `float`, `double` or `decimal`, although since loop 21 pack refuses the items of such a list: open, loop 22); `utf8` takes `string`, `bytes` and `sized` `byte[]`, `bool` `bool`, `f32` `float` or `double`, `f64` `double`, a `u2` an integer type that holds 0 to 3, a `group`, `flags` or `dict` element a type a `Dictionary<string, object?>` can be assigned to, and a `list` element a type a `List<object?>` can be assigned to. The error names the member and the element (`'Ids': List<Int32> cannot hold the u32 elements of its field; element type Int32 is too narrow or of another kind`). Some of these types worked before (`ICollection<int>`, `IReadOnlyList<int>`, `Collection<int>`, an `IConvertible` element type), and are refused now on purpose: a refusal can be relaxed later, an accepted type cannot be withdrawn; which types to accept is the owner's call. A packet that is too large for a narrow element type used to throw `OverflowException` out of `Unpack` (the F25 finding: `01 01 00 FF FF FF FF` against a `List<int>`); the scheme does not build now, and the same packet against `List<long>` returns 4294967295. A non-null typed nested row whose members are all null counts as present under `Flags`, so pack fails naming the first missing member (before, the bit was clear and the row was dropped silently); a null nested row still packs `01 00`, and a filled depth-2 row packs `01 01 04 06`. `u2` slots and the items of `bits` and `packed` are strict (see Integers): a fraction, a number out of range, a `bool`, string, `char`, enum, other object or `null` throws an `ArgumentException` that names the member; `char`, enum and `object` stay refused for every numeric field by decision. The dictionary form of `Pack` takes back the rows that `Read` returns for a `list` or `dict` of groups (it failed with `'A' has no value`), and a `byte`-run field given an `int` is an `ArgumentException` (`expected a byte[], got Int32`; it was a bare `InvalidCastException`). A `Flags` as a direct `list` or `dict` element packs and unpacks, in typed and in dictionary rows (it threw `KeyNotFoundException` out of `Unpack`): a list of `[{A: 1}, {}, {B: 2}]` packs `01 03 00 01 01 00 02 02 00`. C# now takes part in the `listgroup`, `dictgroup` and `listflags` handoff rings of CI, and the C# handoff driver was changed to match the stricter member rule. In calling code, declare list and dict members as arrays, `List<E>` or `Dictionary<string, E>` of a wide enough element type, give `u2` slots and `bits` items whole numbers in range, and expect `Pack` to throw for an all-null nested row under `Flags`.

Loop 19 (all six packages unless named). These changes break existing code or data: a scheme that built before can fail to build, and a row that packed before can pack to other bytes or fail to pack. Packet bytes of every scheme that does not use the shapes below do not change, and `fixtures/golden.hex` and the route packet are unchanged. Every packet an older version wrote still unpacks as it did, except for the Python round scope and the Rust sibling `flags` scope below. Each change has a test that failed on the previous version, and the hostile set (`fixtures/hostile/cases.txt`, 33 cases) replays the new pack and construct cases in all six packages (C++ skips two with a stated reason).

Pack refuses a `times` count above the scheme's `maxRounds` (default 65,535) in TypeScript, Python, Java, C# and Rust. It checks before it writes a round and allocates nothing for the count, so a count of 65,536 or 4,000,000,000 with one lone value no longer writes that many rounds (65,541 bytes, and about 4 GiB). The error names a member of the body (TypeScript `k: the times count is 65536, above the limit of 65535 rounds`; Python `ValueError`, `times 1: 65536 rounds, the limit is 65535` (since loop 20 `k: the times count is 65536, above the limit of 65535 rounds`, as TypeScript); Java `IllegalArgumentException`, `times: count 65536 is above the limit of 65535 rounds`, and a count too large for an `int` is refused the same way; C# `ArgumentException`; Rust `PackError::Type`). It covers a `times` in `flags`, in a round and in a group, and it uses the limit the scheme carries: a scheme built with a lower `maxRounds` cannot pack a count above it (Rust `with_limits(2, ..)` cannot pack a count of 3), and a scheme with a higher one packs that many rounds (Python `with_limits(max_rounds=70_000)` packs 70,000). C++ is unchanged: its rounds live in an `Array` of at most 65,535 items and a longer count is `BadValue`. `repeat` is capped on pack since loop 20. In calling code, check the count where you set it, or raise `maxRounds` on the scheme.

Python rounds use a fresh scope, in pack and in unpack, as TypeScript and C# do. A `when` in a `repeat` or `times` round used to see a value that an earlier round skipped. A round whose `when` names such a value now packs and reads like TypeScript (`u8 a; times(a, u8 k, when(k == 1, u8 v), when(v == 5, u8 w))` with `a` = 2, `k` = [1, 0], `v` = [5] and `w` = [7] packs `01 02 01 05 07 00` in both; Python raised `TypeError` there before). The bytes change for that shape, and so does the unpack of a packet written for it. In calling code, check the schemes whose `when` names a value from another round.

A split flag bit that decides a `when` or `times` whose source is written after the flag byte no longer drops its body silently. Pack fails, naming the member, when the body would be written and the byte left the bit clear: the condition is true, the count is above 0, or the count is 0 and a list of values is given, or the count is never written and values are given (see Flags). A false condition still packs silently, with the body left out, before or after the byte, and the combined `flags` form is unchanged. C#, Rust, TypeScript, Python, Java and C++ agree on the hostile shapes (`pack_split_when_source_after_byte`, `pack_split_times_count_after_byte`, `pack_split_times_count_skipped`, `pack_split_false_condition_silent`). C++ differed in two corners; loop 20 closed both (see the loop 20 notes). Python and C++ also refuse values given for a `times` whose count was skipped in the combined `flags` form, where the other four dropped them until loop 20. A row that packed before can fail now: write the condition or count field before the flag byte, or leave the body out.

A lone byte buffer for a `bytes` or `sized` name in a `repeat` or `times` round is refused in TypeScript, Python, Java and Rust (they copied the buffer to every round, and C# has refused it since loop 17). Give a list with one buffer per round: `d: [b"\x01\x02", b"\x03\x04"]` with a count of 2 packs. The error names the member. A lone string for a `utf8` name still goes to every round. C++ rounds are typed arrays, so it has no such value.

Rust gives each member of a `flags` its own flag-byte scope, as C++, TypeScript and Java do. A flag byte read inside one member no longer serves a bit in the next member. A scheme whose bit bound to an earlier sibling's byte now binds to the outer byte, or fails at construction when there is none, and its bytes change: `flagbyte fb; flags(group g1 {v; fb byte; bit fb x}, group g2 {bit fb y}); bit fb b` with `v` = 3, `x` = 5, `y` = 6 and `b` = 7 packed `01 01 03 03 03 05 06 07` and packs `01 03 03 03 01 05 06 07`, the bytes TypeScript gives for it.

C++ accepts an empty group as a `when` source, as Rust does: `group<&Row::m>(id)` on a `bool` member, tested with `eq(id, true)`. It used to fail with `SchemeInvalid`. An empty group takes the id of the field after it, so it binds only when no other field has that id; if one does, that field is the source.

A `times` count of 0 with a list of values is an error in all six packages (before and after a flag byte), and a lone scalar with a count of 0 packs `01 00` and drops the value in all six. Python names the member for a `times` list that is shorter than the count or empty (`ValueError`, `1: 1 items, times count is 2`); it was a bare `IndexError`. A member under `flags` or a flag bit still takes a short list as absent for the rounds it does not reach.

A C# `List` or `Dict` element that is a group takes its values from its own members only. In the dictionary form, a row whose element lacked a member and relied on the outer row's value of the same name now throws an `ArgumentException` that names the member; the outer value is no longer copied in.

`eq` on an integer source is checked when the scheme is built, in all six packages (C++ for out-of-range integers only, below). A value outside the source's range (`eq(u8, 300)`, `eq(u64, -1)`, a `u2` slot against 4, `i8` against 200), a string, `NaN` or a fraction (`1.5`), or a `bool` is refused at construction, because the condition could never match. The edge values of the range still build (0 and 255 for `u8`, 3 for a `u2` slot). A whole-number float such as `5.0` is not uniform: Java, Python and Rust refuse it; C# refuses it since loop 20 (`5f` and `5m` too), and TypeScript accepts it because it cannot tell it from `5`. C# also refuses a double near a whole number (`255.00000000000003`) and `5.5m`. C++ refuses out-of-range integers only: a `constexpr` scheme with such a constant does not compile (`when_eq_out_of_range.cpp`), a scheme built at run time fails with `SchemeInvalid`, and `eq(u8, 1.5)` and `eq(u8, true)` still build because a typed constant is converted to a 64-bit integer first. TypeScript no longer accepts `eq(intSource, undefined)` or `eq(intSource, null)`, which matched an unwritten source: a scheme that relied on it fails at construction. In calling code, check every `eq` constant against the width of its source.

C# keeps the strict member-type set for typed `List` and `Dict` members (owner decision 10): `ICollection<E>`, `IReadOnlyList<E>`, `Collection<E>` and the other types listed in the loop 18 notes stay refused, and the rule may be relaxed in a later loop. C# also stays in the `listgroup`, `dictgroup` and `listflags` rings as a chain (TypeScript, Python, Java, C#, TypeScript), not as every pair (owner decision 12).

Loop 20 (all six packages unless named). These changes break existing code or data: a row that packed before can fail to pack, and a scheme that built before can fail to build. Packet bytes of every row that still packs do not change, `fixtures/golden.hex` and the route packet are unchanged, and every packet an older version wrote still unpacks as it did. Each change has a test that failed on the previous version, and the hostile set (`fixtures/hostile/cases.txt`, 40 cases) replays seven new `pack` cases in all six packages (C++ skips five and Rust one, each with a stated reason).

Pack has an output budget. One pack call may write at most `maxBytes` bytes, the type byte included (default 16,777,216, 16 MiB). Each write is checked before it is made, so the buffer never grows past the budget, and a refused call returns nothing: `s: the packet would be 16777477 bytes, above the limit of 16777216 bytes`. The member named is the one being written (a `u2` by its first slot, a combined `flags` byte by the first name its members declare). A packet of exactly `maxBytes` packs. Before, a lone `utf8` of 65,535 characters under a `times` of 65,535 rounds wrote 4 GiB from a 64 KiB request, and a `list` element that holds a `times` repeated that cap per element; both are refused now in milliseconds and under 256 MB. A lone string for a `utf8` name in a round is still repeated in every round, so `n` rounds of a long string are `n` times its size: the packet length is the caller's to bound, and `maxBytes` is the bound pack applies for you. Raise it only as far as your memory per concurrent call allows. The error is a `RangeError` in TypeScript, a `ValueError` in Python, an `IllegalArgumentException` in Java, an `ArgumentException` in C# and a `PackError::Type` in Rust. Set the budget where you declare the scheme: `new Scheme(type, fields, { maxBytes: 64_000_000 })` or `scheme.withLimits({ maxBytes: 64_000_000 })` (TypeScript; a limit left out of `withLimits` takes the default), `scheme.with_limits(max_bytes=64_000_000)` (Python; `Scheme.DEFAULT_MAX_BYTES`), `scheme.withMaxBytes(64_000_000L)` (Java; `Scheme.DEFAULT_MAX_BYTES`; `withLimits(int, long)` resets it to the default), an optional trailing `maxBytes` parameter of `WithLimits` (C#; `BinaryPacker.DefaultMaxBytes`) and `scheme.with_max_bytes(64_000_000)` (Rust, on `MapScheme` and the typed `Scheme`; `DEFAULT_MAX_BYTES`; `with_limits` keeps it). A value below 1 is refused when you call it (TypeScript: `maxBytes: expected a positive integer up to 9007199254740991`). C# stops at 2,147,483,591 bytes and Java at 2,147,483,639 whatever `maxBytes` says (the array limit). A row that packed to more than 16 MiB before now fails until the scheme raises `maxBytes`. C++ has no budget: it writes into your buffer and returns `BufferFull`, and its rounds live in fixed arrays.

Pack applies the other two limits as well. `maxSlots` is charged as each round starts, before any of its bytes, with the width the package's own unpack charges; one counter covers every `repeat` and `times` of the call at any depth, `list` and `dict` elements included, and slots are checked before bytes (`k: the rounds would hold 1048580 slots, above the limit of 1048576 slots`). A `repeat` whose longest list passes `maxRounds` is refused before any round, naming the first member whose list passes it (`k: the repeat count is 65536, above the limit of 65535 rounds`); 65,536 entries packed before, into a packet the same scheme's unpack refused. Raise the limits on the scheme to pack more. Messages differ by package; test for the failure, not its words. The width is one rule in all six packages since loop 21 (see Limits).

Rows that packed before and are refused now:

- A plain `times` (no flag byte) whose count sits behind a clear `when`, with a count of 0 and no rounds, packed `01 00` in C++ and is `BadValue` now; C++'s own unpack and Python's pack already refused that packet. It is the one accepted row that changed in C++.
- A combined `flags` whose `times` count was skipped and that is given values (`pt: a value is given, but the count of its times is not written, so its bit is clear; write the count before the times`, TypeScript text) in C#, TypeScript, Java and Rust, which dropped them; Python's error now names the member (`pt`), not `times 1`. A typed C# row cannot leave a non-nullable member out, so it counts as given: a row with a `byte Pt` packed `01 00` and is refused now.
- Java: a `Long` or `BigInteger` of 2^32 + 1 and a `BigDecimal` of `0.1` or `1.5` in a `u2`, `bits` or `packed` slot (cut to 1, 0 and 1 before; `0: expected 2-bit int`), and a `u64` count above the `int` range in `sized` or `bits` (`1: count 4294967299 is above the limit of 2147483647 items`; it was cut to an `int`).
- C#, a `list` or `dict` member of a `repeat` or `times` round: the round holds one list per round, so the member must be able to hold it (`List<List<object?>>`, `IList`, `IList<object?>`, `List<object?>`, `object[]` or `object`). `List<int>` and `List<long>` of scalars, and a pack-only member such as `List<List<int>>` or `IList<int>`, fail when the scheme is built (`'Ids': List<Int32> cannot hold the list a repeat or times round reads for its field (one list per round); use ...`). A `dict` member in a round built in loop 20 and a typed unpack returned an error value for it; since loop 21 it must hold one dictionary per round too (see the loop 21 notes).
- C#, whole-number floats: `Eq(u8, 5.0)` (and `5f`, `5m`) fails when the scheme is built, and `3.0` in a `u2`, `bits` or `packed` slot fails on pack. A plain integer field (`u8` to `i64`) took `5.0` in the dictionary form in loop 20, because C# unpack returned narrow integers as `double`; since loop 21 unpack returns the exact integer types and an integer field refuses a whole float too (see the loop 21 notes).
- A `times` count of 0 written after the flag byte with a list of values is refused in all six packages; with a lone scalar it packs zero rounds (`01 00 00`). Python and Rust refused the lone scalar before.
- Python: a `repeat` as a `flags` member with an empty list no longer raises a bare `IndexError` (`repeat { u8 w; flags { u8 v } }` with `w` = [1, 2] and `v` = [] packs `01 01 00 02 00`), and a required value with an empty list beside a longer one raises a `KeyError` that names it (`'missing field w'`).
- C++: a `bits`, `packed` or `sized` count behind a clear `when` is refused, as a `times` count is (a packet such as `01 00 05` packed before and C++'s own unpack refused it), and so is every late `when` or `times` of one flag bit, nested ones included; only the first was seen. Two new limits at construction (`SchemeInvalid`): a count more than 255 entries after the `when` that holds it, and a link of more than 255 entries between two late `when`s of one bit; a count that sits inside the `when` that holds it has no such limit. The Cortex-M4F image is 8,160 of 8,192 bytes of flash (margin 32 bytes) and the deepest stack is 448 of 512 bytes.

C# also changes in two ways that are not row refusals. `Scheme<T>.WithLimits(int, long)` became `WithLimits(int, long, long)` with the third parameter optional: source compatible, but code compiled against the old assembly had to be recompiled (a `MissingMethodException` otherwise). Loop 21 brings the two-argument overload back, so that code binds again without a recompile. A typed `Unpack` of a packet whose round is set returns an error value naming the member instead of throwing `InvalidCastException`, when the row has a member that cannot hold the list of rounds (a `byte` member).

C++ `eq(u8, true)` and `eq(u8, 1.5)` still build, as before: a typed constant is converted to a 64-bit integer before the range check, and refusing them needs an `Eq` overload per type. That is documented and kept (owner decision, loop 20). In calling code: raise `maxBytes`, `maxSlots` or `maxRounds` on a scheme that must pack more, write the count before the flag byte, declare round members of a C# row as one of the types above, and recompile C# code that calls `WithLimits` (not needed since loop 21).

Loop 21 (all six packages unless named). These changes break existing code or data: a scheme that built before can fail to build, and a row that packed before can fail to pack. Packet bytes of every row that still packs do not change, `fixtures/golden.hex` and the route packet are unchanged, and every packet an older version wrote still unpacks as it did, except that Python's unpack now accepts packets its slot surcharge refused. The hostile set (`fixtures/hostile/cases.txt`, 55 cases) gained 15 cases (C++ skips seven and Rust two, each with a stated reason in the file's README), and the Python, Java, Rust and C++ loaders now name the rule or message each refused case must give, so a refusal by some other rule no longer passes.

One slot rule. The width of a round is the same in all six packages (see Limits), and pack and unpack charge it alike, so a packet that pack writes at exactly `maxSlots` unpacks. Rust no longer counts the names of a group, a `flags` or a flag byte, so its rounds are narrower. Python now counts an empty group's name, counts a name that two `when` branches both declare once, and no longer charges 8 more slots per name for the first round of each run when it unpacks: a Python packet that the surcharge refused (many short runs, in `list` elements for example) unpacks now. Java counts a nested-row group as one slot. If `maxSlots` is set close to what a Rust or Python workload needs, check it.

Rows and schemes that built or packed before and are refused now:

- A `repeat` or `times` whose body holds no member (see Untrusted input).
- A `repeat` row with a short non-empty list under `flags` or a flag bit (TypeScript, Python, Java, C#; see Repeat). Give one entry per round, with the absent value where the member is absent.
- A split-bit or combined-`flags` `times` whose count is above 0 in the row but was written by no field, because its `when` is clear (see Flags). Where it was accepted it packed a clear bit.
- A `bits`, `packed` or `sized` that is given a value while its count sits behind a clear `when`. TypeScript and C++ refused it before; all six refuse it now.
- C#: an integer field given a `float`, `double` or `decimal`, whole or not, in a dictionary row (see Integers). A dictionary built by hand with `5.0` for a `u8` must hold `5`; a row that unpack returned holds the exact type and packs as before.
- C#: a `dict` member of a `repeat` or `times` round that cannot hold one dictionary per round (below).

Rows that failed or packed other bytes before and pack now: a Java split-bit `times` with a count above 0 written after the byte and no body (a clear bit, see Flags), and a late `when` in a bit body that another member of the bit sets, in C++ and Rust (see Flags). The Cortex-M4F image after the C++ changes is 8,152 of 8,192 bytes of flash (margin 40 bytes) and the deepest stack is 456 of 512 bytes.

C# changed in these places besides the refusals above (AZ-2373, AZ-2388, AZ-2389, AZ-2393). `UnpackResult.Values` holds `byte`, `sbyte`, `ushort`, `short`, `uint`, `int`, `ulong` and `long` for the integer fields (an `f32` stays a `double`); the narrow ones arrived as `double` before. The `BinaryPacker.Read` that returns it is internal, so only code that reaches it sees the change: a read of `(double)Values["x"]` for a `u8` throws `InvalidCastException` now; read the exact type or use `Convert.ToDouble`. The dictionary form of `Pack` takes those types back, so unpack then pack gives the same bytes; `f32` and `f64` fields still take any number, whole floats included. A typed row binds its rounds to a collection of rows (see Times). A `dict` member of a round must hold one dictionary per round, as a `list` member holds one list: `List<Dictionary<string, object?>>`, `IList`, `IList<object?>`, `List<object?>`, `object[]` or `object`, and any other type, `Dictionary<string, E>` for one, fails when the scheme is built (`'Maps': ... cannot hold the list a repeat or times round reads for its field (one dictionary per round); use List<Dictionary<string, object?>>, IList, IList<object?>, List<object?>, object[] or object`). A count above `int.MaxValue` is an `ArgumentException` with a fixed text (`Out: count 'U' is 3000000000, which does not fit an int`; `times: count 'L' is -9223372036854775808, which does not fit an int` for a `times`). A lone `byte[]` for a `bytes` name in a `repeat` is refused with `'Raw': a round's value belongs in a list with one entry per round; wrap this value in a list`, unless it is longer than `maxRounds`, which is checked first (`'Raw': the repeat count is 3, above the limit of 2 rounds`); a `byte[]` for a scalar name is one round per byte. `WithLimits(int, long)` is an overload again. A `List<double>`, `List<float>` or `List<decimal>` member (or an array, `IList<>` or `Dictionary<string, E>` of them) for an integer `list` or `dict` is refused when the scheme is built since loop 22; it built and unpacked before, and pack refused its items (`'Ids': List<Double> holds Double elements, which pack refuses for the u8 elements of its field; use an integer element type`). An `f32` or `f64` list keeps taking `float` and `double`.

Accepted differences (owner decision, loop 21). The six packages refuse the same rows, not always with the same words or the same exception class, so test for the failure and not for its kind. Message wording differs; C# quotes the member (`'Raw': ...`); a `bits`, `packed` or `sized` count behind a clear `when` is an `IllegalStateException` in Java and a `RuntimeError` in Python, where the others raise their argument error; and the `field` an unpack error names is the first name unpack finds, which is not always the member pack names (a split flag byte comes first). The rounds, the counts and the bytes are the same.

In calling code: give one entry per round for the members under `flags` in a `repeat`, give no `repeat` or `times` an empty body, leave a count behind a clear `when` out of the row (or give 0), give integer fields of a C# dictionary row an integer type, and give a C# `dict` member of a round one of the types above.

Loop 22 (named packages). These changes break existing code or data: a scheme that built before can fail to build, and a row that packed before can fail to pack. Packet bytes of every row that still packs do not change, `fixtures/golden.hex` and the route packet are unchanged, and every packet an older version wrote still unpacks as it did, except that a packet with more than 1,048,576 slots in its rounds is refused until the scheme raises `maxSlots`. The hostile set (`fixtures/hostile/cases.txt`) has 65 cases, ten of them new.

- Default `maxSlots` is 1,048,576 in C#, TypeScript, Java, Rust and Python (it was 4,194,304; C++ has no limit). See Limits and the memory figures there.
- A `bits`, `packed` or `sized` whose count sits in the row, above 0, behind a clear `when`, with no value for the member, in a split bit or a combined `flags`, is refused in all six packages (it packed a clear bit, `01 00 00`). Count 0, no count and a holding `when` pack as before. In C++ a member bound to an `Array` or `Blob` is always present, so its bit is set and pack refuses every such row with `BadValue` at the member, whatever the count or the `packed` bias (loop 23 trace, U20); written unbound (no member pointer) it packs the clear bit like a member with no value, count 3 included, where the five refuse (a documented exception, U24 B, see below).
- C#: a `List<double>`, `List<float>`, `List<decimal>`, `double[]` or a dictionary of them for an integer `list` or `dict` no longer builds (see Integers).
- Rust (map form): per-name lists for a `repeat` given without `__repeat__` groups are refused, and a short or empty list for a `times` member under `flags` or a flag bit is accepted (see Repeat and Times).
- Python: `repeat` lists no longer need equal lengths (a lone value, a `when` list shorter than the longest); a short required list is still refused.

Loop 23 (named packages). These changes break existing code: a scheme that built before can fail to build, and a row that packed before can fail to pack. Packet bytes of every row that still packs do not change, `fixtures/golden.hex` and the route packet are unchanged, every packet an older version wrote still unpacks as it did, and the hostile set keeps its 65 cases.

- C++: a `when` whose `eq` names a field id below 0 or above 32,767 is refused when the scheme is built (`SchemeInvalid` at the `when`'s id). Count ids are not checked yet (see the open rows below). Before, `eq(-1, v)` built, the `when` never held, its member was dropped on pack and unpack of the same packet failed; `eq(32768)` and `eq(65535)` wrapped to a negative id the same way. The check is made at compile time and costs no flash.
- Rust (map form): a value kept beside `__repeat__` groups that the rounds do not hold, and a name of a `times` nested in a `repeat` body, its `__times_<anchor>` key or the own name of a `flags` in the body given without groups, are refused instead of dropped (see Repeat).
- TypeScript: a `bigint` count above 2^53 for a `bits`, `packed` or `sized` behind a clear `when`, with no value, is refused as Python, Rust, Java and C# refuse it (it packed a clear bit). A `times` count above 2^53 behind a clear `when` still packs its clear bit in TypeScript (a documented split, U6).
- Python: a count list in a `times` or `repeat` round that is shorter than the rounds, where the round with no entry has its `when` clear, packs again (`times(n) { u8 mode; when(mode == 1, u8 c); flags(bits v, count c) }` with `n = 2`, `mode = [1, 0]`, `c = [3]` packs `01 02 01 03 00 00 00`, as in TypeScript, Java and C#); loop 22 refused it with `2: 1 items, times count is 2` (`repeat`: `missing field c`). A round whose `when` holds still needs its entry.
- C++ (documented, U20): a `bits`, `packed` or `sized` member bound to an `Array` or `Blob` is always present in a typed row (an empty one is a value with zero items), so its flag bit is always set and pack reaches the member. When the `when` that holds its count is clear, pack refuses with `BadValue` at the member's id whatever the count or the `packed` bias (count 0, a left-out count and bias -1 with count 1 included), where the other five pack `01 00 00` for a row with no value. To leave the member out, write it unbound (for example `packed(1, 2, 1, -1)`, no member pointer): its bit is then clear and it packs as the other five do for count 0, a left-out count, count 1 with bias -1 and a holding `when`.

Loop 24 (Go). The seventh package, `go/`, is new: no existing package changed, and `fixtures/golden.hex` and the route packet are the same for all seven. Go runs the 65 hostile vectors of `fixtures/hostile/cases.txt` like the others. Go follows TypeScript row for row, and where it differs, the owner decided it; the differences are refusals and row shapes, never bytes (see [Go rows](#go-rows)):

- Group rows are nested maps in both directions (Go-4). TypeScript packs the group's members from the nested object or from flat keys and unpacks them flat. In Go a flat key that names a member of a group whose map is not given is refused, a group in a round takes one map a round, and a list or dict inside a lone group map given once for every round is refused.
- A `Nested` row is a scope of its own, so its members may repeat a name of the row around it (the anchored `Group` still refuses that).
- A non-`bool` value for a `Bool` (Go-1) and a whole float for an integer field (Go-2) are refused. TypeScript clears the bit and packs the float. A `json.Unmarshal` map needs typed rows or integer values.
- A typed `Times` refuses a count that differs from the slice length, as C# does. `[]byte` is a byte run and never a list or a list of rounds.
- `WithLimits(Limits)` takes all three limits and refuses a value below 1.
- `NewScheme` refuses `zero_progress_repeat_bool` and `zero_progress_repeat_when`, which TypeScript builds, and reports a ninth `Flags` member.
- A split flag bit inside a false `when` packs as TypeScript does, with the bit of the unwritten member set (Go-3, pinned); the other packages are still to be probed.

Loop 26 (Swift). The eighth package is new: `Package.swift` at the repository root and the sources in `swift/`. No existing package changed, and `fixtures/golden.hex` and the route packet are the same for all eight. Swift runs the 65 hostile vectors of `fixtures/hostile/cases.txt` like the others, and its session gives the C# ciphertext. Swift follows TypeScript row for row; where it differs, it takes the owner's Go decisions, and the differences are refusals and row shapes, never bytes (see [Swift rows](#swift-rows)):

- Group rows are nested maps in both directions (Go-4), a flat key that names a member of a group whose map is not given is refused, and a nested row (`.group(name, ...)`) is a scope of its own.
- A non-`Bool` value for a `bool` or a mark (Go-1), and a `Double` (a whole one too), a `Bool` or an enum case for an integer field (Go-2), are refused.
- A typed `times` refuses a count other than the number of elements. `[UInt8]` is a byte run and never a list or a list of rounds.
- Dict keys that are equal as Swift strings and differ in bytes (NFC and NFD) are refused on unpack and on pack; TypeScript keeps both.
- `withLimits(maxRounds:maxSlots:maxBytes:)` gives a left-out limit its default and refuses a value below 1.
- `Scheme` refuses a negative `bytes` size, a `u2` or flag byte as a list or dict element, and the hostile schemes `zero_progress_repeat_bool` and `zero_progress_repeat_when`, which TypeScript builds.
- Every error is a thrown `PackbinError`, and unpack reports an unusable value as `.short` with `needed` 0 (as Go and TypeScript) and a round past a limit as `.tooMany` (as Go).

Limits to keep in mind:

- Round limits (C#, TypeScript, Java, Rust, Python, Go and Swift). A scheme carries two limits on one unpack call (and a third, `maxBytes`, on one pack call: see the loop 20 notes). `maxRounds`, default 65,535, is the most rounds one `repeat` or `times` field may start. `maxSlots`, default 1,048,576 (4,194,304 before loop 22), is the most slots all the rounds of the call may create together. A slot is one entry of a round's lists, one for each name the round can hold, even where the round read nothing, so a round of a 36-name `when` body takes 36 slots. Since loop 21 all six packages count the width of a round the same way: the number of distinct names it can hold. One slot each for a value field (an integer, a float, `utf8`, `bytes`, `bool`), a `sized`, `bits` or `packed` name, a `list` or `dict` name (however many items it holds), each slot name of a `u2`, and an empty group's own name; and one for each name inside a `when` (whether its condition holds in the round or not), a `flags`, a flag bit or a group, at any depth. A non-empty group's own name, a `flags` itself and its flag byte, a split flag byte, and the anchors of `when`, `repeat` and `times` are no slot. A name that the round declares twice (two `when` branches that both declare `k`) is one slot. One counter covers a whole pack call and a whole unpack call, shared by every `repeat` and `times` at any depth (top level, `flags`, groups, `when`, split bits, `list` and `dict` elements). Pack and unpack charge the same width at the same round, so a packet that pack writes at exactly `maxSlots` unpacks, and the round after it is refused by both. The one exception is Java: it counts a nested-row group (a `group(get, set, ...)` row, an empty one too) as one slot, its own name, where the others count the names inside it. A member that has no name (a Java typed accessor or lambda, a Python identity accessor `lambda row: row`) is a slot of its own, so two of those are two slots. A packet that would pass either limit is refused when the round that crosses it starts, before the round's bytes are read and before anything is allocated for it, with the same bad-value error as any other unreadable value (see above): no row, handler not called. On unpack a `times` count above `maxRounds` is not refused up front; a packet that states a huge count and holds few rounds still ends in a short read. Pack refuses a `times` count or a `repeat` list above `maxRounds` before it writes a round, and charges `maxSlots` per round (loops 19 and 20, see the notes above). Raise or lower the limits where you declare the scheme: `scheme.WithLimits(maxRounds: 200_000, maxSlots: 16_000_000)` (C#, `Scheme<T>`), `scheme.withLimits({ maxRounds: 200_000, maxSlots: 16_000_000 })` (TypeScript), `scheme.withLimits(200_000, 16_000_000L)` (Java), `scheme.with_limits(200_000, 16_000_000)` (Rust, on `MapScheme` and the typed `Scheme`; it takes and returns the scheme) and `scheme.with_limits(max_rounds=200_000, max_slots=16_000_000)` (Python; it returns a new scheme, and `scheme.max_rounds` and `scheme.max_slots` read the limits) and `scheme.WithLimits(limits)` (Go; it returns a copy, takes all three values of a `Limits` every time and reads them with `scheme.Limits()`, so start from `DefaultLimits()`) and `scheme.withLimits(maxRounds: 200_000, maxSlots: 16_000_000)` (Swift; it returns a copy, a limit left out takes its default, and `scheme.maxRounds`, `maxSlots` and `maxBytes` read the limits). The defaults are constants (`BinaryPacker.DefaultMaxRounds` and `DefaultMaxSlots`, `Scheme.DefaultMaxRounds` and `DefaultMaxSlots`, `Scheme.DEFAULT_MAX_ROUNDS` and `DEFAULT_MAX_SLOTS` in Java and Python, `packbin::DEFAULT_MAX_ROUNDS` and `DEFAULT_MAX_SLOTS`, `packbin.DefaultMaxRounds`, `DefaultMaxSlots` and `DefaultMaxBytes` in Go, `Scheme.defaultMaxRounds`, `defaultMaxSlots` and `defaultMaxBytes` in Swift). A value below 1 is refused when you call it (an exception in C#, TypeScript and Java, a `ValueError` in Python, which also refuses a value that is not a whole number; a panic in Rust; an `InvalidScheme` error value in Go; a thrown `.schemeError` in Swift). A Go `Nested` row and a Swift nested row (`.group(name, ...)`) are scopes of their own and charge the width of their own members, and Go and Swift refuse a round past a limit with a too-many error (`TooMany`, `.tooMany`) rather than the bad-value error. C++ has no limit and needs none: it unpacks into `Array<T, N>` storage you own, of capacity at most 65,535, and returns `Error::TooMany` for a longer count. Time still grows with the length of the packet, so cap the packet length where you read it from the network as well. A dict key must sort after the key before it by its UTF-8 bytes on unpack in all eight packages (an equal or smaller key refuses the packet with the package's dict-key error), so the key check is one compare with the previous key and 65,535 keys unpack in well under a second (security report F51, F56).
- Memory at the defaults of loop 21 (`maxSlots` 4,194,304; since loop 22 the default is 1,048,576, which refuses the 36-name body below after 29,127 rounds (the 29,128th does not fit) instead of at round 65,536, and takes less), for a 1 MiB packet of one-byte rounds in a `repeat` with a 36-name `when` body (resident set, runtime included; measured on a macOS arm64 laptop with Node 22, .NET 10, Java 21 and Rust 1.79 in release mode, three runs each; your figures will differ). Refused at round 65,536: about 86 MiB in TypeScript, 86 MiB in C# and 92 MiB in Java, where an unlimited run took about 400, 530 and 560 MiB, and about 64 MiB in Python 3.14 (one run), where an unlimited run took about 410 MiB; the same body inside 65,535 `list` elements is refused after about 76 MiB in Python. A Rust one-byte round cannot hold 36 names, so Rust is measured on a `times` of one-byte rounds, about 21 MiB (about 310 MiB unlimited), and on rounds that each set eight flag bits, about 64 MiB (about 1.3 to 1.4 GiB unlimited). A packet that stays inside the limits costs up to the limits and no more: 65,535 rounds of the 36-name body, accepted, peaked at about 106 MiB in TypeScript and 86 MiB in Java, and a 64-name body stopped by the slot limit at about 110 MiB in Java and C#. The C# packet that took 1.4 seconds to read is now refused in about 0.1 seconds. The ceiling is higher when the rounds set their names: a 300-name body stopped by the slot limit peaked at about 190 MB in C#, 350 MB in Java and 130 MB in TypeScript (net of the runtime, measured by the security audit), and 64 set flag bits per round in Rust peaked at about 430 MB (all of these measured at the old default of 4,194,304 slots); raise the limits only as far as your memory per concurrent call allows. `maxBytes` is also the memory bound of a pack call: the packet is built in memory, so a call takes about 2 to 3 times the packet while it writes, and a scheme left at the default 16 MiB is bounded accordingly; raise it with the same care. In Python a slot is one entry of a per-name list, so `maxSlots` bounds that memory too. The Python figures above were measured before loop 21, when unpack charged 8 more slots per name for the first round of each run; with that charge gone, many short runs can take more memory than those figures (see the loop 21 measurement below). Measured in loop 21 (resident set, runtime included): a 4.3 MB packet of 65,535 `list` elements, each holding a `times` of one round of 64 names (4,194,240 slots, just under the default limit), peaked at about 1,070 MB in TypeScript and about 550 MB in Python; the worst case at the defaults is therefore the slot limit times the cost of one slot in your runtime, and a service that takes packets from untrusted callers should lower `maxSlots` (the default was 4,194,304 until loop 22, which lowered it to 1,048,576, a quarter). Measured in loop 22 on the same 4.3 MB packet shape, resident set at the old and the new default: TypeScript 1,070 MB to 353 MB, Java 960 MB to 317 MB (`-Xmx4g`), C# 733 MB to 235 MB, Python 550 MB to 162 MB; Rust, on a stand-in shape (a list element cannot hold a `times`: 65,535 rounds of a 64-name `times`), 628 MB to 120 MB, and 64 set flag bits per round took 637 MB at the old default and 117 MB at the new. The peak is a third of the old one rather than a quarter because the runtime and the packet itself do not shrink. A scheme that needs more raises the limit, and then the old worst case applies again. Measured for Go in loop 25 (the heap in use, sampled during the unpack in `golang:1.27`; one run each, about 10 %): the F10 packet (4.26 MB, 4,194,304 slots, limit raised) peaks at about 625 MB, and a 1 MiB packet of 16,128 rounds of 65 one-byte members (1,048,320 slots, the defaults) at about 94 MB. The measurement is a test behind the build tag `packbin_memtest`; its large-packet tests (a 16 MiB packet, a wide raised-limit unpack) pass under the race detector in a 7.6 GiB Docker VM.
- In C#, a typed `Unpack` of a packet that holds a `repeat` or `times` round returns an error value naming the member when the row cannot hold the list of rounds for it (a scalar member always cannot), instead of throwing `InvalidCastException` (loop 20). A member that can hold the list (`object`, `List<object?>`, `List<List<object?>>`, `object[]`, `IList`, `IList<object?>`) is filled, but no public C# call returns an aligned row yet. Since loop 21 a typed round can bind a collection of rows instead (`E[]`, `List<E>` or `IList<E>`; see Times).
- In C#, a typed `list` or `dict` member is checked when the scheme is built (see the loop 18 notes). Inside a `repeat` or `times` round a `list` member is checked against the list of rounds it must hold (loop 20 notes) and a `dict` member against the dictionary per round it must hold (loop 21 notes); a `bits`, `packed`, `when` or `times` element is not checked when the scheme is built. The accepted member types are fixed on purpose: a refusal can be relaxed later, an accepted type cannot be withdrawn. The owner kept this refusal in loop 19 (decision 10) and it may be relaxed in a later loop.
- Pack caps a `times` count and a `repeat` list at the scheme's `maxRounds`, charges `maxSlots` per round and refuses a packet above `maxBytes`, in C#, TypeScript, Python, Java and Rust (loops 19 and 20) and in Go and Swift. The slot width of a round is one rule in all six packages since loop 21 (first bullet), and pack and unpack charge it alike. C++ needs no cap: pack writes into your buffer and its rounds live in an `Array` of at most 65,535 items.
- Decided in loop 25 (the open rows of loop 24). C++ packs the clear bit for an unbound `bits`, `packed` or `sized` member (no member pointer) whose count sits behind a clear `when`, count above 0 included, where the other five refuse: an unbound member is C++'s spelling of "not carried", and this stays a documented exception (owner decision U24 B). The C++ builder refuses an id outside 0 to 32,767: a field's own id, a `when` anchor and the count id of `times`, `bits`, `packed` or `sized` give `SchemeInvalid` at the field (the error carries the id as a 16-bit number, so a wrapped id is the one it names); before, `bits(1, 65536)` built and bound field 0, and `bits(1, 32768)` built as a member with no count. A count id of -1 is the one value that still builds, and it fails every pack and unpack with `BadValue` (owner decision U25 A). A C# dictionary row reads the names of a nested-row group (`group(get, set, ...)`) from the nested dictionary under the group's name, on pack and on unpack, as a typed row reads its nested object and as TypeScript and Java read it on pack; a flat row that puts those names at the outer level is refused naming the inner member. Unpack returns the group as a nested dictionary, as Go does (owner decision U26 A): code that read the group's names from the outer level of a dictionary-row unpack must read them under the group's name. Python raises `ValueError` (`2: count 1 was not written`) for a value given to a member whose count no field wrote, with the text TypeScript uses in its `RangeError` (owner decision Low-1 A). Documented exceptions, not open: Java counts a nested-row group (a `group(get, set, ...)` row, an empty one too) as one slot where the others count the names inside it, and the Go package copies TypeScript's count (owner decision U16, loop 22), a `Nested` row charging the width of its own members. The Rust map form takes the values of a member under a `when` inside a `times` as rounds under `__times_<anchor>` only (owner decision U18, loop 23).
- Probed in loop 25 against TypeScript (owner decisions D1 and D7, both kept and documented). A split flag bit inside a false `when` with the member given packs `01 00 03 06` and repacks `01 00 02 06` in all seven packages; no package changed. An empty anchored group `flags(0, group(0, "mark")), u8(0, "n")` packs TypeScript's bytes in C#, Rust, Java and C++ wherever the scheme builds (`01 01 03` for a set mark and `n` 3), with these differences: Python refuses the scheme at construction (see the empty-group rule above); Rust gives the empty group an id slot of its own, so the `u8` after it takes the next id (1) where TypeScript takes 0, and Rust and C++ build a `when` that names the mark where TypeScript refuses it; Java reads `Boolean.FALSE` for such a mark as present (`01 01`, where TypeScript clears the bit and writes `01 00`) and returns a set mark as `{mark: {}}`, and a Java `group(0)` with no accessor is refused.
- C++ `eq(u8, true)` and `eq(u8, 1.5)` still build: a typed constant is converted to a 64-bit integer before the check. A C++ empty group that is a `when` source takes the id of the field after it, so a field with the same id wins for that `eq`.
- In TypeScript a decoded dictionary keeps a key named `__proto__` as an ordinary own entry. Copy or merge decoded dictionaries with care: `Object.assign({}, dict)` sets the target's prototype from that entry. Read them with `Object.hasOwn`.
- In C# every integer field arrives in `UnpackResult.Values` as its exact type (`byte`, `sbyte`, `ushort`, `short`, `uint`, `int`, `ulong`, `long`; an `f32` stays a `double`). Read through the row type and nothing changes for you; code that reads the narrow kinds straight from `Values` as `double` must change, as it had to for `u64` and `i64` before.
- A session packs from several threads safely in C# and Java (each packet gets its own number). Unpacking on one session must be called in packet order, one caller at a time. A Go `PackSession` is safe for concurrent use too (a lock around the counter and the pad); the receiver must still `Unpack` in the order the sender's `Pack` calls took the lock. A built Go `Scheme` is safe to share. A Swift `PackSession` is not `Sendable` and is used by one task at a time; a built Swift `Scheme` is `Sendable` and safe to share.

## License

MIT
