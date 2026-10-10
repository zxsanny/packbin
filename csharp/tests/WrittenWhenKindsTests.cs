using Packbin;

namespace Packbin.Tests;

// A `when` can name an integer or a bool, written at the top level, in a flag bit (short or split form) or in a
// group. Pack records each of them as it writes it, so the `when` after it matches and writes its body. A float, utf8 or
// byte source is refused at construction (EqBoolTrueOnlyTests, AZ-2126).
public class WrittenWhenKindsTests
{
    private sealed class KindRow
    {
        public byte? N { get; set; }
        public int P { get; set; }
        public int Q { get; set; }
        public bool? On { get; set; }
        public byte? G { get; set; }
        public byte? V { get; set; }
    }

    private static Field Body(int anchor, int id, object value) =>
        Field.When(anchor, Condition.Eq(id, value), Field.U8<KindRow>(anchor, x => x.V));

    private static Scheme<KindRow> SplitBit(Field inner, Field when)
    {
        var m = Field.FlagByte();
        return new Scheme<KindRow>(1, m, m.Bit(inner), when);
    }

    private static readonly Dictionary<string, Func<(Scheme<KindRow> Scheme, string Hex, bool Reads)>> Cases = new()
    {
        { "u2", () => (new Scheme<KindRow>(1,
            Field.U2<KindRow>((0, x => x.P), (1, x => x.Q)),
            Body(2, 1, 2)), "010907", true) },
        { "flags bool", () => (new Scheme<KindRow>(1,
            Field.Flags(0, Field.Bool<KindRow>(0, x => x.On)),
            Body(1, 0, true)), "010107", true) },
        { "flags scalar", () => (new Scheme<KindRow>(1,
            Field.Flags(0, Field.U8<KindRow>(0, x => x.N)),
            Body(1, 0, 5)), "01010507", true) },
        { "flags group child", () => (new Scheme<KindRow>(1,
            Field.Flags(0, Field.Group(0, (KindRow x) => x.On, Field.U8<KindRow>(0, x => x.G))),
            Body(1, 0, 4)), "01010407", true) },
        { "split bit scalar", () => (SplitBit(Field.U8<KindRow>(0, x => x.N), Body(1, 0, 5)), "01010507", true) },
        { "split bit bool", () => (SplitBit(Field.Bool<KindRow>(0, x => x.On), Body(1, 0, true)), "010107", true) },
        { "group child", () => (new Scheme<KindRow>(1,
            Field.Group(0, (KindRow x) => x.On, Field.U8<KindRow>(0, x => x.G)),
            Body(1, 0, 4)), "010407", true) },
    };

    private static Dictionary<string, object?> Row() => new()
    {
        ["N"] = (byte)5,
        ["P"] = 1,
        ["Q"] = 2,
        ["On"] = true,
        ["G"] = (byte)4,
        ["V"] = (byte)7,
    };

    [Theory]
    [InlineData("u2")]
    [InlineData("flags bool")]
    [InlineData("flags scalar")]
    [InlineData("flags group child")]
    [InlineData("split bit scalar")]
    [InlineData("split bit bool")]
    [InlineData("group child")]
    public void When_NamingAFieldPackWrote_MatchesAndTheBodyIsWritten(string kind)
    {
        // Arrange
        var (scheme, hex, reads) = Cases[kind]();

        // Act
        var raw = BinaryPacker.Pack(scheme, Row());

        // Assert
        Assert.Equal(hex, Convert.ToHexString(raw).ToLowerInvariant());
        if (reads)
            Assert.Null(BinaryPacker.Read(scheme, raw).Error);
    }
}
