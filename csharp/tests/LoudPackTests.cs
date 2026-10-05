using Packbin;

namespace Packbin.Tests;

// Pack returns bytes the peer can read or throws. A walked field with no value, a repeat or times round that runs out of
// list, and an absent list, dictionary or sized value are errors that name the field, never a shorter packet.
public class LoudPackTests
{
    private sealed class NullRow
    {
        public ushort? Heading { get; set; }
        public byte Tail { get; set; }
    }

    private sealed class FlaggedRow
    {
        public ushort? Heading { get; set; }
        public byte Tail { get; set; }
    }

    private sealed class WhenRow
    {
        public byte K { get; set; }
        public byte? V { get; set; }
    }

    private sealed class PointsRow
    {
        public int Lat { get; set; }
        public int Lon { get; set; }
    }

    private sealed class CountedPointsRow
    {
        public byte N { get; set; }
        public int Lat { get; set; }
        public int Lon { get; set; }
    }

    public sealed class TaggedRow
    {
        public byte[]? Tag { get; set; }
        public string? Name { get; set; }
        public int? Q { get; set; }
    }

    public sealed class HolderRow
    {
        public List<int>? Xs { get; set; }
        public Dictionary<string, byte>? Map { get; set; }
        public byte[]? Payload { get; set; }
        public List<int>? Bits { get; set; }
        public List<int>? Kinds { get; set; }
        public byte N { get; set; }
    }

    private sealed class RoundWhenRow
    {
        public byte K { get; set; }
        public byte V { get; set; }
    }

    private sealed class El
    {
        public ushort V { get; set; }
    }

    private sealed class ByteEl
    {
        public byte V { get; set; }
    }

    private static string Hex(byte[] raw) => Convert.ToHexString(raw).ToLowerInvariant();

    [Fact]
    public void Pack_RequiredValueMissing_ThrowsNamingTheMemberAndItsId()
    {
        // Arrange
        var scheme = new Scheme<NullRow>(1, Field.U16<NullRow>(0, x => x.Heading), Field.U8<NullRow>(1, x => x.Tail));

        // Act
        var ex = Assert.Throws<ArgumentException>(() => BinaryPacker.Pack(scheme, new NullRow { Tail = 7 }));

        // Assert
        Assert.Contains("Heading", ex.Message);
        Assert.Contains("field id 0", ex.Message);
    }

    [Fact]
    public void Pack_RequiredValueMissingInADictionary_Throws()
    {
        // Arrange
        var scheme = new Scheme<NullRow>(1, Field.U16<NullRow>(0, x => x.Heading), Field.U8<NullRow>(1, x => x.Tail));
        var values = new Dictionary<string, object?> { ["Tail"] = (byte)7 };

        // Act
        var ex = Assert.Throws<ArgumentException>(() => BinaryPacker.Pack(scheme, values));

        // Assert
        Assert.Contains("Heading", ex.Message);
    }

    [Fact]
    public void Pack_RequiredValueSetToNull_Throws()
    {
        // Arrange
        var scheme = new Scheme<NullRow>(1, Field.U16<NullRow>(0, x => x.Heading), Field.U8<NullRow>(1, x => x.Tail));
        var values = new Dictionary<string, object?> { ["Heading"] = null, ["Tail"] = (byte)7 };

        // Act and Assert
        Assert.Throws<ArgumentException>(() => BinaryPacker.Pack(scheme, values));
    }

    [Fact]
    public void Pack_RequiredValuePresent_PacksAsBefore()
    {
        // Arrange
        var scheme = new Scheme<NullRow>(1, Field.U16<NullRow>(0, x => x.Heading), Field.U8<NullRow>(1, x => x.Tail));

        // Act
        var raw = BinaryPacker.Pack(scheme, new NullRow { Heading = 0x0102, Tail = 7 });

        // Assert
        Assert.Equal("01020107", Hex(raw));
    }

    [Fact]
    public void Pack_FlagBitChildMissing_StaysABitClear()
    {
        // Arrange
        var scheme = new Scheme<FlaggedRow>(1,
            Field.U8<FlaggedRow>(0, x => x.Tail),
            Field.Flags(1, Field.U16<FlaggedRow>(1, x => x.Heading)));

        // Act
        var raw = BinaryPacker.Pack(scheme, new FlaggedRow { Tail = 7 });

        // Assert
        Assert.Equal("010700", Hex(raw));
    }

    [Fact]
    public void Pack_FieldInsideAFalseWhen_IsNotWalked()
    {
        // Arrange
        var scheme = new Scheme<WhenRow>(1,
            Field.U8<WhenRow>(0, x => x.K),
            Field.When(1, Condition.Eq(0, (byte)1), Field.U8<WhenRow>(1, x => x.V)));

        // Act
        var raw = BinaryPacker.Pack(scheme, new WhenRow { K = 2 });

        // Assert
        Assert.Equal("0102", Hex(raw));
    }

    [Fact]
    public void Pack_FieldInsideATrueWhenWithoutAValue_ThrowsNamingTheField()
    {
        // Arrange
        var scheme = new Scheme<WhenRow>(1,
            Field.U8<WhenRow>(0, x => x.K),
            Field.When(1, Condition.Eq(0, (byte)1), Field.U8<WhenRow>(1, x => x.V)));

        // Act
        var ex = Assert.Throws<ArgumentException>(() => BinaryPacker.Pack(scheme, new WhenRow { K = 1 }));

        // Assert
        Assert.Contains("'V'", ex.Message);
    }

    [Fact]
    public void Pack_RepeatListsOfUnequalLength_ThrowsNamingTheShortList()
    {
        // Arrange
        var scheme = new Scheme<PointsRow>(1,
            Field.Repeat(0, Field.I32<PointsRow>(0, x => x.Lat), Field.I32<PointsRow>(1, x => x.Lon)));
        var values = new Dictionary<string, object?> { ["Lat"] = new[] { 1, 2 }, ["Lon"] = new[] { 3 } };

        // Act
        var ex = Assert.Throws<ArgumentException>(() => BinaryPacker.Pack(scheme, values));

        // Assert
        Assert.Contains("'Lon'", ex.Message);
    }

    [Fact]
    public void Pack_RepeatListsOfEqualLength_PacksEveryRound()
    {
        // Arrange
        var scheme = new Scheme<PointsRow>(1,
            Field.Repeat(0, Field.I32<PointsRow>(0, x => x.Lat), Field.I32<PointsRow>(1, x => x.Lon)));
        var values = new Dictionary<string, object?> { ["Lat"] = new[] { 1, 2 }, ["Lon"] = new[] { 3, 4 } };

        // Act
        var raw = BinaryPacker.Pack(scheme, values);

        // Assert
        Assert.Equal("01" + "01000000" + "03000000" + "02000000" + "04000000", Hex(raw));
    }

    [Fact]
    public void Pack_TimesListShorterThanTheCount_ThrowsNamingTheShortList()
    {
        // Arrange
        var scheme = TimesScheme();
        var values = Counted(2, [10], [20, 40]);

        // Act
        var ex = Assert.Throws<ArgumentException>(() => BinaryPacker.Pack(scheme, values));

        // Assert
        Assert.Contains("'Lat'", ex.Message);
    }

    [Fact]
    public void Pack_TimesListLongerThanTheCount_ThrowsNamingTheLongList()
    {
        // Arrange
        var scheme = TimesScheme();
        var values = Counted(1, [10, 20], [30]);

        // Act
        var ex = Assert.Throws<ArgumentException>(() => BinaryPacker.Pack(scheme, values));

        // Assert
        Assert.Contains("'Lat'", ex.Message);
    }

    [Fact]
    public void Pack_TimesListsOfExactlyTheCount_PacksEveryRound()
    {
        // Arrange
        var scheme = TimesScheme();
        var values = Counted(2, [10, 20], [30, 40]);

        // Act
        var raw = BinaryPacker.Pack(scheme, values);

        // Assert
        Assert.Equal("0102" + "0a000000" + "1e000000" + "14000000" + "28000000", Hex(raw));
    }

    [Fact]
    public void Pack_WhenHoldsInARoundWhoseValueListRanOut_Throws()
    {
        // Arrange
        var scheme = new Scheme<RoundWhenRow>(1,
            Field.Repeat(0,
                Field.U8<RoundWhenRow>(0, x => x.K),
                Field.When(1, Condition.Eq(0, (byte)1), Field.U8<RoundWhenRow>(1, x => x.V))));
        var values = new Dictionary<string, object?> { ["K"] = new[] { 2, 1 }, ["V"] = new[] { 9 } };

        // Act
        var ex = Assert.Throws<ArgumentException>(() => BinaryPacker.Pack(scheme, values));

        // Assert
        Assert.Contains("'V'", ex.Message);
    }

    [Fact]
    public void Pack_WhenFalseInTheRoundsWhereTheValueListRanOut_StillPacks()
    {
        // Arrange
        var scheme = new Scheme<RoundWhenRow>(1,
            Field.Repeat(0,
                Field.U8<RoundWhenRow>(0, x => x.K),
                Field.When(1, Condition.Eq(0, (byte)1), Field.U8<RoundWhenRow>(1, x => x.V))));
        var values = new Dictionary<string, object?> { ["K"] = new[] { 1, 2 }, ["V"] = new[] { 9 } };

        // Act
        var raw = BinaryPacker.Pack(scheme, values);

        // Assert
        Assert.Equal("01010902", Hex(raw));
    }

    private static Dictionary<string, object?> Counted(byte n, int[] lat, int[] lon) =>
        new() { ["N"] = n, ["Lat"] = lat, ["Lon"] = lon };

    private static Scheme<CountedPointsRow> TimesScheme() => new(1,
        Field.U8<CountedPointsRow>(0, x => x.N),
        Field.Times(1, 0,
            Field.I32<CountedPointsRow>(1, x => x.Lat),
            Field.I32<CountedPointsRow>(2, x => x.Lon)));

    public static TheoryData<string, Func<Scheme<HolderRow>>, string> AbsentValues() => new()
    {
        {
            "List",
            () => new Scheme<HolderRow>(1, Field.List((HolderRow x) => x.Xs, Field.U16<El>(0, e => e.V))),
            "Xs"
        },
        {
            "Dict",
            () => new Scheme<HolderRow>(1, Field.Dict((HolderRow x) => x.Map, Field.U8<ByteEl>(0, e => e.V))),
            "Map"
        },
        {
            "Sized",
            () => new Scheme<HolderRow>(1,
                Field.U8<HolderRow>(0, x => x.N),
                Field.Sized<HolderRow>(1, x => x.Payload!, 0)),
            "Payload"
        },
        {
            "Bits",
            () => new Scheme<HolderRow>(1,
                Field.U8<HolderRow>(0, x => x.N),
                Field.Bits<HolderRow>(1, x => x.Bits, 0)),
            "Bits"
        },
        {
            "Packed",
            () => new Scheme<HolderRow>(1,
                Field.U8<HolderRow>(0, x => x.N),
                Field.Packed<HolderRow>(2, 1, x => x.Kinds, 0)),
            "Kinds"
        },
    };

    [Theory]
    [MemberData(nameof(AbsentValues))]
    public void Pack_AbsentListDictOrSized_ThrowsArgumentExceptionNamingTheField(
        string kind, Func<Scheme<HolderRow>> build, string member)
    {
        // Arrange
        var scheme = build();

        // Act
        var ex = Assert.Throws<ArgumentException>(() => BinaryPacker.Pack(scheme, new HolderRow { N = 1 }));

        // Assert
        Assert.True(ex.Message.Contains($"'{member}'"), $"{kind}: {ex.Message}");
    }

    [Fact]
    public void Pack_AbsentListInADictionary_ThrowsArgumentException()
    {
        // Arrange
        var scheme = new Scheme<HolderRow>(1, Field.List((HolderRow x) => x.Xs, Field.U16<El>(0, e => e.V)));
        var values = new Dictionary<string, object?>();

        // Act
        var ex = Assert.Throws<ArgumentException>(() => BinaryPacker.Pack(scheme, values));

        // Assert
        Assert.Contains("'Xs'", ex.Message);
    }

    public static TheoryData<string, Func<Scheme<TaggedRow>>, string> AbsentScalars() => new()
    {
        { "Bytes", () => new Scheme<TaggedRow>(1, Field.Bytes<TaggedRow>(0, x => x.Tag!, 2)), "Tag" },
        { "Utf8", () => new Scheme<TaggedRow>(1, Field.Utf8<TaggedRow>(0, x => x.Name!)), "Name" },
        { "I32", () => new Scheme<TaggedRow>(1, Field.I32<TaggedRow>(0, x => x.Q)), "Q" },
    };

    [Theory]
    [MemberData(nameof(AbsentScalars))]
    public void Pack_AbsentBytesUtf8OrNullableScalar_ThrowsArgumentExceptionNamingTheField(
        string kind, Func<Scheme<TaggedRow>> build, string member)
    {
        // Arrange
        var scheme = build();

        // Act
        var ex = Assert.Throws<ArgumentException>(() => BinaryPacker.Pack(scheme, new TaggedRow()));

        // Assert
        Assert.True(ex.Message.Contains(member), $"{kind}: {ex.Message}");
    }
}
