using Packbin;

namespace Packbin.Tests;

// AZ-2135 (G4): a split-form flag bit is numbered by its place in the scheme among the bits that follow one read of
// its flag byte, as in Rust and C++, so a flag byte handle holds no bit and can be shared by any number of schemes.
public class SplitBitOrderTests
{
    private sealed class Row
    {
        public byte? A { get; set; }
        public byte? B { get; set; }
        public byte? X { get; set; }
    }

    private sealed class FiveRow
    {
        public byte? V0 { get; set; }
        public byte? V1 { get; set; }
        public byte? V2 { get; set; }
        public byte? V3 { get; set; }
        public byte? V4 { get; set; }
    }

    private sealed class EightRow
    {
        public byte? B0 { get; set; }
        public byte? B1 { get; set; }
        public byte? B2 { get; set; }
        public byte? B3 { get; set; }
        public byte? B4 { get; set; }
        public byte? B5 { get; set; }
        public byte? B6 { get; set; }
        public byte? B7 { get; set; }
        public byte? C0 { get; set; }
        public byte? C7 { get; set; }
    }

    private sealed class Inner
    {
        public byte? X { get; set; }
    }

    private sealed class Outer
    {
        public byte? A { get; set; }
        public Inner? G { get; set; }
        public byte? B { get; set; }
    }

    private static string Hex(byte[] raw) => Convert.ToHexString(raw).ToLowerInvariant();

    private static T Unpack<T>(Scheme<T> scheme, byte[] raw) where T : class, new()
    {
        T? got = null;
        var err = BinaryPacker.Unpack(raw, scheme.On(v => got = v));
        Assert.Null(err);
        Assert.NotNull(got);
        return got;
    }

    private static Field[] Five(Field m) =>
    [
        m.Bit(Field.U8<FiveRow>(0, x => x.V0)), m.Bit(Field.U8<FiveRow>(1, x => x.V1)), m.Bit(Field.U8<FiveRow>(2, x => x.V2)),
        m.Bit(Field.U8<FiveRow>(3, x => x.V3)), m.Bit(Field.U8<FiveRow>(4, x => x.V4)),
    ];

    [Fact]
    public void OneHandleInTwoSchemes_EachNumbersItsBitFromZero()
    {
        // Arrange
        var m = Field.FlagByte();
        var first = new Scheme<Row>(1, m, m.Bit(Field.U8<Row>(0, x => x.X)));
        var second = new Scheme<Row>(1, m, m.Bit(Field.U8<Row>(0, x => x.X)));

        // Act
        var a = BinaryPacker.Pack(first, new Row { X = 5 });
        var b = BinaryPacker.Pack(second, new Row { X = 5 });

        // Assert
        Assert.Equal("010105", Hex(a));
        Assert.Equal("010105", Hex(b));
        Assert.Equal((byte)5, Unpack(first, a).X);
        Assert.Equal((byte)5, Unpack(second, b).X);
    }

    [Fact]
    public void TwoFiveBitSchemesOnOneHandle_BothBuild()
    {
        // Arrange
        var m = Field.FlagByte();

        // Act
        var first = new Scheme<FiveRow>(1, [m, .. Five(m)]);
        var second = new Scheme<FiveRow>(2, [m, .. Five(m)]);
        var raw = BinaryPacker.Pack(second, new FiveRow { V4 = 7 });

        // Assert
        Assert.Equal(6, first.Fields.Count);
        Assert.Equal("02" + "10" + "07", Hex(raw));
        Assert.Equal((byte)7, Unpack(second, raw).V4);
    }

    [Fact]
    public void BitCreatedEarlyButPlacedLate_TakesItsPlaceInTheScheme()
    {
        // Arrange
        var m = Field.FlagByte();
        var late = m.Bit(Field.U8<Row>(1, x => x.B));
        var early = m.Bit(Field.U8<Row>(0, x => x.A));
        var scheme = new Scheme<Row>(1, m, early, late);

        // Act
        var onlyLate = BinaryPacker.Pack(scheme, new Row { B = 9 });
        var both = BinaryPacker.Pack(scheme, new Row { A = 4, B = 9 });

        // Assert
        Assert.Equal("010209", Hex(onlyLate));
        Assert.Equal("01030409", Hex(both));
        Assert.Equal((byte)9, Unpack(scheme, onlyLate).B);
        Assert.Null(Unpack(scheme, onlyLate).A);
    }

    [Fact]
    public void SecondReadOfTheSameByte_StartsItsOwnBits()
    {
        // Arrange
        var m = Field.FlagByte();
        var scheme = new Scheme<Row>(1,
            m, m.Bit(Field.U8<Row>(0, x => x.A)),
            m, m.Bit(Field.U8<Row>(1, x => x.B)));

        // Act
        var raw = BinaryPacker.Pack(scheme, new Row { B = 9 });
        var got = Unpack(scheme, raw);
        var both = BinaryPacker.Pack(scheme, new Row { A = 1, B = 9 });

        // Assert
        Assert.Equal("01000109", Hex(raw));
        Assert.Null(got.A);
        Assert.Equal((byte)9, got.B);
        Assert.Equal("0101010109", Hex(both));
    }

    [Fact]
    public void NinthBitOfOneRead_IsRefusedWhenTheSchemeIsBuilt()
    {
        // Arrange
        var m = Field.FlagByte();
        var fields = new Field[9];
        for (var i = 0; i < 9; i++)
            fields[i] = m.Bit(Field.U8<NineRow>(i, NineAccessor(i)));

        // Act
        var ex = Assert.Throws<ArgumentException>(() => new Scheme<NineRow>(1, [m, .. fields]));

        // Assert
        Assert.Contains("A8", ex.Message, StringComparison.Ordinal);
        Assert.Contains("8 bits", ex.Message, StringComparison.Ordinal);
    }

    [Fact]
    public void EightBitsPerRead_TwoReadsHoldSixteen()
    {
        // Arrange
        var m = Field.FlagByte();
        var scheme = new Scheme<EightRow>(1,
            m,
            m.Bit(Field.U8<EightRow>(0, x => x.B0)), m.Bit(Field.U8<EightRow>(1, x => x.B1)),
            m.Bit(Field.U8<EightRow>(2, x => x.B2)), m.Bit(Field.U8<EightRow>(3, x => x.B3)),
            m.Bit(Field.U8<EightRow>(4, x => x.B4)), m.Bit(Field.U8<EightRow>(5, x => x.B5)),
            m.Bit(Field.U8<EightRow>(6, x => x.B6)), m.Bit(Field.U8<EightRow>(7, x => x.B7)),
            m,
            m.Bit(Field.U8<EightRow>(8, x => x.C0)),
            m.Bit(Field.U8<EightRow>(9, x => x.C7)));

        // Act
        var raw = BinaryPacker.Pack(scheme, new EightRow { B7 = 1, C7 = 2 });

        // Assert
        Assert.Equal("01" + "80" + "01" + "02" + "02", Hex(raw));
    }

    [Fact]
    public void BitCreatedButNeverPlaced_LeavesNoTraceInTheFlagByte()
    {
        // Arrange
        var m = Field.FlagByte();
        _ = m.Bit(Field.U8<Row>(1, x => x.B));
        var scheme = new Scheme<Row>(1, m, m.Bit(Field.U8<Row>(0, x => x.A)));

        // Act
        var raw = BinaryPacker.Pack(scheme, new Row { A = 5, B = 7 });

        // Assert
        Assert.Equal("010105", Hex(raw));
        Assert.Null(Unpack(scheme, raw).B);
    }

    [Fact]
    public void NestedRowReadsItsOwnByte_OuterBitsKeepTheirNumbers()
    {
        // Arrange
        var m = Field.FlagByte();
        var scheme = new Scheme<Outer>(1,
            m, m.Bit(Field.U8<Outer>(0, x => x.A)),
            Field.Group((Outer x) => x.G, m, m.Bit(Field.U8<Inner>(0, i => i.X))),
            m.Bit(Field.U8<Outer>(1, x => x.B)));

        // Act
        var raw = BinaryPacker.Pack(scheme, new Outer { A = 1, G = new Inner { X = 2 }, B = 3 });
        var got = Unpack(scheme, raw);

        // Assert
        Assert.Equal("01" + "03" + "01" + "01" + "02" + "03", Hex(raw));
        Assert.Equal((byte)1, got.A);
        Assert.Equal((byte)2, got.G!.X);
        Assert.Equal((byte)3, got.B);
    }

    private sealed class NineRow
    {
        public byte? A0 { get; set; }
        public byte? A1 { get; set; }
        public byte? A2 { get; set; }
        public byte? A3 { get; set; }
        public byte? A4 { get; set; }
        public byte? A5 { get; set; }
        public byte? A6 { get; set; }
        public byte? A7 { get; set; }
        public byte? A8 { get; set; }
    }

    private static System.Linq.Expressions.Expression<Func<NineRow, byte?>> NineAccessor(int i) => i switch
    {
        0 => x => x.A0, 1 => x => x.A1, 2 => x => x.A2, 3 => x => x.A3, 4 => x => x.A4,
        5 => x => x.A5, 6 => x => x.A6, 7 => x => x.A7, _ => x => x.A8,
    };
}
