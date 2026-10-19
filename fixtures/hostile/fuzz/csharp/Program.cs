// AZ-2666 hostile-input probes for the C# package: compact text decoder and message ECC unpack (loop 41 audit).
// Build: see PackbinProbe.csproj. Run: PackbinProbe <repo> <probe> [seed] [count]
//   fuzz-text   seeded random and mutated strings against TextDecoder.Read and the public Unpack (single, list, dict)
//   fuzz-ecc    seeded random and corrupted protected messages against Ecc.Repair, the public Unpack and PackSession
//   ecc-worst   per-call time of the costliest repairs at N = 254, n = 32 (t = 16 and t = 0)
//   text-amp <case>   decoded size and time of the largest texts; case: max, over, silent, packet1m, packet16m, dict, collide, baseline
//   edges       the AC-1 / AC-2 edge cases a random run is unlikely to hit (prints PASS / FAIL per case)
// Peak RSS of a run: /usr/bin/time -l PackbinProbe ...
// Every probe exits 0 when nothing unexpected happened and 1 when a check failed or an exception escaped.
using System.Diagnostics;
using System.Text;
using Packbin;

namespace PackbinProbe;

public sealed class NameRow
{
    public string Name { get; set; } = "";
}

public sealed class MapRow
{
    public Dictionary<string, object?>? M { get; set; }
}

public sealed class MapEl
{
    public byte V { get; set; }
}

public sealed class ListRow
{
    public List<object?>? L { get; set; }
}

public sealed class TextEl
{
    public string V { get; set; } = "";
}

internal static class Schemes
{
    internal static readonly Scheme<NameRow> Single = new(1, Field.Utf8<NameRow>(0, x => x.Name));
    internal static readonly Scheme<ListRow> List = new(3, Field.List((ListRow x) => x.L, Field.Utf8<TextEl>(0, e => e.V)));
    internal static readonly Scheme<MapRow> Map = new(2, Field.Dict((MapRow x) => x.M, Field.U8<MapEl>(0, e => e.V)));
    internal static readonly Scheme<MapRow> MapText = new(4, Field.Dict((MapRow x) => x.M, Field.Utf8<TextEl>(0, e => e.V)));
}

internal static class Program
{
    internal static string Repo = "";
    internal static int Failures;

    private static int Main(string[] args)
    {
        if (args.Length < 2)
        {
            Console.Error.WriteLine("usage: PackbinProbe <repo> <probe> [seed] [count]");
            return 2;
        }
        Repo = args[0];
        var seed = args.Length > 2 && int.TryParse(args[2], out var s) ? s : 41;
        var count = args.Length > 3 && int.TryParse(args[3], out var c) ? c : 0;
        Console.WriteLine($"probe={args[1]} seed={seed} runtime={Environment.Version} load={Load()}");
        var clock = Stopwatch.StartNew();
        switch (args[1])
        {
            case "fuzz-text":
                FuzzText.Run(seed, count == 0 ? 300_000 : count);
                break;
            case "fuzz-ecc":
                FuzzEcc.Run(seed, count == 0 ? 300_000 : count);
                break;
            case "ecc-worst":
                EccWorst.Run(seed, count == 0 ? 2_000 : count);
                break;
            case "text-amp":
                TextAmp.Run(args.Length > 2 ? args[2] : "max");
                break;
            case "edges":
                EdgesText.Run();
                EdgesEcc.Run();
                break;
            default:
                Console.Error.WriteLine($"unknown probe {args[1]}");
                return 2;
        }
        Console.WriteLine($"done in {clock.Elapsed.TotalSeconds:F2} s, failures={Failures}, load={Load()}");
        return Failures == 0 ? 0 : 1;
    }

    internal static void Fail(string what)
    {
        Failures++;
        if (Failures <= 40)
            Console.WriteLine("FAIL " + what);
    }

    internal static void Check(bool ok, string what)
    {
        if (ok)
            Console.WriteLine("PASS " + what);
        else
            Fail(what);
    }

    // The 1-minute load average, so every timing figure can carry it.
    internal static string Load()
    {
        try
        {
            var start = new ProcessStartInfo("/usr/sbin/sysctl", "-n vm.loadavg")
            {
                RedirectStandardOutput = true,
                RedirectStandardInput = true,
                UseShellExecute = false,
            };
            using var p = Process.Start(start)!;
            p.StandardInput.Close();
            var text = p.StandardOutput.ReadToEnd().Trim().Trim('{', '}').Trim();
            p.WaitForExit(2000);
            return text.Split(' ', StringSplitOptions.RemoveEmptyEntries).FirstOrDefault() ?? "?";
        }
        catch (System.ComponentModel.Win32Exception ex)
        {
            return "? (" + ex.Message + ")";
        }
    }

    internal static string Hex(ReadOnlySpan<byte> b, int max = 48)
    {
        var s = Convert.ToHexString(b.Length > max ? b[..max] : b).ToLowerInvariant();
        return b.Length > max ? s + $"..(+{b.Length - max})" : s;
    }

    internal static byte[] Bytes(string hex) => hex is "-" or "" ? [] : Convert.FromHexString(hex);

    internal static IEnumerable<string[]> Rows(string relative)
    {
        foreach (var line in File.ReadLines(Path.Combine(Repo, relative)))
        {
            if (line.Length == 0 || line[0] == '#')
                continue;
            yield return line.Split((char[]?)null, StringSplitOptions.RemoveEmptyEntries);
        }
    }

    internal static byte[] Varint(int count)
    {
        var out_ = new List<byte>();
        do
        {
            var b = count & 0x7f;
            count >>= 7;
            out_.Add((byte)(count != 0 ? b | 0x80 : b));
        } while (count != 0);
        return out_.ToArray();
    }

    internal static byte[] Concat(params byte[][] parts)
    {
        var all = new byte[parts.Sum(p => p.Length)];
        var at = 0;
        foreach (var p in parts)
        {
            p.CopyTo(all, at);
            at += p.Length;
        }
        return all;
    }

    // A string with no lone surrogate: what a strict UTF-8 decode can produce.
    internal static bool WellFormed(string s)
    {
        for (var i = 0; i < s.Length; i++)
        {
            if (char.IsHighSurrogate(s[i]))
            {
                if (i + 1 >= s.Length || !char.IsLowSurrogate(s[i + 1]))
                    return false;
                i++;
            }
            else if (char.IsLowSurrogate(s[i]))
            {
                return false;
            }
        }
        return true;
    }

    internal static int Utf8Count(string s) => Encoding.UTF8.GetByteCount(s);
}

// Per-run counters: calls, accepted, refused, thrown, and the slowest call with its input.
internal sealed class Stats(string name)
{
    internal long Calls;
    internal long Accepted;
    internal long Refused;
    internal long Thrown;
    internal double SlowestMs;
    internal string SlowestInput = "";
    internal byte[] SlowestBytes = [];
    internal (int N, int T) Context;
    internal (int N, int T) SlowestContext;
    internal readonly Dictionary<string, long> Kinds = new();

    internal void Time(long startTicks, byte[] input)
    {
        var ms = Stopwatch.GetElapsedTime(startTicks).TotalMilliseconds;
        Calls++;
        if (ms > SlowestMs)
        {
            SlowestMs = ms;
            SlowestInput = $"{input.Length} B {Program.Hex(input, 24)}" + (Context.N > 0 ? $" (n={Context.N}, t={Context.T})" : "");
            SlowestBytes = input;
            SlowestContext = Context;
        }
    }

    internal void Outcome(object? result)
    {
        if (result is null)
        {
            Accepted++;
            return;
        }
        Refused++;
        var kind = result.GetType().Name;
        Kinds[kind] = Kinds.GetValueOrDefault(kind) + 1;
        if (result is not (ShortPacket or TrailingBytes or TypeMismatch or Uncorrectable or TooLong))
            Program.Fail($"{name}: undocumented result type {kind}");
    }

    internal void Threw(Exception ex, byte[] input)
    {
        Thrown++;
        Program.Fail($"{name}: {ex.GetType().Name} escaped: {ex.Message} input {Program.Hex(input)}");
    }

    // The slowest input again, 5 times after the run (JIT and GC warm): its median, to tell a pause from real cost.
    internal double Retime(Func<byte[], object?> call)
    {
        var times = new List<double>();
        for (var i = 0; i < 5; i++)
        {
            var t0 = Stopwatch.GetTimestamp();
            try
            {
                call(SlowestBytes);
            }
            catch (Exception ex)
            {
                Threw(ex, SlowestBytes);
            }
            times.Add(Stopwatch.GetElapsedTime(t0).TotalMilliseconds);
        }
        times.Sort();
        RetimedMs = times[2];
        return RetimedMs;
    }

    internal double RetimedMs = -1;

    internal void Print()
    {
        var kinds = string.Join(", ", Kinds.OrderBy(k => k.Key).Select(k => $"{k.Key} {k.Value}"));
        Console.WriteLine(
            $"{name}: calls {Calls}, accepted {Accepted}, refused {Refused} ({kinds}), thrown {Thrown}, " +
            $"slowest {SlowestMs:F3} ms on {SlowestInput}" + (RetimedMs >= 0 ? $" (re-run warm: median {RetimedMs:F3} ms)" : ""));
    }
}
