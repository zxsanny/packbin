// Probe of AZ-4251: a `flags` that is a direct member of a `flags`. It builds scheme S of ../README.md,
// packs each shape's values and unpacks its own bytes. One line per shape: package, shape, build, pack,
// unpack (tab separated). It asserts nothing: it prints what happens.
//
// S is Field.Flags(0, Field.Flags(0, Field.U8<Row>(0, r => r.X)), Field.Bool<Row>(1, r => r.B)): both Flags and
// X are 0, B is 1. The row class has `byte? X` (null: absent) and `bool B` (false: the bit is clear).
//
// C# packs a scheme two ways:
//   - the typed row (BinaryPacker.Pack(scheme, row)): the lines on stdout.
//   - a dictionary row (BinaryPacker.Pack(scheme, IReadOnlyDictionary)) with the same scheme, a shape leaving a
//     value out by leaving its key out: the same shapes with the suffix "-map", on stderr. The package has no
//     public call that reads a dictionary row, so the bytes are read back with the typed Unpack and compared
//     with the typed row that holds the same values.
// Only public members of the package are called (the sources are compiled into this assembly, see Probe.csproj).
using System.Text.RegularExpressions;
using Packbin;

namespace FlagsProbe;

public sealed class Row
{
    public byte? X { get; set; }
    public bool B { get; set; }
}

public static class Program
{
    private static string OneLine(string text) => Regex.Replace(text, @"\s+", " ").Trim();

    private static string Named(Exception e) => OneLine($"{e.GetType().Name}: {e.Message}");

    private static string Hex(byte[] bytes) => Convert.ToHexString(bytes).ToLowerInvariant();

    private static string Shown(Row row) =>
        "{\"B\":" + (row.B ? "true" : "false") + ",\"X\":" + (row.X is { } x ? x.ToString() : "null") + "}";

    // An error value has public properties and no ToString of its own: its class and its properties as declared.
    private static string Error(object? value)
    {
        if (value is null)
            return "null";
        var members = value.GetType().GetProperties().OrderBy(p => p.MetadataToken)
            .Select(p => p.Name + "=" + p.GetValue(value));
        return value.GetType().Name + "(" + string.Join(", ", members) + ")";
    }

    private static Scheme<Row> Build() =>
        new(1, Field.Flags(0, Field.Flags(0, Field.U8<Row>(0, r => r.X)), Field.Bool<Row>(1, r => r.B)));

    // The unpack column once Unpack returned. The probe's own rendering runs inside the try: a failure of it is
    // printed, and the shapes after this one still run.
    private static string Unpacked(object? result, Row? got, Row given)
    {
        try
        {
            if (result is not null || got is null)
                return "refused: " + OneLine(Error(result));
            return Shown(got) == Shown(given) ? "same" : "differs: " + Shown(got);
        }
        catch (Exception e)
        {
            return "threw: probe: " + Named(e);
        }
    }

    private static void Probe(TextWriter output, string shape, Func<Scheme<Row>, byte[]> pack, Row given)
    {
        void Line(string built, string packed, string unpacked) =>
            output.WriteLine(string.Join("\t", "csharp", shape, built, packed, unpacked));

        Scheme<Row> scheme;
        try
        {
            scheme = Build();
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
        Row? got = null;
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

    public static void Main()
    {
        (string Shape, byte? X, bool? B)[] shapes =
        [
            ("both", 9, true),
            ("x-only", 9, null),
            ("b-only", null, true),
            ("none", null, null),
        ];
        foreach (var (shape, x, b) in shapes)
        {
            var row = new Row { X = x, B = b ?? false };
            Probe(Console.Out, shape, scheme => BinaryPacker.Pack(scheme, row), row);
        }
        foreach (var (shape, x, b) in shapes)
        {
            var values = new Dictionary<string, object?>();
            if (x is { } xv)
                values["X"] = xv;
            if (b is { } bv)
                values["B"] = bv;
            var row = new Row { X = x, B = b ?? false };
            Probe(Console.Error, shape + "-map", scheme => BinaryPacker.Pack(scheme, (IReadOnlyDictionary<string, object?>)values), row);
        }
    }
}
