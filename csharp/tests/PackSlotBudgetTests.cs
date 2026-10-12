using Packbin;
using static Packbin.Tests.Budget;

namespace Packbin.Tests;

// AZ-2354: pack charges maxSlots per round with the width unpack charges, before any byte of the round, and checks the
// limits in order (rounds, then per round slots before bytes). Rows 14 to 25 of
// _docs/03_implementation/reference_loop20_budget.md.
public class PackSlotBudgetTests
{
    private sealed class Bag
    {
        public List<object?>? Items { get; set; }
    }

    private static Scheme<BudgetRow> CountedTimes(int maxRounds = 65_535, long maxSlots = 1_048_576, long maxBytes = 16_777_216) =>
        new Scheme<BudgetRow>(1,
            Field.U32<BudgetRow>(0, x => x.N),
            Field.Times(1, 0, Field.U8<BudgetRow>(1, x => x.K))).WithLimits(maxRounds, maxSlots, maxBytes);

    private static Scheme<Bag> Elements(long maxSlots) =>
        new Scheme<Bag>(1,
            Field.List((Bag x) => x.Items,
                Field.Group(0, (BudgetItem e) => e.Mark,
                    Field.U8<BudgetItem>(0, e => e.N),
                    Field.Times(1, 0, Field.U8<BudgetItem>(1, e => e.K))))).WithLimits(maxSlots: maxSlots);

    private static Scheme<BudgetRow> GroupInRepeat(long maxSlots) =>
        new Scheme<BudgetRow>(1,
            Field.Repeat(0,
                Field.U8<BudgetRow>(0, x => x.A),
                Field.Group(1, (BudgetRow x) => x.G, Field.U8<BudgetRow>(1, x => x.B)))).WithLimits(maxSlots: maxSlots);

    private static Dictionary<string, object?> Item(byte n, byte k) =>
        new() { ["N"] = n, ["K"] = k };

    private static string Slots(long slots, long limit, string member) =>
        $"'{member}': the rounds would hold {slots} slots, above the limit of {limit} slots";

    [Fact]
    public void Ac4_Pack_RoundOf65NamesTimes65535_IsRefusedAtTheRoundThatPassesTheLimit()
    {
        // Arrange
        var scheme = WideRound();

        // Act (16 131 rounds of 65 slots are charged, 1 048 515 bytes are written)
        var error = Refused(scheme, WideRow(65_535));

        // Assert
        Assert.Equal(Slots(1_048_580, 1_048_576, "M0"), error.Message);
    }

    [Fact]
    public void Ac4_Pack_RoundOf65NamesWithRaisedSlots_PacksAndUnpacks()
    {
        // Arrange
        var scheme = WideRound().WithLimits(maxSlots: 4_259_775);

        // Act
        var raw = BinaryPacker.Pack(scheme, WideRow(65_535));
        var read = BinaryPacker.Read(scheme, raw);

        // Assert
        Assert.Equal(4_259_780, raw.Length);
        Assert.Equal("01ffff00000101010101010101010101", Hex(raw, 0, 16));
        Assert.Equal(string.Concat(Enumerable.Repeat("01", 16)), Hex(raw, raw.Length - 16, 16));
        Assert.Null(read.Error);
        Assert.All(Enumerable.Range(0, 65), i => Assert.Equal(65_535, ((List<object?>)read.Values[$"M{i}"]!).Count));
    }

    [Fact]
    public void Ac4_Unpack_OfThePackedRoundAtTheDefault_RefusesAtTheSameRoundPackDid()
    {
        // Arrange
        var raw = BinaryPacker.Pack(WideRound().WithLimits(maxSlots: 4_259_775), WideRow(65_535));

        // Act
        var read = BinaryPacker.Read(WideRound(), raw);

        // Assert (C# names the failing field `times`, as it has since AZ-2329)
        var refused = Assert.IsType<ShortPacket>(read.Error);
        Assert.Equal(3_211_260, refused.Left);
    }

    // AZ-2415 (F10): 65 535 elements of `u32 n; times(n) { 64 names }` with n = 1, 4 194 240 slots in 4 259 778 bytes.
    private static Scheme<Bag> Cheapest() =>
        new(1, Field.List((Bag x) => x.Items,
            Field.Group(0, (BudgetWide e) => e.Mark,
                Field.U32<BudgetWide>(0, e => e.N),
                Field.Times(1, 0, [.. Enumerable.Range(0, 64).Select(WideMember)]))));

    private static byte[] CheapestPacket()
    {
        var raw = new byte[3 + 68 * 65_535];
        raw[0] = 1;
        raw[1] = 0xff;
        raw[2] = 0xff;
        for (var item = 0; item < 65_535; item++)
        {
            var at = 3 + 68 * item;
            raw[at] = 1;
            Array.Fill(raw, (byte)1, at + 4, 64);
        }
        return raw;
    }

    [Fact]
    public void Ac2_Unpack_CheapestBodyPacketAtTheDefault_IsRefusedAtTheSlotLimit()
    {
        // Act
        var read = BinaryPacker.Read(Cheapest(), CheapestPacket());

        // Assert (16 384 elements hold 1 048 576 slots; the 16 385th is refused after its u32 count is read)
        var refused = Assert.IsType<ShortPacket>(read.Error);
        Assert.Equal(CheapestPacket().Length - 3 - 68 * 16_384 - 4, refused.Left);
    }

    [Fact]
    public void Ac3_Unpack_CheapestBodyPacketWithTheLimitRaised_Unpacks()
    {
        // Act
        var read = BinaryPacker.Read(Cheapest().WithLimits(maxSlots: 4_194_304), CheapestPacket());

        // Assert
        Assert.Null(read.Error);
        Assert.Equal(65_535, ((List<object?>)read.Values["Items"]!).Count);
    }

    [Fact]
    public void Order_Pack_RowAtBothLimits_Packs()
    {
        // Arrange
        var scheme = CountedTimes(maxSlots: 3, maxBytes: 8);

        // Act
        var raw = BinaryPacker.Pack(scheme, Typed(("N", 3u), ("K", 7)));

        // Assert
        Assert.Equal("0103000000070707", Hex(raw));
    }

    [Fact]
    public void Order_Pack_RoundThatPassesSlotsAndBytes_RaisesTheSlotError()
    {
        // Arrange
        var scheme = CountedTimes(maxSlots: 3, maxBytes: 8);

        // Act
        var error = Refused(scheme, Typed(("N", 10u), ("K", 7)));

        // Assert
        Assert.Equal(Slots(4, 3, "K"), error.Message);
    }

    [Fact]
    public void Order_Pack_BytesRunOutBeforeSlots_RaisesTheByteError()
    {
        // Arrange
        var scheme = CountedTimes(maxSlots: 3, maxBytes: 7);

        // Act
        var error = Refused(scheme, Typed(("N", 10u), ("K", 7)));

        // Assert
        Assert.Equal("'K': the packet would be 8 bytes, above the limit of 7 bytes", error.Message);
    }

    [Fact]
    public void Order_Pack_RoundsLimitComesBeforeAnyRound()
    {
        // Arrange
        var scheme = CountedTimes(maxRounds: 5, maxSlots: 3, maxBytes: 8);

        // Act
        var error = Refused(scheme, Typed(("N", 10u), ("K", 7)));

        // Assert
        Assert.Equal("'K': the times count is 10, above the limit of 5 rounds", error.Message);
    }

    [Fact]
    public void Order_Pack_CountFieldPassingTheBytesIsRefusedBeforeTheTimes()
    {
        // Arrange
        var scheme = CountedTimes(maxRounds: 5, maxSlots: 3, maxBytes: 4);

        // Act
        var error = Refused(scheme, Typed(("N", 10u), ("K", 7)));

        // Assert
        Assert.Equal("'N': the packet would be 5 bytes, above the limit of 4 bytes", error.Message);
    }

    [Fact]
    public void Scope_Pack_SlotsAddUpAcrossTheElementsOfAList()
    {
        // Arrange
        var scheme = Elements(5);
        var values = new Dictionary<string, object?> { ["Items"] = new List<object?> { Item(3, 1), Item(3, 2) } };

        // Act
        var error = Refused(scheme, values);

        // Assert
        Assert.Equal(Slots(6, 5, "K"), error.Message);
    }

    [Fact]
    public void Scope_Pack_FiveSlotsAcrossTheElements_Pack()
    {
        // Arrange
        var scheme = Elements(5);
        var values = new Dictionary<string, object?> { ["Items"] = new List<object?> { Item(3, 1), Item(2, 2) } };

        // Act
        var raw = BinaryPacker.Pack(scheme, values);

        // Assert
        Assert.Equal("01020003010101020202", Hex(raw));
    }

    [Fact]
    public void Width_Pack_GroupNameIsNotCharged_SoTwoSlotsARoundPack()
    {
        // Arrange
        var scheme = GroupInRepeat(5);
        var values = Row(("A", new object?[] { (byte)1, (byte)2 }), ("B", new object?[] { (byte)3, (byte)4 }));

        // Act
        var raw = BinaryPacker.Pack(scheme, values);

        // Assert
        Assert.Equal("0101030204", Hex(raw));
    }

    [Fact]
    public void Width_Pack_ThreeRoundsOfTwoSlots_AreRefusedNamingTheFirstMember()
    {
        // Arrange
        var scheme = GroupInRepeat(5);
        var values = Row(("A", new object?[] { (byte)1, (byte)2, (byte)3 }), ("B", new object?[] { (byte)3, (byte)4, (byte)5 }));

        // Act
        var error = Refused(scheme, values);

        // Assert
        Assert.Equal(Slots(6, 5, "A"), error.Message);
    }

    [Fact]
    public void Ac6_Pack_RowsUnderBothLimits_KeepTheirBytes()
    {
        // Arrange
        var scheme = CountedTimes();

        // Act
        var raw = BinaryPacker.Pack(scheme, Typed(("N", 3u), ("K", 7)));

        // Assert
        Assert.Equal("0103000000070707", Hex(raw));
    }
}
