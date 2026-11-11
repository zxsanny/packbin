import 'package:packbin/packbin.dart';
import 'package:test/test.dart';

import 'hex.dart';

/// The scheme error [body] throws; fails when the scheme is built.
PackbinError refusal(Object Function() body) {
  try {
    body();
  } on PackbinException catch (e) {
    expect(e.kind, ErrorKind.schemeError);
    return e.error;
  }
  fail('the scheme was built');
}

/// The pack error [body] throws; fails when the row is packed.
PackbinError packRefusal(Object Function() body) {
  try {
    body();
  } on PackbinException catch (e) {
    expect(e.kind, ErrorKind.packError);
    return e.error;
  }
  fail('the row was packed');
}

/// The row the packet [wire] (hex) unpacks to with [layout]; fails when it is
/// refused.
R readRow<R extends Object>(Scheme<R> layout, String wire) {
  final result = unpackRow(unhex(wire), layout);
  expect(result.error, isNull, reason: 'unpack of $wire');
  return result.row!;
}
