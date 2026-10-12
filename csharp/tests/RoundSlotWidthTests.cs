using Packbin;

namespace Packbin.Tests;

// AZ-2382 (U2): a round charges `maxSlots` the width the TypeScript reference gives it (rows 1 to 14 of
// _docs/03_implementation/reference_loop21_slots.md): the distinct names it can hold, an empty group's name and each u2
// slot name included, a non-empty group, `flags` and a flag byte not. Each row is a repeat of the body packed at
// maxSlots = 2W (two rounds), refused for a third round, written at 3W, and the 3-round packet unpacked at 2W.
public class RoundSlotWidthTests
{
    internal sealed class SlotRow
    {
        public byte A { get; set; }
        public byte B { get; set; }
        public byte C { get; set; }
        public byte M { get; set; }
        public byte K { get; set; }
        public byte N { get; set; }
        public byte V { get; set; }
        public bool? G { get; set; }
        public bool? H { get; set; }
        public bool? On { get; set; }
        public int P { get; set; }
        public int Q { get; set; }
        public int R { get; set; }
        public List<List<object?>>? L { get; set; }
        public List<Dictionary<string, object?>>? D { get; set; }
        public byte[]? Bb { get; set; }
        public byte[]? S { get; set; }
        public SlotNest? Inner { get; set; }
    }

    internal sealed class SlotNest
    {
        public byte B { get; set; }
    }

    internal sealed class SlotItem
    {
        public byte E { get; set; }
        public byte N { get; set; }
    }

    internal sealed record Case(
        string Name, int Width, Func<long, Scheme<SlotRow>> Scheme, Func<int, Dictionary<string, object?>> Values,
        string Hex2, string Hex3, string Member, int Left);

    private static object?[] L(params object?[] items) => items;

    private static object?[] Bytes(params string[] hex) => [.. hex.Select(h => (object?)Convert.FromHexString(h))];

    // The first `rounds` entries of each list, as the dictionary form of one row.
    private static Dictionary<string, object?> Row(int rounds, params (string Name, object?[] List)[] lists) =>
        lists.ToDictionary(l => l.Name, l => (object?)l.List.Take(rounds).ToArray());

    private static string Hex(byte[] raw) => Convert.ToHexString(raw).ToLowerInvariant();

    private static Scheme<SlotRow> Repeat(long maxSlots, params Field[] body) =>
        new Scheme<SlotRow>(1, Field.Repeat(0, body)).WithLimits(maxSlots: maxSlots);

    private static Scheme<SlotRow> Counted(long maxSlots, params Field[] body) =>
        new Scheme<SlotRow>(1, Field.U8<SlotRow>(0, x => x.N), Field.Times(1, 0, body)).WithLimits(maxSlots: maxSlots);

    private static readonly Case[] Rows =
    [
        new("1 empty group, flag byte", 2,
            n => Repeat(n, Field.U8<SlotRow>(0, x => x.A), Field.Flags(1, Field.Group(1, (SlotRow x) => x.G))),
            r => Row(r, ("A", L((byte)1, (byte)2, (byte)3)), ("G", L(true, null, true))),
            "0101010200", "01010102000301", "A", 2),
        new("2 duplicate leaf names", 2,
            n => Repeat(n, Field.U8<SlotRow>(0, x => x.M),
                Field.When(1, Condition.Eq(0, 1), Field.U8<SlotRow>(1, x => x.K)),
                Field.When(2, Condition.Eq(0, 2), Field.U8<SlotRow>(2, x => x.K))),
            r => Row(r, ("M", L((byte)1, (byte)2, (byte)1)), ("K", L((byte)7, (byte)8, (byte)9))),
            "0101070208", "01010702080109", "M", 2),
        new("3 combined flags", 2,
            n => Repeat(n, Field.Flags(0, Field.Bool<SlotRow>(0, x => x.On), Field.U8<SlotRow>(1, x => x.V))),
            r => Row(r, ("On", L(true, true, true)), ("V", L((byte)5, (byte)6, (byte)7))),
            "0103050306", "01030503060307", "On", 2),
        new("4 split bits and flag byte", 2,
            n =>
            {
                var m = Field.FlagByte();
                return Repeat(n, m, m.Bit(Field.U8<SlotRow>(0, x => x.A)), m.Bit(Field.U8<SlotRow>(1, x => x.B)));
            },
            r => Row(r, ("A", L((byte)1, (byte)2, (byte)3)), ("B", L((byte)4, (byte)5, (byte)6))),
            "01030104030205", "01030104030205030306", "A", 3),
        new("5 when clear in every round", 2,
            n => Repeat(n, Field.U8<SlotRow>(0, x => x.M), Field.When(1, Condition.Eq(0, 1), Field.U8<SlotRow>(1, x => x.K))),
            r => Row(r, ("M", L((byte)0, (byte)0, (byte)0))),
            "010000", "01000000", "M", 1),
        new("6 nested anchored groups", 3,
            n => Repeat(n, Field.U8<SlotRow>(0, x => x.A),
                Field.Group(1, (SlotRow x) => x.G, Field.U8<SlotRow>(1, x => x.B),
                    Field.Group(2, (SlotRow x) => x.H, Field.U8<SlotRow>(2, x => x.C)))),
            r => Row(r, ("A", L((byte)1, (byte)2, (byte)3)), ("B", L((byte)4, (byte)5, (byte)6)), ("C", L((byte)7, (byte)8, (byte)9))),
            "01010407020508", "01010407020508030609", "A", 3),
        new("8 u2 slots", 4,
            n => Repeat(n, Field.U8<SlotRow>(0, x => x.A), Field.U2<SlotRow>((1, x => x.P), (2, x => x.Q), (3, x => x.R))),
            r => Row(r, ("A", L((byte)1, (byte)2, (byte)3)), ("P", L(1, 1, 1)), ("Q", L(2, 2, 2)), ("R", L(3, 3, 3))),
            "0101390239", "01013902390339", "A", 2),
        new("9 list and dict names", 3,
            n => Repeat(n, Field.U8<SlotRow>(0, x => x.N),
                Field.List((SlotRow x) => x.L, Field.U8<SlotItem>(0, e => e.E)),
                Field.Dict((SlotRow x) => x.D, Field.U8<SlotItem>(0, e => e.E))),
            r => Row(r, ("N", L((byte)1, (byte)2, (byte)3)),
                ("L", L(L((byte)0, (byte)1), L((byte)1, (byte)2), L((byte)2, (byte)3))),
                ("D", L(new Dictionary<string, object?> { ["k"] = (byte)0 }, new Dictionary<string, object?> { ["k"] = (byte)1 },
                    new Dictionary<string, object?> { ["k"] = (byte)2 }))),
            "010102000001010001006b000202000102010001006b01", "010102000001010001006b000202000102010001006b010302000203010001006b02",
            "N", 11),
        new("10 bytes and sized names", 3,
            n => Repeat(n, Field.U8<SlotRow>(0, x => x.N), Field.Bytes<SlotRow>(1, x => x.Bb!, 2), Field.Sized<SlotRow>(2, x => x.S!, 0)),
            r => Row(r, ("N", L((byte)1, (byte)1, (byte)1)), ("Bb", Bytes("0000", "0101", "0202")), ("S", Bytes("09", "09", "09"))),
            "010100000901010109", "01010000090101010901020209", "N", 4),
    ];

    public static TheoryData<string> Names() => [.. Rows.Select(r => r.Name)];

    private static Case Of(string name) => Rows.Single(r => r.Name == name);

    [Theory]
    [MemberData(nameof(Names))]
    public void Ac1_Pack_TwoRoundsAtMaxSlotsOfTwiceTheWidth_WritesTheReferenceBytes(string name)
    {
        // Arrange
        var row = Of(name);

        // Act
        var raw = BinaryPacker.Pack(row.Scheme(2L * row.Width), row.Values(2));

        // Assert
        Assert.Equal(row.Hex2, Hex(raw));
    }

    [Theory]
    [MemberData(nameof(Names))]
    public void Ac1_Pack_ThirdRoundAtTwiceTheWidth_IsRefusedWithTheSlotsItWouldHold(string name)
    {
        // Arrange
        var row = Of(name);

        // Act
        var error = Budget.Refused(row.Scheme(2L * row.Width), row.Values(3));

        // Assert
        Assert.Equal($"'{row.Member}': the rounds would hold {3 * row.Width} slots, above the limit of {2 * row.Width} slots", error.Message);
    }

    [Theory]
    [MemberData(nameof(Names))]
    public void Ac1_Pack_ThreeRoundsAtThreeTimesTheWidth_WritesTheReferenceBytes(string name)
    {
        // Arrange
        var row = Of(name);

        // Act
        var raw = BinaryPacker.Pack(row.Scheme(3L * row.Width), row.Values(3));

        // Assert
        Assert.Equal(row.Hex3, Hex(raw));
    }

    [Theory]
    [MemberData(nameof(Names))]
    public void Ac1_Unpack_ThreeRoundPacketAtTwiceTheWidth_RefusesTheThirdRound(string name)
    {
        // Arrange
        var row = Of(name);

        // Act
        var read = BinaryPacker.Read(row.Scheme(2L * row.Width), Convert.FromHexString(row.Hex3));

        // Assert (C# names the refused field by the repeat, which has no name, so only the numbers are compared)
        var refused = Assert.IsType<ShortPacket>(read.Error);
        Assert.Equal(0, refused.Needed);
        Assert.Equal(row.Left, refused.Left);
    }

    [Theory]
    [MemberData(nameof(Names))]
    public void Ac2_Unpack_PacketPackWroteAtTheLimit_UnpacksAndRepacksToTheSameBytes(string name)
    {
        // Arrange
        var row = Of(name);
        var scheme = row.Scheme(2L * row.Width);

        // Act
        var read = BinaryPacker.Read(scheme, Convert.FromHexString(row.Hex2));
        var again = BinaryPacker.Pack(scheme, read.Values);

        // Assert
        Assert.Null(read.Error);
        Assert.Equal(row.Hex2, Hex(again));
    }

    // Row 7 (an unanchored group) is a nested row in C#, so it is typed: see RoundSlotWidthTypedTests.

    [Fact]
    public void Times_Row11_TwoRoundsOfTwoSlotsPackAtFour()
    {
        // Arrange
        var scheme = Counted(4,
            Field.U8<SlotRow>(1, x => x.M),
            Field.When(2, Condition.Eq(1, 1), Field.U8<SlotRow>(2, x => x.K)),
            Field.When(3, Condition.Eq(1, 2), Field.U8<SlotRow>(3, x => x.K)));
        var values = new Dictionary<string, object?>
        {
            ["N"] = (byte)2, ["M"] = L((byte)1, (byte)2), ["K"] = L((byte)7, (byte)8),
        };

        // Act
        var raw = BinaryPacker.Pack(scheme, values);

        // Assert
        Assert.Equal("010201070208", Hex(raw));
    }

    [Fact]
    public void Times_Row12_ThirdRoundIsRefused()
    {
        // Arrange
        var scheme = Counted(4,
            Field.U8<SlotRow>(1, x => x.M),
            Field.When(2, Condition.Eq(1, 1), Field.U8<SlotRow>(2, x => x.K)),
            Field.When(3, Condition.Eq(1, 2), Field.U8<SlotRow>(3, x => x.K)));
        var values = new Dictionary<string, object?>
        {
            ["N"] = (byte)3, ["M"] = L((byte)1, (byte)2, (byte)1), ["K"] = L((byte)7, (byte)8, (byte)9),
        };

        // Act
        var error = Budget.Refused(scheme, values);

        // Assert
        Assert.Equal("'M': the rounds would hold 6 slots, above the limit of 4 slots", error.Message);
    }

    private static Scheme<SlotRow> TimesThenRepeat(long maxSlots) =>
        new Scheme<SlotRow>(1,
            Field.U8<SlotRow>(0, x => x.N),
            Field.Times(1, 0, Field.U8<SlotRow>(1, x => x.A)),
            Field.Repeat(2, Field.U8<SlotRow>(2, x => x.B))).WithLimits(maxSlots: maxSlots);

    [Fact]
    public void Counter_Row13_TimesAndRepeatShareOneCounter_ThreeSlotsPackAtThree()
    {
        // Arrange
        var values = new Dictionary<string, object?> { ["N"] = (byte)1, ["A"] = L((byte)1), ["B"] = L((byte)2, (byte)3) };

        // Act
        var raw = BinaryPacker.Pack(TimesThenRepeat(3), values);

        // Assert
        Assert.Equal("0101010203", Hex(raw));
    }

    [Fact]
    public void Counter_Row14_TimesAndRepeatShareOneCounter_TheFourthSlotIsRefused()
    {
        // Arrange
        var values = new Dictionary<string, object?> { ["N"] = (byte)1, ["A"] = L((byte)1), ["B"] = L((byte)2, (byte)3, (byte)4) };

        // Act
        var error = Budget.Refused(TimesThenRepeat(3), values);

        // Assert
        Assert.Equal("'B': the rounds would hold 4 slots, above the limit of 3 slots", error.Message);
    }
}
