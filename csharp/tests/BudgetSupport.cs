using System.Linq.Expressions;
using Packbin;

namespace Packbin.Tests;

// Rows, schemes and helpers shared by the pack budget tests (AZ-2354, AZ-2355).
internal sealed class BudgetRow
{
    public uint N { get; set; }
    public byte N8 { get; set; }
    public string S { get; set; } = "";
    public byte A { get; set; }
    public byte B { get; set; }
    public byte C { get; set; }
    public byte K { get; set; }
    public bool? G { get; set; }
    public List<object?>? Items { get; set; }
}

internal sealed class BudgetItem
{
    public byte N { get; set; }
    public byte K { get; set; }
    public bool? Mark { get; set; }
}

internal sealed class BudgetWideItem
{
    public uint N { get; set; }
    public ulong K { get; set; }
    public bool? Mark { get; set; }
}

internal sealed class BudgetWide
{
    public uint N { get; set; }
    public bool? Mark { get; set; }
    public byte M0 { get; set; }
    public byte M1 { get; set; }
    public byte M2 { get; set; }
    public byte M3 { get; set; }
    public byte M4 { get; set; }
    public byte M5 { get; set; }
    public byte M6 { get; set; }
    public byte M7 { get; set; }
    public byte M8 { get; set; }
    public byte M9 { get; set; }
    public byte M10 { get; set; }
    public byte M11 { get; set; }
    public byte M12 { get; set; }
    public byte M13 { get; set; }
    public byte M14 { get; set; }
    public byte M15 { get; set; }
    public byte M16 { get; set; }
    public byte M17 { get; set; }
    public byte M18 { get; set; }
    public byte M19 { get; set; }
    public byte M20 { get; set; }
    public byte M21 { get; set; }
    public byte M22 { get; set; }
    public byte M23 { get; set; }
    public byte M24 { get; set; }
    public byte M25 { get; set; }
    public byte M26 { get; set; }
    public byte M27 { get; set; }
    public byte M28 { get; set; }
    public byte M29 { get; set; }
    public byte M30 { get; set; }
    public byte M31 { get; set; }
    public byte M32 { get; set; }
    public byte M33 { get; set; }
    public byte M34 { get; set; }
    public byte M35 { get; set; }
    public byte M36 { get; set; }
    public byte M37 { get; set; }
    public byte M38 { get; set; }
    public byte M39 { get; set; }
    public byte M40 { get; set; }
    public byte M41 { get; set; }
    public byte M42 { get; set; }
    public byte M43 { get; set; }
    public byte M44 { get; set; }
    public byte M45 { get; set; }
    public byte M46 { get; set; }
    public byte M47 { get; set; }
    public byte M48 { get; set; }
    public byte M49 { get; set; }
    public byte M50 { get; set; }
    public byte M51 { get; set; }
    public byte M52 { get; set; }
    public byte M53 { get; set; }
    public byte M54 { get; set; }
    public byte M55 { get; set; }
    public byte M56 { get; set; }
    public byte M57 { get; set; }
    public byte M58 { get; set; }
    public byte M59 { get; set; }
    public byte M60 { get; set; }
    public byte M61 { get; set; }
    public byte M62 { get; set; }
    public byte M63 { get; set; }
    public byte M64 { get; set; }
}

internal static class Budget
{
    public static string Hex(byte[] raw) => Convert.ToHexString(raw).ToLowerInvariant();

    public static string Hex(byte[] raw, int from, int length) => Convert.ToHexString(raw, from, length).ToLowerInvariant();

    public static Dictionary<string, object?> Row(params (string Name, object? Value)[] values) =>
        values.ToDictionary(v => v.Name, v => v.Value);

    // The same row as a typed instance, for the values that are not lists.
    public static BudgetRow Typed(params (string Name, object? Value)[] values)
    {
        var row = new BudgetRow();
        foreach (var (name, value) in values)
        {
            var property = typeof(BudgetRow).GetProperty(name)!;
            property.SetValue(row, Convert.ChangeType(value, property.PropertyType));
        }
        return row;
    }

    public static object?[] Repeated(object value, int count) => [.. Enumerable.Repeat<object?>(value, count)];

    public static ArgumentException Refused<T>(Scheme<T> scheme, IReadOnlyDictionary<string, object?> values) where T : class, new() =>
        Assert.IsAssignableFrom<ArgumentException>(Record.Exception(() => BinaryPacker.Pack(scheme, values)));

    public static ArgumentException Refused<T>(Scheme<T> scheme, T row) where T : class, new() =>
        Assert.IsAssignableFrom<ArgumentException>(Record.Exception(() => BinaryPacker.Pack(scheme, row)));

    // `u8 M<i>` of the 65-name round.
    public static Field WideMember(int i)
    {
        var x = Expression.Parameter(typeof(BudgetWide), "x");
        var member = Expression.Lambda<Func<BudgetWide, byte>>(Expression.Property(x, $"M{i}"), x);
        return Field.U8(i + 1, member);
    }

    // u32 n; times(n) { u8 m0 ... u8 m64 }
    public static Scheme<BudgetWide> WideRound() => new(1,
        [Field.U32<BudgetWide>(0, x => x.N), Field.Times(1, 0, [.. Enumerable.Range(0, 65).Select(WideMember)])]);

    public static Dictionary<string, object?> WideRow(uint n)
    {
        var row = new Dictionary<string, object?> { ["N"] = n };
        for (var i = 0; i < 65; i++)
            row[$"M{i}"] = (byte)1;
        return row;
    }
}
