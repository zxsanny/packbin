using Packbin;

namespace Packbin.Tests;

// AZ-2191: a dictionary row's number is checked against the field it is packed to. An integer field takes a whole number
// that fits, a float field any number; a bare OverflowException, a rounded fraction or a coerced bool or string is gone.
public class StrictNumberTests
{
    private sealed class NumRow
    {
        public byte U8 { get; set; }
        public sbyte I8 { get; set; }
        public ushort U16 { get; set; }
        public short I16 { get; set; }
        public uint U32 { get; set; }
        public int I32 { get; set; }
        public ulong U64 { get; set; }
        public long I64 { get; set; }
        public float F32 { get; set; }
        public double F64 { get; set; }
        public List<object?>? Xs { get; set; }
    }

    private static Field One(string kind) => kind switch
    {
        "U8" => Field.U8<NumRow>(0, x => x.U8),
        "I8" => Field.I8<NumRow>(0, x => x.I8),
        "U16" => Field.U16<NumRow>(0, x => x.U16),
        "I16" => Field.I16<NumRow>(0, x => x.I16),
        "U32" => Field.U32<NumRow>(0, x => x.U32),
        "I32" => Field.I32<NumRow>(0, x => x.I32),
        "U64" => Field.U64<NumRow>(0, x => x.U64),
        "I64" => Field.I64<NumRow>(0, x => x.I64),
        "F32" => Field.F32<NumRow>(0, x => x.F32),
        _ => Field.F64<NumRow>(0, x => x.F64),
    };

    private static string Hex(byte[] raw) => Convert.ToHexString(raw).ToLowerInvariant();

    private static byte[] Pack(string kind, object value) =>
        BinaryPacker.Pack(new Scheme<NumRow>(1, One(kind)), new Dictionary<string, object?> { [kind] = value });

    private static void ExpectRefused(Func<byte[]> pack, string member, string kind)
    {
        var error = Assert.Throws<ArgumentException>(pack);

        Assert.Contains($"{member}:", error.Message, StringComparison.Ordinal);
        Assert.Contains(kind.ToLowerInvariant(), error.Message, StringComparison.Ordinal);
    }

    public static TheoryData<string, object> DoNotFit() => new()
    {
        { "U8", 300 },
        { "U8", -1 },
        { "I8", 200 },
        { "U16", 65536 },
        { "I16", -32769 },
        { "U32", 4294967296L },
        { "I32", 3000000000L },
        { "I64", 9223372036854775808UL },
        { "U64", -1 },
        { "U8", 256.0 },
        { "U64", 1e20 },
        { "I64", -1e20 },
    };

    [Theory]
    [MemberData(nameof(DoNotFit))]
    public void Pack_IntegerThatDoesNotFit_ThrowsNamingMemberAndKind(string kind, object value) =>
        ExpectRefused(() => Pack(kind, value), kind, kind);

    [Theory]
    [InlineData(1.5)]
    [InlineData(double.NaN)]
    [InlineData(double.PositiveInfinity)]
    [InlineData(true)]
    [InlineData("5")]
    public void Pack_FractionBoolOrStringForAnInteger_ThrowsNamingTheMember(object value) =>
        ExpectRefused(() => Pack("U8", value), "U8", "U8");

    [Theory]
    [InlineData("F64", "1.5")]
    [InlineData("F64", true)]
    [InlineData("F32", "1.5")]
    [InlineData("F32", false)]
    [InlineData("F32", 1e39)]
    [InlineData("F32", -1e39)]
    public void Pack_StringBoolOrOverflowForAFloat_ThrowsNamingTheMember(string kind, object value) =>
        ExpectRefused(() => Pack(kind, value), kind, kind);

    [Theory]
    [InlineData(float.PositiveInfinity, "0000807f")]
    [InlineData(float.NegativeInfinity, "000080ff")]
    public void Pack_F32Infinity_IsWritten(float value, string hex) =>
        Assert.Equal("01" + hex, Hex(Pack("F32", value)));

    [Theory]
    [InlineData("F32", 5)]
    [InlineData("F64", 9)]
    public void Pack_Nan_IsWritten(string kind, int length)
    {
        // Act
        var raw = Pack(kind, double.NaN);

        // Assert
        Assert.Equal(length, raw.Length);
    }

    [Theory]
    [InlineData(2, "0000000000000040")]
    [InlineData(2L, "0000000000000040")]
    [InlineData(1.5f, "000000000000f83f")]
    [InlineData(1.5, "000000000000f83f")]
    public void Pack_AnyNumericTypeForF64_Packs(object value, string hex) => Assert.Equal("01" + hex, Hex(Pack("F64", value)));

    public static TheoryData<string, object, string> Valid() => new()
    {
        { "U8", (byte)0, "0100" },
        { "U8", (byte)255, "01ff" },
        { "I8", (sbyte)-128, "0180" },
        { "I8", (sbyte)127, "017f" },
        { "U16", (ushort)65535, "01ffff" },
        { "I16", (short)-32768, "010080" },
        { "U32", 4294967295u, "01ffffffff" },
        { "I32", int.MinValue, "0100000080" },
        { "U64", ulong.MaxValue, "01ffffffffffffffff" },
        { "I64", long.MinValue, "010000000000000080" },
        { "U8", 5.0, "0105" },
        { "U8", 5L, "0105" },
        { "U32", 4294967295.0, "01ffffffff" },
        { "I16", -2.0f, "01feff" },
        { "U64", 18446744073709549568.0, "0100f8ffffffffffff" },
        { "U8", 5m, "0105" },
    };

    [Theory]
    [MemberData(nameof(Valid))]
    public void Pack_NumberThatFits_PacksAsBefore(string kind, object value, string hex) => Assert.Equal(hex, Hex(Pack(kind, value)));

    [Fact]
    public void Pack_RowReadByUnpack_PacksAgainToTheSameBytes()
    {
        // Arrange
        var scheme = new Scheme<NumRow>(1,
            Field.U8<NumRow>(0, x => x.U8), Field.I8<NumRow>(1, x => x.I8), Field.U16<NumRow>(2, x => x.U16).Be(),
            Field.I16<NumRow>(3, x => x.I16), Field.U32<NumRow>(4, x => x.U32), Field.I32<NumRow>(5, x => x.I32),
            Field.U64<NumRow>(6, x => x.U64), Field.I64<NumRow>(7, x => x.I64), Field.F32<NumRow>(8, x => x.F32),
            Field.F64<NumRow>(9, x => x.F64));
        var bytes = Convert.FromHexString(
            "01" + "ff" + "80" + "ffff" + "0080" + "ffffffff" + "00000080" + "ffffffffffffffff" + "0000000000000080"
            + "0000807f" + "000000000000f83f");

        // Act
        var read = BinaryPacker.Read(scheme, bytes);
        var again = BinaryPacker.Pack(scheme, read.Values);

        // Assert
        Assert.Null(read.Error);
        Assert.Equal(Hex(bytes), Hex(again));
    }

    [Fact]
    public void Pack_BigEndianFieldWithAValueThatDoesNotFit_Throws() =>
        ExpectRefused(
            () => BinaryPacker.Pack(
                new Scheme<NumRow>(1, Field.U16<NumRow>(0, x => x.U16).Be()),
                new Dictionary<string, object?> { ["U16"] = 70000 }),
            "U16",
            "U16");

    [Fact]
    public void Pack_ValueInsideFlagsRepeatAndListElement_IsChecked()
    {
        // Arrange
        var inFlags = new Scheme<NumRow>(1, Field.Flags(0, Field.U8<NumRow>(0, x => x.U8)));
        var inRepeat = new Scheme<NumRow>(1, Field.Repeat(0, Field.U8<NumRow>(0, x => x.U8)));
        var inList = new Scheme<NumRow>(1, Field.List((NumRow x) => x.Xs, Field.U8<NumRow>(0, x => x.U8)));

        // Act
        var flags = Record.Exception(() => BinaryPacker.Pack(inFlags, new Dictionary<string, object?> { ["U8"] = 300 }));
        var repeat = Record.Exception(() => BinaryPacker.Pack(inRepeat, new Dictionary<string, object?> { ["U8"] = new object?[] { 1, 300 } }));
        var list = Record.Exception(() => BinaryPacker.Pack(inList, new Dictionary<string, object?> { ["Xs"] = new List<object?> { 1, 300 } }));

        // Assert
        Assert.All([flags, repeat, list], e => Assert.IsType<ArgumentException>(e));
    }
}
