using Packbin;

namespace Packbin.Tests;

// A nested row reads and writes values of its own, so its flag byte and the bits that follow it live inside it.
public class NestedRowFlagByteTests
{
    private sealed class Inner
    {
        public byte? A { get; set; }
        public byte? B { get; set; }
    }

    private sealed class Outer
    {
        public byte Id { get; set; }
        public Inner? Inner { get; set; }
        public byte? After { get; set; }
    }

    private static string Hex(byte[] raw) => Convert.ToHexString(raw).ToLowerInvariant();

    [Fact]
    public void FlagByteAndBitsInsideANestedRow_RoundTrip()
    {
        // Arrange
        var m = Field.FlagByte();
        var scheme = new Scheme<Outer>(1,
            Field.U8<Outer>(0, x => x.Id),
            Field.Group((Outer x) => x.Inner, m, m.Bit(Field.U8<Inner>(0, i => i.A)), m.Bit(Field.U8<Inner>(1, i => i.B))));

        // Act
        var raw = BinaryPacker.Pack(scheme, new Outer { Id = 9, Inner = new Inner { B = 5 } });
        Outer? got = null;
        var err = BinaryPacker.Unpack(raw, scheme.On(v => got = v));

        // Assert
        Assert.Equal("01090205", Hex(raw));
        Assert.Null(err);
        Assert.Equal((byte)9, got!.Id);
        Assert.Null(got.Inner!.A);
        Assert.Equal((byte)5, got.Inner.B);
    }

    [Fact]
    public void FlagByteOutsideANestedRow_BitInside_FailsNamingTheBit()
    {
        // Arrange
        var m = Field.FlagByte();

        // Act
        var ex = Assert.Throws<ArgumentException>(() => new Scheme<Outer>(1,
            m,
            Field.Group((Outer x) => x.Inner, m.Bit(Field.U8<Inner>(0, i => i.A)))));

        // Assert
        Assert.Contains("'A'", ex.Message, StringComparison.Ordinal);
    }

    [Fact]
    public void FlagByteInsideANestedRow_BitAfterIt_FailsNamingTheBit()
    {
        // Arrange
        var m = Field.FlagByte();

        // Act
        var ex = Assert.Throws<ArgumentException>(() => new Scheme<Outer>(1,
            Field.Group((Outer x) => x.Inner, m, Field.U8<Inner>(0, i => i.A)),
            m.Bit(Field.U8<Outer>(0, x => x.After))));

        // Assert
        Assert.Contains("After", ex.Message, StringComparison.Ordinal);
    }
}
