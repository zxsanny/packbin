using Packbin;

namespace Packbin.Tests;

// AZ-2476 (D1) and AZ-2478 (D7), loop 25: two hostile rows probed against TypeScript, the reference, and pinned here
// with the hex TypeScript produced for each (a throwaway script on typescript/src/index.ts, 2026-10-14).
//   D1: an anchored group with no members is a presence mark that takes no wire id of its own, so the field after it
//       reuses its number, and no `eq` can name the mark.
//   D7: a split flag bit named inside a `when` whose condition is false still sets its bit; unpack reads no body, and
//       the repack of what unpack returned clears the bit.
public class Loop25ProbeD1D7Tests
{
    private sealed class Row
    {
        public byte K { get; set; }
        public bool Mark { get; set; }
        public byte? N { get; set; }
        public byte? A { get; set; }
        public byte? B { get; set; }
        public byte? V { get; set; }
    }

    private static string Hex(byte[] raw) => Convert.ToHexString(raw).ToLowerInvariant();

    private static string Pack(Scheme<Row> scheme, Dictionary<string, object?> row) =>
        Hex(BinaryPacker.Pack(scheme, row));

    private static Dictionary<string, object?> Read(Scheme<Row> scheme, string wire)
    {
        var read = BinaryPacker.Read(scheme, Convert.FromHexString(wire));
        Assert.Null(read.Error);
        return read.Values;
    }

    private static Row Unpack(Scheme<Row> scheme, string wire)
    {
        Row? got = null;
        var err = BinaryPacker.Unpack(Convert.FromHexString(wire), scheme.On(v => got = v));
        Assert.Null(err);
        Assert.NotNull(got);
        return got;
    }

    // Flags(0, Group(0,"mark"))
    private static Scheme<Row> EmptyMark() => new(1, Field.Flags(0, Field.Group(0, (Row x) => x.Mark)));

    // m, m.Bit(Group(0,"mark")), m.Bit(U8(0,"n"))
    private static Scheme<Row> MarkSplit()
    {
        var m = Field.FlagByte();
        return new Scheme<Row>(1, m, m.Bit(Field.Group(0, (Row x) => x.Mark)), m.Bit(Field.U8<Row>(0, x => x.N)));
    }

    // Flags(0, Group(0,"mark")), U8(0,"n"): the mark's anchor 0 is the next id, yet it takes none, so the U8 is id 0 too.
    private static Scheme<Row> MarkThenU8() =>
        new(1, Field.Flags(0, Field.Group(0, (Row x) => x.Mark)), Field.U8<Row>(0, x => x.N));

    // Flags(0, Group(0,"mark")), When(0, Eq(0, true), U8(0,"v")): the mark has no id for the `eq` to name.
    private static Scheme<Row> EqNamesTheMark() =>
        new(1, Field.Flags(0, Field.Group(0, (Row x) => x.Mark)),
            Field.When(0, Condition.Eq(0, true), Field.U8<Row>(0, x => x.V)));

    // U8(0,"k"), m, When(1, Eq(0,1), m.Bit(U8(1,"a"))), m.Bit(U8(2,"b"))
    private static Scheme<Row> SplitBitInsideWhen()
    {
        var m = Field.FlagByte();
        return new Scheme<Row>(1,
            Field.U8<Row>(0, x => x.K),
            m,
            Field.When(1, Condition.Eq(0, 1), m.Bit(Field.U8<Row>(1, x => x.A))),
            m.Bit(Field.U8<Row>(2, x => x.B)));
    }

    [Theory]
    [InlineData(true, "0101")]
    [InlineData(false, "0100")]
    public void Pack_EmptyGroupMark_SetsTheBitOnlyForTrue(bool mark, string expected)
    {
        // Arrange
        var scheme = EmptyMark();

        // Act
        var wire = Pack(scheme, new() { ["Mark"] = mark });

        // Assert
        Assert.Equal(expected, wire);
    }

    [Fact]
    public void Read_EmptyGroupMarkSet_GivesMarkTrue()
    {
        // Arrange
        var scheme = EmptyMark();

        // Act
        var values = Read(scheme, "0101");

        // Assert
        Assert.Equal(true, Assert.Single(values).Value);
    }

    [Fact]
    public void Read_EmptyGroupMarkClear_GivesNoMember()
    {
        // Arrange
        var scheme = EmptyMark();

        // Act
        var values = Read(scheme, "0100");

        // Assert
        Assert.Empty(values);
    }

    [Fact]
    public void Pack_EmptyGroupMarkAsSplitBit_PacksTheMarkBitThenTheNextBit()
    {
        // Arrange
        var scheme = MarkSplit();

        // Act
        var wire = Pack(scheme, new() { ["Mark"] = true, ["N"] = (byte)3 });

        // Assert
        Assert.Equal("010303", wire);
    }

    [Fact]
    public void Read_EmptyGroupMarkAsSplitBit_GivesTheMarkAndTheNumber()
    {
        // Arrange
        var scheme = MarkSplit();

        // Act
        var values = Read(scheme, "010303");

        // Assert
        Assert.Equal(true, values["Mark"]);
        Assert.Equal((byte)3, values["N"]);
        Assert.Equal(2, values.Count);
    }

    [Fact]
    public void Pack_MarkThenU8SharingTheNextId_PacksTheMarkByteThenTheNumber()
    {
        // Arrange
        var scheme = MarkThenU8();

        // Act
        var wire = Pack(scheme, new() { ["Mark"] = true, ["N"] = (byte)3 });

        // Assert
        Assert.Equal("010103", wire);
    }

    [Fact]
    public void Pack_MarkThenU8WithoutTheMark_PacksAClearMarkByte()
    {
        // Arrange
        var scheme = MarkThenU8();

        // Act
        var wire = Pack(scheme, new() { ["N"] = (byte)1 });

        // Assert
        Assert.Equal("010001", wire);
    }

    [Fact]
    public void Pack_MarkThenU8WithoutTheNumber_FailsNamingTheMissingNumber()
    {
        // Arrange
        var scheme = MarkThenU8();

        // Act
        var error = Assert.Throws<ArgumentException>(() => Pack(scheme, new()));

        // Assert: TypeScript throws RangeError "missing n"; C# names the member and its field id.
        Assert.Contains("'N' (field id 0) has no value", error.Message, StringComparison.Ordinal);
    }

    [Fact]
    public void Read_MarkThenU8_GivesTheMarkAndTheNumber()
    {
        // Arrange
        var scheme = MarkThenU8();

        // Act
        var values = Read(scheme, "010103");

        // Assert
        Assert.Equal(true, values["Mark"]);
        Assert.Equal((byte)3, values["N"]);
    }

    [Fact]
    public void Construct_EqNamingTheEmptyGroupMark_FailsBecauseTheMarkHasNoId()
    {
        // Act
        var error = Assert.Throws<ArgumentException>(() => EqNamesTheMark());

        // Assert: TypeScript throws "when 0: eq names field id 0, which is not declared earlier in the same scope".
        Assert.Contains("when 0 names field id 0, which is not an earlier field in the same scope", error.Message,
            StringComparison.Ordinal);
    }

    [Theory]
    [InlineData(1, "0101030506")]
    [InlineData(0, "01000306")]
    public void Pack_SplitBitInsideWhen_SetsTheBitWhetherOrNotTheWhenMatches(byte k, string expected)
    {
        // Arrange
        var scheme = SplitBitInsideWhen();

        // Act: A is given in both rows; the false when writes no `a` byte but its bit stays set.
        var wire = Pack(scheme, new() { ["K"] = k, ["A"] = (byte)5, ["B"] = (byte)6 });

        // Assert
        Assert.Equal(expected, wire);
    }

    [Fact]
    public void Read_SplitBitInsideFalseWhen_GivesNoMemberForTheBit()
    {
        // Arrange
        var scheme = SplitBitInsideWhen();

        // Act
        var values = Read(scheme, "01000306");

        // Assert: the bit is set on the wire, the when does not match, so no `a` and no body byte.
        Assert.Equal((byte)0, values["K"]);
        Assert.Equal((byte)6, values["B"]);
        Assert.Equal(2, values.Count);
    }

    [Fact]
    public void Unpack_SplitBitInsideFalseWhen_LeavesTheBitMemberUnset()
    {
        // Arrange
        var scheme = SplitBitInsideWhen();

        // Act
        var row = Unpack(scheme, "01000306");

        // Assert
        Assert.Equal(((byte)0, (byte?)null, (byte?)6), (row.K, row.A, row.B));
    }

    [Fact]
    public void Pack_ReadValuesOfSplitBitInsideFalseWhen_ClearsTheBit()
    {
        // Arrange
        var scheme = SplitBitInsideWhen();
        var values = Read(scheme, "01000306");

        // Act
        var wire = Pack(scheme, values);

        // Assert: TypeScript repacks the unpacked {k:0,b:6} as 01000206.
        Assert.Equal("01000206", wire);
    }

    [Fact]
    public void Pack_UnpackedTypedRowOfSplitBitInsideFalseWhen_ClearsTheBit()
    {
        // Arrange
        var scheme = SplitBitInsideWhen();
        var row = Unpack(scheme, "01000306");

        // Act
        var wire = Hex(BinaryPacker.Pack(scheme, row));

        // Assert
        Assert.Equal("01000206", wire);
    }

    [Fact]
    public void Pack_ReadValuesOfSplitBitInsideMatchingWhen_GivesTheSameBytes()
    {
        // Arrange
        var scheme = SplitBitInsideWhen();
        var values = Read(scheme, "0101030506");

        // Act
        var wire = Pack(scheme, values);

        // Assert
        Assert.Equal("0101030506", wire);
    }
}
