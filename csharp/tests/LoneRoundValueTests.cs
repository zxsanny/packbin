using Packbin;

namespace Packbin.Tests;

// AZ-2182: in a repeat or times round a lone scalar goes to every round, and a lone byte run or list for a name that
// holds one per round is refused, because the pack would otherwise take its items for the rounds.
public class LoneRoundValueTests
{
    private sealed class Row
    {
        public byte X { get; set; }
        public byte Y { get; set; }
        public byte A { get; set; }
        public byte B { get; set; }
        public byte N { get; set; }
        public byte C { get; set; }
        public byte[] Raw { get; set; } = [];
        public byte[] Data { get; set; } = [];
        public List<int>? Segs { get; set; }
        public List<int>? Kinds { get; set; }
    }

    private static string Hex(byte[] raw) => Convert.ToHexString(raw).ToLowerInvariant();

    private static object?[] Rounds(params object?[] items) => items;

    private static Field[] Round(string kind, int first) => kind switch
    {
        "bytes" => [Field.Bytes<Row>(first, x => x.Raw, 2)],
        "sized" => [Field.U8<Row>(first, x => x.N), Field.Sized<Row>(first + 1, x => x.Data, first)],
        "bits" => [Field.U8<Row>(first, x => x.N), Field.Bits<Row>(first + 1, x => x.Segs, first)],
        "packed" => [Field.U8<Row>(first, x => x.N), Field.Packed<Row>(2, first + 1, x => x.Kinds, first)],
        _ => throw new ArgumentException(kind),
    };

    private static Scheme<Row> InRound(string kind, bool times) => times
        ? new Scheme<Row>(1, Field.U8<Row>(0, x => x.C), Field.Times(1, 0, Round(kind, 1)))
        : new Scheme<Row>(1, Field.Repeat(0, Round(kind, 0)));

    private static string Name(string kind) => kind switch
    {
        "bytes" => "Raw",
        "sized" => "Data",
        "bits" => "Segs",
        _ => "Kinds",
    };

    private static Row LoneTyped(string kind) => kind switch
    {
        "bytes" => new Row { C = 2, Raw = [1, 2] },
        "sized" => new Row { C = 2, N = 2, Data = [9, 9] },
        "bits" => new Row { C = 2, N = 2, Segs = [1, 0] },
        _ => new Row { C = 2, N = 2, Kinds = [1, 2] },
    };

    private static Dictionary<string, object?> LoneMap(string kind)
    {
        var row = LoneTyped(kind);
        return kind switch
        {
            "bytes" => new() { ["C"] = row.C, ["Raw"] = row.Raw },
            "sized" => new() { ["C"] = row.C, ["N"] = row.N, ["Data"] = row.Data },
            "bits" => new() { ["C"] = row.C, ["N"] = row.N, ["Segs"] = row.Segs },
            _ => new() { ["C"] = row.C, ["N"] = row.N, ["Kinds"] = row.Kinds },
        };
    }

    [Fact]
    public void Pack_LoneScalarWithAListInARepeat_GoesToEveryRound()
    {
        // Arrange
        var scheme = new Scheme<Row>(1, Field.Repeat(0, Field.U8<Row>(0, x => x.X), Field.U8<Row>(1, x => x.Y)));
        var values = new Dictionary<string, object?> { ["X"] = (byte)1, ["Y"] = Rounds((byte)4, (byte)5) };

        // Act
        var raw = BinaryPacker.Pack(scheme, values);

        // Assert
        Assert.Equal("0101040105", Hex(raw));
    }

    [Fact]
    public void Pack_LoneScalarWithAListInATimes_GoesToEveryRound()
    {
        // Arrange
        var scheme = new Scheme<Row>(1,
            Field.U8<Row>(0, x => x.N),
            Field.Times(1, 0, Field.U8<Row>(1, x => x.X), Field.U8<Row>(2, x => x.Y)));
        var values = new Dictionary<string, object?>
        {
            ["N"] = (byte)2, ["X"] = (byte)1, ["Y"] = Rounds((byte)4, (byte)5),
        };

        // Act
        var raw = BinaryPacker.Pack(scheme, values);

        // Assert
        Assert.Equal("010201040105", Hex(raw));
    }

    [Fact]
    public void Pack_LoneScalarsInATypedTimes_GoToEveryRound()
    {
        // Arrange
        var scheme = new Scheme<Row>(1, Field.U8<Row>(0, x => x.N), Field.Times(1, 0, Field.U8<Row>(1, x => x.X)));

        // Act
        var raw = BinaryPacker.Pack(scheme, new Row { N = 2, X = 7 });

        // Assert
        Assert.Equal("01020707", Hex(raw));
    }

    [Fact]
    public void Pack_LoneScalarUnderAFlagBit_SetsTheBitInEveryRound()
    {
        // Arrange
        var scheme = new Scheme<Row>(1,
            Field.Repeat(0, Field.Flags(0, Field.U8<Row>(0, x => x.A)), Field.U8<Row>(1, x => x.B)));
        var values = new Dictionary<string, object?> { ["A"] = (byte)5, ["B"] = Rounds((byte)1, (byte)2) };

        // Act
        var raw = BinaryPacker.Pack(scheme, values);

        // Assert
        Assert.Equal("01010501010502", Hex(raw));
    }

    [Fact]
    public void Pack_OneRoundOfScalars_IsUnchanged()
    {
        // Arrange
        var scheme = new Scheme<Row>(1, Field.Repeat(0, Field.U8<Row>(0, x => x.A)));

        // Act
        var raw = BinaryPacker.Pack(scheme, new Dictionary<string, object?> { ["A"] = (byte)5 });

        // Assert
        Assert.Equal("0105", Hex(raw));
    }

    [Theory]
    [InlineData("bytes", false, false)]
    [InlineData("bytes", true, false)]
    [InlineData("sized", false, false)]
    [InlineData("sized", true, false)]
    [InlineData("bits", false, false)]
    [InlineData("bits", true, false)]
    [InlineData("packed", false, false)]
    [InlineData("packed", true, false)]
    [InlineData("bytes", false, true)]
    [InlineData("bytes", true, true)]
    [InlineData("sized", false, true)]
    [InlineData("sized", true, true)]
    [InlineData("bits", false, true)]
    [InlineData("bits", true, true)]
    [InlineData("packed", false, true)]
    [InlineData("packed", true, true)]
    public void Pack_LoneCollectionInARound_ThrowsNamingTheField(string kind, bool times, bool typed)
    {
        // Arrange
        var scheme = InRound(kind, times);

        // Act
        var refused = Record.Exception(() => typed
            ? BinaryPacker.Pack(scheme, LoneTyped(kind))
            : BinaryPacker.Pack(scheme, LoneMap(kind)));

        // Assert
        var error = Assert.IsType<ArgumentException>(refused);
        Assert.Contains($"'{Name(kind)}'", error.Message, StringComparison.Ordinal);
        Assert.Contains("one entry per round", error.Message, StringComparison.Ordinal);
    }

    [Fact]
    public void Pack_PerRoundBytes_PacksReadsAndRepacksTheSameBytes()
    {
        // Arrange
        var scheme = InRound("bytes", times: false);
        var values = new Dictionary<string, object?> { ["Raw"] = Rounds(new byte[] { 1, 2 }, new byte[] { 3, 4 }) };

        // Act
        var raw = BinaryPacker.Pack(scheme, values);
        var again = BinaryPacker.Pack(scheme, BinaryPacker.Read(scheme, raw).Values);

        // Assert
        Assert.Equal("0101020304", Hex(raw));
        Assert.Equal(Hex(raw), Hex(again));
    }

    [Theory]
    [InlineData("sized", "0102" + "0909" + "01" + "08")]
    [InlineData("bits", "0103" + "05" + "02" + "02")]
    [InlineData("packed", "0102" + "09" + "03" + "13")]
    public void Pack_PerRoundCollectionWithItsCountInTheRound_PacksReadsAndRepacksTheSameBytes(string kind, string hex)
    {
        // Arrange
        var scheme = InRound(kind, times: false);
        var counts = kind == "sized" ? Rounds((byte)2, (byte)1) : kind == "bits" ? Rounds((byte)3, (byte)2) : Rounds((byte)2, (byte)3);
        var values = new Dictionary<string, object?> { ["N"] = counts };
        values[Name(kind)] = kind switch
        {
            "sized" => Rounds(new byte[] { 9, 9 }, new byte[] { 8 }),
            "bits" => Rounds(new List<int> { 1, 0, 1 }, new List<int> { 0, 1 }),
            _ => Rounds(new List<int> { 1, 2 }, new List<int> { 3, 0, 1 }),
        };

        // Act
        var raw = BinaryPacker.Pack(scheme, values);
        var again = BinaryPacker.Pack(scheme, BinaryPacker.Read(scheme, raw).Values);

        // Assert
        Assert.Equal(hex, Hex(raw));
        Assert.Equal(Hex(raw), Hex(again));
    }

    [Fact]
    public void Pack_ListsOfTwoAndOneEntries_StillThrows()
    {
        // Arrange
        var scheme = new Scheme<Row>(1, Field.Repeat(0, Field.U8<Row>(0, x => x.A), Field.U8<Row>(1, x => x.B)));
        var values = new Dictionary<string, object?> { ["A"] = Rounds((byte)1, (byte)2), ["B"] = Rounds((byte)3) };

        // Act
        var refused = Record.Exception(() => BinaryPacker.Pack(scheme, values));

        // Assert
        var error = Assert.IsType<ArgumentException>(refused);
        Assert.Contains("'B'", error.Message, StringComparison.Ordinal);
    }
}
