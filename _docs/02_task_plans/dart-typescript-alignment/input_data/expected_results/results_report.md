# Loop 100 expected results — Dart aligned with TypeScript

Read by running TypeScript (`node`, v22.23.0) and Dart (3.13.5, `dart run`) on HEAD 0a678be of 2026-11-11; the probe scripts are in the session scratchpad (`probes-text/`, `probes-rounds/`). "TS" is the reference. Packets are hex. Dict scheme: `dict(d, u8(v))`; text scheme: `utf8(s)`; type byte `01`.

## D1 — lone surrogates at pack (AL-1, AL-2, AL-3)

| input | TS packet (Dart after = same) | Dart today |
|-------|-------------------------------|------------|
| text `\uD800` or `\uDC00` (bare) | `010410efbfbd` | `packError`, field 0 `s`, `s: the text holds an unpaired surrogate at unit 0` |
| text `\uDC00\uD800` | `010710efbfbdefbfbd` | same, unit 0 |
| text `a\uD800b` | `01061061efbfbd62` | same, unit 1 |
| raw-form context `中文` + `\uD800` or `\uDC00` | `010a10e4b8ade69687efbfbd` | refused, unit 2 |
| `中文` + `\uDC00\uD800` | `010d10e4b8ade69687efbfbdefbfbd` | refused, unit 2 |
| `中文` + `a\uD800b` | `010c10e4b8ade6968761efbfbd62` | refused, unit 3 |
| compact-form context `hello world ` + `\uD800` or `\uDC00` | `010deaa2d673dbe2d43ff977dfde80` | refused, unit 12 |
| `hello world ` + `\uDC00\uD800` | `01116aa2d673dbe2d43fbffefbfbdfff7dfde8` | refused, unit 12 |
| `hello world ` + `a\uD800b` | `010e8aa2d673dbe2d429ff977dfdefa0` | refused, unit 13 |
| dict key `\uD800` or `\uDC00` | `0101000410efbfbd01` | refused, field null, name `d` |
| dict key `\uDC00\uD800` | `0101000710efbfbdefbfbd01` | refused |
| dict key `a\uD800b` | `010100061061efbfbd6201` | refused |
| dict keys `￿`, `\uD800` | `0102000410efbfbd020410efbfbf01` (the swapped key sorts first) | refused |
| dict keys `\u{10000}`, `\uDC00` | `efbfbd` key before `f0908080` key | refused |
| dict keys `\uD800`, `\uDC00` (collide) | TS writes `0102000410efbfbd010410efbfbd02`, TS unpack then refuses it (`needed` 0, `left` 0) | refused |
| dict keys `�`, `\uD800` (collide) | same packet as the row above | refused |

After: the collision rows throw `PackbinException` kind `packError`, `field` null, `name` `d`, and write no packet (owner decision, AL-3). Every TS packet above unpacks in Dart today to the same U+FFFD text; after the change Dart writes those packets.

## D8 — unpack refusals (AL-5, AL-9)

| packet | TS result | Dart today |
|--------|-----------|------------|
| dict `a,a` `0102000210610002106101` | field `d`, needed 0, left 0 | `bad_value`, left 1, "the key "a" is given twice" |
| dict `b,a` `0102000210620002106101` | field `d`, needed 0, left 0 | `bad_value`, left 1, "not in ascending order" |
| dict `a,b,a` `010300021061000210620102106102` | field `d`, needed 0, left 0 | `bad_value`, "not ascending" |
| dict `a,a` + 2 bytes `01020002106100021061019998` | needed 0, left 0 | `bad_value`, left 3 |
| dict `a,b` `0102000210610002106201` | ok | ok |
| text `C0 80` `010310c080` | field `s`, needed 0, left 4 | `bad_value`, left 4, `s: the text is refused (utf8)` |
| text `E0 80 AF` `010410e080af` | needed 0, left 5 | `bad_value`, left 5 |
| text `ED A0 80` `010410eda080` | needed 0, left 5 | `bad_value`, left 5 |
| text `F4 90 80 80` `010510f4908080` | needed 0, left 6 | `bad_value`, left 6 |
| text `E2 82` cut by count `010310e282` | needed 0, left 4 | `bad_value`, left 4 |
| the same five as a dict key (`0101000310c08000`, …) | field `d`, left +1 | `bad_value`, field null, name `d`, same left |
| real short read `010410e2` | needed 4, left 2 | `short`, same (unchanged) |
| `80`, `050102`, empty buffer | needed 2/5/1, left 1/2/0 | `short`, identical (unchanged) |

Fixture `fixtures/text/vectors.txt`: 32 `bad` rows = 29 refusals (needed 0, left = bytes from the field start to the end) + 3 `short` rows (unchanged); the same rows as a dict key have `field` `d` and `left` +1.

## D6 — zero rounds in a map row (AL-6)

| case | wire | TS unpack keys | Dart today | Dart after |
|------|------|----------------|------------|------------|
| a `repeat`, 0 rounds | `01` | `{}` | `{a:[], b:[]}` | `{}` |
| b `times`, n = 0 | `010007` | `{n, tail}` | `{n, a:[], b:[], tail}` | `{n, tail}` |
| c1 `times` in an anchored group | `010007` | `{n, tail}` | `{n, g:{a:[]}, tail}` | `{n, g:{}, tail}` |
| c2 `repeat` in an anchored group | `0100` | `{n}` | `{n, g:{a:[]}}` | `{n, g:{}}` |
| c3 `times` in an unanchored group or `nested` | `01010007` | `{z, n, tail}` | `{z, g:{n:0, a:[]}, tail}` | `{z, g:{n:0}, tail}` |
| c4 `repeat` in an unanchored group or `nested` | `0101` | `{z}` | `{z, g:{a:[]}}` | `{z, g:{}}` |
| c5, c6 under a `when` that holds | | no round key | `a: []` | no round key |
| c7 to c10 under `flags` or a split bit (count 0, bit clear) | | no key | no key | no key (unchanged) |
| c11 list element `[{n:0}, {n:1, a:[5]}]` | | item 0 `{n:0}` | item 0 `{n:0, a:[]}` | item 0 `{n:0}` |
| c12 a `when` inside a group | `010100` | `{k, n}` | `{k, g:{n:0, a:[]}}` | `{k, g:{n:0}}` |
| c13 group under flags, bit set | `01000309` | `{n, h}`, repacks `01000209` | `{n, g:{a:[]}, h}`, repacks `01000309` | `{n, g:{}, h}`, repacks `01000309` |

The `g: {}` shape (groups and nested maps keep their key, Go-4) is the owner's choice of 2026-11-11; TypeScript's flat groups show no key. Observed on a scratch copy with a one-line patch at `rounds_unpack.dart` line 61 (the "after" column is what that copy printed): packing each unpacked map again gives the packet it came from in all 15 sections; the two non-canonical packets `01000309` (c7) and `01010309` (c8, a set bit over 0 rounds) repack with the bit cleared (`01000209`, `01010109`), as TypeScript does. In c13 TypeScript repacks `01000209` (it has no `g` key) and Dart `01000309`. Typed rows keep `[]`.

## D7 — too long for its parity, at pack (AL-4)

| setting | limit of the clear message | one byte over: TS `RangeError` message | Dart today |
|---------|---------------------------|----------------------------------------|------------|
| count n = 1, 4, 32 | 253, 250, 222 | `the packet would be 251 bytes, above the limit of 250 bytes for 4 parity bytes` (n = 4) | kind `tooLong`, same text, field null, name empty, `left` the clear length |
| percent p = 1, 10, 50, 100 | 251, 230, 222, 222 | `the packet would be 231 bytes, above the limit of 230 bytes for 10 percent parity` (p = 10) | same |

At the limit every setting packs. After: kind `packError`, `field` null, `name` empty, the same `reason`; `toString()` reads `packbin: pack refused: <reason>` (to be confirmed against the code). With `maxBytes` and parity both set, the `maxBytes` refusal wins in both packages (`s: the packet would be 66 bytes, above the limit of 64 bytes`, field 0). Go's percentage text says `the message is %d bytes` (own wording; not changed).

## D10 — empty nested row (AL-7, AL-8)

| place | TS | Dart today | Dart after |
|-------|----|------------|------------|
| row member, under `when`, in a non-empty group, list element, dict element | refused at build: `empty group g: allowed only directly inside flags or a flag bit; move it into flags` | refused: `nested row g: needs at least one member` | refused with TS's words |
| directly under `flags` or a flag bit, `{h: 9}` | `010209`, unpack `{h: 9}` | refused at build | `010209`, unpack `{h: 9}` |
| `{h: 9, g: true}` | `010309`, unpack `{g: true, h: 9}` | refused at build | `010309`, unpack `{g: true, h: 9}` |
| `{h: 9, g: false}` | `010209` | refused at build | `010209` |
| `{h: 9, g: {}}` and `{h: 9, g: {x: 1}}` | `010209` (bit clear, no error) | refused at build | refused naming `g` (a mark must be a `bool`; the `groupOf` rule) |
| unpack `0103` | short, field `h`, needed 1, left 0 | n/a | same |
| unpack `0101` | `{g: true}` | n/a | `{g: true}` |
| unpack `0100` | `{}` | n/a | `{}` |

An empty `nestedRow` stays refused at build. The member-less `groupOf` is unchanged.
