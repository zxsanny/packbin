using Packbin;
using static Packbin.Tests.Budget;

namespace Packbin.Tests;

// The pack stage of fixtures/hostile/cases.txt (AZ-2194): a case expects the packet bytes or a refusal that returns no
// bytes. The file holds outcomes only (ADR-001), so each case id maps to a hand-written C# scheme and dictionary row,
// written from fixtures/hostile/README.md. C# runs every case through dictionary rows (typed rows are statically
// typed, so they cannot hold an out-of-range integer, a missing value or a lone buffer in a round).
public class HostilePackVectorTests
{
    private sealed class PackRow
    {
        public byte A { get; set; }
        public byte B { get; set; }
        public byte X { get; set; }
        public bool? On { get; set; }
        public byte? N { get; set; }
    }

    private sealed class WideRow
    {
        public uint N { get; set; }
        public byte? X { get; set; }
    }

    private sealed class SplitRow
    {
        public byte Mode { get; set; }
        public byte Sel { get; set; }
        public byte? N { get; set; }
        public byte? Speed { get; set; }
        public byte? Pt { get; set; }
        public ushort? Heading { get; set; }
    }

    private sealed class BufferRow
    {
        public byte N { get; set; }
        public byte[] D { get; set; } = [];
    }

    private static Dictionary<string, object?> Row(params (string Name, object? Value)[] values) =>
        values.ToDictionary(v => v.Name, v => v.Value);

    private static Scheme<PackRow> TimesScheme() => new(1,
        Field.U8<PackRow>(0, x => x.A),
        Field.Times(1, 0, Field.U8<PackRow>(1, x => x.X)));

    // Split-form flag byte: the byte is written first when the source or count comes after it.
    private static Scheme<SplitRow> SplitScheme(string shape)
    {
        var m = Field.FlagByte();
        return shape switch
        {
            "when_after" => new Scheme<SplitRow>(1, m,
                Field.U8<SplitRow>(0, x => x.Mode),
                m.Bit(Field.When(1, Condition.Eq(0, 1), Field.U8<SplitRow>(1, x => x.Speed)))),
            "times_after" => new Scheme<SplitRow>(1, m,
                Field.U8<SplitRow>(0, x => x.N),
                m.Bit(Field.Times(1, 0, Field.U8<SplitRow>(1, x => x.Pt)))),
            "times_skipped" => new Scheme<SplitRow>(1,
                Field.U8<SplitRow>(0, x => x.Sel),
                m,
                Field.When(1, Condition.Eq(0, 1), Field.U8<SplitRow>(1, x => x.N)),
                m.Bit(Field.Times(2, 1, Field.U8<SplitRow>(2, x => x.Pt)))),
            _ => new Scheme<SplitRow>(1,
                Field.U8<SplitRow>(0, x => x.Mode),
                m,
                m.Bit(Field.When(1, Condition.Eq(0, 1), Field.U8<SplitRow>(1, x => x.Speed))),
                m.Bit(Field.U16<SplitRow>(2, x => x.Heading))),
        };
    }

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
    };

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
        ["pack_element_times_over_budget"] = "'K'",
        ["pack_slots_over_limit"] = "'M0'",
        ["pack_repeat_over_limit"] = "'K'",
        ["pack_split_count_zero_after_byte_list"] = "'Pt'",
        ["pack_flags_skipped_count_with_values"] = "'Pt'",
    };

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
    public void PackCase_ReturnsTheBytesOrRefuses(string id, string expected, string hex)
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
            if (NamedMember.TryGetValue(id, out var member))
                Assert.True(error.Message.Contains(member, StringComparison.Ordinal), $"{id}: refused by another rule: {error.Message}");
            Assert.Null(packed);
        }
    }
}
