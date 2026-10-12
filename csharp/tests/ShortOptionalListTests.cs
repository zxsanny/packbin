using Packbin;

namespace Packbin.Tests;

// AZ-2383 (U3): in a `repeat`, a non-empty list under a member a flag bit can leave absent that is shorter than the
// rounds is refused before any round (rows 27 to 39 of _docs/03_implementation/reference_loop21_slots.md). `times` keeps
// accepting it (AZ-2248), and so does a member under a `when` outside `flags`.
public class ShortOptionalListTests
{
    internal sealed class Row
    {
        public byte W { get; set; }
        public byte C { get; set; }
        public byte K { get; set; }
        public byte? V { get; set; }
        public byte? A { get; set; }
        public byte? B { get; set; }
        public bool? On { get; set; }
        public bool? G { get; set; }
        public int P { get; set; }
        public int Q { get; set; }
    }

    private static string Hex(byte[] raw) => Convert.ToHexString(raw).ToLowerInvariant();

    private static object?[] L(params object?[] items) => items;

    private static Dictionary<string, object?> Dict(params (string Name, object? Value)[] items) =>
        items.ToDictionary(item => item.Name, item => item.Value);

    private static string Short(string member, int items, int rounds) =>
        $"'{member}': {items} items, repeat count {rounds}; give one entry per round, null where the member is absent";

    private static Scheme<Row> FlagsValue() => new(1,
        Field.Repeat(0, Field.U8<Row>(0, x => x.W), Field.Flags(1, Field.U8<Row>(1, x => x.V))));

    [Fact]
    public void Ac1_Repeat_ShortListUnderFlags_IsRefusedNamingTheMember()
    {
        // Arrange (row 27: this packed 010101050200 before)
        var values = Dict(("W", L((byte)1, (byte)2)), ("V", L((byte)5)));

        // Act
        var error = Budget.Refused(FlagsValue(), values);

        // Assert
        Assert.Equal(Short("V", 1, 2), error.Message);
    }

    [Fact]
    public void Ac1_Repeat_ShortListAmongThreeRounds_NamesItsLength()
    {
        // Arrange (row 28)
        var values = Dict(("W", L((byte)1, (byte)2, (byte)3)), ("V", L((byte)5, null)));

        // Act
        var error = Budget.Refused(FlagsValue(), values);

        // Assert
        Assert.Equal(Short("V", 2, 3), error.Message);
    }

    [Fact]
    public void Ac2_Repeat_ListWithNullEntryForTheAbsentRound_PacksTheOldBytes()
    {
        // Arrange (row 29)
        var values = Dict(("W", L((byte)1, (byte)2)), ("V", L((byte)5, null)));

        // Act
        var raw = BinaryPacker.Pack(FlagsValue(), values);

        // Assert
        Assert.Equal("010101050200", Hex(raw));
    }

    [Fact]
    public void Ac2_Repeat_FullListNoListEmptyListAndLoneValue_PackAsBefore()
    {
        // Arrange (row 30)
        var w = L((byte)1, (byte)2);
        var rows = new[]
        {
            Dict(("W", w), ("V", L((byte)5, (byte)6))),
            Dict(("W", w)),
            Dict(("W", w), ("V", L())),
            Dict(("W", w), ("V", (byte)5)),
        };

        // Act
        var hex = rows.Select(row => Hex(BinaryPacker.Pack(FlagsValue(), row)));

        // Assert
        Assert.Equal(["01010105020106", "0101000200", "0101000200", "01010105020105"], hex);
    }

    [Fact]
    public void Ac2_Repeat_ShortListOfARequiredMember_StaysMissingTheMember()
    {
        // Arrange (row 31)
        var values = Dict(("W", L((byte)1)), ("V", L((byte)5, (byte)6)));

        // Act
        var error = Budget.Refused(FlagsValue(), values);

        // Assert
        Assert.StartsWith("'W'", error.Message, StringComparison.Ordinal);
        Assert.Contains("has no value", error.Message, StringComparison.Ordinal);
    }

    [Fact]
    public void Ac1_Repeat_ShortBoolUnderFlags_IsRefusedAndNullEntryPacks()
    {
        // Arrange (row 32)
        var scheme = new Scheme<Row>(1,
            Field.Repeat(0, Field.U8<Row>(0, x => x.W), Field.Flags(1, Field.Bool<Row>(1, x => x.On))));

        // Act
        var error = Budget.Refused(scheme, Dict(("W", L((byte)1, (byte)2)), ("On", L(true))));
        var raw = BinaryPacker.Pack(scheme, Dict(("W", L((byte)1, (byte)2)), ("On", L(true, null))));

        // Assert
        Assert.Equal((Short("On", 1, 2), "0101010200"), (error.Message, Hex(raw)));
    }

    [Fact]
    public void Ac1_Repeat_ShortListInASplitFlagBit_IsRefusedAndNullEntryPacks()
    {
        // Arrange (row 33)
        var m = Field.FlagByte();
        var scheme = new Scheme<Row>(1, Field.Repeat(0, Field.U8<Row>(0, x => x.W), m, m.Bit(Field.U8<Row>(1, x => x.V))));

        // Act
        var error = Budget.Refused(scheme, Dict(("W", L((byte)1, (byte)2)), ("V", L((byte)5))));
        var raw = BinaryPacker.Pack(scheme, Dict(("W", L((byte)1, (byte)2)), ("V", L((byte)5, null))));

        // Assert
        Assert.Equal((Short("V", 1, 2), "010101050200"), (error.Message, Hex(raw)));
    }

    [Fact]
    public void Ac1_Repeat_ShortListOfAGroupMember_IsRefused()
    {
        // Arrange (row 34)
        var scheme = new Scheme<Row>(1,
            Field.Repeat(0, Field.U8<Row>(0, x => x.W),
                Field.Flags(1, Field.Group(1, (Row x) => x.G, Field.U8<Row>(1, x => x.V)))));

        // Act
        var error = Budget.Refused(scheme, Dict(("W", L((byte)1, (byte)2)), ("V", L((byte)5))));

        // Assert
        Assert.Equal(Short("V", 1, 2), error.Message);
    }

    [Fact]
    public void Ac1_Repeat_ShortListOfAU2Slot_NamesTheFirstShortSlot()
    {
        // Arrange (row 35)
        var scheme = new Scheme<Row>(1,
            Field.Repeat(0, Field.U8<Row>(0, x => x.W), Field.Flags(1, Field.U2<Row>((1, x => x.P), (2, x => x.Q)))));

        // Act
        var error = Budget.Refused(scheme, Dict(("W", L((byte)1, (byte)2)), ("P", L(1)), ("Q", L(2, 3))));

        // Assert
        Assert.Equal(Short("P", 1, 2), error.Message);
    }

    [Fact]
    public void Ac1_Repeat_ShortListOfAWhenUnderFlags_IsRefused()
    {
        // Arrange (row 36)
        var scheme = new Scheme<Row>(1,
            Field.Repeat(0, Field.U8<Row>(0, x => x.W),
                Field.Flags(1, Field.When(1, Condition.Eq(0, 1), Field.U8<Row>(1, x => x.V)))));

        // Act
        var error = Budget.Refused(scheme, Dict(("W", L((byte)1, (byte)1)), ("V", L((byte)5))));

        // Assert
        Assert.Equal(Short("V", 1, 2), error.Message);
    }

    [Fact]
    public void Ac1_Repeat_FlagsOnlyRound_NamesTheFirstShortListInRoundOrder()
    {
        // Arrange (row 37)
        var scheme = new Scheme<Row>(1,
            Field.Repeat(0, Field.Flags(0, Field.U8<Row>(0, x => x.A), Field.U8<Row>(1, x => x.B))));

        // Act
        var first = Budget.Refused(scheme, Dict(("A", L((byte)1)), ("B", L((byte)5, (byte)6))));
        var second = Budget.Refused(scheme, Dict(("A", L((byte)1, (byte)2, (byte)3)), ("B", L((byte)5, (byte)6))));

        // Assert
        Assert.Equal((Short("A", 1, 2), Short("B", 2, 3)), (first.Message, second.Message));
    }

    [Fact]
    public void Ac2_Repeat_ShortListUnderAWhenOutsideFlags_PacksAsBefore()
    {
        // Arrange (row 38)
        var scheme = new Scheme<Row>(1,
            Field.Repeat(0, Field.U8<Row>(0, x => x.K), Field.When(1, Condition.Eq(0, 1), Field.U8<Row>(1, x => x.V))));

        // Act
        var raw = BinaryPacker.Pack(scheme, Dict(("K", L((byte)1, (byte)2)), ("V", L((byte)9))));

        // Assert
        Assert.Equal("01010902", Hex(raw));
    }

    [Fact]
    public void Ac2_Times_ShortListUnderFlags_StillReadsAsAbsentForTheRoundsItDoesNotReach()
    {
        // Arrange (row 39)
        var scheme = new Scheme<Row>(1,
            Field.U8<Row>(0, x => x.C), Field.Times(1, 0, Field.Flags(1, Field.U8<Row>(1, x => x.V))));

        // Act
        var raw = BinaryPacker.Pack(scheme, Dict(("C", (byte)2), ("V", L((byte)5))));

        // Assert
        Assert.Equal("0102010500", Hex(raw));
    }

    [Fact]
    public void Ac2_Repeat_UnpackedRowRepacks_BecauseEveryNameHoldsOneEntryPerRound()
    {
        // Arrange
        var scheme = FlagsValue();
        var read = BinaryPacker.Read(scheme, Convert.FromHexString("010101050200"));

        // Act
        var again = BinaryPacker.Pack(scheme, read.Values);

        // Assert
        Assert.Equal("010101050200", Hex(again));
    }
}
