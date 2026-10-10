using Packbin;

namespace Packbin.Tests;

// AZ-2306: a non-null typed nested row is a value that is present, even when every member of it is null. Pack sets the
// group's bit and fails naming the first missing member, instead of dropping the object without an error.
public class EmptyNestedRowTests
{
    private sealed class Leaf
    {
        public byte? A { get; set; }
        public byte? B { get; set; }
    }

    private sealed class Mid
    {
        public byte? M { get; set; }
        public Leaf? Leaf { get; set; }
    }

    private sealed class Top
    {
        public Mid? Mid { get; set; }
    }

    private sealed class Wrapper
    {
        public byte? Id { get; set; }
        public Leaf? Leaf { get; set; }
    }

    private static string Hex(byte[] raw) => Convert.ToHexString(raw).ToLowerInvariant();

    private static Scheme<Wrapper> Depth1() => new(1,
        Field.Flags(0, Field.Group((Wrapper x) => x.Leaf, Field.U8<Leaf>(0, l => l.A), Field.U8<Leaf>(1, l => l.B))));

    private static Scheme<Top> Depth2() => new(1,
        Field.Flags(0, Field.Group((Top x) => x.Mid,
            Field.U8<Mid>(0, m => m.M),
            Field.Group((Mid m) => m.Leaf, Field.U8<Leaf>(0, l => l.A)))));

    [Fact]
    public void Pack_AllNullObjectUnderFlags_FailsNamingTheFirstMissingMember()
    {
        // Arrange
        var row = new Wrapper { Leaf = new Leaf() };

        // Act
        var error = Assert.Throws<ArgumentException>(() => BinaryPacker.Pack(Depth1(), row));

        // Assert
        Assert.Contains("'A'", error.Message, StringComparison.Ordinal);
    }

    [Fact]
    public void Pack_AllNullObjectAtDepthTwo_FailsNamingTheFirstMissingMember()
    {
        // Arrange
        var row = new Top { Mid = new Mid() };

        // Act
        var error = Assert.Throws<ArgumentException>(() => BinaryPacker.Pack(Depth2(), row));

        // Assert
        Assert.Contains("'M'", error.Message, StringComparison.Ordinal);
    }

    [Fact]
    public void Pack_FilledMidWithAllNullInnerObject_FailsNamingTheInnerMember()
    {
        // Arrange
        var row = new Top { Mid = new Mid { M = 4, Leaf = new Leaf() } };

        // Act
        var error = Assert.Throws<ArgumentException>(() => BinaryPacker.Pack(Depth2(), row));

        // Assert
        Assert.Contains("'A'", error.Message, StringComparison.Ordinal);
    }

    [Fact]
    public void Pack_NullNestedRow_BitClearAndBytesUnchanged()
    {
        // Act
        var one = BinaryPacker.Pack(Depth1(), new Wrapper());
        var two = BinaryPacker.Pack(Depth2(), new Top());

        // Assert
        Assert.Equal("0100", Hex(one));
        Assert.Equal("0100", Hex(two));
    }

    [Fact]
    public void Pack_FilledObject_BytesAndRoundTripUnchanged()
    {
        // Arrange
        var scheme = Depth2();
        var row = new Top { Mid = new Mid { M = 4, Leaf = new Leaf { A = 6 } } };

        // Act
        var raw = BinaryPacker.Pack(scheme, row);
        Top? got = null;
        var error = BinaryPacker.Unpack(raw, scheme.On(v => got = v));

        // Assert
        Assert.Equal("01010406", Hex(raw));
        Assert.Null(error);
        Assert.Equal((byte)6, got!.Mid!.Leaf!.A);
    }
}
