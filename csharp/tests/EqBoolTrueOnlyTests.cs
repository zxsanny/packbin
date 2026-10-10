using Packbin;

namespace Packbin.Tests;

// AZ-2126 (owner decision 2026-10-06): a `when` names an integer or a bool, and a bool only against `true`. Any other
// scheme fails at construction naming the `when` and its field. A bool count and a float count are refused by
// CountKindTests (AZ-2181).
public class EqBoolTrueOnlyTests
{
    private sealed class Row
    {
        public bool? On { get; set; }
        public byte? W { get; set; }
        public float F { get; set; }
        public double D { get; set; }
        public string S { get; set; } = "";
        public byte[] Raw { get; set; } = [];
        public byte N { get; set; }
        public byte[] Data { get; set; } = [];
        public List<int>? Segs { get; set; }
        public List<int>? Kinds { get; set; }
        public int Slot { get; set; }
        public long L { get; set; }
    }

    private static string Hex(byte[] raw) => Convert.ToHexString(raw).ToLowerInvariant();

    private static Scheme<Row> OnWhen(object? value) => new(1,
        Field.Flags(0, Field.Bool<Row>(0, x => x.On)),
        Field.When(1, Condition.Eq(0, value!), Field.U8<Row>(1, x => x.W)));

    public static TheoryData<object?, string> NonTrueValues() => new()
    {
        { false, "false" },
        { 1, "1" },
        { "yes", "yes" },
        { (byte)1, "1" },
        { null, "null" },
    };

    [Theory]
    [MemberData(nameof(NonTrueValues))]
    public void Ac1_EqBoolAgainstANonTrueValue_FailsConstructionNamingTheWhenAndTheField(object? value, string shown)
    {
        // Act
        var error = Assert.Throws<ArgumentException>(() => OnWhen(value));

        // Assert
        Assert.Equal($"when 1 tests bool field 0 ('On') against {shown}; a bool is compared only with true", error.Message);
    }

    [Fact]
    public void Ac1_EqBoolFalseOnAFlagByteBit_FailsConstruction()
    {
        // Arrange
        var m = Field.FlagByte();

        // Act
        var error = Assert.Throws<ArgumentException>(() => new Scheme<Row>(1,
            m, m.Bit(Field.Bool<Row>(0, x => x.On)),
            Field.When(1, Condition.Eq(0, false), Field.U8<Row>(1, x => x.W))));

        // Assert
        Assert.Contains("when 1 tests bool field 0", error.Message, StringComparison.Ordinal);
        Assert.Contains("only with true", error.Message, StringComparison.Ordinal);
    }

    [Fact]
    public void Ac1_EqBoolFalseInsideARepeatRound_FailsConstruction()
    {
        // Act
        var error = Assert.Throws<ArgumentException>(() => new Scheme<Row>(1,
            Field.Repeat(0,
                Field.Flags(0, Field.Bool<Row>(0, x => x.On)),
                Field.When(1, Condition.Eq(0, false), Field.U8<Row>(1, x => x.W)))));

        // Assert
        Assert.Contains("when 1 tests bool field 0", error.Message, StringComparison.Ordinal);
    }

    [Fact]
    public void Ac2_EqBoolTrue_PacksAndRoundTripsTyped()
    {
        // Arrange
        var scheme = OnWhen(true);
        Row? got = null;

        // Act
        var raw = BinaryPacker.Pack(scheme, new Row { On = true, W = 5 });
        var err = BinaryPacker.Unpack(raw, scheme.On(r => got = r));

        // Assert
        Assert.Equal("010105", Hex(raw));
        Assert.Null(err);
        Assert.True(got!.On);
        Assert.Equal((byte)5, got.W);
    }

    [Fact]
    public void Ac2_EqBoolTrue_PacksAndRoundTripsInDictionaryMode()
    {
        // Arrange
        var scheme = OnWhen(true);
        var row = new Dictionary<string, object?> { ["On"] = true, ["W"] = (byte)5 };

        // Act
        var raw = BinaryPacker.Pack(scheme, row);
        var got = BinaryPacker.Read(scheme, raw);

        // Assert
        Assert.Equal("010105", Hex(raw));
        Assert.Null(got.Error);
        Assert.Equal(true, got.Values["On"]);
        Assert.Equal(5, Convert.ToInt32(got.Values["W"]));
    }

    [Theory]
    [InlineData(false)]
    [InlineData(null)]
    public void Ac2_EqBoolTrueWithAClearBit_WritesNoBodyAndReadsBack(bool? on)
    {
        // Arrange
        var scheme = OnWhen(true);
        Row? got = null;

        // Act
        var raw = BinaryPacker.Pack(scheme, new Row { On = on, W = 5 });
        var err = BinaryPacker.Unpack(raw, scheme.On(r => got = r));

        // Assert
        Assert.Equal("0100", Hex(raw));
        Assert.Null(err);
        Assert.Null(got!.W);
    }

    private static (Field[] Before, int Source, string Member) Source(string kind) => kind switch
    {
        "f32" => ([Field.F32<Row>(0, x => x.F)], 0, "F"),
        "f64" => ([Field.F64<Row>(0, x => x.D)], 0, "D"),
        "utf8" => ([Field.Utf8<Row>(0, x => x.S)], 0, "S"),
        "bytes" => ([Field.Bytes<Row>(0, x => x.Raw, 2)], 0, "Raw"),
        "sized" => ([Field.U8<Row>(0, x => x.N), Field.Sized<Row>(1, x => x.Data, 0)], 1, "Data"),
        "bits" => ([Field.U8<Row>(0, x => x.N), Field.Bits<Row>(1, x => x.Segs, 0)], 1, "Segs"),
        "packed" => ([Field.U8<Row>(0, x => x.N), Field.Packed<Row>(2, 1, x => x.Kinds, 0)], 1, "Kinds"),
        _ => throw new ArgumentException(kind),
    };

    [Theory]
    [InlineData("f32")]
    [InlineData("f64")]
    [InlineData("utf8")]
    [InlineData("bytes")]
    [InlineData("sized")]
    [InlineData("bits")]
    [InlineData("packed")]
    public void Ac1_WhenNamingANonIntegerNonBoolField_FailsConstructionNamingTheWhenAndTheField(string kind)
    {
        // Arrange
        var (before, id, member) = Source(kind);

        // Act
        var error = Assert.Throws<ArgumentException>(() => new Scheme<Row>(1,
            [.. before, Field.When(before.Length, Condition.Eq(id, 1), Field.U8<Row>(before.Length, x => x.W))]));

        // Assert
        Assert.StartsWith($"when {before.Length} tests '{member}' (field id {id}), a {kind} field;", error.Message, StringComparison.Ordinal);
        Assert.EndsWith("a when names an integer or a bool field", error.Message, StringComparison.Ordinal);
    }

    [Fact]
    public void Ac1_WhenNamingAFloatInsideAListElement_FailsConstruction()
    {
        // Act
        var error = Assert.Throws<ArgumentException>(() => new Scheme<ListRow>(1,
            Field.List((ListRow x) => x.Xs,
                Field.Group(0, (Row x) => x.On,
                    Field.F32<Row>(0, x => x.F),
                    Field.When(1, Condition.Eq(0, 1.5), Field.U8<Row>(1, x => x.W))))));

        // Assert
        Assert.Contains("when 1 tests 'F' (field id 0), a f32 field", error.Message, StringComparison.Ordinal);
    }

    private sealed class ListRow
    {
        public List<object?>? Xs { get; set; }
    }

    [Theory]
    [InlineData("u8")]
    [InlineData("i64")]
    [InlineData("u2")]
    public void Ac1_WhenNamingAnInteger_StillBuildsPacksAndReadsBack(string kind)
    {
        // Arrange
        Field source = kind switch
        {
            "u8" => Field.U8<Row>(0, x => x.N),
            "i64" => Field.I64<Row>(0, x => x.L),
            _ => Field.U2<Row>((0, x => x.Slot)),
        };
        var scheme = new Scheme<Row>(1, source, Field.When(1, Condition.Eq(0, 1), Field.U8<Row>(1, x => x.W)));
        var row = new Dictionary<string, object?> { ["N"] = (byte)1, ["L"] = 1L, ["Slot"] = 1, ["W"] = (byte)9 };

        // Act
        var raw = BinaryPacker.Pack(scheme, row);
        var got = BinaryPacker.Read(scheme, raw);

        // Assert
        Assert.Equal((byte)9, raw[^1]);
        Assert.Null(got.Error);
        Assert.Equal(9, Convert.ToInt32(got.Values["W"]));
    }
}
