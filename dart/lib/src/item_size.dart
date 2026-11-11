import 'node.dart';

/// The fewest bytes one item of a list or dict (of [kind], with [element])
/// takes, at least 1: an item that reads no byte is refused on unpack, so a
/// valid packet holds at least this many bytes for each item.
int minItemBytes(NodeKind kind, Node element) {
  final item = _fewest(element);
  // A dictionary pair is a key (at least its length byte) and the item.
  final pair = kind == NodeKind.dict ? 1 + item : item;
  return pair < 1 ? 1 : pair;
}

/// The bytes a field always writes, whatever the row holds; 0 for a field a
/// bit, a condition or a count can leave out.
int _fewest(Node n) {
  switch (n.kind) {
    case NodeKind.integer:
    case NodeKind.float:
    case NodeKind.bytes:
      return n.size;
    case NodeKind.utf8:
    case NodeKind.flags:
    case NodeKind.flagByte:
      return 1;
    case NodeKind.list:
    case NodeKind.dict:
      return 2;
    case NodeKind.u2:
      return (n.fields.length + 3) >> 2;
    case NodeKind.nested:
    case NodeKind.group:
      var sum = 0;
      for (final m in n.fields) {
        sum += _fewest(m);
      }
      return sum;
    case NodeKind.boolean:
    case NodeKind.flagBit:
    case NodeKind.when:
    case NodeKind.sized:
    case NodeKind.slot:
    case NodeKind.bits:
    case NodeKind.packed:
    case NodeKind.repeat:
    case NodeKind.times:
      return 0;
  }
}
