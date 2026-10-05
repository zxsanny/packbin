using Packbin;

namespace Packbin.Tests;

// A `when` condition or a borrowed count names a value field read earlier in the same scope: the top level, one repeat
// or times body, one list or dict element, or one nested row. Flags, when and continuing groups stay in their parent's.
public class ReferenceScopeTests
{
    private const string Rule = "not an earlier field in the same scope";

    private sealed class RefRow
    {
        public byte P { get; set; }
        public byte? A { get; set; }
        public byte B { get; set; }
        public byte[]? Payload { get; set; }
        public List<int>? Segs { get; set; }
        public List<int>? Kinds { get; set; }
        public byte? K { get; set; }
        public byte? V { get; set; }
        public byte? W { get; set; }
        public byte X { get; set; }
        public byte N { get; set; }
        public bool? Mark { get; set; }
        public Inner? Row { get; set; }
        public List<object?>? Items { get; set; }
        public Dictionary<string, object?>? Map { get; set; }
    }

    private sealed class Inner
    {
        public byte K { get; set; }
        public byte V { get; set; }
    }

    // The element's own ids are 0 and 1; id 2 exists only in the row around the list.
    private static Field ElementNamingId2() =>
        Field.Group(0, (RefRow x) => x.Mark,
            Field.U8<RefRow>(0, x => x.K),
            Field.When(1, Condition.Eq(2, (byte)1), Field.U8<RefRow>(1, x => x.V)));

    private static readonly Dictionary<string, Func<object>> LaterCount = new()
    {
        ["sized"] = () => new Scheme<RefRow>(1,
            Field.Sized<RefRow>(0, x => x.Payload!, 1),
            Field.U8<RefRow>(1, x => x.N)),
        ["bits"] = () => new Scheme<RefRow>(1,
            Field.Bits<RefRow>(0, x => x.Segs, 1),
            Field.U8<RefRow>(1, x => x.N)),
        ["packed"] = () => new Scheme<RefRow>(1,
            Field.Packed<RefRow>(2, 0, x => x.Kinds, 1),
            Field.U8<RefRow>(1, x => x.N)),
        ["times"] = () => new Scheme<RefRow>(1,
            Field.Times(0, 1, Field.U8<RefRow>(0, x => x.X)),
            Field.U8<RefRow>(1, x => x.N)),
    };

    private static readonly Dictionary<string, Func<object>> OuterReference = new()
    {
        ["when in repeat"] = () => new Scheme<RefRow>(1,
            Field.U8<RefRow>(0, x => x.P),
            Field.Repeat(1,
                Field.U8<RefRow>(1, x => x.X),
                Field.When(2, Condition.Eq(0, (byte)1), Field.U8<RefRow>(2, x => x.V)))),
        ["when in times"] = () => new Scheme<RefRow>(1,
            Field.U8<RefRow>(0, x => x.P),
            Field.Times(1, 0,
                Field.U8<RefRow>(1, x => x.X),
                Field.When(2, Condition.Eq(0, (byte)1), Field.U8<RefRow>(2, x => x.V)))),
        ["count in repeat"] = () => new Scheme<RefRow>(1,
            Field.U8<RefRow>(0, x => x.P),
            Field.Repeat(1, Field.Sized<RefRow>(1, x => x.Payload!, 0))),
        ["count in times"] = () => new Scheme<RefRow>(1,
            Field.U8<RefRow>(0, x => x.P),
            Field.Times(1, 0, Field.Packed<RefRow>(1, 1, x => x.Kinds, 0))),
        ["list element"] = () => new Scheme<RefRow>(1,
            Field.U8<RefRow>(0, x => x.P),
            Field.U8<RefRow>(1, x => x.A),
            Field.U8<RefRow>(2, x => x.B),
            Field.List((RefRow x) => x.Items, ElementNamingId2())),
        ["dict element"] = () => new Scheme<RefRow>(1,
            Field.U8<RefRow>(0, x => x.P),
            Field.U8<RefRow>(1, x => x.A),
            Field.U8<RefRow>(2, x => x.B),
            Field.Dict((RefRow x) => x.Map, ElementNamingId2())),
        ["nested row"] = () => new Scheme<RefRow>(1,
            Field.U8<RefRow>(0, x => x.P),
            Field.U8<RefRow>(1, x => x.A),
            Field.U8<RefRow>(2, x => x.B),
            Field.Group((RefRow x) => x.Row,
                Field.U8<Inner>(0, x => x.K),
                Field.When(1, Condition.Eq(2, (byte)1), Field.U8<Inner>(1, x => x.V)))),
    };

    private static string Hex(byte[] raw) => Convert.ToHexString(raw).ToLowerInvariant();

    [Fact]
    public void When_NamingALaterField_FailsConstruction()
    {
        // Arrange
        // Act
        var refused = Record.Exception(() => new Scheme<RefRow>(1,
            Field.When(0, Condition.Eq(1, (byte)1), Field.U8<RefRow>(0, x => x.A)),
            Field.U8<RefRow>(1, x => x.B)));

        // Assert
        var error = Assert.IsType<ArgumentException>(refused);
        Assert.Contains("when 0 names field id 1", error.Message, StringComparison.Ordinal);
        Assert.Contains(Rule, error.Message, StringComparison.Ordinal);
        Assert.Contains("separate scopes", error.Message, StringComparison.Ordinal);
    }

    [Theory]
    [InlineData("sized", "count of field id 0 names field id 1")]
    [InlineData("bits", "count of field id 0 names field id 1")]
    [InlineData("packed", "count of field id 0 names field id 1")]
    [InlineData("times", "count of times 0 names field id 1")]
    public void Count_NamingALaterField_FailsConstruction(string kind, string expected)
    {
        // Arrange
        var build = LaterCount[kind];

        // Act
        var refused = Record.Exception(build);

        // Assert
        var error = Assert.IsType<ArgumentException>(refused);
        Assert.Contains(expected, error.Message, StringComparison.Ordinal);
        Assert.Contains(Rule, error.Message, StringComparison.Ordinal);
    }

    [Theory]
    [InlineData("when in repeat")]
    [InlineData("when in times")]
    [InlineData("count in repeat")]
    [InlineData("count in times")]
    [InlineData("list element")]
    [InlineData("dict element")]
    [InlineData("nested row")]
    public void ReferenceToAnOuterField_FailsConstruction(string shape)
    {
        // Arrange
        var build = OuterReference[shape];

        // Act
        var refused = Record.Exception(build);

        // Assert
        var error = Assert.IsType<ArgumentException>(refused);
        Assert.Contains(Rule, error.Message, StringComparison.Ordinal);
    }

    [Fact]
    public void When_NamingAFieldInsideAnEarlierTimesBody_FailsConstruction()
    {
        // Arrange
        // Act
        var refused = Record.Exception(() => new Scheme<RefRow>(1,
            Field.U8<RefRow>(0, x => x.N),
            Field.Times(1, 0, Field.U8<RefRow>(1, x => x.X)),
            Field.When(2, Condition.Eq(1, (byte)1), Field.U8<RefRow>(2, x => x.V))));

        // Assert
        var error = Assert.IsType<ArgumentException>(refused);
        Assert.Contains("when 2 names field id 1", error.Message, StringComparison.Ordinal);
    }

    [Fact]
    public void When_NamingAnUnknownId_FailsConstruction()
    {
        // Arrange
        // Act
        var refused = Record.Exception(() => new Scheme<RefRow>(1,
            Field.U8<RefRow>(0, x => x.P),
            Field.When(1, Condition.Eq(7, (byte)1), Field.U8<RefRow>(1, x => x.V))));

        // Assert
        var error = Assert.IsType<ArgumentException>(refused);
        Assert.Contains("names field id 7", error.Message, StringComparison.Ordinal);
    }

    [Fact]
    public void Repeat_WhenNamingAnEarlierSibling_ReadsOnlyTheMatchingRounds()
    {
        // Arrange
        var scheme = new Scheme<RefRow>(1,
            Field.Repeat(0,
                Field.U8<RefRow>(0, x => x.K),
                Field.When(1, Condition.Eq(0, (byte)1), Field.U8<RefRow>(1, x => x.V))));

        // Act
        var got = BinaryPacker.Read(scheme, Convert.FromHexString("01010902"));

        // Assert
        Assert.Null(got.Error);
        Assert.Equal([1, 2], RoundValueTests.Cells(got.Values["K"]));
        Assert.Equal([9, null], RoundValueTests.Cells(got.Values["V"]));
    }

    [Fact]
    public void Repeat_WhenNamingAnEarlierSibling_PacksOnlyTheMatchingRounds()
    {
        // Arrange
        var scheme = new Scheme<RefRow>(1,
            Field.Repeat(0,
                Field.U8<RefRow>(0, x => x.K),
                Field.When(1, Condition.Eq(0, (byte)1), Field.U8<RefRow>(1, x => x.V))));
        var values = new Dictionary<string, object?>
        {
            ["K"] = new byte[] { 1, 2 },
            ["V"] = new byte[] { 9 },
        };

        // Act
        var packed = BinaryPacker.Pack(scheme, values);
        var got = BinaryPacker.Read(scheme, packed);
        var again = BinaryPacker.Pack(scheme, got.Values);

        // Assert
        Assert.Equal("01010902", Hex(packed));
        Assert.Null(got.Error);
        Assert.Equal(Hex(packed), Hex(again));
    }

    [Fact]
    public void Repeat_NestedWhenNamingAnEarlierSibling_PacksAndReadsTheInnerValue()
    {
        // Arrange
        var scheme = new Scheme<RefRow>(1,
            Field.Repeat(0,
                Field.U8<RefRow>(0, x => x.K),
                Field.When(1, Condition.Eq(0, (byte)1),
                    Field.When(1, Condition.Eq(0, (byte)1), Field.U8<RefRow>(1, x => x.V)))));
        var values = new Dictionary<string, object?>
        {
            ["K"] = new byte[] { 1, 2 },
            ["V"] = new byte[] { 9 },
        };

        // Act
        var packed = BinaryPacker.Pack(scheme, values);
        var got = BinaryPacker.Read(scheme, packed);

        // Assert
        Assert.Equal("01010902", Hex(packed));
        Assert.Null(got.Error);
        Assert.Equal([1, 2], RoundValueTests.Cells(got.Values["K"]));
        Assert.Equal([9, null], RoundValueTests.Cells(got.Values["V"]));
    }

    [Fact]
    public void Times_WhenNamingAnEarlierSibling_ReadsOnlyTheMatchingRounds()
    {
        // Arrange
        var scheme = new Scheme<RefRow>(1,
            Field.U8<RefRow>(0, x => x.N),
            Field.Times(1, 0,
                Field.U8<RefRow>(1, x => x.K),
                Field.When(2, Condition.Eq(1, (byte)1), Field.U8<RefRow>(2, x => x.V))));

        // Act
        var got = BinaryPacker.Read(scheme, Convert.FromHexString("0102010902"));

        // Assert
        Assert.Null(got.Error);
        Assert.Equal([1, 2], RoundValueTests.Cells(got.Values["K"]));
        Assert.Equal([9, null], RoundValueTests.Cells(got.Values["V"]));
    }

    [Fact]
    public void FlagsWhenAndContinuingGroup_KeepTheirFieldsInTheParentScope()
    {
        // Arrange
        var scheme = new Scheme<RefRow>(1,
            Field.U8<RefRow>(0, x => x.K),
            Field.When(1, Condition.Eq(0, (byte)1), Field.U8<RefRow>(1, x => x.V)),
            Field.Flags(2, Field.U8<RefRow>(2, x => x.W)),
            Field.Group(3, (RefRow x) => x.Mark, Field.U8<RefRow>(3, x => x.X)),
            Field.When(4, Condition.Eq(2, (byte)5), Field.Sized<RefRow>(4, x => x.Payload!, 1)),
            Field.Bits<RefRow>(5, x => x.Segs, 3));
        var values = new Dictionary<string, object?>
        {
            ["K"] = (byte)1,
            ["V"] = (byte)2,
            ["W"] = (byte)5,
            ["X"] = (byte)3,
            ["Payload"] = new byte[] { 0xAA, 0xBB },
            ["Segs"] = new List<int> { 1, 0, 1 },
        };

        // Act
        var packed = BinaryPacker.Pack(scheme, values);
        var got = BinaryPacker.Read(scheme, packed);

        // Assert
        Assert.Equal("010102010503aabb05", Hex(packed));
        Assert.Null(got.Error);
        Assert.Equal(new byte[] { 0xAA, 0xBB }, got.Values["Payload"]);
        Assert.Equal([1, 0, 1], (List<int>)got.Values["Segs"]!);
    }
}
