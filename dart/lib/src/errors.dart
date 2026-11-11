/// What went wrong. [term] is the outcome term every packbin package shares
/// (`fixtures/hostile/README.md`). A kind is never renamed; later versions
/// only add kinds.
enum ErrorKind {
  /// The buffer ends inside a field: `field`, `name`, `needed` and `left` are
  /// set. An empty buffer names no field and needs 1 byte.
  short('short_packet'),

  /// Bytes are left after the scheme's last field: `left` is their count.
  trailing('trailing_bytes'),

  /// The first byte names no scheme of the call: `actual` is that byte.
  unknownType('type_mismatch'),

  /// Unpack read a value it cannot use.
  badValue('bad_value'),

  /// Unpack refuses a round past a limit of the scheme.
  tooMany('too_many'),

  /// A scheme, a field or an unpack call's handler list is refused.
  schemeError('scheme_error'),

  /// Pack cannot write the row; it returns no bytes.
  packError('pack_error');

  const ErrorKind(this.term);

  /// The stable outcome term, for example `short_packet`.
  final String term;
}

/// One error, as a value. Unpack returns it inside its result and never
/// throws on input bytes; pack and scheme construction throw it wrapped in a
/// [PackbinException].
final class PackbinError {
  /// Makes an error value.
  const PackbinError(
    this.kind, {
    this.field,
    this.name = '',
    this.needed = 0,
    this.left = 0,
    this.actual,
    this.reason = '',
  });

  /// What went wrong.
  final ErrorKind kind;

  /// The field id (the anchor of `flags` and `when`), or null for an error
  /// that belongs to no field: trailing bytes, an unknown type byte, an empty
  /// buffer, a split flag byte.
  final int? field;

  /// The field's name, or ''.
  final String name;

  /// The bytes a short field needed.
  final int needed;

  /// The bytes left where a short field started, or the count of trailing
  /// bytes.
  final int left;

  /// The first byte of a packet whose type number no scheme has.
  final int? actual;

  /// Why a value, a row or a scheme is refused.
  final String reason;

  String get _where {
    final id = field;
    if (id != null) {
      return name.isEmpty ? ' at field $id' : ' at field $id ($name)';
    }
    return name.isEmpty ? '' : ' at $name';
  }

  @override
  String toString() => switch (kind) {
    ErrorKind.short =>
      'packbin: short packet$_where: needed $needed, left $left',
    ErrorKind.trailing => 'packbin: $left trailing bytes',
    ErrorKind.unknownType => 'packbin: unknown type number ${actual ?? -1}',
    ErrorKind.badValue => 'packbin: bad value$_where: $reason',
    ErrorKind.tooMany => 'packbin: too many$_where: $reason',
    ErrorKind.schemeError => 'packbin: invalid scheme$_where: $reason',
    ErrorKind.packError => 'packbin: pack refused$_where: $reason',
  };

  @override
  bool operator ==(Object other) =>
      other is PackbinError &&
      other.kind == kind &&
      other.field == field &&
      other.name == name &&
      other.needed == needed &&
      other.left == left &&
      other.actual == actual &&
      other.reason == reason;

  @override
  int get hashCode =>
      Object.hash(kind, field, name, needed, left, actual, reason);
}

/// Thrown by pack (kind [ErrorKind.packError]) and by scheme construction and
/// a refused handler list (kind [ErrorKind.schemeError]).
final class PackbinException implements Exception {
  /// Wraps [error].
  const PackbinException(this.error);

  /// The error, with its kind, field id, field name and reason.
  final PackbinError error;

  /// The error's kind.
  ErrorKind get kind => error.kind;

  /// The id of the field the error names, or null.
  int? get field => error.field;

  /// The name of the field the error names, or ''.
  String get name => error.name;

  /// Why the row or the scheme is refused.
  String get reason => error.reason;

  @override
  String toString() => error.toString();
}

PackbinException schemeFail(int? id, String name, String reason) =>
    PackbinException(
      PackbinError(
        ErrorKind.schemeError,
        field: id,
        name: name,
        reason: reason,
      ),
    );

PackbinException packFail(int? id, String name, String reason) =>
    PackbinException(
      PackbinError(ErrorKind.packError, field: id, name: name, reason: reason),
    );

PackbinError shortPacket(int? id, String name, int needed, int left) =>
    PackbinError(
      ErrorKind.short,
      field: id,
      name: name,
      needed: needed,
      left: left,
    );
