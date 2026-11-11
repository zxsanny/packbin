import 'dart:collection';

import 'utf8_order.dart';

/// The empty map unpack fills with the pairs of a dictionary. Its keys come in
/// ascending order of their UTF-8 bytes, which is also the order it keeps, so
/// it compares keys and never hashes them: a packet of keys that share one
/// string hash cannot make a lookup or an insert slow.
Map<String, V> newDict<V>() => SplayTreeMap<String, V>(compareUtf8);
