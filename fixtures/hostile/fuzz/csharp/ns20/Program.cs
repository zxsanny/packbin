// AZ-2666: Compat.TryUtf8 as the netstandard2.0 build compiles it, against Utf8.IsValid, on random and edge buffers.
// Usage: Ns20Utf8Probe [seed] [count]. Exit 1 when the two disagree or an exception escapes.
using System.Text.Unicode;

var seed = args.Length > 0 ? int.Parse(args[0]) : 41;
var count = args.Length > 1 ? int.Parse(args[1]) : 2_000_000;
var r = new Random(seed);
long disagree = 0, thrown = 0, valid = 0;
string[] edges = ["eda080", "edbfbf", "c080", "c1bf", "e08080", "e09fbf", "f0808080", "f08fbfbf", "f4908080", "f5808080",
    "f8", "ff", "80", "e282", "f09f98", "e228a1", "c328", "efbbbf61", "00", "f48fbfbf", "efbfbf", "f09f9880"];
byte[] Next(int i)
{
    if (i < edges.Length)
        return Convert.FromHexString(edges[i]);
    var b = new byte[r.Next(0, 12)];
    for (var k = 0; k < b.Length; k++)
        b[k] = r.Next(3) switch { 0 => (byte)r.Next(0x80), 1 => (byte)(0x80 | r.Next(0x40)), _ => (byte)(0xc0 | r.Next(0x40)) };
    return b;
}
for (var i = 0; i < count; i++)
{
    var b = Next(i);
    try
    {
        var ok = Packbin.Compat.TryUtf8(b, out _);
        if (ok != Utf8.IsValid(b))
        {
            if (disagree++ < 10)
                Console.WriteLine($"disagree on {Convert.ToHexString(b)}: ns20 {ok}");
        }
        valid += ok ? 1 : 0;
    }
    catch (Exception ex)
    {
        if (thrown++ < 10)
            Console.WriteLine($"{ex.GetType().Name} on {Convert.ToHexString(b)}");
    }
}
Console.WriteLine($"ns20 TryUtf8: {count} buffers (seed {seed}), valid {valid}, disagree with Utf8.IsValid {disagree}, thrown {thrown}");
return disagree == 0 && thrown == 0 ? 0 : 1;
