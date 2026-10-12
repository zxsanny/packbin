using Packbin;

namespace Packbin.Tests;

// AZ-2386 (U6) and AZ-2387 (U7), rows 44 to 56 of _docs/03_implementation/reference_loop21_slots.md: a count that no field
// wrote because the `when` holding it is clear. A `times` whose row still holds a count above 0 is refused at its clear bit
// (split and combined `flags`); `bits`, `packed` and `sized` are refused when they have a value, and with no value and a
// count above 0 (row 56, AZ-2410 U11) once the bit is found clear. C# words the U7 refusal as it always has
// ("count 'C' is missing").
public class CountBehindClearWhenTests
{
    private sealed class Row
    {
        public byte Mode { get; set; }
        public byte? C { get; set; }
        public byte? Pt { get; set; }
        public ushort? Heading { get; set; }
        public List<int>? V { get; set; }
        public byte[]? Bv { get; set; }
    }

    private static string Hex(byte[] raw) => Convert.ToHexString(raw).ToLowerInvariant();

    private static Dictionary<string, object?> Dict(params (string Name, object? Value)[] items) =>
        items.ToDictionary(item => item.Name, item => item.Value);

    private static string Stranded(string member, string count, string n) =>
        $"'{member}': the count {count} is {n} in the row, but no field wrote it (the when that holds it is clear), "
        + "so its times reads no round; give the count 0, leave it out, or make the when hold";

    private static Field CountWhen() => Field.When(1, Condition.Eq(0, 1), Field.U8<Row>(1, x => x.C));

    private static Scheme<Row> SplitTimes()
    {
        var fb = Field.FlagByte();
        return new Scheme<Row>(1,
            Field.U8<Row>(0, x => x.Mode), CountWhen(), fb,
            fb.Bit(Field.Times(2, 1, Field.U8<Row>(2, x => x.Pt))), fb.Bit(Field.U16<Row>(3, x => x.Heading)));
    }

    private static Scheme<Row> CombinedTimes() => new(1,
        Field.U8<Row>(0, x => x.Mode), CountWhen(),
        Field.Flags(2, Field.Times(2, 1, Field.U8<Row>(2, x => x.Pt)), Field.U16<Row>(3, x => x.Heading)));

    private static Scheme<Row> PlainTimes() => new(1,
        Field.U8<Row>(0, x => x.Mode), CountWhen(),
        Field.Times(2, 1, Field.U8<Row>(2, x => x.Pt)), Field.U16<Row>(3, x => x.Heading));

    public static TheoryData<string, object?, string> StrandedRows() => new()
    {
        { "row 44: count 1, no body", (byte)1, "1" },
        { "row 45: count 1, empty body", (byte)1, "1" },
        { "row 46: a wide count", 3UL, "3" },
    };

    [Theory]
    [MemberData(nameof(StrandedRows))]
    public void Ac1_Pack_CountAboveZeroBehindAClearWhenInASplitBit_IsRefused(string row, object? count, string printed)
    {
        // Arrange
        var values = row.StartsWith("row 45", StringComparison.Ordinal)
            ? Dict(("Mode", (byte)0), ("C", count), ("Pt", new object[] { }), ("Heading", (ushort)90))
            : Dict(("Mode", (byte)0), ("C", count), ("Heading", (ushort)90));

        // Act
        var error = Budget.Refused(SplitTimes(), values);

        // Assert
        Assert.Equal(Stranded("Pt", "C", printed), error.Message);
    }

    [Fact]
    public void Ac1_Pack_CountAboveZeroBehindAClearWhenInATypedRow_IsRefused()
    {
        // Act
        var error = Budget.Refused(SplitTimes(), new Row { Mode = 0, C = 1, Heading = 90 });

        // Assert
        Assert.Equal(Stranded("Pt", "C", "1"), error.Message);
    }

    [Fact]
    public void Ac1_Pack_CountAboveZeroBehindAClearWhenInCombinedFlags_IsRefused()
    {
        // Act (row 50: this packed 0100025a00 before)
        var error = Budget.Refused(CombinedTimes(), Dict(("Mode", (byte)0), ("C", (byte)2), ("Heading", (ushort)90)));

        // Assert
        Assert.Equal(Stranded("Pt", "C", "2"), error.Message);
    }

    [Fact]
    public void Ac2_Pack_CountZeroOrLeftOut_PacksAClearBit()
    {
        // Act (rows 47 and 48)
        var zero = BinaryPacker.Pack(SplitTimes(), Dict(("Mode", (byte)0), ("C", (byte)0), ("Heading", (ushort)90)));
        var left = BinaryPacker.Pack(SplitTimes(), Dict(("Mode", (byte)0), ("Heading", (ushort)90)));
        var combined = BinaryPacker.Pack(CombinedTimes(), Dict(("Mode", (byte)0), ("Heading", (ushort)90)));

        // Assert
        Assert.Equal(("0100025a00", "0100025a00", "0100025a00"), (Hex(zero), Hex(left), Hex(combined)));
    }

    [Fact]
    public void Ac1_Pack_BodyGivenBehindASkippedCount_KeepsItsOwnRefusalFirst()
    {
        // Act (row 49)
        var error = Budget.Refused(SplitTimes(),
            Dict(("Mode", (byte)0), ("C", (byte)2), ("Pt", new object[] { (byte)5, (byte)6 }), ("Heading", (ushort)90)));

        // Assert
        Assert.Equal(
            "'Pt' has a value, but its flag bit is clear: the count that decides the bit was skipped", error.Message);
    }

    [Fact]
    public void Ac2_Pack_WhenHolds_PacksTheRounds()
    {
        // Act (row 51)
        var raw = BinaryPacker.Pack(SplitTimes(),
            Dict(("Mode", (byte)1), ("C", (byte)1), ("Pt", new object[] { (byte)5 }), ("Heading", (ushort)90)));

        // Assert
        Assert.Equal("01010103055a00", Hex(raw));
    }

    [Theory]
    [InlineData(1)]
    [InlineData(0)]
    public void Ac1_Pack_PlainTimesBehindAClearWhen_IsRefusedWhateverTheCountInTheRow(int count)
    {
        // Act (row 52)
        var error = Budget.Refused(PlainTimes(), Dict(("Mode", (byte)0), ("C", (byte)count), ("Heading", (ushort)90)));

        // Assert
        Assert.Equal("times: count 'C' is missing", error.Message);
    }

    // The counted member of U7 (id 2, count id 1), plain, as a split flag bit and in combined flags.
    private static Field Bits() => Field.Bits<Row>(2, x => x.V, 1);
    private static Field Packed() => Field.Packed<Row>(1, 2, x => x.V, 1);
    private static Field Sized() => Field.Sized<Row>(2, x => x.Bv!, 1);

    private static Scheme<Row> Counted(Func<Field> member, string position)
    {
        var fb = Field.FlagByte();
        return position switch
        {
            "plain" => new Scheme<Row>(1, Field.U8<Row>(0, x => x.Mode), CountWhen(), member()),
            "split" => new Scheme<Row>(1, Field.U8<Row>(0, x => x.Mode), CountWhen(), fb, fb.Bit(member())),
            _ => new Scheme<Row>(1, Field.U8<Row>(0, x => x.Mode), CountWhen(), Field.Flags(2, member())),
        };
    }

    private static Dictionary<string, object?> Given(string kind, byte mode, bool withValue)
    {
        var values = Dict(("Mode", mode), ("C", (byte)3));
        if (withValue)
            values[kind == "sized" ? "Bv" : "V"] = kind == "sized" ? new byte[] { 1, 2, 3 } : new List<int> { 1, 0, 1 };
        return values;
    }

    private static readonly Dictionary<string, Func<Field>> Kinds = new() { ["bits"] = Bits, ["packed"] = Packed, ["sized"] = Sized };

    public static TheoryData<string, string> Nine()
    {
        var data = new TheoryData<string, string>();
        foreach (var kind in Kinds.Keys)
        {
            foreach (var position in new[] { "plain", "split", "combined" })
                data.Add(kind, position);
        }
        return data;
    }

    [Theory]
    [MemberData(nameof(Nine))]
    public void Ac1_Pack_CountedMemberBehindAClearWhen_IsRefused(string kind, string position)
    {
        // Act (row 53)
        var error = Budget.Refused(Counted(Kinds[kind], position), Given(kind, 0, withValue: true));

        // Assert
        Assert.Equal($"{(kind == "sized" ? "Bv" : "V")}: count 'C' is missing", error.Message);
    }

    [Theory]
    [InlineData("bits", "plain", "01010305")]
    [InlineData("bits", "split", "0101030105")]
    [InlineData("packed", "plain", "01010305")]
    [InlineData("packed", "split", "0101030105")]
    [InlineData("sized", "plain", "010103010203")]
    [InlineData("sized", "split", "01010301010203")]
    public void Ac2_Pack_CountedMemberWhenTheWhenHolds_PacksAsBefore(string kind, string position, string expected)
    {
        // Act (rows 54 and 55)
        var raw = BinaryPacker.Pack(Counted(Kinds[kind], position), Given(kind, 1, withValue: true));

        // Assert
        Assert.Equal(expected, Hex(raw));
    }

    public static TheoryData<string, string> SixNoValue()
    {
        var data = new TheoryData<string, string>();
        foreach (var kind in Kinds.Keys)
        {
            foreach (var position in new[] { "split", "combined" })
                data.Add(kind, position);
        }
        return data;
    }

    private static string NoValueCount(string member, string count, string n) =>
        $"'{member}': the count {count} is {n} in the row, but no field wrote it (the when that holds it is clear), "
        + "so the member reads nothing; give the count 0, leave it out, or make the when hold";

    [Theory]
    [MemberData(nameof(SixNoValue))]
    public void Ac1_Pack_CountedMemberWithNoValueBehindAClearWhen_IsRefused(string kind, string position)
    {
        // Act (row 56: AZ-2410 refuses it as a `times` is refused; it packed a clear bit before)
        var error = Budget.Refused(Counted(Kinds[kind], position), Given(kind, 0, withValue: false));

        // Assert
        Assert.Equal(NoValueCount(kind == "sized" ? "Bv" : "V", "C", "3"), error.Message);
    }

    [Theory]
    [MemberData(nameof(SixNoValue))]
    public void Ac1_Pack_WideCountBehindAClearWhenWithNoValue_IsRefusedWithTheCountAsGiven(string kind, string position)
    {
        // Arrange
        var values = Given(kind, 0, withValue: false);
        values["C"] = 4UL;

        // Act
        var error = Budget.Refused(Counted(Kinds[kind], position), values);

        // Assert
        Assert.Equal(NoValueCount(kind == "sized" ? "Bv" : "V", "C", "4"), error.Message);
    }

    [Theory]
    [InlineData("bits")]
    [InlineData("packed")]
    [InlineData("sized")]
    public void Ac1_Pack_CountedMemberWithNoValueInPlainPosition_KeepsItsOwnRefusal(string kind)
    {
        // Act (row 56, plain: never reached the clear-bit path)
        var error = Budget.Refused(Counted(Kinds[kind], "plain"), Given(kind, 0, withValue: false));

        // Assert
        Assert.Equal($"{(kind == "sized" ? "Bv" : "V")}: count 'C' is missing", error.Message);
    }

    [Theory]
    [MemberData(nameof(SixNoValue))]
    public void Ac2_Pack_CountedMemberWithNoValueAndCountZeroOrLeftOut_PacksAClearBit(string kind, string position)
    {
        // Arrange
        var zero = Given(kind, 0, withValue: false);
        zero["C"] = (byte)0;
        var left = Given(kind, 0, withValue: false);
        left.Remove("C");

        // Act (rows 56a and 56b)
        var rawZero = BinaryPacker.Pack(Counted(Kinds[kind], position), zero);
        var rawLeft = BinaryPacker.Pack(Counted(Kinds[kind], position), left);

        // Assert
        Assert.Equal(("010000", "010000"), (Hex(rawZero), Hex(rawLeft)));
    }

    [Theory]
    [MemberData(nameof(SixNoValue))]
    public void Ac3_Pack_CountedMemberWithNoValueWhenTheWhenHolds_PacksAsBefore(string kind, string position)
    {
        // Act (row 56c)
        var raw = BinaryPacker.Pack(Counted(Kinds[kind], position), Given(kind, 1, withValue: false));

        // Assert
        Assert.Equal("01010300", Hex(raw));
    }

    [Theory]
    [InlineData("split", 1, "010000")]
    [InlineData("combined", 1, "010000")]
    [InlineData("split", 3, null)]
    [InlineData("combined", 3, null)]
    public void Ac1_Pack_PackedCountIsComparedAfterTheBias(string position, int count, string? expected)
    {
        // Arrange
        var member = () => Field.Packed<Row>(1, 2, x => x.V, 1, bias: -1);
        var values = Given("packed", 0, withValue: false);
        values["C"] = (byte)count;

        // Act (row 56d: count 1 minus 1 is 0, count 3 minus 1 is 2)
        if (expected is not null)
        {
            Assert.Equal(expected, Hex(BinaryPacker.Pack(Counted(member, position), values)));
            return;
        }
        var error = Budget.Refused(Counted(member, position), values);

        // Assert
        Assert.Equal(NoValueCount("V", "C", "3"), error.Message);
    }
}
