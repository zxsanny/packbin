using Packbin;

namespace Packbin.Tests;

// The pack stage of fixtures/hostile/cases.txt (AZ-2194): a case expects the packet bytes or a refusal that returns no
// bytes. The file holds outcomes only (ADR-001), so each case id maps to a hand-written C# scheme and dictionary row,
// written from fixtures/hostile/README.md. C# runs all five cases through dictionary rows (typed rows are statically
// typed, so they cannot hold an out-of-range integer or a missing value).
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

    private static Dictionary<string, object?> Row(params (string Name, object? Value)[] values) =>
        values.ToDictionary(v => v.Name, v => v.Value);

    private static Scheme<PackRow> TimesScheme() => new(1,
        Field.U8<PackRow>(0, x => x.A),
        Field.Times(1, 0, Field.U8<PackRow>(1, x => x.X)));

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
            Assert.IsType<ArgumentException>(refused);
            Assert.Null(packed);
        }
    }
}
