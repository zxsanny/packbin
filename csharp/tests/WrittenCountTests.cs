using Packbin;

namespace Packbin.Tests;

// A count is read from what pack wrote in its scope, as unpack reads it from what it read. A count whose field a `when`
// skipped is not there: pack throws naming it instead of returning bytes its own read rejects.
public class WrittenCountTests
{
    private sealed class CountRow
    {
        public byte P { get; set; }
        public byte? N { get; set; }
        public byte[] Data { get; set; } = [];
        public List<int>? Bits { get; set; }
        public List<int>? Kinds { get; set; }
        public byte? V { get; set; }
    }

    private static string Hex(byte[] raw) => Convert.ToHexString(raw).ToLowerInvariant();

    // U8 P; when(P == 0) { U8 N }; then a field counted by N.
    private static readonly Dictionary<string, Func<Scheme<CountRow>>> Counted = new()
    {
        { "sized", () => new Scheme<CountRow>(1,
            Field.U8<CountRow>(0, x => x.P),
            Field.When(1, Condition.Eq(0, 0), Field.U8<CountRow>(1, x => x.N)),
            Field.Sized<CountRow>(2, x => x.Data, 1)) },
        { "bits", () => new Scheme<CountRow>(1,
            Field.U8<CountRow>(0, x => x.P),
            Field.When(1, Condition.Eq(0, 0), Field.U8<CountRow>(1, x => x.N)),
            Field.Bits<CountRow>(2, x => x.Bits, 1)) },
        { "packed", () => new Scheme<CountRow>(1,
            Field.U8<CountRow>(0, x => x.P),
            Field.When(1, Condition.Eq(0, 0), Field.U8<CountRow>(1, x => x.N)),
            Field.Packed<CountRow>(2, 2, x => x.Kinds, 1)) },
        { "times", () => new Scheme<CountRow>(1,
            Field.U8<CountRow>(0, x => x.P),
            Field.When(1, Condition.Eq(0, 0), Field.U8<CountRow>(1, x => x.N)),
            Field.Times(2, 1, Field.U8<CountRow>(2, x => x.V))) },
    };

    private static Dictionary<string, object?> Row(byte p) => new()
    {
        ["P"] = p,
        ["N"] = (byte)2,
        ["Data"] = new byte[] { 9, 9 },
        ["Bits"] = new List<int> { 1, 0 },
        ["Kinds"] = new List<int> { 1, 2 },
        ["V"] = new object?[] { (byte)7, (byte)8 },
    };

    [Theory]
    [InlineData("sized")]
    [InlineData("bits")]
    [InlineData("packed")]
    [InlineData("times")]
    public void Pack_CountFieldSkippedByAWhen_ThrowsNamingTheCount(string kind)
    {
        // Arrange
        var scheme = Counted[kind]();

        // Act
        var refused = Record.Exception(() => BinaryPacker.Pack(scheme, Row(1)));

        // Assert
        var error = Assert.IsType<ArgumentException>(refused);
        Assert.Contains("count 'N' is missing", error.Message, StringComparison.Ordinal);
    }

    [Theory]
    [InlineData("sized", "0100020909")]
    [InlineData("bits", "01000201")]
    [InlineData("packed", "01000209")]
    [InlineData("times", "010002" + "0708")]
    public void Pack_CountFieldWrittenByAWhen_PacksAndReadsBack(string kind, string hex)
    {
        // Arrange
        var scheme = Counted[kind]();

        // Act
        var raw = BinaryPacker.Pack(scheme, Row(0));
        var got = BinaryPacker.Read(scheme, raw);

        // Assert
        Assert.Equal(hex, Hex(raw));
        Assert.Null(got.Error);
    }

    [Fact]
    public void Pack_CountWrittenInAnEarlierRound_DoesNotCountInThisOne()
    {
        // Arrange
        var scheme = new Scheme<CountRow>(1,
            Field.Repeat(0,
                Field.U8<CountRow>(0, x => x.P),
                Field.When(1, Condition.Eq(0, 1), Field.U8<CountRow>(1, x => x.N)),
                Field.Sized<CountRow>(2, x => x.Data, 1)));
        var values = new Dictionary<string, object?>
        {
            ["P"] = new object?[] { (byte)1, (byte)0 },
            ["N"] = new object?[] { (byte)2, (byte)2 },
            ["Data"] = new object?[] { new byte[] { 9, 9 }, new byte[] { 8, 8 } },
        };

        // Act
        var refused = Record.Exception(() => BinaryPacker.Pack(scheme, values));

        // Assert
        var error = Assert.IsType<ArgumentException>(refused);
        Assert.Contains("count 'N' is missing", error.Message, StringComparison.Ordinal);
    }

    [Fact]
    public void Pack_CountUnderASetFlagBit_PacksAndReadsBack()
    {
        // Arrange
        var scheme = new Scheme<CountRow>(1,
            Field.U8<CountRow>(0, x => x.P),
            Field.Flags(1, Field.U8<CountRow>(1, x => x.N)),
            Field.Sized<CountRow>(2, x => x.Data, 1));

        // Act
        var raw = BinaryPacker.Pack(scheme, Row(0));
        var got = BinaryPacker.Read(scheme, raw);

        // Assert
        Assert.Equal("010001020909", Hex(raw));
        Assert.Null(got.Error);
    }

    [Fact]
    public void Pack_CountUnderAClearFlagBit_ThrowsNamingTheCount()
    {
        // Arrange
        var scheme = new Scheme<CountRow>(1,
            Field.U8<CountRow>(0, x => x.P),
            Field.Flags(1, Field.U8<CountRow>(1, x => x.N)),
            Field.Sized<CountRow>(2, x => x.Data, 1));
        var values = Row(0);
        values.Remove("N");

        // Act
        var refused = Record.Exception(() => BinaryPacker.Pack(scheme, values));

        // Assert
        var error = Assert.IsType<ArgumentException>(refused);
        Assert.Contains("count 'N' is missing", error.Message, StringComparison.Ordinal);
    }
}
