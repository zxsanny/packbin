using System.Collections;
using System.Globalization;
using Packbin;

namespace Packbin.Tests;

// AZ-2120 AC-4, AZ-2128: a `times` or `repeat` that is a member of a `flags` container is a value like any other. Its
// bit is on exactly when a round is written (a times count above zero, a repeat with a value for a round); unpack of a
// set bit reads the rounds; a round that cannot be written in full fails pack naming the missing value.
// A typed row holds a round value as a scalar, so a typed row packs one round at most and its unpack of a set round bit
// is read through the dictionary (Read); typed unpack is checked only on packets whose bit is clear.
public class FlagsRoundMemberTests
{
    private sealed class Row
    {
        public byte Mode { get; set; }
        public byte N { get; set; }
        public byte? Pt { get; set; }
        public byte? Pu { get; set; }
        public ushort? Heading { get; set; }
        public bool? Mark { get; set; }
    }

    private static string Hex(byte[] raw) => Convert.ToHexString(raw).ToLowerInvariant();

    private static int Int(object? value) => Convert.ToInt32(value, CultureInfo.InvariantCulture);

    private static int[] Ints(object? list) => [.. ((IList)list!).Cast<object?>().Select(Int)];

    private static Scheme<Row> TimesMember() => new(1,
        Field.U8<Row>(0, x => x.N),
        Field.Flags(1,
            Field.Times(1, 0, Field.U8<Row>(1, x => x.Pt)),
            Field.U16<Row>(2, x => x.Heading)));

    private static Scheme<Row> TimesTwoValues() => new(1,
        Field.U8<Row>(0, x => x.N),
        Field.Flags(1,
            Field.Times(1, 0, Field.U8<Row>(1, x => x.Pt), Field.U8<Row>(2, x => x.Pu)),
            Field.U16<Row>(3, x => x.Heading)));

    private static Scheme<Row> TimesInGroup() => new(1,
        Field.U8<Row>(0, x => x.N),
        Field.Flags(1,
            Field.Group(1, (Row x) => x.Mark, Field.Times(1, 0, Field.U8<Row>(1, x => x.Pt))),
            Field.U16<Row>(2, x => x.Heading)));

    private static Scheme<Row> TimesSplitBit()
    {
        var m = Field.FlagByte();
        return new Scheme<Row>(1,
            Field.U8<Row>(0, x => x.N),
            m,
            m.Bit(Field.Times(1, 0, Field.U8<Row>(1, x => x.Pt))),
            m.Bit(Field.U16<Row>(2, x => x.Heading)));
    }

    private static Scheme<Row> RepeatMember() => new(1,
        Field.U8<Row>(0, x => x.Mode),
        Field.Flags(1,
            Field.U16<Row>(1, x => x.Heading),
            Field.Repeat(2, Field.U8<Row>(2, x => x.Pt))));

    private static Scheme<Row> RepeatTwoValues() => new(1,
        Field.U8<Row>(0, x => x.Mode),
        Field.Flags(1,
            Field.U16<Row>(1, x => x.Heading),
            Field.Repeat(2, Field.U8<Row>(2, x => x.Pt), Field.U8<Row>(3, x => x.Pu))));

    private static Dictionary<string, object?> Rounds(byte n, ushort? heading, params byte[] pts)
    {
        var row = new Dictionary<string, object?> { ["N"] = n, ["Mode"] = n };
        if (heading is not null)
            row["Heading"] = heading;
        if (pts.Length > 0)
            row["Pt"] = pts.Select(p => (object?)p).ToList();
        return row;
    }

    private static Row Typed(Scheme<Row> scheme, string hex)
    {
        Row? got = null;
        var err = BinaryPacker.Unpack(Convert.FromHexString(hex), scheme.On(v => got = v));
        Assert.Null(err);
        return got!;
    }

    public static TheoryData<string> TimesShapes() => new() { "direct", "in group", "split bit" };

    private static Scheme<Row> BuildTimes(string shape) => shape switch
    {
        "direct" => TimesMember(),
        "in group" => TimesInGroup(),
        _ => TimesSplitBit(),
    };

    [Theory]
    [MemberData(nameof(TimesShapes))]
    public void Ac4_Times_ZeroRounds_LeavesTheBitClear(string shape)
    {
        // Arrange
        var scheme = BuildTimes(shape);

        // Act
        var typed = BinaryPacker.Pack(scheme, new Row { N = 0, Heading = 90 });
        var dict = BinaryPacker.Pack(scheme, Rounds(0, 90));
        var got = BinaryPacker.Read(scheme, dict);

        // Assert
        Assert.Equal("01" + "00" + "02" + "5a00", Hex(typed));
        Assert.Equal(Hex(typed), Hex(dict));
        Assert.Null(got.Error);
        Assert.False(got.Values.ContainsKey("Pt"));
    }

    [Theory]
    [MemberData(nameof(TimesShapes))]
    public void Ac4_Times_OneRound_SetsTheBitAndRoundTrips(string shape)
    {
        // Arrange
        var scheme = BuildTimes(shape);

        // Act
        var typed = BinaryPacker.Pack(scheme, new Row { N = 1, Pt = 5, Heading = 90 });
        var dict = BinaryPacker.Pack(scheme, Rounds(1, 90, 5));
        var gotDict = BinaryPacker.Read(scheme, dict);

        // Assert
        Assert.Equal("01" + "01" + "03" + "05" + "5a00", Hex(typed));
        Assert.Equal(Hex(typed), Hex(dict));
        Assert.Null(gotDict.Error);
        Assert.Equal([5], Ints(gotDict.Values["Pt"]));
        Assert.Equal(90, Int(gotDict.Values["Heading"]));
    }

    [Theory]
    [MemberData(nameof(TimesShapes))]
    public void Ac4_Dictionary_Times_TwoRounds_SetsTheBitAndRoundTrips(string shape)
    {
        // Arrange
        var scheme = BuildTimes(shape);

        // Act
        var raw = BinaryPacker.Pack(scheme, Rounds(2, 90, 5, 6));
        var got = BinaryPacker.Read(scheme, raw);

        // Assert
        Assert.Equal("01" + "02" + "03" + "05" + "06" + "5a00", Hex(raw));
        Assert.Null(got.Error);
        Assert.Equal([5, 6], Ints(got.Values["Pt"]));
        Assert.Equal(90, Int(got.Values["Heading"]));
    }

    [Fact]
    public void Ac4_Times_OldPacketWithTheBitClear_StillUnpacksWithoutTheMember()
    {
        // Arrange
        var scheme = TimesMember();

        // Act
        var got = Typed(scheme, "01" + "00" + "02" + "5a00");

        // Assert
        Assert.Equal((0, (byte?)null, (ushort?)90), (got.N, got.Pt, got.Heading));
    }

    [Fact]
    public void Ac4_Times_CountAboveZeroButTooFewValues_FailsNamingTheValue()
    {
        // Arrange
        var scheme = TimesMember();

        // Act
        var short_ = Assert.Throws<ArgumentException>(() => BinaryPacker.Pack(scheme, Rounds(2, 90, 5)));
        var none = Assert.Throws<ArgumentException>(() => BinaryPacker.Pack(scheme, Rounds(1, 90)));
        var typed = Assert.Throws<ArgumentException>(() => BinaryPacker.Pack(scheme, new Row { N = 1, Heading = 90 }));

        // Assert
        Assert.Contains("Pt", short_.Message, StringComparison.Ordinal);
        Assert.Contains("Pt", none.Message, StringComparison.Ordinal);
        Assert.Contains("Pt", typed.Message, StringComparison.Ordinal);
    }

    [Fact]
    public void Ac4_Times_OneRoundWithAMissingBodyValue_FailsNamingTheValue()
    {
        // Arrange
        var scheme = TimesTwoValues();

        // Act
        var ex = Assert.Throws<ArgumentException>(() => BinaryPacker.Pack(scheme, new Row { N = 1, Pt = 5, Heading = 90 }));

        // Assert
        Assert.Contains("Pu", ex.Message, StringComparison.Ordinal);
    }

    [Fact]
    public void Ac4_Times_TypedPackOneRoundWithTwoValues_RoundTripsThroughTheDictionary()
    {
        // Arrange
        var scheme = TimesTwoValues();

        // Act
        var raw = BinaryPacker.Pack(scheme, new Row { N = 1, Pt = 5, Pu = 6, Heading = 90 });
        var got = BinaryPacker.Read(scheme, raw);

        // Assert
        Assert.Equal("01" + "01" + "03" + "05" + "06" + "5a00", Hex(raw));
        Assert.Null(got.Error);
        Assert.Equal([5], Ints(got.Values["Pt"]));
        Assert.Equal([6], Ints(got.Values["Pu"]));
        Assert.Equal(90, Int(got.Values["Heading"]));
    }

    [Fact]
    public void Ac4_Times_RowOfOnlyTheTimesValues_SetsOnlyTheTimesBit()
    {
        // Arrange
        var scheme = TimesMember();

        // Act
        var raw = BinaryPacker.Pack(scheme, Rounds(2, null, 5, 6));
        var got = BinaryPacker.Read(scheme, raw);

        // Assert
        Assert.Equal("01" + "02" + "01" + "05" + "06", Hex(raw));
        Assert.Null(got.Error);
        Assert.False(got.Values.ContainsKey("Heading"));
    }

    [Fact]
    public void Ac4_Repeat_ZeroRounds_LeavesTheBitClear()
    {
        // Arrange
        var scheme = RepeatMember();

        // Act
        var typed = BinaryPacker.Pack(scheme, new Row { Mode = 1, Heading = 90 });
        var dict = BinaryPacker.Pack(scheme, Rounds(1, 90));
        var got = BinaryPacker.Read(scheme, dict);

        // Assert
        Assert.Equal("01" + "01" + "01" + "5a00", Hex(typed));
        Assert.Equal(Hex(typed), Hex(dict));
        Assert.Null(got.Error);
        Assert.False(got.Values.ContainsKey("Pt"));
    }

    [Fact]
    public void Ac4_Repeat_OneRound_SetsTheBitAndRoundTrips()
    {
        // Arrange
        var scheme = RepeatMember();

        // Act
        var typed = BinaryPacker.Pack(scheme, new Row { Mode = 1, Pt = 5, Heading = 90 });
        var dict = BinaryPacker.Pack(scheme, Rounds(1, 90, 5));
        var gotDict = BinaryPacker.Read(scheme, dict);

        // Assert
        Assert.Equal("01" + "01" + "03" + "5a00" + "05", Hex(typed));
        Assert.Equal(Hex(typed), Hex(dict));
        Assert.Null(gotDict.Error);
        Assert.Equal([5], Ints(gotDict.Values["Pt"]));
    }

    [Fact]
    public void Ac4_Dictionary_Repeat_TwoRounds_SetsTheBitAndRoundTrips()
    {
        // Arrange
        var scheme = RepeatMember();

        // Act
        var raw = BinaryPacker.Pack(scheme, Rounds(1, 90, 5, 6));
        var got = BinaryPacker.Read(scheme, raw);

        // Assert
        Assert.Equal("01" + "01" + "03" + "5a00" + "05" + "06", Hex(raw));
        Assert.Null(got.Error);
        Assert.Equal([5, 6], Ints(got.Values["Pt"]));
        Assert.Equal(90, Int(got.Values["Heading"]));
    }

    [Fact]
    public void Ac4_Repeat_OnlyTheRepeatValues_SetsOnlyTheRepeatBit()
    {
        // Arrange
        var scheme = RepeatMember();

        // Act
        var raw = BinaryPacker.Pack(scheme, Rounds(1, null, 5, 6));
        var got = BinaryPacker.Read(scheme, raw);

        // Assert
        Assert.Equal("01" + "01" + "02" + "05" + "06", Hex(raw));
        Assert.Null(got.Error);
        Assert.Equal([5, 6], Ints(got.Values["Pt"]));
        Assert.False(got.Values.ContainsKey("Heading"));
    }

    [Fact]
    public void Ac4_Repeat_OldPacketWithTheBitClear_StillUnpacksWithoutTheMember()
    {
        // Arrange
        var scheme = RepeatMember();

        // Act
        var got = Typed(scheme, "01" + "01" + "01" + "5a00");

        // Assert
        Assert.Equal(((byte?)null, (ushort?)90), (got.Pt, got.Heading));
    }

    [Fact]
    public void Ac4_Repeat_RoundWithAMissingBodyValue_FailsNamingTheValue()
    {
        // Arrange
        var scheme = RepeatTwoValues();

        // Act
        var ex = Assert.Throws<ArgumentException>(() => BinaryPacker.Pack(scheme, new Row { Mode = 1, Pt = 5, Heading = 90 }));

        // Assert
        Assert.Contains("Pu", ex.Message, StringComparison.Ordinal);
    }

    [Fact]
    public void Ac4_Times_RoundValueOutsideTheFieldRange_FailsPack()
    {
        // Arrange
        var scheme = TimesMember();
        var row = Rounds(2, 90, 5);
        row["Pt"] = new List<object?> { 5, 300 };

        // Act
        var ex = Assert.Throws<ArgumentException>(() => BinaryPacker.Pack(scheme, row));

        // Assert
        Assert.Contains("Pt", ex.Message, StringComparison.Ordinal);
    }

    [Theory]
    [MemberData(nameof(TimesShapes))]
    public void Ac4_Times_ZeroCountWithValuesGiven_FailsNamingTheValue(string shape)
    {
        // Arrange
        var scheme = BuildTimes(shape);
        var row = Rounds(0, 90, 5);

        // Act
        var ex = Assert.Throws<ArgumentException>(() => BinaryPacker.Pack(scheme, row));

        // Assert
        Assert.Contains("Pt", ex.Message, StringComparison.Ordinal);
    }
}
