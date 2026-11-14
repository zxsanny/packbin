using Packbin;
using static Packbin.Tests.Budget;

namespace Packbin.Tests;

// The pack stage of fixtures/hostile/cases.txt (AZ-2194): a case expects the packet bytes or a refusal that returns no
// bytes. The file holds outcomes only (ADR-001), so each case id maps to a hand-written C# scheme and dictionary row,
// written from fixtures/hostile/README.md. C# runs every case through dictionary rows (typed rows are statically
// typed, so they cannot hold an out-of-range integer, a missing value or a lone buffer in a round).
public partial class HostilePackVectorTests
{
    private static readonly Dictionary<string, Func<byte[]>> Packs = new()
    {
        ["pack_out_of_range_integer"] = () => BinaryPacker.Pack(
            new Scheme<PackRow>(1, Field.U8<PackRow>(0, x => x.A)), Row(("A", 300))),
        ["pack_missing_required_value"] = () => BinaryPacker.Pack(
            new Scheme<PackRow>(1, Field.U8<PackRow>(0, x => x.A), Field.U8<PackRow>(1, x => x.B)),
            Row(("A", (byte)1))),
        ["pack_times_list_too_long"] = () => BinaryPacker.Pack(
            TimesScheme(), Row(("A", (byte)2), ("X", new object?[] { (byte)1, (byte)2, (byte)3 }))),
        ["pack_times_list_too_short"] = () => BinaryPacker.Pack(
            TimesScheme(), Row(("A", (byte)2), ("X", new object?[] { (byte)1 }))),
        ["pack_aligned_round_row"] = () => BinaryPacker.Pack(
            new Scheme<PackRow>(1, Field.Repeat(0,
                Field.Flags(0, Field.Bool<PackRow>(0, x => x.On), Field.U8<PackRow>(1, x => x.N)))),
            Row(("On", new object?[] { true, false, true }), ("N", new object?[] { (byte)1, (byte)2, (byte)3 }))),
        ["pack_times_count_over_limit"] = () => BinaryPacker.Pack(
            new Scheme<WideRow>(1,
                Field.U32<WideRow>(0, x => x.N),
                Field.Times(1, 0, Field.U8<WideRow>(1, x => x.X))),
            Row(("N", 65536u), ("X", (byte)7))),
        ["pack_times_zero_with_values"] = () => BinaryPacker.Pack(
            TimesScheme(), Row(("A", (byte)0), ("X", new object?[] { (byte)5 }))),
        ["pack_split_when_source_after_byte"] = () => BinaryPacker.Pack(
            SplitScheme("when_after"), Row(("Mode", (byte)1), ("Speed", (byte)7))),
        ["pack_split_times_count_after_byte"] = () => BinaryPacker.Pack(
            SplitScheme("times_after"), Row(("N", (byte)2), ("Pt", new object?[] { (byte)5, (byte)6 }))),
        ["pack_split_times_count_skipped"] = () => BinaryPacker.Pack(
            SplitScheme("times_skipped"), Row(("Sel", (byte)0), ("Pt", new object?[] { (byte)5 }))),
        ["pack_lone_bytes_in_round"] = () => BinaryPacker.Pack(
            new Scheme<BufferRow>(1,
                Field.U8<BufferRow>(0, x => x.N),
                Field.Times(1, 0, Field.Bytes<BufferRow>(1, x => x.D, 2))),
            Row(("N", (byte)2), ("D", new byte[] { 1, 2 }))),
        ["pack_split_false_condition_silent"] = () => BinaryPacker.Pack(
            SplitScheme("false_silent"), Row(("Mode", (byte)0), ("Speed", (byte)7), ("Heading", (ushort)90))),
        ["pack_lone_utf8_under_times_over_budget"] = () => BinaryPacker.Pack(
            new Scheme<BudgetRow>(1,
                Field.U32<BudgetRow>(0, x => x.N),
                Field.Times(1, 0, Field.Utf8<BudgetRow>(1, x => x.S))),
            Row(("N", 65_535u), ("S", new string('a', 65_535)))),
        ["pack_element_times_over_budget"] = () => BinaryPacker.Pack(
            new Scheme<BudgetRow>(1,
                Field.List((BudgetRow x) => x.Items,
                    Field.Group(0, (BudgetWideItem e) => e.Mark,
                        Field.U32<BudgetWideItem>(0, e => e.N),
                        Field.Times(1, 0, Field.U64<BudgetWideItem>(1, e => e.K))))),
            Row(("Items", Enumerable.Range(0, 40)
                .Select(_ => (object?)Row(("N", 65_535u), ("K", 5UL))).ToList()))),
        ["pack_slots_over_limit"] = () => BinaryPacker.Pack(WideRound(), WideRow(65_535)),
        ["pack_repeat_over_limit"] = () => BinaryPacker.Pack(
            new Scheme<BudgetRow>(1, Field.Repeat(0, Field.U8<BudgetRow>(0, x => x.K))),
            Row(("K", Repeated((byte)7, 65_536)))),
        ["pack_split_count_zero_after_byte_list"] = () => BinaryPacker.Pack(
            SplitScheme("times_after"), Row(("N", (byte)0), ("Pt", new object?[] { (byte)5, (byte)6 }))),
        ["pack_split_count_zero_after_byte_scalar"] = () => BinaryPacker.Pack(
            SplitScheme("times_after"), Row(("N", (byte)0), ("Pt", (byte)5))),
        ["pack_flags_skipped_count_with_values"] = () => BinaryPacker.Pack(
            new Scheme<SplitRow>(1, Field.Flags(0,
                Field.U8<SplitRow>(0, x => x.N),
                Field.Times(1, 0, Field.U8<SplitRow>(1, x => x.Pt)))),
            Row(("Pt", new object?[] { (byte)5, (byte)6 }))),
        ["pack_round_slots_at_limit"] = () => BinaryPacker.Pack(
            SlotsScheme(), Row(("N", (byte)1), ("A", L((byte)1)), ("B", L((byte)2, (byte)3)))),
        ["pack_round_slots_over_limit"] = () => BinaryPacker.Pack(
            SlotsScheme(), Row(("N", (byte)1), ("A", L((byte)1)), ("B", L((byte)2, (byte)3, (byte)4)))),
        ["pack_round_slots_flags_at_limit"] = () => BinaryPacker.Pack(
            FlagsSlotsScheme(), Row(("On", L(true, true)), ("V", L((byte)5, (byte)6)))),
        ["pack_round_slots_flags_over_limit"] = () => BinaryPacker.Pack(
            FlagsSlotsScheme(), Row(("On", L(true, true, true)), ("V", L((byte)5, (byte)6, (byte)7)))),
        ["pack_flags_short_list"] = () => BinaryPacker.Pack(
            ShortListScheme(), Row(("W", L((byte)1, (byte)2)), ("V", L((byte)5)))),
        ["pack_flags_short_list_filled"] = () => BinaryPacker.Pack(
            ShortListScheme(), Row(("W", L((byte)1, (byte)2)), ("V", L((byte)5, null)))),
        ["pack_split_times_absent_body"] = () => BinaryPacker.Pack(
            SplitScheme("times_after_heading"), Row(("N", (byte)2), ("Heading", (ushort)90))),
        ["pack_late_when_in_bit_body"] = () => BinaryPacker.Pack(
            LateWhenScheme(), Row(("Mode", (byte)1), ("D", (byte)5), ("A", (byte)9))),
        ["pack_count_one_clear_when"] = () => BinaryPacker.Pack(
            CountClearWhenScheme(), Row(("Mode", (byte)0), ("C", (byte)1), ("Heading", (ushort)90))),
        ["pack_bits_count_clear_when"] = () => BinaryPacker.Pack(
            CountedScheme(() => Field.Bits<StrandedRow>(2, x => x.V, 1)),
            Row(("Mode", (byte)0), ("C", (byte)3), ("V", new List<int> { 1, 0, 1 }))),
        ["pack_packed_count_clear_when"] = () => BinaryPacker.Pack(
            CountedScheme(() => Field.Packed<StrandedRow>(1, 2, x => x.V, 1)),
            Row(("Mode", (byte)0), ("C", (byte)3), ("V", new List<int> { 1, 0, 1 }))),
        ["pack_sized_count_clear_when"] = () => BinaryPacker.Pack(
            new Scheme<StrandedSizedRow>(1,
                Field.U8<StrandedSizedRow>(0, x => x.Mode),
                Field.When(1, Condition.Eq(0, 1), Field.U8<StrandedSizedRow>(1, x => x.C)),
                Field.Sized<StrandedSizedRow>(2, x => x.V, 1)),
            Row(("Mode", (byte)0), ("C", (byte)3), ("V", new byte[] { 1, 2, 3 }))),
        ["pack_when_of_skipped_source"] = () => BinaryPacker.Pack(
            SkippedSourceScheme(2), Row(("Mode", (byte)0), ("A", (ushort)7), ("K", (byte)2), ("B", (byte)5))),
        ["pack_when_of_skipped_source_zero"] = () => BinaryPacker.Pack(
            SkippedSourceScheme(0), Row(("Mode", (byte)0), ("A", (ushort)7), ("K", (byte)0), ("B", (byte)5))),
        ["pack_when_of_skipped_bool_source"] = () => BinaryPacker.Pack(
            BoolSourceScheme(), Row(("Mode", (byte)0), ("On", true), ("A", (byte)7), ("B", (byte)5))),
        ["pack_when_of_held_bool_source"] = () => BinaryPacker.Pack(
            BoolSourceScheme(), Row(("Mode", (byte)1), ("On", true), ("A", (byte)7), ("B", (byte)5))),
        ["pack_when_of_held_bool_source_clear"] = () => BinaryPacker.Pack(
            BoolSourceScheme(), Row(("Mode", (byte)1), ("On", false), ("A", (byte)7), ("B", (byte)5))),
        ["pack_novalue_count_clear_when_bits"] = () => BinaryPacker.Pack(
            SplitCounted(() => Field.Bits<StrandedRow>(2, x => x.V, 1)), Row(("Mode", (byte)0), ("C", (byte)3))),
        ["pack_novalue_count_clear_when_packed"] = () => BinaryPacker.Pack(
            SplitCounted(() => Field.Packed<StrandedRow>(1, 2, x => x.V, 1)), Row(("Mode", (byte)0), ("C", (byte)3))),
        ["pack_novalue_count_clear_when_sized"] = () => BinaryPacker.Pack(
            SplitSized(), Row(("Mode", (byte)0), ("C", (byte)3))),
        ["pack_repeat_unequal_lists_lone"] = () => BinaryPacker.Pack(
            new Scheme<PackRow>(1, Field.Repeat(0, Field.U8<PackRow>(0, x => x.A), Field.U8<PackRow>(1, x => x.B))),
            Row(("A", L((byte)1, (byte)2)), ("B", (byte)7))),
        ["pack_repeat_unequal_lists_when"] = () => BinaryPacker.Pack(
            new Scheme<RepeatWhenRow>(1, Field.Repeat(0,
                Field.U8<RepeatWhenRow>(0, x => x.K),
                Field.When(1, Condition.Eq(0, 1), Field.U8<RepeatWhenRow>(1, x => x.V)))),
            Row(("K", L((byte)1, (byte)2)), ("V", L((byte)9)))),
        ["pack_times_short_list_flags"] = () => BinaryPacker.Pack(
            new Scheme<FlagsTimesRow>(1,
                Field.U8<FlagsTimesRow>(0, x => x.C),
                Field.Times(1, 0, Field.Flags(1, Field.U8<FlagsTimesRow>(1, x => x.V)))),
            Row(("C", (byte)2), ("V", L((byte)5)))),
        ["pack_element_times_over_bytes_budget"] = () => BinaryPacker.Pack(
            new Scheme<Utf8Items>(1,
                Field.List((Utf8Items x) => x.Items,
                    Field.Group(0, (Utf8Item e) => e.Mark,
                        Field.U32<Utf8Item>(0, e => e.N),
                        Field.Times(1, 0, Field.Utf8<Utf8Item>(1, e => e.S))))),
            Row(("Items", Enumerable.Range(0, 16)
                .Select(_ => (object?)Row(("N", 65_535u), ("S", new string('\u0001', 16)))).ToList()))),
        // Loop 113 (AZ-4212, contract repeat-last): K1 to K4, a repeat that is last and a times with a field after it.
        ["pack_repeat_last"] = () => BinaryPacker.Pack(
            new Scheme<RepeatWhenRow>(1, Field.U8<RepeatWhenRow>(0, x => x.X), Field.Repeat(1, Field.U8<RepeatWhenRow>(1, x => x.V))),
            Row(("X", (byte)9), ("V", L((byte)5, (byte)6)))),
        ["pack_repeat_last_in_when"] = () => BinaryPacker.Pack(
            new Scheme<RepeatWhenRow>(1, Field.U8<RepeatWhenRow>(0, x => x.K),
                Field.When(1, Condition.Eq(0, 1), Field.Repeat(1, Field.U8<RepeatWhenRow>(1, x => x.V)))),
            Row(("K", (byte)1), ("V", L((byte)5, (byte)6)))),
        ["pack_repeat_last_in_flags"] = () => BinaryPacker.Pack(
            new Scheme<RepeatWhenRow>(1, Field.Flags(0,
                Field.U8<RepeatWhenRow>(0, x => x.X), Field.Repeat(1, Field.U8<RepeatWhenRow>(1, x => x.V)))),
            Row(("X", (byte)9), ("V", L((byte)5, (byte)6)))),
        ["pack_times_then_field"] = () => BinaryPacker.Pack(
            new Scheme<RepeatWhenRow>(1, Field.U8<RepeatWhenRow>(0, x => x.K),
                Field.Times(1, 0, Field.U8<RepeatWhenRow>(1, x => x.V)), Field.U8<RepeatWhenRow>(2, x => x.X)),
            Row(("K", (byte)2), ("V", L((byte)5, (byte)6)), ("X", (byte)9))),
        // Loop 126 (AZ-4296, contract scheme-depth): 256 levels build. The chains are built by a loop (SchemeDepthTests).
        ["pack_depth_when_256"] = () => BinaryPacker.Pack(
            SchemeDepthTests.WhenScheme(256), Row(("A", (byte)1), ("B", (byte)7))),
        ["pack_depth_group_256"] = () => BinaryPacker.Pack(SchemeDepthTests.GroupScheme(256), DepthGroupValue(256)),
    };

    private static SchemeDepthTests.Node DepthGroupValue(int depth)
    {
        var node = new SchemeDepthTests.Node { B = 7 };
        for (var i = 0; i < depth; i++)
            node = new SchemeDepthTests.Node { M = node };
        return node;
    }

    // The member a loop 19 refusal names, so a refusal by some other rule does not pass.
    private static readonly Dictionary<string, string> NamedMember = new()
    {
        ["pack_times_count_over_limit"] = "'X'",
        ["pack_times_zero_with_values"] = "'X'",
        ["pack_split_when_source_after_byte"] = "'Speed'",
        ["pack_split_times_count_after_byte"] = "'Pt'",
        ["pack_split_times_count_skipped"] = "'Pt'",
        ["pack_lone_bytes_in_round"] = "'D'",
        ["pack_lone_utf8_under_times_over_budget"] = "'S'",
        ["pack_element_times_over_budget"] = "'K': the rounds would hold 1048577 slots, above the limit of 1048576 slots",
        ["pack_slots_over_limit"] = "'M0': the rounds would hold 1048580 slots, above the limit of 1048576 slots",
        ["pack_repeat_over_limit"] = "'K'",
        ["pack_split_count_zero_after_byte_list"] = "'Pt'",
        ["pack_flags_skipped_count_with_values"] = "'Pt'",
        ["pack_round_slots_over_limit"] = "'B': the rounds would hold 4 slots, above the limit of 3 slots",
        ["pack_round_slots_flags_over_limit"] = "the rounds would hold 6 slots, above the limit of 4 slots",
        ["pack_flags_short_list"] = "'V': 1 items, repeat count 2",
        ["pack_count_one_clear_when"] = "'Pt': the count C is 1 in the row, but no field wrote it",
        ["pack_bits_count_clear_when"] = "V: count 'C' is missing",
        ["pack_packed_count_clear_when"] = "V: count 'C' is missing",
        ["pack_sized_count_clear_when"] = "V: count 'C' is missing",
        ["pack_novalue_count_clear_when_bits"] = NoValueRule("V"),
        ["pack_novalue_count_clear_when_packed"] = NoValueRule("V"),
        ["pack_novalue_count_clear_when_sized"] = NoValueRule("V"),
        ["pack_element_times_over_bytes_budget"] = "'S': the packet would be 16777233 bytes, above the limit of 16777216 bytes",
    };

    // Row 56: a count above 0 for a member with no value, refused where the clear bit is found (not "count 'C' is missing").
    private static string NoValueRule(string member) =>
        $"'{member}': the count C is 3 in the row, but no field wrote it (the when that holds it is clear), so the member reads nothing";

    public static IEnumerable<object[]> RunCases() =>
        HostileVectorTests.Cases("pack").Where(p => Packs.ContainsKey(p[0])).Select(p => new object[] { p[0], p[2], p[3] });

    [Fact]
    public void EveryPackCase_HasACSharpScheme()
    {
        // Arrange
        var ids = HostileVectorTests.Cases("pack").Select(parts => parts[0]).ToList();

        // Act
        var unclaimed = ids.Where(id => !Packs.ContainsKey(id)).ToList();
        var stale = Packs.Keys.Where(id => !ids.Contains(id)).ToList();

        // Assert
        Assert.NotEmpty(ids);
        Assert.Empty(unclaimed);
        Assert.Empty(stale);
    }

    [Theory]
    [MemberData(nameof(RunCases))]
    public void PackCase_ReturnsTheBytesOrRefuses(string id, string expected, string hex) =>
        CheckPackCase(id, expected, hex, NamedMember);

    // AZ-2418 AC-1: the rule table is part of the check, so a wrong entry must fail the loader naming the case.
    [Fact]
    public void WrongRuleEntry_FailsTheLoaderNamingTheCase()
    {
        // Arrange (a refusal that is real, with a rule that names some other message)
        var wrong = new Dictionary<string, string>(NamedMember)
        {
            ["pack_times_count_over_limit"] = "'NoSuchMember'",
            ["pack_novalue_count_clear_when_bits"] = "'V': a rule this refusal does not carry",
        };

        // Act
        var failedCount = Record.Exception(() => CheckPackCase("pack_times_count_over_limit", "pack_error", "-", wrong));
        var failedNoValue = Record.Exception(() => CheckPackCase("pack_novalue_count_clear_when_bits", "pack_error", "-", wrong));

        // Assert
        Assert.Contains("pack_times_count_over_limit: refused by another rule", Assert.IsAssignableFrom<Xunit.Sdk.XunitException>(failedCount).Message);
        Assert.Contains("pack_novalue_count_clear_when_bits: refused by another rule", Assert.IsAssignableFrom<Xunit.Sdk.XunitException>(failedNoValue).Message);
    }

    [Fact]
    public void WrongBytes_FailTheLoader()
    {
        // Act (the real case packs 0102010500)
        var failed = Record.Exception(() => CheckPackCase("pack_times_short_list_flags", "bytes", "0102010501", NamedMember));

        // Assert
        Assert.IsAssignableFrom<Xunit.Sdk.XunitException>(failed);
    }

    private static void CheckPackCase(string id, string expected, string hex, IReadOnlyDictionary<string, string> rules)
    {
        // Arrange
        var pack = Packs[id];

        // Act
        string? packed = null;
        var refused = Record.Exception(() => packed = Convert.ToHexString(pack()).ToLowerInvariant());

        // Assert
        if (expected == "bytes")
        {
            Assert.Null(refused);
            Assert.Equal(hex, packed);
        }
        else
        {
            Assert.Equal("pack_error", expected);
            var error = Assert.IsType<ArgumentException>(refused);
            if (rules.TryGetValue(id, out var member))
                Assert.True(error.Message.Contains(member, StringComparison.Ordinal), $"{id}: refused by another rule: {error.Message}");
            Assert.Null(packed);
        }
    }
}
