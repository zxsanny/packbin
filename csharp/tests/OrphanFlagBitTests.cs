using System.Globalization;
using Packbin;

namespace Packbin.Tests;

public class OrphanFlagBitTests
{
    private sealed class Row
    {
        public byte Mode { get; set; }
        public ushort? Heading { get; set; }
        public byte? Speed { get; set; }
        public List<object?>? Xs { get; set; }
    }

    private sealed class El
    {
        public byte? V { get; set; }
        public Item? Inner { get; set; }
    }

    private sealed class Item
    {
        public byte? V { get; set; }
    }

    private static int Int(object? value) => Convert.ToInt32(value, CultureInfo.InvariantCulture);

    [Fact]
    public void FlagByteInsideWhen_BitOutside_FailsNamingTheBit()
    {
        var m = Field.FlagByte();

        var ex = Assert.Throws<ArgumentException>(() => new Scheme<Row>(1,
            Field.U8<Row>(0, x => x.Mode),
            Field.When(1, Condition.Eq(0, 1), m),
            m.Bit(Field.U16<Row>(1, x => x.Heading))));

        Assert.Contains("Heading", ex.Message, StringComparison.Ordinal);
    }

    [Fact]
    public void FlagByteOutsideListElement_BitInside_FailsNamingTheBit()
    {
        var m = Field.FlagByte();

        var ex = Assert.Throws<ArgumentException>(() => new Scheme<Row>(1,
            m,
            Field.List((Row x) => x.Xs, m.Bit(Field.U8<El>(0, x => x.V)))));

        Assert.Contains("V", ex.Message, StringComparison.Ordinal);
    }

    [Fact]
    public void FlagByteOutsideRepeat_BitInside_FailsNamingTheBit()
    {
        var m = Field.FlagByte();

        var ex = Assert.Throws<ArgumentException>(() => new Scheme<Row>(1,
            m,
            Field.Repeat(0, m.Bit(Field.U8<Row>(0, x => x.Speed)))));

        Assert.Contains("Speed", ex.Message, StringComparison.Ordinal);
    }

    [Fact]
    public void BitBeforeItsFlagByte_FailsNamingTheBit()
    {
        var m = Field.FlagByte();

        var ex = Assert.Throws<ArgumentException>(() => new Scheme<Row>(1,
            m.Bit(Field.U16<Row>(0, x => x.Heading)),
            m));

        Assert.Contains("Heading", ex.Message, StringComparison.Ordinal);
    }

    [Fact]
    public void SameScopeFlagBit_StillBuildsAndRoundTrips()
    {
        var m = Field.FlagByte();
        var scheme = new Scheme<Row>(1,
            Field.U8<Row>(0, x => x.Mode),
            m,
            Field.When(1, Condition.Eq(0, 0), m.Bit(Field.U8<Row>(1, x => x.Speed))),
            m.Bit(Field.U16<Row>(2, x => x.Heading)));

        var raw = BinaryPacker.Pack(scheme, new Row { Mode = 1, Heading = 90 });
        var got = BinaryPacker.Read(scheme, raw);

        Assert.Equal("0101" + "02" + "5a00", Convert.ToHexString(raw).ToLowerInvariant());
        Assert.Null(got.Error);
        Assert.Equal(90, Int(got.Values["Heading"]));
        Assert.Equal(1, Int(got.Values["Mode"]));
        Assert.False(got.Values.ContainsKey("Speed"));
    }

    [Fact]
    public void BitInsideNestedWhen_UsingAnEnclosingScopeByte_BuildsAndRoundTrips()
    {
        var m = Field.FlagByte();
        var scheme = new Scheme<Row>(1,
            Field.U8<Row>(0, x => x.Mode),
            m,
            Field.When(1, Condition.Eq(0, 1),
                Field.When(1, Condition.Eq(0, 1), m.Bit(Field.U8<Row>(1, x => x.Speed)))));

        var raw = BinaryPacker.Pack(scheme, new Row { Mode = 1, Speed = 7 });
        var got = BinaryPacker.Read(scheme, raw);

        Assert.Equal("0101" + "01" + "07", Convert.ToHexString(raw).ToLowerInvariant());
        Assert.Null(got.Error);
        Assert.Equal(7, Int(got.Values["Speed"]));
    }

    // Building only: unpacking a group as a list element throws today because the element value is never stored.
    [Fact]
    public void ByteAndBitsTogetherInsideAGroupInAListElement_Build()
    {
        var m = Field.FlagByte();

        var scheme = new Scheme<Row>(1,
            Field.List((Row x) => x.Xs,
                Field.Group((El e) => e.Inner, m, m.Bit(Field.U8<Item>(0, x => x.V)))));

        Assert.Single(scheme.Fields);
    }

    [Fact]
    public void FlagByteAndBitsInsideOneRepeatRound_Build()
    {
        var m = Field.FlagByte();

        var scheme = new Scheme<Row>(1, Field.Repeat(0, m, m.Bit(Field.U8<Row>(0, x => x.Speed))));

        Assert.Single(scheme.Fields);
    }

    [Fact]
    public void CombinedFlagsContainingAWhen_BuildsAndUnpacks()
    {
        var scheme = new Scheme<Row>(1,
            Field.U8<Row>(0, x => x.Mode),
            Field.Flags(1,
                Field.When(1, Condition.Eq(0, 1), Field.U8<Row>(1, x => x.Speed)),
                Field.U16<Row>(2, x => x.Heading)));

        var got = BinaryPacker.Read(scheme, Convert.FromHexString("01" + "01" + "03" + "07" + "5a00"));

        Assert.Null(got.Error);
        Assert.Equal(7, Int(got.Values["Speed"]));
        Assert.Equal(90, Int(got.Values["Heading"]));
    }
}
