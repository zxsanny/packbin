import 'flags_times_member_test.dart' as flags_times;
import 'flags_when_member_test.dart' as flags_when;
import 'loop20_pins_test.dart' as loop20;
import 'loop21_probes_test.dart' as loop21;
import 'lone_rows_test.dart' as lone;
import 'parity_support.dart';
import 'reference_scope_test.dart' as reference;
import 'rounds_rows_test.dart' as rounds;
import 'scheme_rows_test.dart' as scheme_rows;
import 'split_loud_test.dart' as split_loud;
import 'split_order_test.dart' as split_order;
import 'u11_test.dart' as u11;
import 'value_rows_test.dart' as value;
import 'written_rows_test.dart' as written;

/// One TypeScript parity table ported to Dart: the TypeScript test file it
/// comes from (under `typescript/tests/`), the Dart test file that runs it
/// (under `dart/test/parity/`) and the number of rows it runs.
final class ParityTable {
  const ParityTable(this.tsFile, this.dartFile, this.rows);
  final String tsFile;
  final String dartFile;
  final int rows;
}

int _with(Iterable<ParityRow> rows, List<String> prefixes) =>
    rows.where((r) => prefixes.any(r.id.startsWith)).length;

int _unpackOnly(Iterable<UnpackRow> rows) => rows.length;

/// Every ported table, with the rows its Dart file runs: the lengths of its
/// row lists, plus the tests the file adds by hand (counted where they are
/// written, and named in the comment).
List<ParityTable> parityTables() => [
  // + 2 hand tests: AZ-2359 (an enum's integer and a string).
  ParityTable(
    'loop20-parity-pins.test.ts',
    'loop20_pins_test.dart',
    _with(loop20.rows, ['AZ-2356', 'AZ-2360', 'AZ-2363']) + 2,
  ),
  ParityTable(
    'times-count-zero-with-values.test.ts',
    'loop20_pins_test.dart',
    _with(loop20.rows, ['AZ-2335']),
  ),
  // + 1 hand test: the member a plain times refusal names.
  ParityTable(
    'loop21-parity-probes.test.ts',
    'loop21_probes_test.dart',
    loop21.rows.length + 1,
  ),
  ParityTable(
    'loop22-novalue-count.test.ts',
    'u11_test.dart',
    u11.topRows.length,
  ),
  ParityTable(
    'loop23-novalue-nested.test.ts',
    'u11_test.dart',
    u11.nestedRows.length,
  ),
  // + 2 hand tests: the U6 split (a times count of 2^60, two positions).
  ParityTable(
    'loop23-bigint-count.test.ts',
    'u11_test.dart',
    u11.bigRows.length + 2,
  ),
  ParityTable(
    'flags-when-member.test.ts',
    'flags_when_member_test.dart',
    flags_when.rows.length + _unpackOnly(flags_when.unpackOnly),
  ),
  ParityTable(
    'flags-times-repeat-member.test.ts',
    'flags_times_member_test.dart',
    flags_times.timesRows.length + _unpackOnly(flags_times.timesUnpackOnly),
  ),
  ParityTable(
    'repeat-short-optional.test.ts',
    'rounds_rows_test.dart',
    rounds.shortRows.length,
  ),
  ParityTable(
    'times-longer-list.test.ts',
    'rounds_rows_test.dart',
    rounds.longerRows.length,
  ),
  ParityTable(
    'split-form-loud-pack.test.ts',
    'split_loud_test.dart',
    split_loud.loudRows.length,
  ),
  ParityTable(
    'split-form-reference.test.ts',
    'split_loud_test.dart',
    split_loud.referenceRows.length,
  ),
  // + 5 hand tests: shared handle, bit call order, withLimits, ninth bit,
  // golden bytes.
  ParityTable(
    'split-bits-field-order.test.ts',
    'split_order_test.dart',
    split_order.orderRows.length + 5,
  ),
  // + 2 hand tests: a nested row's flag byte scope, a flat key.
  ParityTable(
    'flags-under-split-bit.test.ts',
    'split_order_test.dart',
    split_order.underRows.length + 2,
  ),
  ParityTable(
    'duplicate-names.test.ts',
    'scheme_rows_test.dart',
    scheme_rows.refusals
            .where((r) => r.id.startsWith('duplicate-names'))
            .length +
        scheme_rows.rows
            .where((r) => r.id.startsWith('duplicate-names'))
            .length,
  ),
  ParityTable(
    'empty-round-body.test.ts',
    'scheme_rows_test.dart',
    scheme_rows.refusals
            .where((r) => r.id.startsWith('empty-round-body'))
            .length +
        scheme_rows.rows
            .where((r) => r.id.startsWith('empty-round-body'))
            .length,
  ),
  // + 2 hand tests: the route fixture and the route with straight false.
  ParityTable(
    'borrowed-count.test.ts',
    'scheme_rows_test.dart',
    scheme_rows.countRows.length + 2,
  ),
  ParityTable(
    'lone-bytes-in-round.test.ts',
    'lone_rows_test.dart',
    _with(lone.rows, ['AZ-2332']),
  ),
  ParityTable(
    'lone-dict-in-round.test.ts',
    'lone_rows_test.dart',
    _with(lone.rows, ['AZ-2308']),
  ),
  ParityTable(
    'flag-group-presence.test.ts',
    'written_rows_test.dart',
    written.presenceRows.length,
  ),
  // + 3 hand tests: the golden bytes and the two seeded chains.
  ParityTable(
    'when-on-written-values.test.ts',
    'written_rows_test.dart',
    written.writtenRows.length + 3,
  ),
  // + 4 hand tests: nested group ids on unpack, a shared field object, a
  // when in a repeat, eq by value of a u64.
  ParityTable(
    'reference-scope.test.ts',
    'reference_scope_test.dart',
    reference.refusals.length + reference.rows.length + 4,
  ),
  // + 7 hand tests: the differences of Go-2 and A-3, a BigInt, and the
  // unpacked rows that pack again.
  ParityTable(
    'int-range.test.ts',
    'value_rows_test.dart',
    value.rows
            .where(
              (r) =>
                  !r.id.startsWith('bool') &&
                  !r.id.startsWith('diff bool') &&
                  !r.id.startsWith('split form bool') &&
                  !r.id.startsWith('empty group mark'),
            )
            .length +
        7,
  ),
  ParityTable(
    'bool-flag.test.ts',
    'value_rows_test.dart',
    value.rows
        .where(
          (r) =>
              r.id.startsWith('bool') ||
              r.id.startsWith('diff bool') ||
              r.id.startsWith('split form bool') ||
              r.id.startsWith('empty group mark'),
        )
        .length,
  ),
  // The files below write their rows by hand: the counts are the tests of
  // their files.
  const ParityTable(
    'ecc-dispatch-order.test.ts',
    'dispatch_order_test.dart',
    24,
  ),
  const ParityTable('loop22-max-slots.test.ts', 'max_slots_test.dart', 4),
  const ParityTable(
    'eq-source-kinds.test.ts and eq-value-checked.test.ts',
    'eq_checks_test.dart',
    61,
  ),
  const ParityTable('u64-count.test.ts', 'count_rows_test.dart', 31),
];
