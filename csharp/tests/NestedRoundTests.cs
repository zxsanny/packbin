using Packbin;

namespace Packbin.Tests;

// A round packs item i of each value list, so a repeat or times inside it would read every inner round from the same
// item. Such a scheme fails construction; a list or dict element is a row of its own and starts outside any round.
public class NestedRoundTests
{
    private sealed class RoundRow
    {
        public byte? N { get; set; }
        public byte? K { get; set; }
        public byte? V { get; set; }
        public bool? On { get; set; }
        public Child? Row { get; set; }
        public List<object?>? Items { get; set; }
    }

    private sealed class Child
    {
        public byte? V { get; set; }
    }

    private sealed class El
    {
        public byte V { get; set; }
        public bool? Mark { get; set; }
    }

    private static readonly Dictionary<string, Func<object>> Shapes = new()
    {
        { "repeat in repeat", () => new Scheme<RoundRow>(1,
            Field.Repeat(0,
                Field.U8<RoundRow>(0, x => x.K),
                Field.Repeat(1, Field.U8<RoundRow>(1, x => x.V)))) },
        { "times in repeat", () => new Scheme<RoundRow>(1,
            Field.Repeat(0,
                Field.U8<RoundRow>(0, x => x.K),
                Field.Times(1, 0, Field.U8<RoundRow>(1, x => x.V)))) },
        { "repeat in times", () => new Scheme<RoundRow>(1,
            Field.U8<RoundRow>(0, x => x.N),
            Field.Times(1, 0,
                Field.U8<RoundRow>(1, x => x.K),
                Field.Repeat(2, Field.U8<RoundRow>(2, x => x.V)))) },
        { "times in times", () => new Scheme<RoundRow>(1,
            Field.U8<RoundRow>(0, x => x.N),
            Field.Times(1, 0,
                Field.U8<RoundRow>(1, x => x.K),
                Field.Times(2, 1, Field.U8<RoundRow>(2, x => x.V)))) },
        { "repeat through when", () => new Scheme<RoundRow>(1,
            Field.Repeat(0,
                Field.U8<RoundRow>(0, x => x.K),
                Field.When(1, Condition.Eq(0, (byte)1), Field.Repeat(1, Field.U8<RoundRow>(1, x => x.V))))) },
        { "times through flags", () => new Scheme<RoundRow>(1,
            Field.Repeat(0,
                Field.U8<RoundRow>(0, x => x.K),
                Field.Flags(1, Field.Times(1, 0, Field.U8<RoundRow>(1, x => x.V))))) },
        { "repeat through flag byte bit", () => NestedInFlagByteBit() },
        { "repeat through group", () => new Scheme<RoundRow>(1,
            Field.Repeat(0,
                Field.U8<RoundRow>(0, x => x.K),
                Field.Group(1, (RoundRow x) => x.On, Field.Repeat(1, Field.U8<RoundRow>(1, x => x.V))))) },
        { "repeat through nested row", () => new Scheme<RoundRow>(1,
            Field.Repeat(0,
                Field.Group((RoundRow x) => x.Row, Field.Repeat(0, Field.U8<Child>(0, x => x.V))))) },
    };

    private static Scheme<RoundRow> NestedInFlagByteBit()
    {
        var m = Field.FlagByte();
        return new Scheme<RoundRow>(1,
            Field.Repeat(0, m, m.Bit(Field.Repeat(0, Field.U8<RoundRow>(0, x => x.V)))));
    }

    [Theory]
    [InlineData("repeat in repeat", "repeat 1")]
    [InlineData("times in repeat", "times 1")]
    [InlineData("repeat in times", "repeat 2")]
    [InlineData("times in times", "times 2")]
    [InlineData("repeat through when", "repeat 1")]
    [InlineData("times through flags", "times 1")]
    [InlineData("repeat through flag byte bit", "repeat 0")]
    [InlineData("repeat through group", "repeat 1")]
    [InlineData("repeat through nested row", "repeat 0")]
    public void ARoundInsideARound_FailsConstructionNamingTheNestedContainer(string shape, string container)
    {
        // Arrange
        var build = Shapes[shape];

        // Act
        var refused = Record.Exception(build);

        // Assert
        var error = Assert.IsType<ArgumentException>(refused);
        Assert.Equal(
            $"{container} is inside a repeat or times round; a round cannot hold another repeat or times",
            error.Message);
    }

    [Fact]
    public void AListInARound_BuildsAndRoundTrips()
    {
        // Arrange
        var scheme = new Scheme<RoundRow>(1,
            Field.Repeat(0,
                Field.U8<RoundRow>(0, x => x.K),
                Field.List((RoundRow x) => x.Items, Field.U8<El>(0, e => e.V))));
        var values = new Dictionary<string, object?>
        {
            ["K"] = new object?[] { (byte)1, (byte)2 },
            ["Items"] = new object?[]
            {
                new List<object?> { (byte)7, (byte)8 },
                new List<object?> { (byte)9 },
            },
        };

        // Act
        var raw = BinaryPacker.Pack(scheme, values);
        var got = BinaryPacker.Read(scheme, raw);
        var again = BinaryPacker.Pack(scheme, got.Values);

        // Assert
        Assert.Equal("01010200070802010009", Convert.ToHexString(raw).ToLowerInvariant());
        Assert.Null(got.Error);
        Assert.Equal(Convert.ToHexString(raw), Convert.ToHexString(again));
    }

    [Fact]
    public void ATimesInAListElementInARound_Builds()
    {
        // Arrange
        // Act
        var built = Record.Exception(() => new Scheme<RoundRow>(1,
            Field.Repeat(0,
                Field.U8<RoundRow>(0, x => x.K),
                Field.List((RoundRow x) => x.Items,
                    Field.Group(0, (El e) => e.Mark,
                        Field.U8<El>(0, e => e.V),
                        Field.Times(1, 0, Field.U8<El>(1, e => e.V)))))));

        // Assert
        Assert.Null(built);
    }

    [Fact]
    public void ATimesInADictElementInARound_Builds()
    {
        // Arrange
        // Act
        var built = Record.Exception(() => new Scheme<RoundRow>(1,
            Field.U8<RoundRow>(0, x => x.N),
            Field.Times(1, 0,
                Field.Dict((RoundRow x) => x.Items,
                    Field.Group(0, (El e) => e.Mark,
                        Field.U8<El>(0, e => e.V),
                        Field.Times(1, 0, Field.U8<El>(1, e => e.V)))))));

        // Assert
        Assert.Null(built);
    }
}
