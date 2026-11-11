using System.Text;
using Packbin;
public sealed class DictRow { public Dictionary<string, object?>? D { get; set; } }
public sealed class El { public byte V { get; set; } }
public static class Program
{
    static string Key(string units) { if (units == "-") return ""; var sb = new StringBuilder(); for (int i = 0; i < units.Length; i += 4) sb.Append((char)Convert.ToInt32(units.Substring(i, 4), 16)); return sb.ToString(); }
    public static void Main(string[] args)
    {
        var scheme = new Scheme<DictRow>(1, Field.Dict((DictRow x) => x.D, Field.U8<El>(0, e => e.V)));
        int same = 0, diff = 0, refused = 0;
        foreach (var line in File.ReadAllLines(args[0]))
        {
            if (line.Length == 0) continue;
            var f = line.Split('\t');
            var keys = f[0].Split(',').Select(Key).ToArray(); var vals = f[1].Split(',').Select(byte.Parse).ToArray();
            var d = new Dictionary<string, object?>();
            for (int i = 0; i < keys.Length; i++) d[keys[i]] = vals[i];
            string got;
            try { got = Convert.ToHexString(BinaryPacker.Pack(scheme, new Dictionary<string, object?> { ["D"] = d })).ToLowerInvariant(); }
            catch (ArgumentException e) when (e.Message.Contains("two keys are the same")) { got = "REFUSED"; refused++; }
            if (got == f[2]) same++; else { diff++; if (diff < 6) Console.WriteLine($"DIFF keys={f[0]} ts={f[2]} cs={got}"); }
        }
        Console.WriteLine($"csharp vs typescript: {same} same, {diff} different, {refused} refused");
    }
}
