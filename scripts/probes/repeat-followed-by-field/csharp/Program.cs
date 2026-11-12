// Probe of AZ-4206: a repeat that is not the last thing a packet reads. It builds each shape of
// ../README.md, packs the values given there and unpacks its own bytes. One line per shape:
// package, shape, build, pack, unpack (tab separated). It asserts nothing: it prints what happens.
//
// C# writes a scheme two ways:
//   - a typed row whose repeat is bound to a collection of rows (Fields<T>.Repeat(anchor, x => x.Rounds, ...)):
//     the lines on stdout. It is the only form the public Unpack can read back, so it is the one that
//     expresses the shapes. The rounds are rows: round 0 has V = 5, round 1 has V = 6. A list or dict element
//     is the element row of loop 111 (Fields<T>.List(x => x.Items, e => [members])).
//   - a dictionary row with one list per name (BinaryPacker.Pack(scheme, IReadOnlyDictionary)) over an unbound
//     Field.Repeat(anchor, fields): the same shapes with the suffix "-map", on stderr. The package has no
//     public call that reads a dictionary row, and the byte member of a typed row cannot hold the list of its
//     rounds, so no line of this form can read back: the typed Unpack refuses that member in the control too.
//     These lines give no same/differs verdict, since a typed row is not the dictionary given: a row that Unpack
//     returns would be printed as "read: <row>" (no line does today).
// Only public members of the package are called (the sources are compiled into this assembly, see Probe.csproj).
using System.Collections;
using System.Globalization;
using System.Reflection;
using System.Text.RegularExpressions;
using Packbin;

namespace RepeatProbe;

public sealed class Round
{
    public byte V { get; set; }
}

public sealed class Plain
{
    public byte X { get; set; }
    public List<Round> Rounds { get; set; } = [];
}

public sealed class Keyed
{
    public byte K { get; set; }
    public List<Round> Rounds { get; set; } = [];
    public byte X { get; set; }
}

public sealed class Item
{
    public byte Mode { get; set; }
    public List<Round> Rounds { get; set; } = [];
}

public sealed class Listed
{
    public List<Item> Items { get; set; } = [];
}

public sealed class Mapped
{
    public Dictionary<string, Item> D { get; set; } = [];
}

public sealed class Nested
{
    public List<Round> Rounds { get; set; } = [];
}

public sealed class Outer
{
    public Nested? M { get; set; }
    public byte X { get; set; }
}

public sealed class RoundW
{
    public byte W { get; set; }
}

// Shape f. A collection unpack never sets stays null, so it prints apart from one unpack set to no rounds.
public sealed class Twice
{
    public List<Round>? RoundsV { get; set; }
    public List<RoundW>? RoundsW { get; set; }
}

// The rows of the dictionary form: a name inside an unbound repeat is declared on the row that holds the repeat.
public sealed class Flat
{
    public byte X { get; set; }
    public byte K { get; set; }
    public byte V { get; set; }
    public byte W { get; set; }
}

public sealed class FlatItem
{
    public byte Mode { get; set; }
    public byte V { get; set; }
}

public sealed class FlatListed
{
    public List<FlatItem> Items { get; set; } = [];
}

public sealed class FlatMapped
{
    public Dictionary<string, FlatItem> D { get; set; } = [];
}

public sealed class FlatNested
{
    public byte V { get; set; }
}

public sealed class FlatOuter
{
    public FlatNested? M { get; set; }
    public byte X { get; set; }
}

public static class Program
{
    private static string OneLine(string text) => Regex.Replace(text, @"\s+", " ").Trim();

    private static string Named(Exception e) => OneLine($"{e.GetType().Name}: {e.Message}");

    private static string Hex(byte[] bytes) => Convert.ToHexString(bytes).ToLowerInvariant();

    private static string Quoted(string text) => "\"" + text.Replace("\\", "\\\\").Replace("\"", "\\\"") + "\"";

    private static IEnumerable<PropertyInfo> Members(object value) =>
        value.GetType().GetProperties(BindingFlags.Public | BindingFlags.Instance);

    // Keys and member names in sorted order, so two rows that hold the same values print the same text.
    private static string Shown(object? value) => value switch
    {
        null => "null",
        string text => Quoted(text),
        bool flag => flag ? "true" : "false",
        IFormattable number when value.GetType().IsPrimitive => number.ToString(null, CultureInfo.InvariantCulture),
        IDictionary map => "{" + string.Join(",", map.Keys.Cast<string>().OrderBy(k => k, StringComparer.Ordinal)
            .Select(k => Quoted(k) + ":" + Shown(map[k]))) + "}",
        IEnumerable items => "[" + string.Join(",", items.Cast<object?>().Select(Shown)) + "]",
        _ => "{" + string.Join(",", Members(value).OrderBy(p => p.Name, StringComparer.Ordinal)
            .Select(p => Quoted(p.Name) + ":" + Shown(p.GetValue(value)))) + "}",
    };

    // An error value has public properties and no ToString of its own: its class and its properties as declared.
    private static string Error(object? value)
    {
        if (value is null)
            return "null";
        var members = Members(value).OrderBy(p => p.MetadataToken).Select(p =>
            p.Name + "=" + (p.GetValue(value) is string text
                ? Quoted(text)
                : Convert.ToString(p.GetValue(value), CultureInfo.InvariantCulture)));
        return value.GetType().Name + "(" + string.Join(", ", members) + ")";
    }

    // The unpack column once Unpack returned. `given` is null for the dictionary form, whose line says what was read
    // and gives no verdict. The probe's own rendering runs inside the try: a failure of it is printed, and the shapes
    // after this one still run.
    private static string Unpacked(object? result, object? got, object? given)
    {
        try
        {
            if (result is not null || got is null)
                return "refused: " + OneLine(Error(result));
            if (given is null)
                return "read: " + OneLine(Shown(got));
            return Shown(got) == Shown(given) ? "same" : "differs: " + OneLine(Shown(got));
        }
        catch (Exception e)
        {
            return "threw: probe: " + Named(e);
        }
    }

    private static void Probe<T>(
        TextWriter output, string shape, Func<Scheme<T>> build, Func<Scheme<T>, byte[]> pack, object? given)
        where T : class, new()
    {
        void Line(string built, string packed, string unpacked) =>
            output.WriteLine(string.Join("\t", "csharp", shape, built, packed, unpacked));

        Scheme<T> scheme;
        try
        {
            scheme = build();
        }
        catch (Exception e)
        {
            Line("refused: " + Named(e), "-", "-");
            return;
        }
        byte[] packed;
        try
        {
            packed = pack(scheme);
        }
        catch (Exception e)
        {
            Line("built", "refused: " + Named(e), "-");
            return;
        }
        T? got = null;
        object? result;
        try
        {
            result = BinaryPacker.Unpack(packed, scheme.On(row => got = row));
        }
        catch (Exception e)
        {
            Line("built", Hex(packed), "threw: " + Named(e));
            return;
        }
        Line("built", Hex(packed), Unpacked(result, got, given));
    }

    private static void Typed<T>(string shape, Func<Scheme<T>> build, T row) where T : class, new() =>
        Probe(Console.Out, shape, build, scheme => BinaryPacker.Pack(scheme, row), row);

    private static void Map<T>(string shape, Func<Scheme<T>> build, Dictionary<string, object?> row) where T : class, new() =>
        Probe(Console.Error, shape + "-map", build,
            scheme => BinaryPacker.Pack(scheme, (IReadOnlyDictionary<string, object?>)row), given: null);

    private static List<Round> Rounds(params byte[] values) => values.Select(v => new Round { V = v }).ToList();

    private static void TypedRows()
    {
        // control: the repeat is the last thing read.
        Typed("control",
            () => new Scheme<Plain>(1, f => [
                f.U8(0, x => x.X),
                f.Repeat(1, x => x.Rounds, r => [r.U8(1, v => v.V)])]),
            new Plain { X = 9, Rounds = Rounds(5, 6) });

        // a: a field after a repeat, top level.
        Typed("a",
            () => new Scheme<Plain>(1, f => [
                f.Repeat(0, x => x.Rounds, r => [r.U8(0, v => v.V)]),
                f.U8(1, x => x.X)]),
            new Plain { Rounds = Rounds(5, 6), X = 9 });

        // b: a repeat inside a list element row, two items.
        Typed("b",
            () => new Scheme<Listed>(1, f => [
                f.List(x => x.Items, e => [
                    e.U8(0, i => i.Mode),
                    e.Repeat(1, i => i.Rounds, r => [r.U8(1, v => v.V)])])]),
            new Listed { Items = [new Item { Mode = 1, Rounds = Rounds(5) }, new Item { Mode = 2, Rounds = Rounds() }] });

        // c: a repeat inside a dict element row, two entries.
        Typed("c",
            () => new Scheme<Mapped>(1, f => [
                f.Dict(x => x.D, e => [
                    e.U8(0, i => i.Mode),
                    e.Repeat(1, i => i.Rounds, r => [r.U8(1, v => v.V)])])]),
            new Mapped
            {
                D = new()
                {
                    ["a"] = new Item { Mode = 1, Rounds = Rounds(5) },
                    ["b"] = new Item { Mode = 2, Rounds = Rounds() },
                },
            });

        // d: a repeat inside a nested row, then a field. The nested row numbers its fields from 0 itself, so X is
        // field 0 of the top level.
        Typed("d",
            () => new Scheme<Outer>(1, f => [
                f.Group(x => x.M!, m => [m.Repeat(0, n => n.Rounds, r => [r.U8(0, v => v.V)])]),
                f.U8(0, x => x.X)]),
            new Outer { M = new Nested { Rounds = Rounds(5, 6) }, X = 9 });

        // e-when: a repeat under a when that is taken, then a field.
        Typed("e-when",
            () => new Scheme<Keyed>(1, f => [
                f.U8(0, x => x.K),
                f.When(1, Condition.Eq(0, 1), f.Repeat(1, x => x.Rounds, r => [r.U8(1, v => v.V)])),
                f.U8(2, x => x.X)]),
            new Keyed { K = 1, Rounds = Rounds(5, 6), X = 9 });

        // e-flags: a repeat under flags, then a field.
        Typed("e-flags",
            () => new Scheme<Plain>(1, f => [
                f.Flags(0, f.Repeat(0, x => x.Rounds, r => [r.U8(0, v => v.V)])),
                f.U8(1, x => x.X)]),
            new Plain { Rounds = Rounds(5, 6), X = 9 });

        // f: a repeat after a repeat, one round each. Ids number straight through the two bodies.
        Typed("f",
            () => new Scheme<Twice>(1, f => [
                f.Repeat(0, x => x.RoundsV!, r => [r.U8(0, v => v.V)]),
                f.Repeat(1, x => x.RoundsW!, r => [r.U8(1, w => w.W)])]),
            new Twice { RoundsV = Rounds(5), RoundsW = [new RoundW { W = 6 }] });
    }

    private static List<object?> Bytes(params byte[] values) => values.Cast<object?>().ToList();

    private static Dictionary<string, object?> FlatElement(byte mode, params byte[] v) =>
        new() { ["Mode"] = mode, ["V"] = Bytes(v) };

    private static Field[] FlatElementRow() =>
        [Field.U8<FlatItem>(0, i => i.Mode), Field.Repeat(1, Field.U8<FlatItem>(1, i => i.V))];

    private static void DictionaryRows()
    {
        Map("control",
            () => new Scheme<Flat>(1, Field.U8<Flat>(0, x => x.X), Field.Repeat(1, Field.U8<Flat>(1, x => x.V))),
            new() { ["X"] = (byte)9, ["V"] = Bytes(5, 6) });

        Map("a",
            () => new Scheme<Flat>(1, Field.Repeat(0, Field.U8<Flat>(0, x => x.V)), Field.U8<Flat>(1, x => x.X)),
            new() { ["V"] = Bytes(5, 6), ["X"] = (byte)9 });

        Map("b",
            () => new Scheme<FlatListed>(1, Field.List<FlatListed, FlatItem>(x => x.Items, FlatElementRow())),
            new() { ["Items"] = new List<object?> { FlatElement(1, 5), FlatElement(2) } });

        Map("c",
            () => new Scheme<FlatMapped>(1, Field.Dict<FlatMapped, FlatItem>(x => x.D, FlatElementRow())),
            new() { ["D"] = new Dictionary<string, object?> { ["a"] = FlatElement(1, 5), ["b"] = FlatElement(2) } });

        Map("d",
            () => new Scheme<FlatOuter>(1,
                Field.Group((FlatOuter x) => x.M, Field.Repeat(0, Field.U8<FlatNested>(0, n => n.V))),
                Field.U8<FlatOuter>(0, x => x.X)),
            new() { ["M"] = new Dictionary<string, object?> { ["V"] = Bytes(5, 6) }, ["X"] = (byte)9 });

        Map("e-when",
            () => new Scheme<Flat>(1,
                Field.U8<Flat>(0, x => x.K),
                Field.When(1, Condition.Eq(0, 1), Field.Repeat(1, Field.U8<Flat>(1, x => x.V))),
                Field.U8<Flat>(2, x => x.X)),
            new() { ["K"] = (byte)1, ["V"] = Bytes(5, 6), ["X"] = (byte)9 });

        Map("e-flags",
            () => new Scheme<Flat>(1,
                Field.Flags(0, Field.Repeat(0, Field.U8<Flat>(0, x => x.V))),
                Field.U8<Flat>(1, x => x.X)),
            new() { ["V"] = Bytes(5, 6), ["X"] = (byte)9 });

        Map("f",
            () => new Scheme<Flat>(1,
                Field.Repeat(0, Field.U8<Flat>(0, x => x.V)),
                Field.Repeat(1, Field.U8<Flat>(1, x => x.W))),
            new() { ["V"] = Bytes(5), ["W"] = Bytes(6) });
    }

    public static void Main()
    {
        TypedRows();
        DictionaryRows();
    }
}
