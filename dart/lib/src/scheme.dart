import 'dart:typed_data';

import 'build.dart';
import 'ecc/setting.dart';
import 'errors.dart';
import 'fields.dart';
import 'pack.dart';
import 'unpack.dart';

/// A built field list with its type number. It is immutable, so one scheme
/// can pack and unpack from any number of isolates. [R] is the row it packs
/// and unpacks: `Map<String, Object?>` keyed by the field names ([scheme]),
/// or a typed row ([rowScheme]).
final class Scheme<R extends Object> {
  Scheme._(
    this.typeNumber,
    this._plan, [
    this.parity = 0,
    this.parityPercent = 0,
  ]);

  /// The first byte of every packet of this scheme.
  final int typeNumber;

  /// The parity bytes pack appends, 0 to 32; 0 when the scheme declares none
  /// or declares a percentage.
  final int parity;

  /// The parity percentage, 0 to 100: the count is that share of the clear
  /// length, rounded up, at most 32. 0 when the scheme declares none or a
  /// count.
  final int parityPercent;

  final Plan _plan;

  /// A copy of this scheme that appends [n] parity bytes (0 to 32) and
  /// repairs on unpack, and drops a percentage it had; 0 turns protection
  /// off. Both sides declare the same [n]. An [n] out of range throws a
  /// [PackbinException] of kind [ErrorKind.schemeError] naming `parity`.
  Scheme<R> withParity(int n) {
    checkParity(n);
    return Scheme._(typeNumber, _plan, n, 0);
  }

  /// A copy of this scheme that declares the percentage [p] (0 to 100) of the
  /// clear length as parity, and drops a count it had; 0 turns protection
  /// off. A [p] out of range throws a [PackbinException] of kind
  /// [ErrorKind.schemeError] naming `parity`.
  Scheme<R> withParityPercent(int p) {
    checkPercent(p);
    return Scheme._(typeNumber, _plan, 0, p);
  }

  /// A copy of this scheme with the given settings, as one declaration: a
  /// [parity] count (0 to 32) or a [parityPercent] (0 to 100), not both above
  /// 0. A mix, or a value out of range, throws a [PackbinException] of kind
  /// [ErrorKind.schemeError] naming `parity` when the scheme is built. With
  /// neither given the scheme keeps its settings; with either given, the
  /// declaration replaces both (the one not given is 0).
  Scheme<R> withParitySettings({int? parity, int? parityPercent}) {
    if (parity != null) checkParity(parity);
    if (parityPercent != null) checkPercent(parityPercent);
    if ((parity ?? 0) > 0 && (parityPercent ?? 0) > 0) {
      throw mixedDeclaration(parity!, parityPercent!);
    }
    if (parity == null && parityPercent == null) return this;
    return Scheme._(typeNumber, _plan, parity ?? 0, parityPercent ?? 0);
  }

  /// This scheme with the function [unpack] calls with the row of a packet
  /// whose first byte is [typeNumber].
  SchemeHandler on(void Function(R row) handler) =>
      SchemeHandler._(this, (Object row) => handler(row as R));
}

Plan planOf(Scheme<Object> scheme) => scheme._plan;

/// A scheme and what to do with its rows, made by [Scheme.on].
final class SchemeHandler {
  SchemeHandler._(this.scheme, this._call);

  /// The scheme that reads the packet.
  final Scheme<Object> scheme;

  final void Function(Object row) _call;
}

/// A scheme of map rows: [typeNumber] (0 to 255) and [fields], numbered by
/// order from 0. A row is a `Map<String, Object?>` keyed by the field names;
/// a missing key or a null is no value. A refused scheme throws a
/// [PackbinException] of kind [ErrorKind.schemeError].
Scheme<Map<String, Object?>> scheme(int typeNumber, List<Field> fields) =>
    Scheme._(
      typeNumber,
      buildPlan<Map<String, Object?>>(typeNumber, [
        for (final f in fields) nodeOf(f),
      ], null),
    );

/// A scheme of typed rows: every value field is bound to a member of [R]
/// with `bind`, pack reads the row through the getters, and unpack fills a
/// row made by [create] through the setters. A getter that returns null is
/// no value. A refused scheme throws a [PackbinException] of kind
/// [ErrorKind.schemeError].
Scheme<R> rowScheme<R extends Object>(
  int typeNumber,
  R Function() create,
  List<Field> fields,
) => Scheme._(
  typeNumber,
  buildPlan<R>(typeNumber, [for (final f in fields) nodeOf(f)], create),
);

/// What unpack returns: the [row], or the [error] that refused the packet.
/// Unpack never throws on input bytes.
final class Unpacked<R extends Object> {
  const Unpacked._(this.row, this.error, [this.repaired = 0]);

  /// The row read; null when the packet is refused.
  final R? row;

  /// Why the packet is refused; null when it was read.
  final PackbinError? error;

  /// The wrong bytes repaired before the packet was read; 0 when it was
  /// intact or the scheme declares no parity.
  final int repaired;

  /// Whether the packet was read.
  bool get ok => error == null;
}

/// Packs [row]: the scheme's type byte, then the fields in order. A row that
/// cannot be written throws a [PackbinException] of kind
/// [ErrorKind.packError] naming the field, and no bytes are returned. A
/// scheme with parity appends it; a clear message above `254 - n` bytes
/// throws [ErrorKind.tooLong].
Uint8List pack<R extends Object>(Scheme<R> scheme, R row) => protectWith(
  packRow(scheme._plan, scheme.typeNumber, row),
  scheme.parity,
  scheme.parityPercent,
);

/// Unpacks [bytes] with the one [scheme], detect only: a protected message
/// with a wrong byte is an [ErrorKind.uncorrectable] error. A first byte that
/// is not the scheme's type number is an [ErrorKind.unknownType] error.
Unpacked<R> unpackRow<R extends Object>(Uint8List bytes, Scheme<R> scheme) =>
    unpackRowRepair(bytes, scheme, 0);

/// As [unpackRow], repairing up to [limit] wrong bytes first: 0 to `n / 2` of
/// the scheme's parity count, 0 to 16 under a percentage. A [limit] out of
/// range throws a [PackbinException] of kind [ErrorKind.schemeError] naming
/// `limit`, before any byte is read. [Unpacked.repaired] is the count
/// repaired; [bytes] is never written.
Unpacked<R> unpackRowRepair<R extends Object>(
  Uint8List bytes,
  Scheme<R> scheme,
  int limit,
) {
  checkLimit(limit, scheme.parity, scheme.parityPercent);
  final fixed = repairWith(bytes, scheme.parity, scheme.parityPercent, limit);
  final failure = fixed.error;
  if (failure != null) return Unpacked._(null, failure);
  final clear = fixed.clear!;
  if (clear.isEmpty) return Unpacked._(null, shortPacket(null, '', 1, 0));
  if (clear[0] != scheme.typeNumber) {
    return Unpacked._(
      null,
      PackbinError(ErrorKind.unknownType, actual: clear[0]),
    );
  }
  final (row, error) = readRow(scheme._plan, clear);
  return Unpacked._(row as R?, error, error == null ? fixed.count : 0);
}

/// Unpacks [bytes] with the handler whose scheme has the type number in the
/// first byte, calls it with the row and returns the row too; detect only for
/// a protected scheme. A buffer that cannot be read gives an error value and
/// calls no handler; nothing is thrown on input bytes. An empty handler list,
/// two handlers with one type number, or handlers with different parity
/// settings throw a [PackbinException] of kind [ErrorKind.schemeError] before
/// any byte is read.
Unpacked<Object> unpack(Uint8List bytes, List<SchemeHandler> handlers) =>
    unpackRepair(bytes, handlers, 0);

/// As [unpack], repairing up to [limit] wrong bytes before the type byte
/// picks the handler (the type byte can be one of the wrong bytes). All
/// handlers declare the same parity count, or the same percentage; [limit] is
/// 0 to `n / 2`, or 0 to 16 under a percentage. A mix or a [limit] out of
/// range throws a [PackbinException] of kind [ErrorKind.schemeError], naming
/// `parity` or `limit`. [Unpacked.repaired] is the count repaired.
Unpacked<Object> unpackRepair(
  Uint8List bytes,
  List<SchemeHandler> handlers,
  int limit,
) {
  _checkHandlers(handlers);
  final first = handlers[0].scheme;
  final n = first.parity, p = first.parityPercent;
  for (var i = 1; i < handlers.length; i++) {
    final other = handlers[i].scheme;
    if (other.parity != n || other.parityPercent != p) {
      throw mixedSettings(n, p, other.parity, other.parityPercent);
    }
  }
  checkLimit(limit, n, p);
  final fixed = repairWith(bytes, n, p, limit);
  final failure = fixed.error;
  if (failure != null) return Unpacked._(null, failure);
  final clear = fixed.clear!;
  if (clear.isEmpty) return Unpacked._(null, shortPacket(null, '', 1, 0));
  final type = clear[0];
  for (var i = 0; i < handlers.length; i++) {
    final handler = handlers[i];
    if (handler.scheme.typeNumber != type) continue;
    final (row, error) = readRow(handler.scheme._plan, clear);
    if (row != null) handler._call(row);
    return Unpacked._(row, error, error == null ? fixed.count : 0);
  }
  return Unpacked._(null, PackbinError(ErrorKind.unknownType, actual: type));
}

void _checkHandlers(List<SchemeHandler> handlers) {
  if (handlers.isEmpty) {
    throw schemeFail(null, '', 'unpack needs at least one handler');
  }
  if (handlers.length == 1) return;
  var a = 0, b = 0, c = 0, d = 0;
  for (var i = 0; i < handlers.length; i++) {
    final n = handlers[i].scheme.typeNumber;
    final bit = 1 << (n & 63);
    final int old;
    switch (n >> 6) {
      case 0:
        old = a;
        a |= bit;
      case 1:
        old = b;
        b |= bit;
      case 2:
        old = c;
        c |= bit;
      default:
        old = d;
        d |= bit;
    }
    if (old & bit != 0) throw schemeFail(null, '', 'duplicate type number $n');
  }
}
