using Packbin;

namespace Packbin.Tests;

// AZ-2128: a flags group's bit is on when any value inside it is present, at any depth: a nested `Flags` and a split
// flag bit inside the group count, and a set group that lacks a required value fails pack naming it.
public class FlagGroupPresenceTests
{
    private sealed class Row
    {
        public bool? Mark { get; set; }
        public byte? B { get; set; }
        public byte? C { get; set; }
    }

    private static string Hex(byte[] raw) => Convert.ToHexString(raw).ToLowerInvariant();

    private static Row Unpack(Scheme<Row> scheme, byte[] raw)
    {
        Row? got = null;
        var err = BinaryPacker.Unpack(raw, scheme.On(v => got = v));
        Assert.Null(err);
        Assert.NotNull(got);
        return got;
    }

    private static Scheme<Row> NestedFlags(bool withRequired)
    {
        var members = withRequired
            ? new[] { Field.Flags(0, Field.U8<Row>(0, x => x.B)), Field.U8<Row>(1, x => x.C) }
            : [Field.Flags(0, Field.U8<Row>(0, x => x.B))];
        return new Scheme<Row>(1, Field.Flags(0, Field.Group(0, (Row x) => x.Mark, members)));
    }

    private static Scheme<Row> SplitBits(bool withRequired)
    {
        var m = Field.FlagByte();
        var members = withRequired
            ? new[] { m, m.Bit(Field.U8<Row>(0, x => x.B)), Field.U8<Row>(1, x => x.C) }
            : [m, m.Bit(Field.U8<Row>(0, x => x.B))];
        return new Scheme<Row>(1, Field.Flags(0, Field.Group(0, (Row x) => x.Mark, members)));
    }

    public static TheoryData<string> Forms() => new() { "nested flags", "split bit" };

    private static Scheme<Row> Build(string form, bool withRequired) =>
        form == "nested flags" ? NestedFlags(withRequired) : SplitBits(withRequired);

    [Theory]
    [MemberData(nameof(Forms))]
    public void ValueInANestedContainer_SetsTheGroupBitAndRoundTrips(string form)
    {
        // Arrange
        var scheme = Build(form, withRequired: false);

        // Act
        var raw = BinaryPacker.Pack(scheme, new Row { B = 5 });
        var got = Unpack(scheme, raw);

        // Assert
        Assert.Equal("01" + "01" + "01" + "05", Hex(raw));
        Assert.Equal((byte)5, got.B);
        Assert.Null(got.Mark);
    }

    [Theory]
    [MemberData(nameof(Forms))]
    public void NoValueAnywhere_LeavesTheGroupBitClear(string form)
    {
        // Arrange
        var scheme = Build(form, withRequired: false);

        // Act
        var raw = BinaryPacker.Pack(scheme, new Row());

        // Assert
        Assert.Equal("0100", Hex(raw));
    }

    [Theory]
    [MemberData(nameof(Forms))]
    public void NestedContainerHasAValueButARequiredSiblingIsNull_FailsNamingTheSibling(string form)
    {
        // Arrange
        var scheme = Build(form, withRequired: true);

        // Act
        var ex = Assert.Throws<ArgumentException>(() => BinaryPacker.Pack(scheme, new Row { B = 5 }));

        // Assert
        Assert.Contains("'C'", ex.Message, StringComparison.Ordinal);
        Assert.Contains("is set, so it needs a value", ex.Message, StringComparison.Ordinal);
    }

    [Theory]
    [MemberData(nameof(Forms))]
    public void NestedContainerHasAValueAndTheSiblingToo_WritesBothAndRoundTrips(string form)
    {
        // Arrange
        var scheme = Build(form, withRequired: true);

        // Act
        var raw = BinaryPacker.Pack(scheme, new Row { B = 5, C = 7 });
        var got = Unpack(scheme, raw);

        // Assert
        Assert.Equal("01" + "01" + "01" + "05" + "07", Hex(raw));
        Assert.Equal((byte)5, got.B);
        Assert.Equal((byte)7, got.C);
    }

    [Fact]
    public void RequiredSiblingAloneStillSetsTheBit()
    {
        // Arrange
        var scheme = NestedFlags(withRequired: true);

        // Act
        var raw = BinaryPacker.Pack(scheme, new Row { C = 7 });
        var got = Unpack(scheme, raw);

        // Assert
        Assert.Equal("01" + "01" + "00" + "07", Hex(raw));
        Assert.Null(got.B);
        Assert.Equal((byte)7, got.C);
    }
}
