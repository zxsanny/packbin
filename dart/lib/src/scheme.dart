import 'dart:typed_data';

import 'build.dart';
import 'errors.dart';
import 'fields.dart';
import 'pack.dart';
import 'unpack.dart';

/// A built field list with its type number. It is immutable, so one scheme
/// can pack and unpack from any number of isolates. [R] is the row it packs
/// and unpacks: `Map<String, Object?>` keyed by the field names ([scheme]),
/// or a typed row ([rowScheme]).
final class Scheme<R extends Object> {
  Scheme._(this.typeNumber, this._plan);

  /// The first byte of every packet of this scheme.
  final int typeNumber;

  final Plan _plan;

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
  const Unpacked._(this.row, this.error);

  /// The row read; null when the packet is refused.
  final R? row;

  /// Why the packet is refused; null when it was read.
  final PackbinError? error;

  /// Whether the packet was read.
  bool get ok => error == null;
}

/// Packs [row]: the scheme's type byte, then the fields in order. A row that
/// cannot be written throws a [PackbinException] of kind
/// [ErrorKind.packError] naming the field, and no bytes are returned.
Uint8List pack<R extends Object>(Scheme<R> scheme, R row) =>
    packRow(scheme._plan, scheme.typeNumber, row);

/// Unpacks [bytes] with the one [scheme]. A first byte that is not the
/// scheme's type number is an [ErrorKind.unknownType] error.
Unpacked<R> unpackRow<R extends Object>(Uint8List bytes, Scheme<R> scheme) {
  if (bytes.isEmpty) return Unpacked._(null, shortPacket(null, '', 1, 0));
  if (bytes[0] != scheme.typeNumber) {
    return Unpacked._(
      null,
      PackbinError(ErrorKind.unknownType, actual: bytes[0]),
    );
  }
  final (row, error) = readRow(scheme._plan, bytes);
  return Unpacked._(row as R?, error);
}

/// Unpacks [bytes] with the handler whose scheme has the type number in the
/// first byte, calls it with the row and returns the row too. A buffer that
/// cannot be read gives an error value and calls no handler; nothing is
/// thrown on input bytes. An empty handler list, or two handlers with one
/// type number, throws a [PackbinException] of kind [ErrorKind.schemeError]
/// before any byte is read.
Unpacked<Object> unpack(Uint8List bytes, List<SchemeHandler> handlers) {
  _checkHandlers(handlers);
  if (bytes.isEmpty) return Unpacked._(null, shortPacket(null, '', 1, 0));
  final type = bytes[0];
  for (var i = 0; i < handlers.length; i++) {
    final handler = handlers[i];
    if (handler.scheme.typeNumber != type) continue;
    final (row, error) = readRow(handler.scheme._plan, bytes);
    if (row != null) handler._call(row);
    return Unpacked._(row, error);
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
