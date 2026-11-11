import 'package:packbin/packbin.dart';

/// The AC-1 position scheme: the row the position program packs and the clear message the ECC commands protect and
/// repair.
Scheme<Map<String, Object?>> positionScheme() => scheme(0x40, [
  u16(0, 'sid'),
  i32(1, 'lat'),
  i32(2, 'lon'),
  u8(3, 'profile'),
  flags(4, [u16(4, 'heading'), u8(5, 'speed'), i16(6, 'altitude')]),
]);
