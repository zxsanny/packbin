using Packbin;

namespace Packbin.Tests;

// AZ-2121, C# parts: the orphan flag-bit rule (a split bit needs its flag byte earlier in the same scope) holds for a
// times round and a dict element (AC-1) and for a split bit held by a combined flags member (AC-4). Same-scope shapes
// still build.
public class FlagScopeContainerTests
{
    private sealed class El
    {
        public byte? V { get; set; }
        public bool? Mark { get; set; }
    }

    private sealed class Row
    {
        public byte C { get; set; }
        public byte? V { get; set; }
        public byte? A { get; set; }
        public byte? B { get; set; }
        public Dictionary<string, object?>? M { get; set; }
    }

    private static void ExpectRefused(Func<object> build, string bit)
    {
        var error = Assert.Throws<ArgumentException>(build);

        Assert.Equal($"flag bit '{bit}' has no flag byte read before it in its scope", error.Message);
    }

    [Fact]
    public void Construct_FlagByteOutsideATimesBody_BitInside_FailsNamingTheBit()
    {
        // Arrange
        var m = Field.FlagByte();

        // Act and Assert
        ExpectRefused(
            () => new Scheme<Row>(1, m, Field.U8<Row>(0, x => x.C), Field.Times(1, 0, m.Bit(Field.U8<Row>(1, x => x.V)))),
            "V");
    }

    [Fact]
    public void Construct_FlagByteOutsideADictElement_BitInside_FailsNamingTheBit()
    {
        // Arrange
        var m = Field.FlagByte();

        // Act and Assert
        ExpectRefused(() => new Scheme<Row>(1, m, Field.Dict((Row x) => x.M, m.Bit(Field.U8<El>(0, e => e.V)))), "V");
    }

    [Fact]
    public void Construct_FlagByteOutsideADictElementGroup_BitInside_FailsNamingTheBit()
    {
        // Arrange
        var m = Field.FlagByte();

        // Act and Assert
        ExpectRefused(
            () => new Scheme<Row>(1, m,
                Field.Dict((Row x) => x.M, Field.Group(0, (El e) => e.Mark, m.Bit(Field.U8<El>(0, e => e.V))))),
            "V");
    }

    [Fact]
    public void Construct_ByteAndBitInsideOneTimesBody_Builds()
    {
        // Arrange
        var m = Field.FlagByte();

        // Act
        var scheme = new Scheme<Row>(1,
            Field.U8<Row>(0, x => x.C),
            Field.Times(1, 0, m, m.Bit(Field.U8<Row>(1, x => x.V))));

        // Assert
        Assert.Equal(2, scheme.Fields.Count);
    }

    [Fact]
    public void Construct_ByteAndBitInsideOneDictElementGroup_Builds()
    {
        // Arrange
        var m = Field.FlagByte();

        // Act
        var scheme = new Scheme<Row>(1,
            Field.Dict((Row x) => x.M, Field.Group(0, (El e) => e.Mark, m, m.Bit(Field.U8<El>(0, e => e.V)))));

        // Assert
        Assert.Single(scheme.Fields);
    }

    [Fact]
    public void Construct_CombinedFlagsHoldingABitWhoseByteIsMissing_FailsNamingTheBit()
    {
        // Arrange
        var m = Field.FlagByte();

        // Act and Assert
        ExpectRefused(() => new Scheme<Row>(1, Field.Flags(0, m.Bit(Field.U8<Row>(0, x => x.A)))), "A");
    }

    [Fact]
    public void Construct_CombinedFlagsHoldingABitWhoseByteComesAfter_FailsNamingTheBit()
    {
        // Arrange
        var m = Field.FlagByte();

        // Act and Assert
        ExpectRefused(() => new Scheme<Row>(1, Field.Flags(0, m.Bit(Field.U8<Row>(0, x => x.A))), m), "A");
    }

    [Fact]
    public void Construct_SecondMemberOfCombinedFlagsIsAnOrphanBit_FailsNamingTheBit()
    {
        // Arrange
        var m = Field.FlagByte();

        // Act and Assert
        ExpectRefused(
            () => new Scheme<Row>(1, Field.Flags(0, Field.U8<Row>(0, x => x.A), m.Bit(Field.U8<Row>(1, x => x.B)))),
            "B");
    }

    [Fact]
    public void Construct_CombinedFlagsHoldingABitOfAnEarlierByte_Builds()
    {
        // Arrange
        var m = Field.FlagByte();

        // Act
        var scheme = new Scheme<Row>(1, m, Field.Flags(0, m.Bit(Field.U8<Row>(0, x => x.A))));

        // Assert
        Assert.Equal(2, scheme.Fields.Count);
    }
}
