import 'dart:io';
import 'dart:typed_data';

import 'package:packbin/src/frame/frame_results.dart';
import 'package:packbin/src/frame/frame_session.dart';
import 'package:packbin/src/frame/frame_types.dart';
import 'package:packbin/src/frame/mac_key.dart';
import 'package:packbin/src/frame/replay_window.dart';

// Replays the rows of fixtures/frame/vectors.txt through the frame API
// (contract pack-session 3.0.0). A row's input fields build the call; every
// output field of the row is compared with what the call gave.

const int sentinel = 0xa5;
const List<String> ops = ['keys', 'seal', 'open', 'mac', 'replay'];

typedef Row = Map<String, String>;

/// The shared file, found by walking up from the current directory, so the
/// tests run from `dart/` and from the repository root alike.
File vectorsFile() {
  var dir = Directory.current.absolute;
  while (true) {
    final file = File('${dir.path}/fixtures/frame/vectors.txt');
    if (file.existsSync()) return file;
    final parent = dir.parent;
    if (parent.path == dir.path) {
      throw StateError(
        'fixtures/frame/vectors.txt not found above ${Directory.current.path}',
      );
    }
    dir = parent;
  }
}

/// The lines that are neither empty nor a comment.
List<String> dataLines(String text) => [
  for (final line in text.split('\n'))
    if (line.trim().isNotEmpty && !line.startsWith('#')) line.trimRight(),
];

List<Row> load(String text) {
  final rows = <Row>[];
  for (final line in dataLines(text)) {
    final row = <String, String>{};
    for (final token in line.split(' ')) {
      final at = token.indexOf('=');
      if (at <= 0) throw FormatException('no name=value in "$token": $line');
      row[token.substring(0, at)] = token.substring(at + 1);
    }
    rows.add(row);
  }
  return rows;
}

List<Row> loadFixture() => load(vectorsFile().readAsStringSync());

String get(Row row, String name) {
  final value = row[name];
  if (value == null) throw FormatException('${row['case']}: no $name=');
  return value;
}

String caseOf(Row row) => get(row, 'case');
String opOf(Row row) => get(row, 'op');

String hex(Uint8List bytes) {
  if (bytes.isEmpty) return '-';
  final out = StringBuffer();
  for (final b in bytes) {
    out.write(b.toRadixString(16).padLeft(2, '0'));
  }
  return out.toString();
}

Uint8List unhex(String text) {
  if (text == '-') return Uint8List(0);
  if (text.length.isOdd) throw FormatException('odd hex length: $text');
  final out = Uint8List(text.length ~/ 2);
  for (var i = 0; i < out.length; i++) {
    out[i] = int.parse(text.substring(2 * i, 2 * i + 2), radix: 16);
  }
  return out;
}

Uint8List bytes(Row row, String name) => unhex(get(row, name));
int number(Row row, String name) => int.parse(get(row, name));

Uint8List filled(int length) =>
    Uint8List(length)..fillRange(0, length, sentinel);

bool untouched(Uint8List buffer) => buffer.every((b) => b == sentinel);

const Map<FrameRefusalKind, String> _kindNames = {
  FrameRefusalKind.badValue: 'BadValue',
  FrameRefusalKind.tooLong: 'TooLong',
  FrameRefusalKind.bufferFull: 'BufferFull',
  FrameRefusalKind.shortPacket: 'ShortPacket',
  FrameRefusalKind.tagMismatch: 'TagMismatch',
  FrameRefusalKind.duplicate: 'Duplicate',
  FrameRefusalKind.tooOld: 'TooOld',
};

const Map<Freshness, String> _freshnessNames = {
  Freshness.fresh: 'Fresh',
  Freshness.duplicate: 'Duplicate',
  Freshness.tooOld: 'TooOld',
};

/// The contract's name of a refusal kind, as the fixture writes it.
String kindName(FrameRefusal refusal) => _kindNames[refusal.kind]!;

String windowText(ReplayWindow window) =>
    '${window.top.toRadixString(16)}:${window.bits.toRadixString(16)}';

ReplayWindow windowOf(String text) {
  final parts = text.split(':');
  return ReplayWindow(
    BigInt.parse(parts[0], radix: 16),
    BigInt.parse(parts[1], radix: 16),
  );
}

FrameDirections directionsOf(Row row) {
  var bits = 0;
  for (final unit in (row['dirs'] ?? '123').codeUnits) {
    bits |= 1 << (unit - 0x31);
  }
  return FrameDirections(bits);
}

FrameSession? loadSession(Row row) => FrameSession.load(
  bytes(row, 'key'),
  number(row, 'epoch'),
  FrameConfig(
    row.containsKey('tag_len') ? number(row, 'tag_len') : 4,
    directionsOf(row),
  ),
);

MsgContext contextOf(Row row) =>
    MsgContext(bytes(row, 'msg_id'), number(row, 'kind'));

FrameDirection directionOf(Row row) => FrameDirection(number(row, 'dir'));

const Map<String, List<String>> _outputs = {
  'keys': ['k_enc', 'k_mac', 'k_label'],
  'seal': ['body', 'result'],
  'open': ['result', 'slot', 'plain', 'window_after'],
  'mac': ['tag', 'valid', 'result'],
  'replay': ['results', 'states'],
};

/// The output fields the call gave for the row; a row with an error result
/// gives `result` only.
Map<String, String> run(Row row) => switch (opOf(row)) {
  'keys' => _runKeys(row),
  'seal' => _runSeal(row),
  'open' => _runOpen(row),
  'mac' => _runMac(row),
  'replay' => _runReplay(row),
  final op => throw FormatException('unknown op $op'),
};

/// Every mismatch of every row, as "case field: expected X, got Y". [ran]
/// counts the rows run per op.
List<String> mismatches(Iterable<Row> rows, [Map<String, int>? ran]) {
  final problems = <String>[];
  for (final row in rows) {
    final op = opOf(row);
    final got = run(row);
    ran?.update(op, (n) => n + 1, ifAbsent: () => 1);
    var compared = 0;
    for (final name in _outputs[op]!) {
      final expected = row[name];
      if (expected == null) continue;
      compared++;
      final value = got[name];
      if (value == null) {
        problems.add(
          '${caseOf(row)} $name: the row has it, the call gave none',
        );
      } else if (value != expected) {
        problems.add('${caseOf(row)} $name: expected $expected, got $value');
      }
    }
    if (compared == 0) problems.add('${caseOf(row)}: no output field');
  }
  return problems;
}

Map<String, String> _runKeys(Row row) {
  final epoch = number(row, 'epoch');
  if (row.containsKey('label')) {
    final mac = MacKey.derive(bytes(row, 'key'), epoch, bytes(row, 'label'));
    return {'k_label': mac == null ? 'BadValue' : hex(macKeyBytes(mac))};
  }
  final dir = number(row, 'dir');
  final session = FrameSession.load(
    bytes(row, 'key'),
    epoch,
    FrameConfig(4, FrameDirections(1 << (dir - 1))),
  );
  if (session == null) return {'k_enc': 'BadValue', 'k_mac': 'BadValue'};
  final keys = frameCurrentKeys(session);
  return {'k_enc': hex(keys.enc(dir)), 'k_mac': hex(keys.mac(dir))};
}

Map<String, String> _runSeal(Row row) {
  final session = loadSession(row);
  if (session == null) return {'result': 'BadValue'};
  final buffer = filled(
    row.containsKey('out_len') ? number(row, 'out_len') : 300,
  );
  final result = session.seal(
    directionOf(row),
    contextOf(row),
    bytes(row, 'ad'),
    bytes(row, 'clear'),
    bytes(row, 'plain'),
    buffer,
  );
  session.close();
  switch (result) {
    case FrameSealed(:final length):
      final rest = Uint8List.sublistView(buffer, length);
      final spill = untouched(rest) ? '' : ' (wrote past the body)';
      return {'body': hex(Uint8List.sublistView(buffer, 0, length)) + spill};
    case FrameRefusal():
      final wrote = untouched(buffer) ? '' : ' (a refused seal wrote bytes)';
      return {'result': kindName(result) + wrote};
  }
}

Map<String, String> _runOpen(Row row) {
  final got = <String, String>{};
  final window = row.containsKey('window')
      ? windowOf(get(row, 'window'))
      : null;
  final before = window == null ? null : windowText(window);
  var session = loadSession(row);
  if (session != null &&
      row.containsKey('prev_key') &&
      !session.setPrevious(bytes(row, 'prev_key'), number(row, 'prev_epoch'))) {
    session.close();
    session = null;
  }
  if (session == null) {
    got['result'] = 'BadValue';
  } else {
    final buffer = filled(
      row.containsKey('out_len') ? number(row, 'out_len') : 300,
    );
    final result = session.open(
      directionOf(row),
      contextOf(row),
      bytes(row, 'ad'),
      bytes(row, 'body'),
      number(row, 'clear_len'),
      buffer,
      window: window,
      counter: row.containsKey('counter')
          ? BigInt.parse(get(row, 'counter'))
          : null,
    );
    session.close();
    switch (result) {
      case FrameOpened(:final slot, :final plainLength):
        got['result'] = 'Ok';
        got['slot'] = slot == FrameSlot.current ? 'current' : 'previous';
        got['plain'] = hex(Uint8List.sublistView(buffer, 0, plainLength));
        if (!untouched(Uint8List.sublistView(buffer, plainLength))) {
          got['plain'] = '${got['plain']} (wrote past the text)';
        }
      case FrameRefusal():
        var text = kindName(result);
        if (!untouched(buffer)) text += ' (a refused open wrote bytes)';
        if (window != null && windowText(window) != before) {
          text += ' (a refused open changed the window)';
        }
        got['result'] = text;
    }
  }
  if (window != null) got['window_after'] = windowText(window);
  return got;
}

Map<String, String> _runMac(Row row) {
  final mac = MacKey.derive(
    bytes(row, 'key'),
    number(row, 'epoch'),
    bytes(row, 'label'),
  );
  if (mac == null) return {'result': 'BadValue'};
  final parts = row.containsKey('parts')
      ? get(row, 'parts').split('|').map(unhex).toList()
      : [bytes(row, 'message')];
  try {
    if (row.containsKey('verify')) {
      return {'valid': '${mac.verify(parts, bytes(row, 'verify'))}'};
    }
    return switch (mac.tag(parts, number(row, 'n'))) {
      MacTag(:final tag) => {'tag': hex(tag)},
      final FrameRefusal refusal => {'result': kindName(refusal)},
    };
  } finally {
    mac.close();
  }
}

Map<String, String> _runReplay(Row row) {
  final window = ReplayWindow();
  final results = <String>[];
  final states = <String>[];
  for (final step in get(row, 'steps').split(',')) {
    final colon = step.indexOf(':');
    final n = BigInt.parse(step.substring(colon + 1));
    final verb = step.substring(0, colon);
    if (verb == 'check') {
      results.add(_freshnessNames[window.check(n)]!);
    } else if (verb == 'commit') {
      window.commit(n);
      states.add(windowText(window));
    } else {
      throw FormatException('${caseOf(row)}: unknown step $step');
    }
  }
  return {
    'results': results.join(','),
    'states': states.isEmpty ? '-' : states.join(','),
  };
}

/// One of the worked examples E1 to E3 as open inputs, read from its row.
final class Example {
  Example(Row row)
    : key = bytes(row, 'key'),
      epoch = number(row, 'epoch'),
      direction = directionOf(row),
      tagLength = number(row, 'tag_len'),
      msgId = bytes(row, 'msg_id'),
      kind = number(row, 'kind'),
      ad = bytes(row, 'ad'),
      clearLength = number(row, 'clear_len'),
      body = bytes(row, 'body'),
      plain = bytes(row, 'plain');

  final Uint8List key;
  final int epoch;
  final FrameDirection direction;
  final int tagLength;
  final Uint8List msgId;
  final int kind;
  final Uint8List ad;
  final int clearLength;
  final Uint8List body;
  final Uint8List plain;

  MsgContext get context => MsgContext(msgId, kind);

  FrameSession session() => FrameSession.load(
    key,
    epoch,
    FrameConfig(tagLength, FrameDirections.all),
  )!;

  FrameOpenResult open(
    FrameSession session,
    Uint8List frame,
    Uint8List output, {
    ReplayWindow? window,
    BigInt? counter,
  }) => session.open(
    direction,
    context,
    ad,
    frame,
    clearLength,
    output,
    window: window,
    counter: counter,
  );
}

Row rowOf(List<Row> rows, String name) => rows.firstWhere(
  (row) => caseOf(row) == name,
  orElse: () => throw StateError('no row $name'),
);

Example example(List<Row> rows, String name) =>
    Example(rowOf(rows, '$name.open'));
