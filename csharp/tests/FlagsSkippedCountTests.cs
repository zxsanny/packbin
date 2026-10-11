using Packbin;

namespace Packbin.Tests;

// AZ-2360: in a combined flags, a times whose count is skipped while the row gives values is refused naming the member
// (the message of the TypeScript reference); with no values its bit packs clear as before. AZ-2356 (pinned, C# already
// complied): a split count written after the byte that is 0 refuses a list and packs a lone scalar as zero rounds.
public class FlagsSkippedCountTests
{
    private sealed class Row
    {
        public byte Mode { get; set; }
        public byte N { get; set; }
        public byte Pt { get; set; }
    }

    private const string Skipped =
        "'Pt': a value is given, but the count of its times is not written, so its bit is clear; write the count before the times";

    private static string Hex(byte[] raw) => Convert.ToHexString(raw).ToLowerInvariant();

    // flags { u8 n; times(n) { u8 pt } }: the first member is the count of the second.
    private static Scheme<Row> CombinedCount() => new(1,
        Field.Flags(0, Field.U8<Row>(0, x => x.N), Field.Times(1, 0, Field.U8<Row>(1, x => x.Pt))));

    private static Scheme<Row> CountAfterByte()
    {
        var flagByte = Field.FlagByte();
        return new Scheme<Row>(1,
            flagByte,
            Field.U8<Row>(0, x => x.N),
            flagByte.Bit(Field.Times(1, 0, Field.U8<Row>(1, x => x.Pt))));
    }

    [Fact]
    public void Ac1_Pack_SkippedCountWithAListOfValues_IsRefusedNamingTheMember()
    {
        // Arrange
        var values = new Dictionary<string, object?> { ["Pt"] = new object?[] { (byte)5, (byte)6 } };

        // Act
        var error = Assert.Throws<ArgumentException>(() => BinaryPacker.Pack(CombinedCount(), values));

        // Assert
        Assert.Equal(Skipped, error.Message);
    }

    [Fact]
    public void Ac1_Pack_SkippedCountWithALoneScalar_IsRefusedToo()
    {
        // Arrange
        var values = new Dictionary<string, object?> { ["Pt"] = (byte)5 };

        // Act
        var error = Assert.Throws<ArgumentException>(() => BinaryPacker.Pack(CombinedCount(), values));

        // Assert
        Assert.Equal(Skipped, error.Message);
    }

    [Fact]
    public void Ac2_Pack_SkippedCountWithNoValuesOrAnEmptyList_PacksTheBitClear()
    {
        // Act
        var none = BinaryPacker.Pack(CombinedCount(), new Dictionary<string, object?>());
        var empty = BinaryPacker.Pack(CombinedCount(), new Dictionary<string, object?> { ["Pt"] = new object?[] { } });
        var counted = BinaryPacker.Pack(CombinedCount(), new Dictionary<string, object?>
        {
            ["N"] = (byte)2,
            ["Pt"] = new object?[] { (byte)5, (byte)6 },
        });

        // Assert
        Assert.Equal(["0100", "0100", "0103020506"], [Hex(none), Hex(empty), Hex(counted)]);
    }

    [Fact]
    public void Ac1_Pack_TimesUnderAWhenInsideFlags_IsRefusedAndAFalseWhenStaysSilent()
    {
        // Arrange
        var scheme = new Scheme<Row>(1,
            Field.U8<Row>(0, x => x.Mode),
            Field.Flags(1,
                Field.U8<Row>(1, x => x.N),
                Field.When(2, Condition.Eq(0, 1), Field.Times(2, 1, Field.U8<Row>(2, x => x.Pt)))));

        // Act
        var error = Assert.Throws<ArgumentException>(() => BinaryPacker.Pack(scheme, new Dictionary<string, object?>
        {
            ["Mode"] = (byte)1,
            ["Pt"] = new object?[] { (byte)5 },
        }));
        var falseWhen = BinaryPacker.Pack(scheme, new Dictionary<string, object?>
        {
            ["Mode"] = (byte)0,
            ["Pt"] = new object?[] { (byte)5 },
        });

        // Assert
        Assert.Equal(Skipped, error.Message);
        Assert.Equal("010000", Hex(falseWhen));
    }

    [Fact]
    public void Ac1_Pack_SplitCountZeroAfterTheByteWithAList_IsRefusedNamingTheMember()
    {
        // Arrange
        var values = new Dictionary<string, object?> { ["N"] = (byte)0, ["Pt"] = new object?[] { (byte)5, (byte)6 } };

        // Act
        var error = Assert.Throws<ArgumentException>(() => BinaryPacker.Pack(CountAfterByte(), values));

        // Assert
        Assert.Contains("'Pt'", error.Message, StringComparison.Ordinal);
    }

    [Fact]
    public void Ac2_Pack_SplitCountZeroAfterTheByteWithALoneScalar_PacksZeroRounds()
    {
        // Arrange
        var values = new Dictionary<string, object?> { ["N"] = (byte)0, ["Pt"] = (byte)5 };

        // Act
        var raw = BinaryPacker.Pack(CountAfterByte(), values);

        // Assert
        Assert.Equal("010000", Hex(raw));
    }
}
