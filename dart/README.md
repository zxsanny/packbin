# packbin

Compact binary packing for Dart. Both sides keep the same field list (a
scheme); the bytes are only the values, the same bytes as the C#, TypeScript,
Python, Rust, C++, Java, Go and Swift packages. Optional error correction and
authenticated frames (frame mode) are in the package.

Dart 3.13 or newer, on native targets (the Dart VM and ahead-of-time builds).
The web is not supported. The package has no dependency.

```
dart pub add packbin
```

```dart
import 'dart:typed_data';

import 'package:packbin/packbin.dart';

String hex(Uint8List bytes) =>
    bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

final position = scheme(0x40, [
  u16(0, 'sid'),
  i32(1, 'lat'),
  i32(2, 'lon'),
  u8(3, 'profile'),
  flags(4, [u16(4, 'heading'), u8(5, 'speed'), i16(6, 'altitude')]),
]);

final row = {'sid': 1, 'lat': 500000000, 'lon': 300000000, 'profile': 1};
final raw = pack(position, row);
print(hex(raw));

final got = unpackRow(raw, position);
print('${got.ok} ${got.row!['lat']}');
```

```
4001000065cd1d00a3e1110100
true 500000000
```

`unpackRow` returns an `Unpacked` with the row or an error value and never
throws on input bytes; `pack` throws a `PackbinException` that names the
field. A runnable typed-row version is in
[`example/packbin_example.dart`](example/packbin_example.dart).

The repository README describes every field type, the rows and errors of the
Dart package, the limits, error correction and frame mode:
<https://github.com/zxsanny/packbin#dart>.
