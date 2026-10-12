using Packbin;

namespace Packbin.Tests;

// AZ-2373: unpack returns each integer field as its exact type, and an integer field refuses a float, double or decimal on
// pack (a whole one too), so a row unpack returned packs again to the same bytes.
public class ExactIntegerTypeTests
{
    private sealed class Wide
    {
        public byte A { get; set; }
        public ushort B { get; set; }
        public uint C { get; set; }
        public sbyte D { get; set; }
        public short E { get; set; }
        public int F { get; set; }
        public ulong G { get; set; }
        public long H { get; set; }
        public float I { get; set; }
        public double J { get; set; }
        public List<object?>? Items { get; set; }
    }

    private static string Hex(byte[] raw) => Convert.ToHexString(raw).ToLowerInvariant();

    private static Scheme<Wide> Everything() => new(1,
        Field.U8<Wide>(0, x => x.A),
        Field.U16<Wide>(1, x => x.B).Be(),
        Field.U32<Wide>(2, x => x.C),
        Field.I8<Wide>(3, x => x.D),
        Field.I16<Wide>(4, x => x.E).Be(),
        Field.I32<Wide>(5, x => x.F),
        Field.U64<Wide>(6, x => x.G),
        Field.I64<Wide>(7, x => x.H),
        Field.F32<Wide>(8, x => x.I),
        Field.F64<Wide>(9, x => x.J));

    private const string EverythingHex =
        "01" + "ff" + "0102" + "01000000" + "80" + "ff00" + "ffffffff" + "ffffffffffffffff" + "ffffffffffffffff" + "0000a040"
        + "000000000000f83f";

    [Fact]
    public void Ac1_Unpack_IntegerFields_ReturnTheirExactTypes()
    {
        // Act
        var read = BinaryPacker.Read(Everything(), Convert.FromHexString(EverythingHex));

        // Assert
        Assert.Null(read.Error);
        Assert.Equal((byte)255, Assert.IsType<byte>(read.Values["A"]));
        Assert.Equal((ushort)258, Assert.IsType<ushort>(read.Values["B"]));
        Assert.Equal(1u, Assert.IsType<uint>(read.Values["C"]));
        Assert.Equal((sbyte)-128, Assert.IsType<sbyte>(read.Values["D"]));
        Assert.Equal((short)-256, Assert.IsType<short>(read.Values["E"]));
        Assert.Equal(-1, Assert.IsType<int>(read.Values["F"]));
        Assert.Equal(ulong.MaxValue, Assert.IsType<ulong>(read.Values["G"]));
        Assert.Equal(-1L, Assert.IsType<long>(read.Values["H"]));
        Assert.Equal(5.0, Assert.IsType<double>(read.Values["I"]));
        Assert.Equal(1.5, Assert.IsType<double>(read.Values["J"]));
    }

    [Fact]
    public void Ac1_Unpack_IntegerFieldsInRoundsAndElements_ReturnTheirExactTypes()
    {
        // Arrange
        var rounds = new Scheme<Wide>(1, Field.Repeat(0, Field.U16<Wide>(0, x => x.B), Field.I8<Wide>(1, x => x.D)));
        var elements = new Scheme<Wide>(1, Field.List((Wide x) => x.Items, Field.U32<Wide>(0, x => x.C)));

        // Act
        var round = BinaryPacker.Read(rounds, Convert.FromHexString("01" + "0100" + "ff" + "0200" + "7f"));
        var element = BinaryPacker.Read(elements, Convert.FromHexString("01" + "0200" + "05000000" + "06000000"));

        // Assert
        Assert.Null(round.Error);
        Assert.Equal(new object?[] { (ushort)1, (ushort)2 }, ((List<object?>)round.Values["B"]!).ToArray());
        Assert.Equal(new object?[] { (sbyte)-1, (sbyte)127 }, ((List<object?>)round.Values["D"]!).ToArray());
        Assert.Null(element.Error);
        Assert.Equal(new object?[] { 5u, 6u }, ((List<object?>)element.Values["Items"]!).ToArray());
    }

    [Fact]
    public void Ac3_Pack_UnpackedRowOfEveryKind_GivesTheSameBytes()
    {
        // Arrange
        var scheme = Everything();
        var bytes = Convert.FromHexString(EverythingHex);

        // Act
        var again = BinaryPacker.Pack(scheme, BinaryPacker.Read(scheme, bytes).Values);

        // Assert
        Assert.Equal(Hex(bytes), Hex(again));
    }

    [Fact]
    public void Ac3_Pack_UnpackedRounds_GiveTheSameBytes()
    {
        // Arrange
        var scheme = new Scheme<Wide>(1,
            Field.U8<Wide>(0, x => x.A),
            Field.Times(1, 0, Field.U16<Wide>(1, x => x.B).Be(), Field.I8<Wide>(2, x => x.D)));
        var bytes = Convert.FromHexString("01" + "02" + "0100" + "ff" + "0203" + "7f");

        // Act
        var read = BinaryPacker.Read(scheme, bytes);
        var again = BinaryPacker.Pack(scheme, read.Values);

        // Assert
        Assert.Null(read.Error);
        Assert.Equal(Hex(bytes), Hex(again));
    }

    [Theory]
    [InlineData("A", 5.0)]
    [InlineData("A", 5f)]
    [InlineData("B", 258.0)]
    [InlineData("C", 4294967295.0)]
    [InlineData("D", -128.0)]
    [InlineData("E", -2f)]
    [InlineData("F", 0.0)]
    [InlineData("G", 1.0)]
    [InlineData("H", -1.0)]
    public void Ac2_Pack_WholeDoubleOrFloatForAnIntegerField_IsRefusedNamingTheField(string member, object whole)
    {
        // Arrange
        var values = Copy(BinaryPacker.Read(Everything(), Convert.FromHexString(EverythingHex)).Values);
        values[member] = whole;

        // Act
        var error = Assert.Throws<ArgumentException>(() => BinaryPacker.Pack(Everything(), values));

        // Assert
        Assert.StartsWith($"{member}:", error.Message, StringComparison.Ordinal);
    }

    [Fact]
    public void Ac2_Pack_WholeDecimalForAnIntegerField_IsRefusedNamingTheField()
    {
        // Arrange
        var values = Copy(BinaryPacker.Read(Everything(), Convert.FromHexString(EverythingHex)).Values);
        values["A"] = 5m;

        // Act
        var error = Assert.Throws<ArgumentException>(() => BinaryPacker.Pack(Everything(), values));

        // Assert
        Assert.StartsWith("A:", error.Message, StringComparison.Ordinal);
    }

    [Fact]
    public void Ac2_Pack_WholeFloatsForFloatFields_StillPack()
    {
        // Arrange
        var values = Copy(BinaryPacker.Read(Everything(), Convert.FromHexString(EverythingHex)).Values);
        values["I"] = 5.0;
        values["J"] = 2f;

        // Act
        var raw = BinaryPacker.Pack(Everything(), values);

        // Assert
        Assert.EndsWith("0000a040" + "0000000000000040", Hex(raw), StringComparison.Ordinal);
    }

    [Fact]
    public void Ac2_Pack_WholeDoubleInARepeatRoundOrListElement_IsRefused()
    {
        // Arrange
        var rounds = new Scheme<Wide>(1, Field.Repeat(0, Field.U8<Wide>(0, x => x.A)));
        var elements = new Scheme<Wide>(1, Field.List((Wide x) => x.Items, Field.U8<Wide>(0, x => x.A)));

        // Act
        var round = Record.Exception(() => BinaryPacker.Pack(rounds, new Dictionary<string, object?> { ["A"] = new object?[] { (byte)1, 2.0 } }));
        var element = Record.Exception(() => BinaryPacker.Pack(elements, new Dictionary<string, object?> { ["Items"] = new List<object?> { 3.0 } }));

        // Assert
        Assert.IsType<ArgumentException>(round);
        Assert.StartsWith("A:", round.Message, StringComparison.Ordinal);
        Assert.IsType<ArgumentException>(element);
        Assert.StartsWith("A:", element.Message, StringComparison.Ordinal);
    }

    private static Dictionary<string, object?> Copy(Dictionary<string, object?> read) => new(read);
}
