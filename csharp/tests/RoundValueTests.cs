using System.Globalization;
using Packbin;

namespace Packbin.Tests;

// A repeat or times round packs and unpacks its values by round index. A value under when, flags, a flag bit or a
// continuing group has one list entry per round, null where the round skipped it, so a repack gives the same bytes.
public class RoundValueTests
{
    private sealed class RoundRow
    {
        public byte A { get; set; }
        public byte? X { get; set; }
        public byte? K { get; set; }
        public byte? V { get; set; }
        public byte? N { get; set; }
        public bool? On { get; set; }
        public bool? Mark { get; set; }
        public int P { get; set; }
        public int Q { get; set; }
        public Inner? Row { get; set; }
    }

    private sealed class Inner
    {
        public byte? V { get; set; }
    }

    internal static int?[] Cells(object? list) =>
        [.. ((List<object?>)list!).Select(v => v is null ? (int?)null : Convert.ToInt32(v, CultureInfo.InvariantCulture))];

    private static object?[] Items(object? list) => [.. (List<object?>)list!];

    private static Scheme<RoundRow> FlagsRepeat() => new(1,
        Field.Repeat(0,
            Field.Flags(0, Field.Bool<RoundRow>(0, x => x.On), Field.U8<RoundRow>(1, x => x.N))));

    private static Scheme<RoundRow> FlagsTimes() => new(1,
        Field.U8<RoundRow>(0, x => x.A),
        Field.Times(1, 0,
            Field.Flags(1, Field.Bool<RoundRow>(1, x => x.On), Field.U8<RoundRow>(2, x => x.N))));

    private static Scheme<RoundRow> WhenRepeat() => new(1,
        Field.Repeat(0,
            Field.U8<RoundRow>(0, x => x.K),
            Field.When(1, Condition.Eq(0, (byte)1), Field.U8<RoundRow>(1, x => x.V))));

    private static Scheme<RoundRow> WhenTimes() => new(1,
        Field.U8<RoundRow>(0, x => x.A),
        Field.Times(1, 0,
            Field.U8<RoundRow>(1, x => x.K),
            Field.When(2, Condition.Eq(1, (byte)1), Field.U8<RoundRow>(2, x => x.V))));

    private static string Hex(byte[] raw) => Convert.ToHexString(raw).ToLowerInvariant();

    [Fact]
    public void Repeat_FlagsRound_PacksEachRoundByIndex()
    {
        // Arrange
        var values = new Dictionary<string, object?>
        {
            ["On"] = new object?[] { true, false, true },
            ["N"] = new object?[] { (byte)1, (byte)2, (byte)3 },
        };

        // Act
        var raw = BinaryPacker.Pack(FlagsRepeat(), values);

        // Assert
        Assert.Equal("01030102020303", Hex(raw));
    }

    [Fact]
    public void Repeat_FlagsRound_UnpacksOneEntryPerRoundAndRepacksTheSameBytes()
    {
        // Arrange
        var scheme = FlagsRepeat();
        var raw = Convert.FromHexString("01030102020303");

        // Act
        var got = BinaryPacker.Read(scheme, raw);
        var again = BinaryPacker.Pack(scheme, got.Values);

        // Assert
        Assert.Null(got.Error);
        Assert.Equal(new object?[] { true, null, true }, Items(got.Values["On"]));
        Assert.Equal([1, 2, 3], Cells(got.Values["N"]));
        Assert.Equal(Hex(raw), Hex(again));
    }

    [Fact]
    public void Times_FlagsRound_PacksAndRoundTrips()
    {
        // Arrange
        var scheme = FlagsTimes();
        var values = new Dictionary<string, object?>
        {
            ["A"] = (byte)3,
            ["On"] = new object?[] { true, false, true },
            ["N"] = new object?[] { (byte)1, (byte)2, (byte)3 },
        };

        // Act
        var raw = BinaryPacker.Pack(scheme, values);
        var got = BinaryPacker.Read(scheme, raw);
        var again = BinaryPacker.Pack(scheme, got.Values);

        // Assert
        Assert.Equal("0103030102020303", Hex(raw));
        Assert.Null(got.Error);
        Assert.Equal(new object?[] { true, null, true }, Items(got.Values["On"]));
        Assert.Equal(Hex(raw), Hex(again));
    }

    [Fact]
    public void Repeat_FlagsRoundWithASkippedValue_KeepsTheOtherRoundsValue()
    {
        // Arrange
        var scheme = new Scheme<RoundRow>(1,
            Field.Repeat(0,
                Field.U8<RoundRow>(0, x => x.X),
                Field.Flags(1, Field.U8<RoundRow>(1, x => x.N))));
        var values = new Dictionary<string, object?>
        {
            ["X"] = new object?[] { (byte)1, (byte)2 },
            ["N"] = new object?[] { (byte)5, null },
        };

        // Act
        var raw = BinaryPacker.Pack(scheme, values);
        var got = BinaryPacker.Read(scheme, raw);

        // Assert
        Assert.Equal("010101050200", Hex(raw));
        Assert.Equal([5, null], Cells(got.Values["N"]));
        Assert.Equal(Hex(raw), Hex(BinaryPacker.Pack(scheme, got.Values)));
    }

    [Fact]
    public void Repeat_WhenRound_SkippedRoundKeepsItsPlaceAndRepacksTheSameBytes()
    {
        // Arrange
        var scheme = WhenRepeat();
        var raw = Convert.FromHexString("01020109");

        // Act
        var got = BinaryPacker.Read(scheme, raw);
        var again = BinaryPacker.Pack(scheme, got.Values);

        // Assert
        Assert.Null(got.Error);
        Assert.Equal([2, 1], Cells(got.Values["K"]));
        Assert.Equal([null, 9], Cells(got.Values["V"]));
        Assert.Equal(Hex(raw), Hex(again));
    }

    [Fact]
    public void Repeat_WhenRound_ValueNeverSet_IsAListOfNulls()
    {
        // Arrange
        var raw = Convert.FromHexString("010202");

        // Act
        var got = BinaryPacker.Read(WhenRepeat(), raw);

        // Assert
        Assert.Null(got.Error);
        Assert.Equal([2, 2], Cells(got.Values["K"]));
        Assert.Equal([null, null], Cells(got.Values["V"]));
    }

    [Fact]
    public void Times_WhenRound_PacksOnlyTheMatchingRounds()
    {
        // Arrange
        var values = new Dictionary<string, object?>
        {
            ["A"] = (byte)2,
            ["K"] = new byte[] { 1, 2 },
            ["V"] = new byte[] { 9 },
        };

        // Act
        var raw = BinaryPacker.Pack(WhenTimes(), values);

        // Assert
        Assert.Equal("0102010902", Hex(raw));
    }

    [Fact]
    public void Times_WhenRound_SkippedRoundKeepsItsPlaceAndRepacksTheSameBytes()
    {
        // Arrange
        var scheme = WhenTimes();
        var raw = Convert.FromHexString("0102020109");

        // Act
        var got = BinaryPacker.Read(scheme, raw);
        var again = BinaryPacker.Pack(scheme, got.Values);

        // Assert
        Assert.Null(got.Error);
        Assert.Equal([2, 1], Cells(got.Values["K"]));
        Assert.Equal([null, 9], Cells(got.Values["V"]));
        Assert.Equal(Hex(raw), Hex(again));
    }

    [Fact]
    public void Repeat_ContinuingGroupRound_PacksItsFieldsByRoundIndex()
    {
        // Arrange
        var scheme = new Scheme<RoundRow>(1,
            Field.Repeat(0,
                Field.U8<RoundRow>(0, x => x.K),
                Field.Group(1, (RoundRow x) => x.Mark, Field.U8<RoundRow>(1, x => x.V))));
        var values = new Dictionary<string, object?>
        {
            ["K"] = new byte[] { 1, 2 },
            ["V"] = new byte[] { 7, 8 },
        };

        // Act
        var raw = BinaryPacker.Pack(scheme, values);
        var got = BinaryPacker.Read(scheme, raw);

        // Assert
        Assert.Equal("0101070208", Hex(raw));
        Assert.Equal([7, 8], Cells(got.Values["V"]));
    }

    [Fact]
    public void Repeat_ScalarValues_StillMakeOneRound()
    {
        // Arrange
        var values = new Dictionary<string, object?> { ["K"] = (byte)1, ["V"] = (byte)9 };

        // Act
        var raw = BinaryPacker.Pack(WhenRepeat(), values);

        // Assert
        Assert.Equal("010109", Hex(raw));
    }

    [Fact]
    public void Repeat_MultiSlotU2Round_PacksEverySlotByRoundIndex()
    {
        // Arrange
        var scheme = new Scheme<RoundRow>(1,
            Field.Repeat(0,
                Field.U8<RoundRow>(0, x => x.K),
                Field.U2<RoundRow>((1, x => x.P), (2, x => x.Q))));
        var values = new Dictionary<string, object?>
        {
            ["K"] = new byte[] { 1, 2 },
            ["P"] = new[] { 1, 2 },
            ["Q"] = new[] { 3, 0 },
        };

        // Act
        var raw = BinaryPacker.Pack(scheme, values);
        var got = BinaryPacker.Read(scheme, raw);
        var again = BinaryPacker.Pack(scheme, got.Values);

        // Assert
        Assert.Equal("01010d0202", Hex(raw));
        Assert.Null(got.Error);
        Assert.Equal([1, 2], Cells(got.Values["P"]));
        Assert.Equal([3, 0], Cells(got.Values["Q"]));
        Assert.Equal(Hex(raw), Hex(again));
    }

    [Fact]
    public void Repeat_GroupInsideFlagsRound_PacksTheGroupBitAndValuePerRound()
    {
        // Arrange
        var scheme = new Scheme<RoundRow>(1,
            Field.Repeat(0,
                Field.Flags(0, Field.Group(0, (RoundRow x) => x.Mark, Field.U8<RoundRow>(0, x => x.V)))));
        var values = new Dictionary<string, object?>
        {
            ["V"] = new object?[] { (byte)7, null, (byte)9 },
        };

        // Act
        var raw = BinaryPacker.Pack(scheme, values);
        var got = BinaryPacker.Read(scheme, raw);
        var again = BinaryPacker.Pack(scheme, got.Values);

        // Assert
        Assert.Equal("010107000109", Hex(raw));
        Assert.Null(got.Error);
        Assert.Equal([7, null, 9], Cells(got.Values["V"]));
        Assert.False(got.Values.ContainsKey("Mark"));
        Assert.Equal(Hex(raw), Hex(again));
    }

    [Fact]
    public void Repeat_GroupInsideFlagsRound_OwnMemberTurnsTheBitOnSoAMissingValueIsRefused()
    {
        // Arrange
        var scheme = new Scheme<RoundRow>(1,
            Field.Repeat(0,
                Field.Flags(0, Field.Group(0, (RoundRow x) => x.Mark, Field.U8<RoundRow>(0, x => x.V)))));
        var values = new Dictionary<string, object?>
        {
            ["Mark"] = new object?[] { true },
        };

        // Act
        var ex = Assert.Throws<ArgumentException>(() => BinaryPacker.Pack(scheme, values));

        // Assert
        Assert.Contains("'V'", ex.Message, StringComparison.Ordinal);
        Assert.Contains("is set, so it needs a value", ex.Message, StringComparison.Ordinal);
    }

    [Fact]
    public void Repeat_NestedRowGroupRound_PacksItsFieldsByRoundIndex()
    {
        // Arrange
        var scheme = new Scheme<RoundRow>(1,
            Field.Repeat(0,
                Field.U8<RoundRow>(0, x => x.K),
                Field.Group((RoundRow x) => x.Row, Field.U8<Inner>(0, x => x.V))));
        var values = new Dictionary<string, object?>
        {
            ["K"] = new byte[] { 1, 2 },
            ["V"] = new byte[] { 7, 8 },
        };

        // Act
        var raw = BinaryPacker.Pack(scheme, values);
        var got = BinaryPacker.Read(scheme, raw);
        var again = BinaryPacker.Pack(scheme, got.Values);

        // Assert
        Assert.Equal("0101070208", Hex(raw));
        Assert.Null(got.Error);
        Assert.Equal([7, 8], Cells(got.Values["V"]));
        Assert.Equal(Hex(raw), Hex(again));
    }

    [Fact]
    public void Repeat_NoRounds_LeavesTheKeysAbsentAndRepacksTheSameBytes()
    {
        // Arrange
        var scheme = WhenRepeat();
        var raw = Convert.FromHexString("01");

        // Act
        var got = BinaryPacker.Read(scheme, raw);
        var again = BinaryPacker.Pack(scheme, got.Values);

        // Assert
        Assert.Null(got.Error);
        Assert.False(got.Values.ContainsKey("K"));
        Assert.False(got.Values.ContainsKey("V"));
        Assert.Equal(Hex(raw), Hex(again));
    }

    [Fact]
    public void Times_ZeroCount_LeavesTheKeysAbsentAndRepacksTheSameBytes()
    {
        // Arrange
        var scheme = WhenTimes();
        var raw = Convert.FromHexString("0100");

        // Act
        var got = BinaryPacker.Read(scheme, raw);
        var again = BinaryPacker.Pack(scheme, got.Values);

        // Assert
        Assert.Null(got.Error);
        Assert.False(got.Values.ContainsKey("K"));
        Assert.False(got.Values.ContainsKey("V"));
        Assert.Equal(Hex(raw), Hex(again));
    }
}
