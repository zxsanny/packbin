/// The compact text format (contract `compact-text` 1.0.0, ADR-006): a LEB128
/// count, then a payload of prefix codes in four modes (Ukrainian, Russian,
/// English, number) or raw UTF-8.
library;

export 'text_decode.dart' show decodeText;
export 'text_encode.dart' show encodeText;
export 'text_model.dart' show maxTextBytes;
export 'text_types.dart';
