using Packbin;

namespace Packbin.Tests;

// A group behind a flag bit has no presence of its own for each value: once the bit is on, the group is written in
// full, so every value in it must be there. A nested group or nested row inside it counts towards the bit.
public class FlagGroupValueTests
{
    private sealed class MixedRow
    {
        public bool? Mark { get; set; }
        public byte? V { get; set; }
        public int P { get; set; }
        public int Q { get; set; }
    }

    private sealed class SizedMixRow
    {
        public byte N { get; set; }
        public bool? Mark { get; set; }
        public byte? V { get; set; }
        public byte[] P { get; set; } = [];
    }

    private sealed class NullableRow
    {
        public bool? Mark { get; set; }
        public byte? V { get; set; }
        public ushort? W { get; set; }
    }

    private sealed class NestRow
    {
        public bool? Outer { get; set; }
        public bool? Inner { get; set; }
        public byte? V { get; set; }
    }

    private sealed class Leaf
    {
        public byte? W { get; set; }
    }

    private sealed class LeafRow
    {
        public bool? Outer { get; set; }
        public Leaf? Leaf { get; set; }
    }

    private static string Hex(byte[] raw) => Convert.ToHexString(raw).ToLowerInvariant();

    private static T UnpackRow<T>(Scheme<T> scheme, byte[] raw) where T : class, new()
    {
        T? got = null;
        var err = BinaryPacker.Unpack(raw, scheme.On(v => got = v));
        Assert.Null(err);
        Assert.NotNull(got);
        return got;
    }

    private static Field MixedGroup() =>
        Field.Group(0, (MixedRow x) => x.Mark,
            Field.U8<MixedRow>(0, x => x.V),
            Field.U2<MixedRow>((1, x => x.P), (2, x => x.Q)));

    private static Field NullableGroup() =>
        Field.Group(0, (NullableRow x) => x.Mark,
            Field.U8<NullableRow>(0, x => x.V),
            Field.U16<NullableRow>(1, x => x.W));

    [Fact]
    public void MixedGroup_U2AlwaysPresentAndVNull_ThrowsNamingV()
    {
        // Arrange
        var scheme = new Scheme<MixedRow>(1, Field.Flags(0, MixedGroup()));

        // Act
        var ex = Assert.Throws<ArgumentException>(() => BinaryPacker.Pack(scheme, new MixedRow()));

        // Assert
        Assert.Contains("'V'", ex.Message, StringComparison.Ordinal);
        Assert.Contains("is set, so it needs a value", ex.Message, StringComparison.Ordinal);
    }

    [Fact]
    public void MixedGroup_EmptySizedPayloadAndVNull_ThrowsNamingV()
    {
        // Arrange
        var scheme = new Scheme<SizedMixRow>(1,
            Field.U8<SizedMixRow>(0, x => x.N),
            Field.Flags(1, Field.Group(1, (SizedMixRow x) => x.Mark,
                Field.U8<SizedMixRow>(1, x => x.V),
                Field.Sized<SizedMixRow>(2, x => x.P, 0))));

        // Act
        var ex = Assert.Throws<ArgumentException>(() => BinaryPacker.Pack(scheme, new SizedMixRow { N = 0, P = [] }));

        // Assert
        Assert.Contains("'V'", ex.Message, StringComparison.Ordinal);
        Assert.Contains("is set, so it needs a value", ex.Message, StringComparison.Ordinal);
    }

    [Fact]
    public void MixedGroup_SplitFormBit_ThrowsNamingV()
    {
        // Arrange
        var m = Field.FlagByte();
        var scheme = new Scheme<MixedRow>(1, m, m.Bit(MixedGroup()));

        // Act
        var ex = Assert.Throws<ArgumentException>(() => BinaryPacker.Pack(scheme, new MixedRow()));

        // Assert
        Assert.Contains("'V'", ex.Message, StringComparison.Ordinal);
        Assert.Contains("is set, so it needs a value", ex.Message, StringComparison.Ordinal);
    }

    [Fact]
    public void MixedGroup_AllValuesSet_RoundTrips()
    {
        // Arrange
        var scheme = new Scheme<MixedRow>(1, Field.Flags(0, MixedGroup()));

        // Act
        var raw = BinaryPacker.Pack(scheme, new MixedRow { V = 7, P = 1, Q = 2 });
        var got = UnpackRow(scheme, raw);

        // Assert
        Assert.Equal("01010709", Hex(raw));
        Assert.Equal((byte)7, got.V);
        Assert.Equal(1, got.P);
        Assert.Equal(2, got.Q);
        Assert.Null(got.Mark);
    }

    [Fact]
    public void NullableGroup_OneValueNull_ThrowsNamingIt()
    {
        // Arrange
        var scheme = new Scheme<NullableRow>(1, Field.Flags(0, NullableGroup()));

        // Act
        var ex = Assert.Throws<ArgumentException>(() => BinaryPacker.Pack(scheme, new NullableRow { V = 5 }));

        // Assert
        Assert.Contains("'W'", ex.Message, StringComparison.Ordinal);
        Assert.Contains("is set, so it needs a value", ex.Message, StringComparison.Ordinal);
    }

    [Fact]
    public void NullableGroup_AllNull_LeavesTheBitClear()
    {
        // Arrange
        var scheme = new Scheme<NullableRow>(1, Field.Flags(0, NullableGroup()));

        // Act
        var raw = BinaryPacker.Pack(scheme, new NullableRow());
        var got = UnpackRow(scheme, raw);

        // Assert
        Assert.Equal("0100", Hex(raw));
        Assert.Null(got.V);
        Assert.Null(got.W);
    }

    [Fact]
    public void NestedGroupChild_WithAValue_SetsTheBitAndWritesIt()
    {
        // Arrange
        var scheme = new Scheme<NestRow>(1,
            Field.Flags(0, Field.Group(0, (NestRow x) => x.Outer,
                Field.Group(0, (NestRow x) => x.Inner, Field.U8<NestRow>(0, x => x.V)))));

        // Act
        var raw = BinaryPacker.Pack(scheme, new NestRow { V = 5 });
        var got = UnpackRow(scheme, raw);

        // Assert
        Assert.Equal("010105", Hex(raw));
        Assert.Equal((byte)5, got.V);
    }

    [Fact]
    public void NestedGroupChild_OuterMemberSetAndValueNull_ThrowsNamingV()
    {
        // Arrange
        var scheme = new Scheme<NestRow>(1,
            Field.Flags(0, Field.Group(0, (NestRow x) => x.Outer,
                Field.Group(0, (NestRow x) => x.Inner, Field.U8<NestRow>(0, x => x.V)))));

        // Act
        var ex = Assert.Throws<ArgumentException>(() => BinaryPacker.Pack(scheme, new NestRow { Outer = true }));

        // Assert
        Assert.Contains("'V'", ex.Message, StringComparison.Ordinal);
        Assert.Contains("is set, so it needs a value", ex.Message, StringComparison.Ordinal);
    }

    [Fact]
    public void NestedRowChild_WithAValue_SetsTheBitAndWritesIt()
    {
        // Arrange
        var scheme = new Scheme<LeafRow>(1,
            Field.Flags(0, Field.Group(0, (LeafRow x) => x.Outer,
                Field.Group((LeafRow x) => x.Leaf, Field.U8<Leaf>(0, l => l.W)))));

        // Act
        var raw = BinaryPacker.Pack(scheme, new LeafRow { Leaf = new Leaf { W = 5 } });
        var got = UnpackRow(scheme, raw);

        // Assert
        Assert.Equal("010105", Hex(raw));
        Assert.Equal((byte)5, got.Leaf?.W);
    }
}
