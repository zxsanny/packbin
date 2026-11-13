using Packbin;

namespace Packbin.Tests;

// AZ-4251: a `flags` that is a direct member of a `flags` sets its bit when any member inside it holds a value, as in
// TypeScript and Java. Before, C# never set that bit and dropped the inner value with no error.
public class FlagsInFlagsTests
{
    private sealed class Row
    {
        public byte? X { get; set; }
        public bool? B { get; set; }
    }

    private static string Hex(byte[] raw) => Convert.ToHexString(raw).ToLowerInvariant();

    // flags(flags(u8 x), bool b), type 1.
    private static Scheme<Row> Scheme() =>
        new(1, Field.Flags(0, Field.Flags(0, Field.U8<Row>(0, r => r.X)), Field.Bool<Row>(1, r => r.B)));

    private static Row Unpack(Scheme<Row> scheme, byte[] raw)
    {
        Row? got = null;
        var err = BinaryPacker.Unpack(raw, scheme.On(v => got = v));
        Assert.Null(err);
        Assert.NotNull(got);
        return got;
    }

    public static TheoryData<byte?, bool?, string> Combinations() => new()
    {
        { 9, true, "01030109" },
        { 9, null, "01010109" },
        { null, true, "0102" },
        { null, null, "0100" },
    };

    [Theory]
    [MemberData(nameof(Combinations))]
    public void Pack_TypedRow_WritesTheTypeScriptBytes(byte? x, bool? b, string expected)
    {
        // Arrange
        var scheme = Scheme();

        // Act
        var raw = BinaryPacker.Pack(scheme, new Row { X = x, B = b });

        // Assert
        Assert.Equal(expected, Hex(raw));
    }

    [Theory]
    [MemberData(nameof(Combinations))]
    public void Unpack_TypedRow_ReadsTheValuesBack(byte? x, bool? b, string expected)
    {
        // Arrange
        var scheme = Scheme();
        var raw = Convert.FromHexString(expected);

        // Act
        var got = Unpack(scheme, raw);

        // Assert
        Assert.Equal((x, b ?? false), (got.X, got.B ?? false));
    }

    [Theory]
    [MemberData(nameof(Combinations))]
    public void Pack_Dictionary_WritesTheTypeScriptBytes(byte? x, bool? b, string expected)
    {
        // Arrange
        var values = new Dictionary<string, object?>();
        if (x is { } xv)
            values["X"] = xv;
        if (b is { } bv)
            values["B"] = bv;

        // Act
        var raw = BinaryPacker.Pack(Scheme(), values);

        // Assert
        Assert.Equal(expected, Hex(raw));
    }

    // The same members behind a split flag byte: its bits are decided by the same rule (FlagGroup.Compute).
    [Theory]
    [MemberData(nameof(Combinations))]
    public void PackAndUnpack_SplitFlagByte_WritesTheTypeScriptBytesAndReadsBack(byte? x, bool? b, string expected)
    {
        // Arrange
        var m = Field.FlagByte();
        var scheme = new Scheme<Row>(
            1, m, m.Bit(Field.Flags(0, Field.U8<Row>(0, r => r.X))), m.Bit(Field.Bool<Row>(1, r => r.B)));

        // Act
        var raw = BinaryPacker.Pack(scheme, new Row { X = x, B = b });
        var got = Unpack(scheme, raw);

        // Assert
        Assert.Equal((expected, x, b ?? false), (Hex(raw), got.X, got.B ?? false));
    }

    [Fact]
    public void PackAndUnpack_ThreeLevels_WritesTheTypeScriptBytesAndReadsBack()
    {
        // Arrange
        var scheme = new Scheme<Row>(1, Field.Flags(0, Field.Flags(0, Field.Flags(0, Field.U8<Row>(0, r => r.X)))));

        // Act
        var raw = BinaryPacker.Pack(scheme, new Row { X = 9 });
        var got = Unpack(scheme, raw);

        // Assert
        Assert.Equal(("0101010109", (byte?)9), (Hex(raw), got.X));
    }
}
