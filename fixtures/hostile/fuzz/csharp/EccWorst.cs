using System.Diagnostics;
using Packbin;

namespace PackbinProbe;

public sealed class BlobRow
{
    public byte[] Data { get; set; } = [];
}

// AC-2 probe (b): the per-call time of the costliest repairs, N = 254 sent bytes and n = 32 parity bytes. Each case has
// `count` distinct inputs; every input runs 5 times as warm-up (JIT tiering), then 5 timed times; median, p99 and max.
internal static class EccWorst
{
    private const int N = 254;
    private const int Parity = 32;

    internal static void Run(int seed, int count)
    {
        var r = new Random(seed);
        var blob = new Scheme<BlobRow>(9, Field.Bytes<BlobRow>(0, x => x.Data, N - Parity - 1)).WithParity(Parity);
        var cases = new (string Name, int T, Func<byte[]> Make)[]
        {
            ("t=16, 16 wrong bytes (repaired: every step runs)", 16, () => Wrong(r, 16)),
            ("t=16, 15 wrong bytes + wrong unsent length byte (degree 16, 15 roots: near miss)", 16, () => NearMiss(r)),
            ("t=16, random 254 bytes (degree ~16, full root search)", 16, () => Random254(r)),
            ("t=16, 17 wrong bytes (degree above t)", 16, () => Wrong(r, 17)),
            ("t=16, intact", 16, () => Wrong(r, 0)),
            ("t=0 (default), 1 wrong byte (detect only)", 0, () => Wrong(r, 1)),
            ("t=0 (default), random 254 bytes", 0, () => Random254(r)),
        };
        Console.WriteLine($"N={N} n={Parity}, {count} inputs per case, 5 warm-up + 5 timed runs each; load {Program.Load()}");
        foreach (var (name, t, make) in cases)
        {
            var inputs = Enumerable.Range(0, count).Select(_ => make()).ToArray();
            var outcomes = new Dictionary<string, int>();
            foreach (var input in inputs)
            {
                var e = Ecc.Repair(input, Parity, t, out _, out _);
                var kind = e?.GetType().Name ?? "ok";
                outcomes[kind] = outcomes.GetValueOrDefault(kind) + 1;
            }
            Report("Ecc.Repair   " + name, inputs, input => Ecc.Repair(input, Parity, t, out _, out _), outcomes);
            var handler = blob.On(_ => { });
            Report("Unpack(blob) " + name, inputs, input => BinaryPacker.Unpack(input, t, out _, handler), null);
        }
        Console.WriteLine($"load after {Program.Load()}");
    }

    private static void Report(string name, byte[][] inputs, Func<byte[], object?> call, Dictionary<string, int>? outcomes)
    {
        for (var w = 0; w < 5; w++)
        {
            foreach (var input in inputs)
                call(input);
        }
        var times = new List<double>(inputs.Length * 5);
        var before = GC.GetAllocatedBytesForCurrentThread();
        for (var rep = 0; rep < 5; rep++)
        {
            foreach (var input in inputs)
            {
                var t0 = Stopwatch.GetTimestamp();
                call(input);
                times.Add(Stopwatch.GetElapsedTime(t0).TotalMicroseconds);
            }
        }
        var alloc = (GC.GetAllocatedBytesForCurrentThread() - before) / (inputs.Length * 5);
        times.Sort();
        var kinds = outcomes is null ? "" : " outcomes: " + string.Join(", ", outcomes.Select(k => $"{k.Key} {k.Value}"));
        Console.WriteLine($"{name}: median {times[times.Count / 2]:F1} us, p99 {times[(int)(times.Count * 0.99)]:F1} us, " +
                          $"max {times[^1]:F1} us over {times.Count} calls; {alloc} B allocated per call;{kinds}");
    }

    private static byte[] Clear(Random r)
    {
        var clear = new byte[N - Parity];
        r.NextBytes(clear);
        clear[0] = 9;
        return clear;
    }

    private static byte[] Wrong(Random r, int k)
    {
        var word = Gf.Protect(Clear(r), Parity);
        Gf.Corrupt(word, k, r);
        return word;
    }

    // The unsent length byte is wrong (a code word for another first symbol) and 15 sent bytes too: 16 errors, so
    // Berlekamp-Massey finds the degree-16 locator, and only 15 of its roots are sent positions.
    private static byte[] NearMiss(Random r)
    {
        var clear = Clear(r);
        var word = Gf.Encode(clear.Length ^ (1 + r.Next(255)), clear, Parity);
        Gf.Corrupt(word, 15, r);
        return word;
    }

    private static byte[] Random254(Random r)
    {
        var b = new byte[N];
        r.NextBytes(b);
        return b;
    }
}
