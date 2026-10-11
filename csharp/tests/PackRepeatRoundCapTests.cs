using Packbin;
using static Packbin.Tests.Budget;

namespace Packbin.Tests;

// AZ-2355: pack refuses a repeat whose list is longer than maxRounds, before any round, naming the first member whose
// list passes the limit, so pack never writes a packet its own unpack refuses. Rows 1 to 10 of the AZ-2355 table in
// _docs/03_implementation/reference_loop20_budget.md.
public class PackRepeatRoundCapTests
{
    private sealed class Bag
    {
        public List<object?>? Items { get; set; }
    }

    private sealed class Mixed
    {
        public byte M { get; set; }
        public byte K { get; set; }
    }

    private static Scheme<BudgetRow> RepeatK(int maxRounds = 65_535) =>
        new Scheme<BudgetRow>(1, Field.Repeat(0, Field.U8<BudgetRow>(0, x => x.K))).WithLimits(maxRounds);

    private static string Words(string member, int count, int limit) =>
        $"'{member}': the repeat count is {count}, above the limit of {limit} rounds";

    private static Dictionary<string, object?> Ks(int count) => Row(("K", Repeated((byte)7, count)));

    private static Dictionary<string, object?> OneToFour() => Row(("K", new object?[] { (byte)1, (byte)2, (byte)3, (byte)4 }));

    [Fact]
    public void Ac1_Pack_RepeatListOverTheLimit_IsRefusedNamingTheMember()
    {
        // Arrange
        var scheme = RepeatK();

        // Act
        var error = Refused(scheme, Ks(65_536));

        // Assert
        Assert.Equal(Words("K", 65_536, 65_535), error.Message);
    }

    [Fact]
    public void Ac2_Pack_RepeatListAtTheLimit_PacksAndRoundTrips()
    {
        // Arrange
        var scheme = RepeatK();

        // Act
        var raw = BinaryPacker.Pack(scheme, Ks(65_535));
        var read = BinaryPacker.Read(scheme, raw);
        var again = BinaryPacker.Pack(scheme, read.Values);

        // Assert
        Assert.Equal(65_536, raw.Length);
        Assert.Equal("01070707070707070707070707070707", Hex(raw, 0, 16));
        Assert.Equal(string.Concat(Enumerable.Repeat("07", 16)), Hex(raw, raw.Length - 16, 16));
        Assert.Null(read.Error);
        Assert.Equal(Hex(raw), Hex(again));
    }

    [Fact]
    public void Ac3_Pack_RepeatListWithARaisedLimit_Packs()
    {
        // Arrange
        var scheme = RepeatK(70_000);

        // Act
        var raw = BinaryPacker.Pack(scheme, Ks(70_000));

        // Assert
        Assert.Equal(70_001, raw.Length);
        Assert.Equal("01070707070707070707070707070707", Hex(raw, 0, 16));
        Assert.Equal(string.Concat(Enumerable.Repeat("07", 16)), Hex(raw, raw.Length - 16, 16));
    }

    [Fact]
    public void Pack_RepeatListOneOverALoweredLimit_IsRefused()
    {
        // Arrange
        var scheme = RepeatK(3);

        // Act
        var error = Refused(scheme, OneToFour());

        // Assert
        Assert.Equal(Words("K", 4, 3), error.Message);
    }

    [Fact]
    public void Pack_RepeatListAtALoweredLimit_Packs()
    {
        // Arrange
        var scheme = RepeatK(3);

        // Act
        var raw = BinaryPacker.Pack(scheme, Row(("K", new object?[] { (byte)1, (byte)2, (byte)3 })));

        // Assert
        Assert.Equal("01010203", Hex(raw));
    }

    [Fact]
    public void Pack_RepeatWithTwoMembers_NamesTheLongListNotTheFirstMember()
    {
        // Arrange
        var scheme = new Scheme<BudgetRow>(1,
            Field.Repeat(0, Field.U8<BudgetRow>(0, x => x.A), Field.U8<BudgetRow>(1, x => x.B))).WithLimits(3);

        // Act
        var error = Refused(scheme, Row(("A", (byte)1), ("B", new object?[] { (byte)1, (byte)2, (byte)3, (byte)4 })));

        // Assert
        Assert.Equal(Words("B", 4, 3), error.Message);
    }

    [Fact]
    public void Pack_RepeatInCombinedFlags_IsRefused()
    {
        // Arrange
        var scheme = new Scheme<BudgetRow>(1,
            Field.Flags(0, Field.Repeat(0, Field.U8<BudgetRow>(0, x => x.K)))).WithLimits(3);

        // Act
        var error = Refused(scheme, OneToFour());

        // Assert
        Assert.Equal(Words("K", 4, 3), error.Message);
    }

    [Fact]
    public void Pack_RepeatInASplitFlagBit_IsRefused()
    {
        // Arrange
        var flagByte = Field.FlagByte();
        var scheme = new Scheme<BudgetRow>(1,
            flagByte, flagByte.Bit(Field.Repeat(0, Field.U8<BudgetRow>(0, x => x.K)))).WithLimits(3);

        // Act
        var error = Refused(scheme, OneToFour());

        // Assert
        Assert.Equal(Words("K", 4, 3), error.Message);
    }

    [Fact]
    public void Pack_RepeatUnderAWhen_IsRefused()
    {
        // Arrange
        var scheme = new Scheme<Mixed>(1,
            Field.U8<Mixed>(0, x => x.M),
            Field.When(1, Condition.Eq(0, 1), Field.Repeat(1, Field.U8<Mixed>(1, x => x.K)))).WithLimits(3);
        var values = Row(("M", (byte)1), ("K", new object?[] { (byte)1, (byte)2, (byte)3, (byte)4 }));

        // Act
        var error = Refused(scheme, values);

        // Assert
        Assert.Equal(Words("K", 4, 3), error.Message);
    }

    [Fact]
    public void Pack_RepeatInAListElement_IsRefused()
    {
        // Arrange
        var scheme = new Scheme<Bag>(1,
            Field.List((Bag x) => x.Items,
                Field.Group(0, (BudgetRow e) => e.G, Field.Repeat(0, Field.U8<BudgetRow>(0, e => e.K))))).WithLimits(3);
        var item = new Dictionary<string, object?> { ["K"] = new object?[] { (byte)1, (byte)2, (byte)3, (byte)4 } };

        // Act
        var error = Refused(scheme, new Dictionary<string, object?> { ["Items"] = new List<object?> { item } });

        // Assert
        Assert.Equal(Words("K", 4, 3), error.Message);
    }
}
