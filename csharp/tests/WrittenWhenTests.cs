using Packbin;

namespace Packbin.Tests;

// A `when` is decided from the fields the pack wrote in the same scope, as unpack decides it from the fields it read.
// A tested field that was skipped or absent does not match, so pack never returns bytes its own read rejects or
// misparses.
public class WrittenWhenTests
{
    private sealed class ChainRow
    {
        public byte Profile { get; set; }
        public byte? Shape { get; set; }
        public byte? Detail { get; set; }
    }

    private sealed class RoundRow
    {
        public byte? K { get; set; }
        public byte? A { get; set; }
        public byte? B { get; set; }
        public byte? V { get; set; }
        public bool? On { get; set; }
    }

    private sealed class RequiredRow
    {
        public byte? A { get; set; }
    }

    private static string Hex(byte[] raw) => Convert.ToHexString(raw).ToLowerInvariant();

    private static Scheme<ChainRow> Chain() => new(1,
        Field.U8<ChainRow>(0, x => x.Profile),
        Field.When(1, Condition.Eq(0, (byte)0), Field.U8<ChainRow>(1, x => x.Shape)),
        Field.When(2, Condition.Eq(1, (byte)0), Field.U8<ChainRow>(2, x => x.Detail)));

    private static Scheme<RoundRow> RoundChain() => new(1,
        Field.Repeat(0,
            Field.U8<RoundRow>(0, x => x.K),
            Field.When(1, Condition.Eq(0, (byte)1), Field.U8<RoundRow>(1, x => x.A)),
            Field.When(2, Condition.Eq(1, (byte)5), Field.U8<RoundRow>(2, x => x.B))));

    private static object?[] Items(object? list) => [.. (List<object?>)list!];

    [Fact]
    public void Ac1_Typed_SkippedFieldDoesNotMatchTheNextWhen()
    {
        // Arrange
        var scheme = Chain();
        var row = new ChainRow { Profile = 1, Shape = 0, Detail = 4 };
        ChainRow? got = null;

        // Act
        var raw = BinaryPacker.Pack(scheme, row);
        var err = BinaryPacker.Unpack(raw, scheme.On(r => got = r));

        // Assert
        Assert.Equal("0101", Hex(raw));
        Assert.Null(err);
        Assert.Equal(1, got!.Profile);
        Assert.Null(got.Shape);
        Assert.Null(got.Detail);
    }

    [Fact]
    public void Ac1_Typed_FieldsThatWereWrittenStillDecide()
    {
        // Arrange
        var scheme = Chain();
        var row = new ChainRow { Profile = 0, Shape = 0, Detail = 4 };
        ChainRow? got = null;

        // Act
        var raw = BinaryPacker.Pack(scheme, row);
        var err = BinaryPacker.Unpack(raw, scheme.On(r => got = r));

        // Assert
        Assert.Equal("01000004", Hex(raw));
        Assert.Null(err);
        Assert.Equal((byte?)4, got!.Detail);
    }

    [Fact]
    public void Ac2_Round_SkippedFieldDoesNotMatchTheNextWhen()
    {
        // Arrange
        var scheme = RoundChain();
        var values = new Dictionary<string, object?>
        {
            ["K"] = new object?[] { (byte)0 },
            ["A"] = new object?[] { (byte)5 },
            ["B"] = new object?[] { (byte)3 },
        };

        // Act
        var raw = BinaryPacker.Pack(scheme, values);
        var got = BinaryPacker.Read(scheme, raw);

        // Assert
        Assert.Equal("0100", Hex(raw));
        Assert.Null(got.Error);
        Assert.Equal(new int?[] { 0 }, RoundValueTests.Cells(got.Values["K"]));
        Assert.Equal(new int?[] { null }, RoundValueTests.Cells(got.Values["A"]));
        Assert.Equal(new int?[] { null }, RoundValueTests.Cells(got.Values["B"]));
    }

    [Fact]
    public void Ac2_Round_TheSkipIsDecidedPerRound()
    {
        // Arrange
        var scheme = RoundChain();
        var values = new Dictionary<string, object?>
        {
            ["K"] = new object?[] { (byte)0, (byte)1 },
            ["A"] = new object?[] { (byte)5, (byte)5 },
            ["B"] = new object?[] { (byte)3, (byte)3 },
        };

        // Act
        var raw = BinaryPacker.Pack(scheme, values);
        var got = BinaryPacker.Read(scheme, raw);

        // Assert
        Assert.Equal("010001" + "0503", Hex(raw));
        Assert.Null(got.Error);
        Assert.Equal(new int?[] { null, 5 }, RoundValueTests.Cells(got.Values["A"]));
        Assert.Equal(new int?[] { null, 3 }, RoundValueTests.Cells(got.Values["B"]));
    }

    [Fact]
    public void Ac2_Round_AWriteInAnEarlierRoundDoesNotCount()
    {
        // Arrange
        var scheme = RoundChain();
        var values = new Dictionary<string, object?>
        {
            ["K"] = new object?[] { (byte)1, (byte)0 },
            ["A"] = new object?[] { (byte)5, (byte)5 },
            ["B"] = new object?[] { (byte)3, (byte)3 },
        };

        // Act
        var raw = BinaryPacker.Pack(scheme, values);
        var got = BinaryPacker.Read(scheme, raw);

        // Assert
        Assert.Equal("0101050300", Hex(raw));
        Assert.Null(got.Error);
        Assert.Equal(new int?[] { 5, null }, RoundValueTests.Cells(got.Values["A"]));
        Assert.Equal(new int?[] { 3, null }, RoundValueTests.Cells(got.Values["B"]));
    }

    [Fact]
    public void Ac3_Round_AWhenSeesAnEarlierFieldOfItsOwnRound()
    {
        // Arrange
        var scheme = new Scheme<RoundRow>(1,
            Field.Repeat(0,
                Field.U8<RoundRow>(0, x => x.K),
                Field.When(1, Condition.Eq(0, (byte)1), Field.U8<RoundRow>(1, x => x.V))));
        var values = new Dictionary<string, object?>
        {
            ["K"] = new object?[] { (byte)1, (byte)2 },
            ["V"] = new object?[] { (byte)9 },
        };

        // Act
        var raw = BinaryPacker.Pack(scheme, values);
        var got = BinaryPacker.Read(scheme, raw);
        var again = BinaryPacker.Pack(scheme, got.Values);

        // Assert
        Assert.Equal("01010902", Hex(raw));
        Assert.Null(got.Error);
        Assert.Equal(Hex(raw), Hex(again));
    }

    [Fact]
    public void Ac3_Round_AWhenNamingAFlagBoolSeesItOnlyWhenTheBitWasSet()
    {
        // Arrange
        var scheme = new Scheme<RoundRow>(1,
            Field.Repeat(0,
                Field.Flags(0, Field.Bool<RoundRow>(0, x => x.On)),
                Field.When(1, Condition.Eq(0, true), Field.U8<RoundRow>(1, x => x.V))));
        var values = new Dictionary<string, object?>
        {
            ["On"] = new object?[] { true, false },
            ["V"] = new object?[] { (byte)7, (byte)8 },
        };

        // Act
        var raw = BinaryPacker.Pack(scheme, values);
        var got = BinaryPacker.Read(scheme, raw);

        // Assert
        Assert.Equal("01010700", Hex(raw));
        Assert.Null(got.Error);
        Assert.Equal(new int?[] { 7, null }, RoundValueTests.Cells(got.Values["V"]));
    }

    [Fact]
    public void Ac7_WhenOnABoolWithAClearBit_DoesNotMatch()
    {
        // Arrange
        var scheme = new Scheme<RoundRow>(1,
            Field.Flags(0, Field.Bool<RoundRow>(0, x => x.On)),
            Field.When(1, Condition.Eq(0, false), Field.U8<RoundRow>(1, x => x.V)));
        var row = new RoundRow { On = false, V = 7 };
        RoundRow? got = null;

        // Act
        var raw = BinaryPacker.Pack(scheme, row);
        var err = BinaryPacker.Unpack(raw, scheme.On(r => got = r));

        // Assert
        Assert.Equal("0100", Hex(raw));
        Assert.Null(err);
        Assert.Null(got!.V);
    }

    [Fact]
    public void Ac4_FailedPack_DoesNotAdvanceTheSession()
    {
        // Arrange
        var scheme = new Scheme<RequiredRow>(1, Field.U8<RequiredRow>(0, x => x.A));
        var seed = new byte[PackSession.SeedSize];
        var opener = PackSession.Load(seed)!;
        var waiter = PackSession.Load(seed)!;
        Assert.True(waiter.Join(opener.Start()!));
        RequiredRow? got = null;

        // Act
        Assert.Throws<ArgumentException>(() => opener.Pack(scheme, new RequiredRow()));
        var packet = opener.Pack(scheme, new RequiredRow { A = 7 });
        var err = waiter.Unpack(packet!, scheme.On(r => got = r));

        // Assert
        Assert.Null(err);
        Assert.Equal((byte?)7, got!.A);
    }

    [Fact]
    public void Ac5_SplitFlagByteInARound_PacksReadsAlignedAndRepacks()
    {
        // Arrange
        var m = Field.FlagByte();
        var scheme = new Scheme<RoundRow>(1,
            Field.Repeat(0, m, m.Bit(Field.U8<RoundRow>(0, x => x.A)), m.Bit(Field.Bool<RoundRow>(1, x => x.On))));
        var values = new Dictionary<string, object?>
        {
            ["A"] = new object?[] { (byte)1, null, (byte)3 },
            ["On"] = new object?[] { true, true, null },
        };

        // Act
        var raw = BinaryPacker.Pack(scheme, values);
        var got = BinaryPacker.Read(scheme, raw);
        var again = BinaryPacker.Pack(scheme, got.Values);

        // Assert
        Assert.Equal("010301020103", Hex(raw));
        Assert.Null(got.Error);
        Assert.Equal(new int?[] { 1, null, 3 }, RoundValueTests.Cells(got.Values["A"]));
        Assert.Equal(new object?[] { true, true, null }, Items(got.Values["On"]));
        Assert.Equal(Hex(raw), Hex(again));
    }
}
