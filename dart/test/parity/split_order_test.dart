import 'package:packbin/packbin.dart';
import 'package:test/test.dart';

import '../support/hex.dart';
import '../support/repo.dart';
import 'parity_support.dart';

// TypeScript tables `split-bits-field-order.test.ts` (AZ-2135) and
// `flags-under-split-bit.test.ts`, row for row. The seeded generators of the
// last file are covered by the Dart seeded run (`test/limits/seeded_run_test.dart`).

// ---------------------------------------------------------------------------
// split-bits-field-order
// ---------------------------------------------------------------------------

Scheme<Row> twoReads(FlagByte m) =>
    scheme(1, [m, m.bit(u8(0, 'a')), m, m.bit(u8(1, 'b'))]);

Scheme<Row> fiveBits(int type, FlagByte m) =>
    scheme(type, [m, for (var i = 0; i < 5; i++) m.bit(u8(i, 'f$i'))]);

Scheme<Row> insideWhen() {
  final m = flagByte('m');
  return scheme(1, [
    u8(0, 'k'),
    m,
    when(1, eq(0, 1), [m, m.bit(u8(1, 'x'))]),
    m.bit(u8(2, 'y')),
  ]);
}

Scheme<Row> bitInBit() {
  final m = flagByte('m');
  return scheme(1, [
    m,
    m.bit(groupOf(0, 'g', [u8(0, 'y'), m.bit(u8(1, 'x'))])),
  ]);
}

/// The unanchored group of TypeScript is a nested row in Dart, a scope of its
/// own: the flag byte of the row around it is not read in that scope.
Scheme<Row> bitInNestedRow() {
  final m = flagByte('m');
  return scheme(1, [
    m,
    m.bit(nested('g', [u8(0, 'y'), m.bit(u8(1, 'x'))])),
  ]);
}

Scheme<Row> sixteenBits() {
  final m = flagByte('m');
  return scheme(1, [
    m,
    for (var i = 0; i < 8; i++) m.bit(u8(i, 'a$i')),
    m,
    for (var i = 0; i < 8; i++) m.bit(u8(8 + i, 'b$i')),
  ]);
}

final orderRows = <ParityRow>[
  ParityRow(
    'AZ-2135 AC-1 a flag byte read twice, only the second',
    () => twoReads(flagByte('m')),
    {'b': 9},
    const Pin.wire('01000109'),
    roundTrip: true,
  ),
  ParityRow(
    'AZ-2135 AC-1 a flag byte read twice, both',
    () => twoReads(flagByte('m')),
    {'a': 3, 'b': 9},
    const Pin.wire('0101030109'),
    roundTrip: true,
  ),
  ParityRow(
    'AZ-2135 AC-1 a handle shared by two 5-bit schemes builds both: first',
    () => fiveBits(1, flagByte('m')),
    {'f4': 7},
    const Pin.wire('011007'),
    roundTrip: true,
  ),
  ParityRow(
    'AZ-2135 AC-1 a handle shared by two 5-bit schemes builds both: second',
    () => fiveBits(2, flagByte('m')),
    {'f0': 3, 'f4': 7},
    const Pin.wire('02110307'),
    roundTrip: true,
  ),
  ParityRow(
    'AZ-2135 AC-1 a bit belongs to the latest read of its flag byte (8 bits '
    'per read)',
    sixteenBits,
    {'a7': 1, 'b0': 2},
    const Pin.wire('0180010102'),
    roundTrip: true,
  ),
  ParityRow(
    'AZ-2135 AC-1 a flag byte read inside a when numbers its own bits: taken',
    insideWhen,
    {'k': 1, 'x': 5, 'y': 6},
    const Pin.wire('010101010506'),
    roundTrip: true,
  ),
  ParityRow(
    'AZ-2135 AC-1 a flag byte read inside a when numbers its own bits: skipped',
    insideWhen,
    {'k': 0, 'y': 6},
    const Pin.wire('01000106'),
    roundTrip: true,
  ),
  ParityRow(
    'AZ-2135 AC-1 a bit is numbered before the bits nested in its field: outer '
    'only',
    bitInBit,
    {
      'g': {'y': 1},
    },
    const Pin.wire('010101'),
    roundTrip: true,
  ),
  ParityRow(
    'AZ-2135 AC-1 a bit is numbered before the bits nested in its field: both',
    bitInBit,
    {
      'g': {'y': 1, 'x': 2},
    },
    const Pin.wire('01030102'),
    roundTrip: true,
  ),
];

// ---------------------------------------------------------------------------
// flags-under-split-bit
// ---------------------------------------------------------------------------

/// A split bit holds a group that holds a flags.
Scheme<Row> splitBitGroup() {
  final fb = flagByte('m');
  return scheme(1, [
    fb,
    fb.bit(
      nested('g', [
        u8(0, 'a'),
        flags(1, [u8(1, 'c')]),
      ]),
    ),
  ]);
}

Scheme<Row> flagsInFlags() => scheme(1, [
  flags(0, [
    flags(0, [u8(0, 'c')]),
  ]),
]);

Scheme<Row> deep() => scheme(1, [
  flags(0, [
    flags(0, [
      flags(0, [u8(0, 'c')]),
    ]),
  ]),
]);

Scheme<Row> bitFlags() {
  final fb = flagByte('m');
  return scheme(1, [
    fb,
    fb.bit(flags(0, [u8(0, 'c')])),
  ]);
}

Scheme<Row> twoFlagsInGroup() {
  final fb = flagByte('m');
  return scheme(1, [
    fb,
    fb.bit(
      nested('g', [
        flags(0, [u8(0, 'c')]),
        flags(1, [u8(1, 'd')]),
      ]),
    ),
  ]);
}

final underRows = <ParityRow>[
  ParityRow(
    'AC-1/AC-2 flags in a group under a split bit are packed and repack',
    splitBitGroup,
    {
      'g': {'a': 1, 'c': 2},
    },
    const Pin.wire('0101010102'),
    roundTrip: true,
  ),
  ParityRow(
    'AC-3 absent values stay absent: partial',
    splitBitGroup,
    {
      'g': {'a': 1},
    },
    const Pin.wire('01010100'),
    roundTrip: true,
  ),
  ParityRow(
    'AC-3 absent values stay absent: empty',
    splitBitGroup,
    {},
    const Pin.wire('0100'),
    roundTrip: true,
  ),
  ParityRow(
    'AC-4 a missing required member in a present group is still named',
    splitBitGroup,
    {
      'g': {'c': 2},
    },
    const Pin.names('a'),
  ),
  ParityRow(
    'AC-5 flags directly inside flags are packed',
    flagsInFlags,
    {'c': 2},
    const Pin.wire('01010102'),
    roundTrip: true,
  ),
  ParityRow(
    'AC-5 flags directly inside flags, absent',
    flagsInFlags,
    {},
    const Pin.wire('0100'),
    roundTrip: true,
  ),
  ParityRow(
    'flags three deep are packed and read back',
    deep,
    {'c': 9},
    const Pin.wire('0101010109'),
    roundTrip: true,
  ),
  ParityRow(
    'a split bit that holds flags directly packs them',
    bitFlags,
    {'c': 3},
    const Pin.wire('01010103'),
    roundTrip: true,
  ),
  ParityRow(
    'two flags in one group under a split bit each keep their own flag byte',
    twoFlagsInGroup,
    {
      'g': {'c': 1, 'd': 2},
    },
    const Pin.wire('010101010102'),
    roundTrip: true,
  ),
];

void main() {
  group('split-bits-field-order (AZ-2135)', () {
    runParity(orderRows);

    test('AZ-2135 AC-1 a handle shared by two schemes numbers the bits of '
        'each from 0', () {
      // Arrange
      final m = flagByte('m');
      final first = scheme(1, [m, m.bit(u8(0, 'x'))]);
      final second = scheme(1, [m, m.bit(u8(0, 'x'))]);

      // Act
      final wires = [
        for (final layout in [first, second]) outcome(layout, {'x': 5}),
      ];

      // Assert
      expect(wires, ['010105', '010105']);
    });

    test('AZ-2135 AC-1 bits take their numbers from the scheme order, not '
        'the order of the bit calls', () {
      // Arrange
      final m = flagByte('m');
      final late = m.bit(u8(1, 'b'));
      final early = m.bit(u8(0, 'a'));
      final layout = scheme(1, [m, early, late]);

      // Act
      final wire = outcome(layout, {'b': 9});

      // Assert
      expect(wire, '010209');
      expect(unpackedRow(layout, wire), {'b': 9});
    });

    test('AZ-2135 AC-1 withLimits keeps the numbering of a flag byte read '
        'twice', () {
      // Arrange
      final layout = twoReads(flagByte('m')).withLimits(maxRounds: 3);

      // Act
      final wire = outcome(layout, {'b': 9});

      // Assert
      expect(wire, '01000109');
    });

    test('AZ-2135 AC-1 the ninth bit of one read is refused when the scheme '
        'is built', () {
      // Arrange
      final m = flagByte('m');

      // Act
      PackbinException? error;
      try {
        scheme(1, [m, for (var i = 0; i < 9; i++) m.bit(u8(i, 'f$i'))]);
      } on PackbinException catch (e) {
        error = e;
      }

      // Assert
      expect(error!.kind, ErrorKind.schemeError);
      expect(error.reason, contains('ninth bit (f8)'));
    });

    test(
      'AZ-2135 AC-3 the position golden bytes are the same in split form',
      () {
        // Arrange
        final m = flagByte('m');
        final split = scheme(0x40, [
          u16(0, 'sid'),
          i32(1, 'lat'),
          i32(2, 'lon'),
          u8(3, 'profile'),
          m,
          m.bit(u16(4, 'heading')),
          m.bit(u8(5, 'speed')),
          m.bit(i16(6, 'altitude')),
        ]);
        final joined = scheme(0x40, [
          u16(0, 'sid'),
          i32(1, 'lat'),
          i32(2, 'lon'),
          u8(3, 'profile'),
          flags(4, [u16(4, 'heading'), u8(5, 'speed'), i16(6, 'altitude')]),
        ]);
        final row = {
          'sid': 1,
          'lat': 500000000,
          'lon': 300000000,
          'profile': 1,
        };
        final moving = {...row, 'speed': 7, 'altitude': -2};

        // Act
        final wire = outcome(split, row);
        final movingWire = outcome(split, moving);

        // Assert
        expect(wire, goldenHex());
        expect(movingWire, outcome(joined, moving));
        expect(hex(pack(joined, row)), wire);
      },
    );
  });
  group('flags-under-split-bit', () {
    runParity(underRows);

    test('AZ-2135 AC-1 a flag bit inside a nested row needs its flag byte '
        'in that row', () {
      // Act
      PackbinException? error;
      try {
        bitInNestedRow();
      } on PackbinException catch (e) {
        error = e;
      }

      // Assert
      expect(error!.kind, ErrorKind.schemeError);
      expect(error.name, 'x');
      expect(
        error.reason,
        'flag bit 1 (x): its flag byte is not read earlier in the same scope',
      );
    });

    test('AC-4 a flat key does not reach a nested row: it is not read', () {
      // Act
      final wire = outcome(splitBitGroup(), {'c': 2});

      // Assert
      expect(wire, '0100');
    });
  });
}
