using System.Text;
using Packbin;

public sealed class DictRow { public Dictionary<string, object?>? D { get; set; } }
public sealed class El { public byte V { get; set; } }
public sealed class TextRow { public string S { get; set; } = ""; }

public static class Program
{
    static string Hex(byte[] b) => Convert.ToHexString(b).ToLowerInvariant();
    static string Units(string s) => string.Join(" ", s.Select(c => $"U+{(int)c:X4}"));
    static string Err(object? e) => e switch
    {
        null => "null",
        ShortPacket p => $"ShortPacket(field=\"{p.Field}\", needed={p.Needed}, left={p.Left})",
        TrailingBytes t => $"TrailingBytes(left={t.Left})",
        _ => e.GetType().Name + " " + e,
    };

    static void Case(string label, string[] keys, byte[] vals)
    {
        Console.WriteLine("CASE " + label);
        var scheme = new Scheme<DictRow>(1, Field.Dict((DictRow x) => x.D, Field.U8<El>(0, e => e.V)));
        var d = new Dictionary<string, object?>();
        for (int i = 0; i < keys.Length; i++) d[keys[i]] = vals[i];
        byte[] pkt;
        try { pkt = BinaryPacker.Pack(scheme, new Dictionary<string, object?> { ["D"] = d }); }
        catch (Exception ex) { Console.WriteLine($"  pack (dictionary form) THREW {ex.GetType().FullName}: {ex.Message}"); return; }
        Console.WriteLine("  pack hex=" + Hex(pkt));
        var read = BinaryPacker.Read(scheme, pkt);
        Console.WriteLine("  unpack (Read) error=" + Err(read.Error));
        if (read.Error is null && read.Values.TryGetValue("D", out var v) && v is Dictionary<string, object?> m)
        {
            foreach (var kv in m) Console.WriteLine($"  key read back: {Units(kv.Key)} -> {kv.Value}");
            Console.WriteLine("  count=" + m.Count);
        }
        // public API path too
        DictRow? got = null;
        var res = BinaryPacker.Unpack(pkt, scheme.On(r => got = r));
        Console.WriteLine("  unpack (public Unpack) error=" + Err(res) + (got?.D is { } gd ? " keys=" + string.Join(",", gd.Keys.Select(Units)) : ""));
    }

    public static void Main()
    {
        Case("A", ["\uD800", "\uDC00"], [1, 2]);
        Case("B", ["�", "\uD800"], [1, 2]);
        Case("C", ["?", "\uD800"], [1, 2]);
        Case("D", ["\uD800"], [1]);
        Console.WriteLine("CASE E");
        var s = new Scheme<TextRow>(1, Field.Utf8<TextRow>(0, x => x.S));
        try
        {
            var pkt = BinaryPacker.Pack(s, new Dictionary<string, object?> { ["S"] = "\uD800" });
            Console.WriteLine("  pack hex=" + Hex(pkt));
            var read = BinaryPacker.Read(s, pkt);
            Console.WriteLine("  unpack (Read) error=" + Err(read.Error) + (read.Values.TryGetValue("S", out var v) && v is string t ? " value units: " + Units(t) : ""));
        }
        catch (Exception ex) { Console.WriteLine($"  pack THREW {ex.GetType().FullName}: {ex.Message}"); }
    }
}
