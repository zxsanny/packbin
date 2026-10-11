using Packbin;

namespace Packbin.Tests;

// AZ-2335: a `times` whose count is 0 refuses a list of values, naming the member, inside `flags` (AZ-2304) and outside
// it. A count of 0 with no values packs no round.
public class TimesZeroWithValuesTests
{
    private sealed class Row
    {
        public byte N { get; set; }
        public byte? Pt { get; set; }
        public ushort? Heading { get; set; }
    }

    private static Scheme<Row> Plain() => new(1,
        Field.U8<Row>(0, x => x.N),
        Field.Times(1, 0, Field.U8<Row>(1, x => x.Pt)));

    private static Scheme<Row> InFlags() => new(1,
        Field.U8<Row>(0, x => x.N),
        Field.Flags(1,
            Field.Times(1, 0, Field.U8<Row>(1, x => x.Pt)),
            Field.U16<Row>(2, x => x.Heading)));

    private static Dictionary<string, object?> Row0(object? pt)
    {
        var row = new Dictionary<string, object?> { ["N"] = (byte)0 };
        if (pt is not null)
            row["Pt"] = pt;
        return row;
    }

    public static TheoryData<string> Shapes() => new() { "plain", "in flags" };

    private static Scheme<Row> Build(string shape) => shape == "plain" ? Plain() : InFlags();

    [Theory]
    [MemberData(nameof(Shapes))]
    public void Ac1_Pack_CountZeroWithAListOfValues_NamesTheMember(string shape)
    {
        // Arrange
        var scheme = Build(shape);

        // Act
        var thrown = Record.Exception(() => BinaryPacker.Pack(scheme, Row0(new object[] { (byte)5 })));

        // Assert
        var error = Assert.IsType<ArgumentException>(thrown);
        Assert.Equal("'Pt' holds 1 items, but the times count is 0", error.Message);
    }

    [Theory]
    [MemberData(nameof(Shapes))]
    public void Ac1_Pack_CountZeroWithAnOutOfRangeValueInTheList_StillNamesTheMember(string shape)
    {
        // Arrange
        var scheme = Build(shape);

        // Act
        var thrown = Record.Exception(() => BinaryPacker.Pack(scheme, Row0(new object[] { 300 })));

        // Assert
        Assert.Contains("'Pt'", Assert.IsType<ArgumentException>(thrown).Message);
    }

    [Theory]
    [MemberData(nameof(Shapes))]
    public void Ac2_Pack_CountZeroWithNoValues_PacksNoRound(string shape)
    {
        // Arrange
        var scheme = Build(shape);

        // Act
        var none = BinaryPacker.Pack(scheme, Row0(null));
        var empty = BinaryPacker.Pack(scheme, Row0(new object[] { }));

        // Assert
        Assert.Equal(shape == "plain" ? "0100" : "010000", Convert.ToHexString(none).ToLowerInvariant());
        Assert.Equal(Convert.ToHexString(none), Convert.ToHexString(empty));
    }
}
