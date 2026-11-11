import 'dart:io';
import 'dart:typed_data';
import 'package:packbin/packbin.dart';

String hex(Uint8List b) => b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();
String key(String u) {
  if (u == '-') return '';
  return String.fromCharCodes([for (var i = 0; i < u.length; i += 4) int.parse(u.substring(i, i + 4), radix: 16)]);
}

void main(List<String> args) {
  final s = scheme(1, [dict('d', u8(0, 'v'))]);
  var same = 0, differ = 0, refused = 0;
  for (final line in File(args[0]).readAsLinesSync()) {
    if (line.isEmpty) continue;
    final f = line.split('\t');
    final ks = f[0].split(',').map(key).toList();
    final vs = f[1].split(',').map(int.parse).toList();
    final d = <String, Object?>{for (var i = 0; i < ks.length; i++) ks[i]: vs[i]};
    String got;
    try {
      got = hex(pack(s, {'d': d}));
    } on PackbinException catch (e) {
      got = e.reason.contains('two keys are the same') ? 'REFUSED' : 'OTHER ${e.reason}';
      if (got == 'REFUSED') refused++;
    }
    if (got == f[2]) {
      same++;
    } else {
      differ++;
      if (differ < 6) print('DIFF keys=${f[0]} ts=${f[2]} dart=$got');
    }
  }
  print('dart vs typescript: $same same, $differ different, $refused refused');
}
