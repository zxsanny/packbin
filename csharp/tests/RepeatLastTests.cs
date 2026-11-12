using System.Collections;
using System.Globalization;
using Packbin;

namespace Packbin.Tests;

// AZ-4212 (contract repeat-last 1.0.1): a repeat has no count on the wire, so unpack reads its rounds to the end of the
// packet. A scheme is refused when it is built if a field that can write a byte stands after a repeat (R1 to R6) or a
// repeat sits inside a list or dict element (R7, R8); R9 keeps the nesting rule and its text. A repeat that is the last
// thing read builds and packs the same bytes (K1 to K5). Every case runs in both forms: "typed", a repeat bound to a
// collection of rows, and "dictionary", an unbound Field.Repeat over a dictionary row.
public class RepeatLastTests
{
    private sealed class Leg
    {
        public byte V { get; set; }
    }

    private sealed class LegW
    {
        public byte W { get; set; }
    }

    // One row for both forms: a bound repeat fills Legs, an unbound one reads the list given for V (a name inside an
    // unbound repeat is declared on the row that holds the repeat). A nested row and an element are rows of this class.
    private sealed class Row
    {
        public byte K { get; set; }
        public byte X { get; set; }
        public byte Mode { get; set; }
        public bool B { get; set; }
        public bool? G { get; set; }
        public byte[] Z { get; set; } = [];
        public byte V { get; set; }
        public byte W { get; set; }
        public List<Leg> Legs { get; set; } = [];
        public List<LegW> LegsW { get; set; } = [];
        public Row? M { get; set; }
        public List<Row> Items { get; set; } = [];
        public Dictionary<string, Row> D { get; set; } = [];
        public List<object?>? Bag { get; set; }
        public Dictionary<string, object?>? Map { get; set; }
    }

    public static readonly string[] Forms = ["typed", "dictionary"];

    // The anchor of a round is the id of its first member, since ids number straight through a round body.
    private static Field Repeat(string form, int anchor) => form == "typed"
        ? Field.Repeat(anchor, (Row x) => x.Legs, Field.U8<Leg>(anchor, r => r.V))
        : Field.Repeat(anchor, Field.U8<Row>(anchor, x => x.V));

    private static Field RepeatW(string form, int anchor) => form == "typed"
        ? Field.Repeat(anchor, (Row x) => x.LegsW, Field.U8<LegW>(anchor, r => r.W))
        : Field.Repeat(anchor, Field.U8<Row>(anchor, x => x.W));

    private static Field Times(string form, int anchor, int countId) => form == "typed"
        ? Field.Times(anchor, countId, (Row x) => x.Legs, Field.U8<Leg>(anchor, r => r.V))
        : Field.Times(anchor, countId, Field.U8<Row>(anchor, x => x.V));

    private static Field K(int id) => Field.U8<Row>(id, x => x.K);

    private static Field X(int id) => Field.U8<Row>(id, x => x.X);

    private static Field Mode(int id) => Field.U8<Row>(id, x => x.Mode);

    private static Field Empty(int id) => Field.Bytes<Row>(id, x => x.Z, 0);

    private static Field[] SplitBits(Func<Field, Field[]> place) => place(Field.FlagByte());

    private static string Follows(int anchor, string field) =>
        $"repeat {anchor}: {field} follows it; a repeat reads to the end of the packet, so nothing can follow it; use times";

    private static string InElement(int anchor) =>
        $"repeat {anchor} is inside a list or dict element; a repeat reads to the end of the packet, "
        + "so another element cannot follow it; use times";

    private static string Hex(byte[] raw) => Convert.ToHexString(raw).ToLowerInvariant();

    // The refused cases of the contract: the fields in the given form, and the whole refusal text.
    private static readonly Dictionary<string, (Func<string, Field[]> Fields, string Text)> Refused = new()
    {
        ["R1"] = (form => [Repeat(form, 0), X(1)], Follows(0, "'X' (field id 1)")),
        ["R2"] = (form => [K(0), Field.When(1, Condition.Eq(0, 1), Repeat(form, 1)), X(2)], Follows(1, "'X' (field id 2)")),
        ["R3"] = (form => [Field.Flags(0, Repeat(form, 0)), X(1)], Follows(0, "'X' (field id 1)")),
        // A nested row numbers its members from 0 itself, so `x` is id 0 of the row around it.
        ["R4 nested row"] = (form => [Field.Group((Row x) => x.M, Repeat(form, 0)), X(0)], Follows(0, "'X' (field id 0)")),
        ["R4 anchored group"] = (form => [Field.Group(0, (Row x) => x.G, Repeat(form, 0)), X(1)], Follows(0, "'X' (field id 1)")),
        ["R5"] = (form => [Repeat(form, 0), RepeatW(form, 1)], Follows(0, "repeat 1")),
        ["R6"] = (form => [K(0), Field.When(1, Condition.Eq(0, 1), Repeat(form, 1)), Field.When(2, Condition.Eq(0, 2), X(2))],
            Follows(1, "'X' (field id 2)")),
        ["R7"] = (form => [Field.List<Row, Row>(x => x.Items, Mode(0), Repeat(form, 1))], InElement(1)),
        ["R8"] = (form => [Field.Dict<Row, Row>(x => x.D, Mode(0), Repeat(form, 1))], InElement(1)),
        ["R9"] = (form => [K(0), Field.Times(1, 0, Repeat(form, 1))],
            "repeat 1 is inside a repeat or times round; a round cannot hold another repeat or times"),

        // What follows is named by its kind: the first thing after the repeat that can write a byte.
        ["a flags follows"] = (form => [Repeat(form, 0), Field.Flags(1, X(1))], Follows(0, "flags 1")),
        ["a flag byte follows"] = (form => SplitBits(m => [Repeat(form, 0), m, m.Bit(X(1))]), Follows(0, "a flag byte")),
        ["a list follows"] = (form => [Repeat(form, 0), Field.List((Row x) => x.Bag, Field.U8<Leg>(0, e => e.V))],
            Follows(0, "list 'Bag'")),
        ["a dict follows"] = (form => [Repeat(form, 0), Field.Dict((Row x) => x.Map, Field.U8<Leg>(0, e => e.V))],
            Follows(0, "dict 'Map'")),
        ["a times follows"] = (form => [K(0), Repeat(form, 1), Field.Times(2, 0, X(2))], Follows(1, "times 2")),
        ["a later bit of an earlier flag byte"] = (form => SplitBits(m => [m, Repeat(form, 0), m.Bit(X(1))]),
            Follows(0, "'X' (field id 1)")),
        ["a later member of the same flags"] = (form => [Field.Flags(0, Repeat(form, 0), X(1))], Follows(0, "'X' (field id 1)")),
        ["a field after a repeat of zero-width rounds"] = (_ => [Field.Repeat(0, Empty(0)), X(1)], Follows(0, "'X' (field id 1)")),

        // Inside an element under a container of the element, and in an element of a list that a round holds.
        ["in a flags element"] = (form => [Field.List((Row x) => x.Bag, Field.Flags(0, Mode(0), Repeat(form, 1)))], InElement(1)),
        ["under a when of an element row"] = (
            form => [Field.List<Row, Row>(x => x.Items, Mode(0), Field.When(1, Condition.Eq(0, 1), Repeat(form, 1)))], InElement(1)),
        ["in a nested row of an element row"] = (
            form => [Field.Dict<Row, Row>(x => x.D, Mode(0), Field.Group((Row x) => x.M, Repeat(form, 0)))], InElement(0)),
        // Both cases hold (a member of the element follows the repeat): the walk meets the repeat first and names case 2.
        ["in an element with a member after it"] = (form => [Field.List<Row, Row>(x => x.Items, Repeat(form, 0), Mode(1))], InElement(0)),
        ["in an element of a list in a round"] = (
            form => [Field.Repeat(0, K(0), Field.List((Row x) => x.Bag, Field.Group(0, (Row e) => e.G, Mode(0), Repeat(form, 1))))],
            InElement(1)),
    };

    public static IEnumerable<object[]> RefusedCases() =>
        from id in Refused.Keys from form in Forms select new object[] { id, form };

    [Theory]
    [MemberData(nameof(RefusedCases))]
    public void Ac1_Build_RepeatThatIsNotLast_IsRefusedWithTheWholeText(string id, string form)
    {
        // Arrange (AC-1: R1 to R9 and the kinds of follower, in both forms)
        var (fields, text) = Refused[id];
        var members = fields(form);

        // Act
        var refused = Record.Exception(() => new Scheme<Row>(1, members));

        // Assert
        Assert.Equal(text, Assert.IsType<ArgumentException>(refused).Message);
    }

    // The cases that keep building: the fields, and the names packed and read back. K is the count of K4 and the `when`
    // source of K2; the other values are the contract's: x = 9, v = [5, 6], the bool true, a zero-width byte run.
    private static readonly Dictionary<string, (Func<string, Field[]> Fields, byte K, string[] Names)> Kept = new()
    {
        ["K1"] = (form => [X(0), Repeat(form, 1)], 0, ["X", "V"]),
        ["K2"] = (form => [K(0), Field.When(1, Condition.Eq(0, 1), Repeat(form, 1))], 1, ["K", "V"]),
        ["K3"] = (form => [Field.Flags(0, X(0), Repeat(form, 1))], 0, ["X", "V"]),
        ["K4"] = (form => [K(0), Times(form, 1, 0), X(2)], 2, ["K", "V", "X"]),
        ["K5"] = (form => SplitBits(m => [m, m.Bit(X(0)), Repeat(form, 1), m.Bit(Field.Bool<Row>(2, x => x.B))]), 0, ["X", "V", "B"]),
        ["bool after the repeat in one flags"] = (
            form => [Field.Flags(0, Repeat(form, 0), Field.Bool<Row>(1, x => x.B))], 0, ["V", "B"]),
        ["zero-width bytes after the repeat"] = (form => [Repeat(form, 0), Empty(1)], 0, ["V", "Z"]),
    };

    private static string Shown(object? value) => value switch
    {
        IEnumerable items and not string => string.Join(",", items.Cast<object?>().Select(Shown)),
        _ => Convert.ToString(value, CultureInfo.InvariantCulture) ?? "null",
    };

    private static string TypedBack(Scheme<Row> scheme, byte k, string[] names, out string packet)
    {
        var row = new Row { K = k, X = 9, B = true, Legs = [new Leg { V = 5 }, new Leg { V = 6 }] };
        var raw = BinaryPacker.Pack(scheme, row);
        Row? got = null;
        var error = BinaryPacker.Unpack(raw, scheme.On(read => got = read));
        Assert.Null(error);
        packet = Hex(raw);
        var back = new Dictionary<string, object?>
        {
            ["K"] = got!.K,
            ["X"] = got.X,
            ["B"] = got.B,
            ["Z"] = got.Z,
            ["V"] = got.Legs.Select(leg => leg.V).ToList(),
        };
        return string.Join(" ", names.Select(name => $"{name}={Shown(back[name])}"));
    }

    private static string DictionaryBack(Scheme<Row> scheme, byte k, string[] names, out string packet)
    {
        var all = new Dictionary<string, object?>
        {
            ["K"] = k,
            ["X"] = (byte)9,
            ["B"] = true,
            ["Z"] = Array.Empty<byte>(),
            ["V"] = new object?[] { (byte)5, (byte)6 },
        };
        var raw = BinaryPacker.Pack(scheme, names.ToDictionary(name => name, name => all[name]));
        var read = BinaryPacker.Read(scheme, raw);
        Assert.Null(read.Error);
        packet = Hex(raw);
        return string.Join(" ", names.Select(name => $"{name}={Shown(read.Values[name])}"));
    }

    [Theory]
    [InlineData("K1", "01090506", "X=9 V=5,6")]
    [InlineData("K2", "01010506", "K=1 V=5,6")]
    [InlineData("K3", "0103090506", "X=9 V=5,6")]
    [InlineData("K4", "0102050609", "K=2 V=5,6 X=9")]
    [InlineData("K5", "0103090506", "X=9 V=5,6 B=True")]
    public void Ac2_TypedRows_RepeatThatIsLast_PacksTheContractPacketAndReadsBack(string id, string packet, string values)
    {
        // Arrange (AC-2: K1 to K5 with typed rows)
        var (fields, k, names) = Kept[id];
        var scheme = new Scheme<Row>(1, fields("typed"));

        // Act
        var back = TypedBack(scheme, k, names, out var packed);

        // Assert
        Assert.Equal((packet, values), (packed, back));
    }

    [Theory]
    [InlineData("K1", "01090506", "X=9 V=5,6")]
    [InlineData("K2", "01010506", "K=1 V=5,6")]
    [InlineData("K3", "0103090506", "X=9 V=5,6")]
    [InlineData("K4", "0102050609", "K=2 V=5,6 X=9")]
    [InlineData("K5", "0103090506", "X=9 V=5,6 B=True")]
    public void Ac2_DictionaryRows_RepeatThatIsLast_PacksTheContractPacketAndReadsBack(string id, string packet, string values)
    {
        // Arrange (AC-2: K1 to K5 with an unbound repeat over a dictionary row)
        var (fields, k, names) = Kept[id];
        var scheme = new Scheme<Row>(1, fields("dictionary"));

        // Act
        var back = DictionaryBack(scheme, k, names, out var packed);

        // Assert
        Assert.Equal((packet, values), (packed, back));
    }

    [Theory]
    [InlineData("bool after the repeat in one flags", "typed", "01030506", "V=5,6 B=True")]
    [InlineData("bool after the repeat in one flags", "dictionary", "01030506", "V=5,6 B=True")]
    [InlineData("zero-width bytes after the repeat", "typed", "010506", "V=5,6 Z=")]
    [InlineData("zero-width bytes after the repeat", "dictionary", "010506", "V=5,6 Z=")]
    public void Ac1_FieldAfterTheRepeatThatWritesNoByte_BuildsAndReadsBack(string id, string form, string packet, string values)
    {
        // Arrange (AC-1, second row: a bool is a bit of a flag byte written earlier, a zero-width byte run writes nothing)
        var (fields, k, names) = Kept[id];
        var scheme = new Scheme<Row>(1, fields(form));

        // Act
        string packed;
        var back = form == "typed" ? TypedBack(scheme, k, names, out packed) : DictionaryBack(scheme, k, names, out packed);

        // Assert
        Assert.Equal((packet, values), (packed, back));
    }

    // Schemes near the rule that it must not refuse (Risk 2 of the task): nothing after the repeat can write a byte, or
    // the round has a count.
    private static readonly Dictionary<string, Func<string, Field[]>> StillBuilds = new()
    {
        ["a times of zero-width rounds after the repeat"] = form => [K(0), Repeat(form, 1), Field.Times(2, 0, Empty(2))],
        ["a when that holds a zero-width byte run after the repeat"] = form =>
            [K(0), Repeat(form, 1), Field.When(2, Condition.Eq(0, 1), Empty(2))],
        ["a repeat of zero-width rounds after the repeat"] = form => [Repeat(form, 0), Field.Repeat(1, Empty(1))],
        ["an empty group bit of an earlier flag byte after the repeat"] = form =>
            SplitBits(m => [m, Repeat(form, 0), m.Bit(Field.Group(1, (Row x) => x.G))]),
        ["a list before the repeat"] = form => [Field.List((Row x) => x.Bag, Field.U8<Leg>(0, e => e.V)), Repeat(form, 0)],
        ["a times in a list element and a field after the list"] = form =>
            [Field.List<Row, Row>(x => x.Items, Mode(0), Times(form, 1, 0)), X(0)],
        ["a list in the round of a repeat that is last"] = form =>
            [X(0), Field.Repeat(1, K(1), Field.List((Row x) => x.Bag, Field.U8<Leg>(0, e => e.V)))],
    };

    public static IEnumerable<object[]> StillBuildsCases() =>
        from id in StillBuilds.Keys from form in Forms select new object[] { id, form };

    [Theory]
    [MemberData(nameof(StillBuildsCases))]
    public void Ac2_Build_SchemeTheRuleDoesNotName_Builds(string id, string form)
    {
        // Arrange
        var members = StillBuilds[id](form);

        // Act
        var refused = Record.Exception(() => new Scheme<Row>(1, members));

        // Assert
        Assert.Null(refused);
    }
}
