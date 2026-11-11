import 'dart:typed_data';

import 'package:packbin/packbin.dart';
import 'package:test/test.dart';

import '../support/hex.dart';

typedef Row = Map<String, Object?>;

/// What pack does with a row: it gives a packet ([wire]), or it is refused
/// with the text TypeScript pins ([text]: `name: reason`), or with a text
/// that starts with [prefix], or naming only [member].
final class Pin {
  const Pin.wire(String this.wire) : text = null, prefix = null, member = null;
  const Pin.refused(String this.text)
    : wire = null,
      prefix = null,
      member = null;
  const Pin.prefix(String this.prefix)
    : wire = null,
      text = null,
      member = null;
  const Pin.names(String this.member) : wire = null, text = null, prefix = null;

  final String? wire;
  final String? text;
  final String? prefix;
  final String? member;

  /// The packet is refused (any text).
  bool get refuses => wire == null;
}

/// One pinned TypeScript row: a table-local [id], the scheme, the row, what
/// pack gives, and the row unpack gives back from the packet ([back], when
/// the table pins it; the row itself when [roundTrip]).
final class ParityRow {
  ParityRow(
    this.id,
    this.build,
    this.row,
    this.pin, {
    this.back,
    this.roundTrip = false,
  });

  final String id;
  final Scheme<Row> Function() build;
  final Row row;
  final Pin pin;
  final Row? back;
  final bool roundTrip;
}

/// A packet that is only unpacked (a packet an earlier build wrote, or a row
/// of the wire that pack never writes).
final class UnpackRow {
  UnpackRow(this.id, this.build, this.wire, this.row);

  final String id;
  final Scheme<Row> Function() build;
  final String wire;
  final Row row;
}

/// The name of the member the last refusal of [outcome] named.
String lastRefusedName = '';

/// Packs [row]; the hex of the packet, or `refused: <reason>` (the reason of
/// the Dart error; its `name` is the member, kept in [lastRefusedName]).
String outcome(Scheme<Row> layout, Row row) {
  try {
    return hex(pack(layout, row));
  } on PackbinException catch (e) {
    expect(e.kind, ErrorKind.packError, reason: 'the refusal is a pack error');
    lastRefusedName = e.name;
    return 'refused: ${e.reason}';
  }
}

/// Whether [got] (an [outcome]) is the refusal TypeScript words as [text]:
/// `member: reason`. The Dart reason carries the member's name or leaves it
/// to the error's `name`; a text led by `times` or `repeat` (TypeScript's word
/// for a round, which has no name) is the reason itself.
bool sameRefusal(String got, String text) {
  if (got == 'refused: $text') return true;
  final lead = '$lastRefusedName: ';
  return lastRefusedName.isNotEmpty &&
      text.startsWith(lead) &&
      got == 'refused: ${text.substring(lead.length)}';
}

/// As [sameRefusal], for a text that only has to start as [prefix] does.
bool startsRefusal(String got, String prefix) {
  if (got.startsWith('refused: $prefix')) return true;
  final lead = '$lastRefusedName: ';
  return lastRefusedName.isNotEmpty &&
      prefix.startsWith(lead) &&
      got.startsWith('refused: ${prefix.substring(lead.length)}');
}

/// The row packet [wire] unpacks to; fails when it is refused.
Row unpackedRow(Scheme<Row> layout, String wire) {
  final result = unpackRow(unhex(wire), layout);
  expect(result.error, isNull, reason: 'unpack of $wire');
  return result.row!;
}

void _check(ParityRow r) {
  final layout = r.build();
  final got = outcome(layout, r.row);
  final pin = r.pin;
  if (pin.wire != null) {
    expect(got, pin.wire, reason: r.id);
    final back = r.back ?? (r.roundTrip ? r.row : null);
    if (back != null) {
      expect(unpackedRow(layout, pin.wire!), equals(back), reason: r.id);
    }
    expect(
      outcome(layout, unpackedRow(layout, pin.wire!)),
      pin.wire,
      reason: '${r.id}: the unpacked row packs again',
    );
  } else if (pin.text != null) {
    expect(sameRefusal(got, pin.text!), isTrue, reason: '${r.id}: $got');
  } else if (pin.prefix != null) {
    expect(startsRefusal(got, pin.prefix!), isTrue, reason: '${r.id}: $got');
  } else {
    expect(got, startsWith('refused: '), reason: r.id);
    expect(lastRefusedName, pin.member, reason: '${r.id}: $got');
  }
}

/// Runs each row of [rows] as a test named `<id>`; ids are unique.
void runParity(List<ParityRow> rows, [List<UnpackRow> unpackOnly = const []]) {
  final ids = <String>{};
  for (final r in [...rows.map((r) => r.id), ...unpackOnly.map((r) => r.id)]) {
    if (!ids.add(r)) fail('duplicate parity row id $r');
  }
  for (final r in rows) {
    test(r.id, () => _check(r));
  }
  for (final u in unpackOnly) {
    test(u.id, () {
      final layout = u.build();
      expect(unpackedRow(layout, u.wire), equals(u.row), reason: u.id);
    });
  }
}

/// The bytes of [items] as a `Uint8List`.
Uint8List bytesOf(List<int> items) => Uint8List.fromList(items);
