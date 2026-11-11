import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:packbin/packbin.dart';

import 'hex.dart';

// The frame commands of the handoff driver (AZ-3338; fixtures/frame/README.md): `frame-batch <file>` answers one line
// for each line of the file (seal, open, mac, verify, and open-skip / verify-skip, which answer `skip`).

/// The error of a malformed line: a message that names it.
final class _LineError implements Exception {
  const _LineError(this.message);

  final String message;
}

/// The top of each number field: a number is decimal digits only (no sign, space or `_`) and at most its top.
const _byteTop = 255;
const _lengthTop = 65535;
const _epochTop = 4294967295;

/// The words of one line. A token that is not hex, a number with other characters and a missing field are an error of
/// the line, never a zero or a cut.
final class _Fields {
  _Fields(this.w);

  final List<String> w;

  String word(int i) {
    if (i >= w.length) throw _LineError('missing field $i');
    return w[i];
  }

  Uint8List bytes(int i) => _piece(word(i));

  /// A message: its pieces joined by `|`, each hex or `-`. An empty piece (`ab||cd`, `|ab`, `ab|`) is an error.
  List<Uint8List> parts(int i) {
    final token = word(i);
    return [
      for (final piece in token.split('|'))
        if (piece.isEmpty)
          throw _LineError('empty piece: $token')
        else
          _piece(piece),
    ];
  }

  Uint8List _piece(String token) {
    if (token == '-') return Uint8List(0);
    final b = hexBytes(token);
    if (b == null) throw _LineError('bad hex: $token');
    return b;
  }

  int num(int i, int top) {
    final token = word(i);
    var n = 0;
    var bad = token.isEmpty;
    for (var j = 0; j < token.length && !bad; j++) {
      final c = token.codeUnitAt(j);
      bad = c < 0x30 || c > 0x39;
      if (!bad) n = n * 10 + (c - 0x30);
      bad = bad || n > top;
    }
    if (bad) throw _LineError('bad number: $token (digits of 0 to $top)');
    return n;
  }
}

String _frameHex(Uint8List data) => data.isEmpty ? '-' : hexString(data);

String _refusal(FrameRefusal r) => switch (r.kind) {
  FrameRefusalKind.badValue => 'BadValue',
  FrameRefusalKind.tooLong => 'TooLong',
  FrameRefusalKind.bufferFull => 'BufferFull',
  FrameRefusalKind.shortPacket => 'ShortPacket',
  FrameRefusalKind.tagMismatch => 'TagMismatch',
  _ => 'error',
};

/// The optional trailing fields of a seal or open line: the directions loaded (digits 1 to 3) and the output size.
(FrameDirections, int) _loaded(_Fields f) {
  var digits = '123';
  var size = 300;
  if (f.w.length > 9) digits = f.w[9];
  if (f.w.length > 10) size = f.num(10, _lengthTop);
  if (digits.isEmpty || RegExp(r'[^123]').hasMatch(digits)) {
    throw _LineError('bad dirs: $digits');
  }
  var mask = 0;
  for (final unit in digits.codeUnits) {
    mask |= 1 << (unit - 0x31);
  }
  return (FrameDirections(mask), size);
}

String _seal(List<String> w) {
  final f = _Fields(w);
  final key = f.bytes(0);
  final epoch = f.num(1, _epochTop);
  final d = f.num(2, _byteTop);
  final tagLength = f.num(3, _byteTop);
  final msgId = f.bytes(4);
  final kind = f.num(5, _byteTop);
  final ad = f.bytes(6);
  final clear = f.bytes(7);
  final plain = f.bytes(8);
  final (directions, size) = _loaded(f);
  final session = FrameSession.load(
    key,
    epoch,
    FrameConfig(tagLength, directions),
  );
  if (session == null) return 'BadValue';
  final out = Uint8List(size);
  final result = session.seal(
    FrameDirection(d),
    MsgContext(msgId, kind),
    ad,
    clear,
    plain,
    out,
  );
  session.close();
  return switch (result) {
    FrameSealed(:final length) => _frameHex(
      Uint8List.sublistView(out, 0, length),
    ),
    FrameRefusal() => _refusal(result),
  };
}

String _open(List<String> w) {
  final f = _Fields(w);
  final key = f.bytes(0);
  final epoch = f.num(1, _epochTop);
  final d = f.num(2, _byteTop);
  final tagLength = f.num(3, _byteTop);
  final msgId = f.bytes(4);
  final kind = f.num(5, _byteTop);
  final ad = f.bytes(6);
  final clearLength = f.num(7, _lengthTop);
  final body = f.bytes(8);
  final (directions, size) = _loaded(f);
  final session = FrameSession.load(
    key,
    epoch,
    FrameConfig(tagLength, directions),
  );
  if (session == null) return 'BadValue';
  final out = Uint8List(size);
  final result = session.open(
    FrameDirection(d),
    MsgContext(msgId, kind),
    ad,
    body,
    clearLength,
    out,
  );
  session.close();
  return switch (result) {
    FrameOpened(:final plainLength) => _frameHex(
      Uint8List.sublistView(out, 0, plainLength),
    ),
    FrameRefusal() => _refusal(result),
  };
}

String _mac(List<String> w) {
  final f = _Fields(w);
  final key = f.bytes(0);
  final epoch = f.num(1, _epochTop);
  final label = f.bytes(2);
  final n = f.num(3, _byteTop);
  final parts = f.parts(4);
  final mk = MacKey.derive(key, epoch, label);
  if (mk == null) return 'BadValue';
  final result = mk.tag(parts, n);
  mk.close();
  return switch (result) {
    MacTag(:final tag) => _frameHex(tag),
    FrameRefusal() => _refusal(result),
  };
}

String _verify(List<String> w) {
  final f = _Fields(w);
  final key = f.bytes(0);
  final epoch = f.num(1, _epochTop);
  final label = f.bytes(2);
  f.num(
    3,
    _byteTop,
  ); // n is not used for verify: the tag length comes from the tag
  final parts = f.parts(4);
  final tag = f.bytes(5);
  final mk = MacKey.derive(key, epoch, label);
  if (mk == null) return 'BadValue';
  final valid = mk.verify(parts, tag);
  mk.close();
  return valid ? 'valid' : 'invalid';
}

String _line(List<String> words) {
  final rest = words.sublist(1);
  return switch (words[0]) {
    'seal' => _seal(rest),
    'open' => _open(rest),
    'mac' => _mac(rest),
    'verify' => _verify(rest),
    'open-skip' || 'verify-skip' => 'skip',
    _ => throw _LineError('unknown word ${words[0]}'),
  };
}

/// Runs one frame command and returns the exit status.
int runFrame(List<String> args) {
  if (args[0] != 'frame-batch' || args.length != 2) return 2;
  final String text;
  try {
    text = utf8.decode(File(args[1]).readAsBytesSync(), allowMalformed: true);
  } on FileSystemException catch (e) {
    stderr.writeln('frame-batch: ${e.message}: ${e.path}');
    return 1;
  }
  final lines = wordLines(text);
  for (var i = 0; i < lines.length; i++) {
    if (lines[i].isEmpty) continue;
    try {
      stdout.writeln(_line(lines[i]));
    } on _LineError catch (e) {
      stderr.writeln('frame line ${i + 1}: ${e.message}');
      return 1;
    }
  }
  return 0;
}
