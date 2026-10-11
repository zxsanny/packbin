using System.Diagnostics;
using Packbin;
using static Packbin.Tests.Budget;

namespace Packbin.Tests;

// AZ-2354: pack refuses, naming the member and before the append that would pass it, a packet longer than the scheme's
// maxBytes (default 16 MiB, the type byte counts). The rows are the numbered rows of
// _docs/03_implementation/reference_loop20_budget.md (the TypeScript reference).
public class PackOutputBudgetTests
{
    private static Scheme<BudgetRow> LoneUtf8Times() => new(1,
        Field.U32<BudgetRow>(0, x => x.N),
        Field.Times(1, 0, Field.Utf8<BudgetRow>(1, x => x.S)));

    private static Scheme<Bag> ElementTimes() => new(1,
        Field.List((Bag x) => x.Items,
            Field.Group(0, (BudgetWideItem e) => e.Mark,
                Field.U32<BudgetWideItem>(0, e => e.N),
                Field.Times(1, 0, Field.U64<BudgetWideItem>(1, e => e.K)))));

    private sealed class Bag
    {
        public List<object?>? Items { get; set; }
    }

    private static Scheme<BudgetRow> Utf8Only(long maxBytes) =>
        new Scheme<BudgetRow>(1, Field.Utf8<BudgetRow>(0, x => x.S)).WithLimits(maxBytes: maxBytes);

    private static Scheme<BudgetRow> RepeatK(long maxBytes) =>
        new Scheme<BudgetRow>(1, Field.Repeat(0, Field.U8<BudgetRow>(0, x => x.K))).WithLimits(maxBytes: maxBytes);

    private static string Words(long packet, long limit, string member) =>
        $"'{member}': the packet would be {packet} bytes, above the limit of {limit} bytes";

    private static List<object?> Items(int count, uint n)
    {
        var items = new List<object?>();
        for (var i = 0; i < count; i++)
            items.Add(new Dictionary<string, object?> { ["N"] = n, ["K"] = 5UL });
        return items;
    }

    [Theory]
    [InlineData(true)]
    [InlineData(false)]
    public void Ac1_Pack_LoneUtf8UnderACappedTimes_IsRefusedNamingTheMember(bool typed)
    {
        // Arrange
        var scheme = LoneUtf8Times();
        var text = new string('a', 65_535);

        // Act
        var error = typed
            ? Refused(scheme, Typed(("N", 65_535u), ("S", text)))
            : Refused(scheme, Row(("N", 65_535u), ("S", text)));

        // Assert (5 + 255 * 65 537 bytes are written; the next utf8 append is 65 537)
        Assert.Equal(Words(16_777_477, 16_777_216, "S"), error.Message);
    }

    [Fact]
    public void Ac1_Pack_LoneUtf8UnderACappedTimes_IsRefusedFastAndWithoutGrowingTheBufferPastTheBudget()
    {
        // Arrange
        var scheme = LoneUtf8Times();
        var values = Row(("N", 65_535u), ("S", new string('a', 65_535)));
        Refused(scheme, values);
        var allocated = GC.GetAllocatedBytesForCurrentThread();
        var clock = Stopwatch.StartNew();

        // Act
        Refused(scheme, values);

        // Assert (a buffer that doubled past the budget would allocate 2 GB; the test allocates the 255 rounds' text, ~17 MB)
        clock.Stop();
        Assert.True(clock.ElapsedMilliseconds < 1_000, $"took {clock.ElapsedMilliseconds} ms");
        var spent = GC.GetAllocatedBytesForCurrentThread() - allocated;
        Assert.True(spent < 256L * 1024 * 1024, $"allocated {spent} bytes");
    }

    [Fact]
    public void Ac2_Pack_ElementsThatEachHoldATimes_AreRefusedAtTheDefaultAndPackWithARaisedBudget()
    {
        // Arrange
        var scheme = ElementTimes();
        var values = new Dictionary<string, object?> { ["Items"] = Items(40, 65_535) };

        // Act
        var error = Refused(scheme, values);
        var raw = BinaryPacker.Pack(scheme.WithLimits(maxBytes: 33_554_432), values);
        var read = BinaryPacker.Read(scheme, raw);

        // Assert (item 32, round 15: 3 + 32 * 524 284 + 4 + 15 * 8 = 16 777 215 bytes are written)
        Assert.Equal(Words(16_777_223, 16_777_216, "K"), error.Message);
        Assert.Equal(20_971_363, raw.Length);
        Assert.Equal("012800ffff0000050000000000000005", Hex(raw, 0, 16));
        Assert.Equal("05000000000000000500000000000000", Hex(raw, raw.Length - 16, 16));
        Assert.Null(read.Error);
        var items = (List<object?>)read.Values["Items"]!;
        Assert.Equal(40, items.Count);
        var last = (Dictionary<string, object?>)items[39]!;
        Assert.Equal(65_535.0, last["N"]);
        Assert.Equal(65_535, ((List<object?>)last["K"]!).Count);
        Assert.All((List<object?>)last["K"]!, k => Assert.Equal(5UL, k));
    }

    [Fact]
    public void Ac2_Pack_ElementsOfTypedRows_AreRefusedAtTheDefault()
    {
        // Arrange
        var scheme = ElementTimes();
        var items = new List<object?>();
        for (var i = 0; i < 40; i++)
            items.Add(new BudgetWideItem { N = 65_535, K = 5 });

        // Act
        var error = Refused(scheme, new Bag { Items = items });

        // Assert
        Assert.Equal(Words(16_777_223, 16_777_216, "K"), error.Message);
    }

    [Theory]
    [InlineData(true)]
    [InlineData(false)]
    public void Ac3_Pack_Utf8PacketOfExactlyMaxBytes_Packs(bool typed)
    {
        // Arrange
        var scheme = Utf8Only(64);
        var text = new string('a', 61);

        // Act
        var raw = typed ? BinaryPacker.Pack(scheme, Typed(("S", text))) : BinaryPacker.Pack(scheme, Row(("S", text)));

        // Assert
        Assert.Equal(64, raw.Length);
        Assert.Equal("013d00" + string.Concat(Enumerable.Repeat("61", 61)), Hex(raw));
    }

    [Theory]
    [InlineData(true)]
    [InlineData(false)]
    public void Ac3_Pack_Utf8PacketOneByteOverMaxBytes_IsRefused(bool typed)
    {
        // Arrange
        var scheme = Utf8Only(64);
        var text = new string('a', 62);

        // Act
        var error = typed ? Refused(scheme, Typed(("S", text))) : Refused(scheme, Row(("S", text)));

        // Assert
        Assert.Equal(Words(65, 64, "S"), error.Message);
    }

    [Fact]
    public void Ac3_Pack_RepeatPacketOfExactlyMaxBytes_Packs()
    {
        // Arrange
        var scheme = RepeatK(64);

        // Act
        var raw = BinaryPacker.Pack(scheme, Row(("K", Repeated((byte)7, 63))));

        // Assert
        Assert.Equal("01" + string.Concat(Enumerable.Repeat("07", 63)), Hex(raw));
    }

    [Fact]
    public void Ac3_Pack_RepeatPacketOneByteOverMaxBytes_IsRefusedAtTheLastRound()
    {
        // Arrange
        var scheme = RepeatK(64);

        // Act
        var error = Refused(scheme, Row(("K", Repeated((byte)7, 64))));

        // Assert
        Assert.Equal(Words(65, 64, "K"), error.Message);
    }

    [Fact]
    public void Ac3_Pack_BareSchemeAtMaxBytesOne_PacksTheTypeByte()
    {
        // Arrange
        var scheme = new Scheme<BudgetRow>(1).WithLimits(maxBytes: 1);

        // Act
        var raw = BinaryPacker.Pack(scheme, Row());

        // Assert
        Assert.Equal("01", Hex(raw));
    }

    [Theory]
    [InlineData(true)]
    [InlineData(false)]
    public void Ac3_Pack_ScalarOverMaxBytesOne_NamesTheField(bool typed)
    {
        // Arrange
        var scheme = new Scheme<BudgetRow>(1, Field.U8<BudgetRow>(0, x => x.A)).WithLimits(maxBytes: 1);

        // Act
        var error = typed ? Refused(scheme, Typed(("A", 1))) : Refused(scheme, Row(("A", (byte)1)));

        // Assert
        Assert.Equal(Words(2, 1, "A"), error.Message);
    }

    [Fact]
    public void Ac3_Pack_SplitFlagByteOverMaxBytesOne_NamesTheFirstMemberItsBitsDeclare()
    {
        // Arrange (the C# FlagByte() has no name of its own)
        var byteHandle = Field.FlagByte();
        var scheme = new Scheme<BudgetRow>(1, byteHandle, byteHandle.Bit(Field.U8<BudgetRow>(0, x => x.C)))
            .WithLimits(maxBytes: 1);

        // Act
        var error = Refused(scheme, Typed(("C", 1)));

        // Assert
        Assert.Equal(Words(2, 1, "C"), error.Message);
    }

    [Theory]
    [InlineData(true)]
    [InlineData(false)]
    public void Ac3_Pack_CombinedFlagsByteOverMaxBytesOne_NamesTheFirstMember(bool typed)
    {
        // Arrange
        var scheme = new Scheme<BudgetRow>(1, Field.Flags(0, Field.U8<BudgetRow>(0, x => x.C))).WithLimits(maxBytes: 1);

        // Act
        var error = typed ? Refused(scheme, Typed(("C", 1))) : Refused(scheme, Row(("C", (byte)1)));

        // Assert
        Assert.Equal(Words(2, 1, "C"), error.Message);
    }

    [Fact]
    public void Ac3_Pack_CombinedFlagsByteOverTheBudget_IsNamedThroughATimes()
    {
        // Arrange
        var scheme = new Scheme<BudgetRow>(1,
            Field.U8<BudgetRow>(0, x => x.N8),
            Field.Flags(1, Field.Times(1, 0, Field.U8<BudgetRow>(1, x => x.K)))).WithLimits(maxBytes: 2);

        // Act
        var error = Refused(scheme, Typed(("N8", 1), ("K", 3)));

        // Assert
        Assert.Equal(Words(3, 2, "K"), error.Message);
    }

    [Fact]
    public void Ac3_Pack_ListCountPrefixOverTheBudget_NamesTheList()
    {
        // Arrange
        var scheme = new Scheme<BudgetRow>(1, Field.List((BudgetRow x) => x.Items, Field.U8<BudgetRow>(0, x => x.A)))
            .WithLimits(maxBytes: 2);

        // Act
        var error = Refused(scheme, Row(("Items", new List<object?>())));

        // Assert
        Assert.Equal(Words(3, 2, "Items"), error.Message);
    }

    [Fact]
    public void Ac3_Pack_DictCountPrefixAndKeyOverTheBudget_NameTheDict()
    {
        // Arrange
        var scheme = new Scheme<DictBag>(1, Field.Dict((DictBag x) => x.Access, Field.U8<BudgetRow>(0, x => x.A)));
        var one = Row(("Access", new Dictionary<string, object?> { ["key"] = (byte)1 }));

        // Act
        var count = Refused(scheme.WithLimits(maxBytes: 2), one);
        var key = Refused(scheme.WithLimits(maxBytes: 4), one);
        var packs = BinaryPacker.Pack(scheme.WithLimits(maxBytes: 9), one);

        // Assert
        Assert.Equal(Words(3, 2, "Access"), count.Message);
        Assert.Equal(Words(8, 4, "Access"), key.Message);
        Assert.Equal("01010003006b657901", Hex(packs));
    }

    private sealed class DictBag
    {
        public Dictionary<string, object?>? Access { get; set; }
    }

    [Fact]
    public void Ac3_Pack_BytesSizedBitsAndPackedOverTheBudget_NameTheField()
    {
        // Arrange
        var bytes = new Scheme<BytesRow>(1, Field.Bytes<BytesRow>(0, x => x.Raw, 4)).WithLimits(maxBytes: 4);
        var u2 = new Scheme<U2Row>(1, Field.U2<U2Row>((0, x => x.A), (1, x => x.B))).WithLimits(maxBytes: 1);

        // Act
        var raw = Refused(bytes, Row(("Raw", new byte[] { 1, 2, 3, 4 })));
        var slots = Refused(u2, Row(("A", 1), ("B", 2)));

        // Assert
        Assert.Equal(Words(5, 4, "Raw"), raw.Message);
        Assert.Equal(Words(2, 1, "A"), slots.Message);
    }

    private sealed class BytesRow
    {
        public byte[] Raw { get; set; } = [];
    }

    private sealed class U2Row
    {
        public int A { get; set; }
        public int B { get; set; }
    }

    [Fact]
    public void Ac5_Limits_MaxBytesDefaultsAndIsKeptByTheOtherLimitCalls()
    {
        // Arrange
        var scheme = new Scheme<BudgetRow>(1, Field.U8<BudgetRow>(0, x => x.A));

        // Act
        var raised = scheme.WithLimits(maxBytes: 64);

        // Assert (an omitted limit is the default, as for maxRounds and maxSlots)
        Assert.Equal(16_777_216, scheme.MaxBytes);
        Assert.Equal(BinaryPacker.DefaultMaxBytes, scheme.MaxBytes);
        Assert.Equal(16_777_216, scheme.WithLimits(maxRounds: 9).MaxBytes);
        Assert.Equal(64, raised.MaxBytes);
        Assert.Equal(16_777_216, raised.WithLimits(maxSlots: 9).MaxBytes);
    }

    [Theory]
    [InlineData(0L)]
    [InlineData(-1L)]
    [InlineData(long.MinValue)]
    public void Ac5_Limits_MaxBytesBelowOne_IsRefusedLikeTheOtherLimits(long value)
    {
        // Arrange
        var scheme = new Scheme<BudgetRow>(1);

        // Act
        var error = Assert.Throws<ArgumentOutOfRangeException>(() => scheme.WithLimits(maxBytes: value));

        // Assert
        Assert.Equal("maxBytes", error.ParamName);
    }

    [Fact]
    public void Ac5_Limits_MaxBytesIsCheckedBeyondTheIntRange()
    {
        // Arrange
        var scheme = new Scheme<BudgetRow>(1, Field.U8<BudgetRow>(0, x => x.A)).WithLimits(maxBytes: 4_000_000_000);

        // Act
        var raw = BinaryPacker.Pack(scheme, Row(("A", (byte)1)));

        // Assert
        Assert.Equal("0101", Hex(raw));
    }

    [Fact]
    public void Ac6_Pack_LimitsRaisedByTheExistingCallForms_KeepTheBytes()
    {
        // Arrange
        var scheme = new Scheme<BudgetRow>(1,
            Field.U32<BudgetRow>(0, x => x.N),
            Field.Times(1, 0, Field.U8<BudgetRow>(1, x => x.K))).WithLimits(3, 3);

        // Act
        var named = scheme.WithLimits(maxRounds: 3, maxSlots: 3);
        var raw = BinaryPacker.Pack(scheme, Typed(("N", 3u), ("K", 7)));
        var again = BinaryPacker.Pack(named, Row(("N", 3u), ("K", (byte)7)));

        // Assert
        Assert.Equal("0103000000070707", Hex(raw));
        Assert.Equal(Hex(raw), Hex(again));
    }
}
