using Packbin;

namespace Packbin.Tests;

// AZ-2308: in a repeat or times round a lone dictionary for a Dict name is refused naming the member, because it would
// be given to every round; a list with one dictionary per round packs as before, and a lone string for a Utf8 name keeps
// going to every round.
public class LoneDictRoundTests
{
    private sealed class El
    {
        public byte V { get; set; }
    }

    private sealed class LoneRow
    {
        public byte C { get; set; }
        public byte K { get; set; }
        public Dictionary<string, byte>? Maps { get; set; }
        public string S { get; set; } = "";
    }

    private sealed class RoundsRow
    {
        public byte C { get; set; }
        public byte K { get; set; }
        public List<Dictionary<string, byte>>? Maps { get; set; }
        public string S { get; set; } = "";
    }

    private static string Hex(byte[] raw) => Convert.ToHexString(raw).ToLowerInvariant();

    private static Scheme<LoneRow> LoneRepeat() => new(1,
        Field.Repeat(0, Field.U8<LoneRow>(0, x => x.K), Field.Dict((LoneRow x) => x.Maps, Field.U8<El>(0, e => e.V))));

    private static Scheme<LoneRow> LoneTimes() => new(1,
        Field.U8<LoneRow>(0, x => x.C),
        Field.Times(1, 0, Field.U8<LoneRow>(1, x => x.K), Field.Dict((LoneRow x) => x.Maps, Field.U8<El>(0, e => e.V))));

    private static Scheme<RoundsRow> RoundsRepeat() => new(1,
        Field.Repeat(0, Field.U8<RoundsRow>(0, x => x.K), Field.Dict((RoundsRow x) => x.Maps, Field.U8<El>(0, e => e.V))));

    private static Scheme<RoundsRow> RoundsTimes() => new(1,
        Field.U8<RoundsRow>(0, x => x.C),
        Field.Times(1, 0, Field.U8<RoundsRow>(1, x => x.K), Field.Dict((RoundsRow x) => x.Maps, Field.U8<El>(0, e => e.V))));

    private const string RepeatBytes = "01" + "01" + "0100" + "0100" + "61" + "05" + "02" + "0100" + "0100" + "62" + "06";
    private const string TimesBytes = "01" + "02" + "01" + "0100" + "0100" + "61" + "05" + "02" + "0100" + "0100" + "62" + "06";

    private static Dictionary<string, object?> PerRound(bool times)
    {
        var values = new Dictionary<string, object?>
        {
            ["K"] = new object?[] { (byte)1, (byte)2 },
            ["Maps"] = new object?[]
            {
                new Dictionary<string, object?> { ["a"] = (byte)5 },
                new Dictionary<string, object?> { ["b"] = (byte)6 },
            },
        };
        if (times)
            values["C"] = (byte)2;
        return values;
    }

    private static Dictionary<string, object?> Lone(bool times)
    {
        var values = PerRound(times);
        values["Maps"] = new Dictionary<string, object?> { ["a"] = (byte)5 };
        return values;
    }

    [Theory]
    [InlineData(false)]
    [InlineData(true)]
    public void Ac2_Pack_LoneDictionaryInARoundWithDictionaryValues_ThrowsNamingTheMember(bool times)
    {
        // Act
        var error = Assert.Throws<ArgumentException>(
            () => BinaryPacker.Pack(times ? LoneTimes() : LoneRepeat(), Lone(times)));

        // Assert
        Assert.Contains("'Maps'", error.Message, StringComparison.Ordinal);
    }

    [Theory]
    [InlineData(false)]
    [InlineData(true)]
    public void Ac2_Pack_LoneDictionaryInARoundOfATypedRow_ThrowsNamingTheMember(bool times)
    {
        // Arrange
        var row = new LoneRow { C = 2, K = 1, Maps = new Dictionary<string, byte> { ["a"] = 5 } };

        // Act
        var error = Assert.Throws<ArgumentException>(() => BinaryPacker.Pack(times ? LoneTimes() : LoneRepeat(), row));

        // Assert
        Assert.Contains("'Maps'", error.Message, StringComparison.Ordinal);
    }

    [Theory]
    [InlineData(false)]
    [InlineData(true)]
    public void Ac3_Pack_ListOfDictionaries_OneEntryPerRound(bool times)
    {
        // Arrange
        var values = PerRound(times);

        // Act
        var dictionary = BinaryPacker.Pack(times ? RoundsTimes() : RoundsRepeat(), values);

        // Assert
        Assert.Equal(times ? TimesBytes : RepeatBytes, Hex(dictionary));
    }

    [Theory]
    [InlineData(false)]
    [InlineData(true)]
    public void Ac3_Pack_ListOfDictionariesInATypedRow_OneEntryPerRound(bool times)
    {
        // Arrange
        var row = new RoundsRow
        {
            C = 2,
            K = 0,
            Maps = [new() { ["a"] = 5 }, new() { ["b"] = 6 }],
        };

        // Act
        var raw = BinaryPacker.Pack(times ? RoundsTimes() : RoundsRepeat(), row);

        // Assert
        const string rounds = "00" + "0100" + "0100" + "61" + "05" + "00" + "0100" + "0100" + "62" + "06";
        Assert.Equal(times ? "0102" + rounds : "01" + rounds, Hex(raw));
    }

    [Fact]
    public void Ac3_Pack_UnpackedRoundsOfDictionaries_RepackToTheSameBytes()
    {
        // Arrange
        var scheme = LoneRepeat();
        var packet = Convert.FromHexString(RepeatBytes);

        // Act
        var read = BinaryPacker.Read(scheme, packet);
        var again = BinaryPacker.Pack(scheme, read.Values);

        // Assert
        Assert.Null(read.Error);
        Assert.Equal(RepeatBytes, Hex(again));
    }

    [Fact]
    public void Pack_LoneStringForAUtf8NameInARound_StillGoesToEveryRound()
    {
        // Arrange
        var scheme = new Scheme<LoneRow>(1,
            Field.Repeat(0, Field.U8<LoneRow>(0, x => x.K), Field.Utf8<LoneRow>(1, x => x.S)));
        var values = new Dictionary<string, object?> { ["K"] = new object?[] { (byte)1, (byte)2 }, ["S"] = "x" };

        // Act
        var raw = BinaryPacker.Pack(scheme, values);

        // Assert
        Assert.Equal("01" + "01" + "0100" + "78" + "02" + "0100" + "78", Hex(raw));
    }
}
