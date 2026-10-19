using System.Diagnostics;
using Packbin;

namespace PackbinProbe;

// AC-1 probe (c): how much one payload byte can decode to, and the time and memory of the largest texts. Run one case
// per process under /usr/bin/time -l to read its peak RSS ("baseline" is the process with nothing decoded).
internal static class TextAmp
{
    internal static void Run(string which)
    {
        switch (which)
        {
            case "baseline":
                Console.WriteLine($"baseline: schemes built, nothing decoded; allocated {GC.GetTotalAllocatedBytes()} B");
                break;
            case "max":
                Max();
                break;
            case "over":
                Over();
                break;
            case "silent":
                Silent();
                break;
            case "packet1m":
                Packet(1 << 20);
                break;
            case "packet16m":
                Packet(16 << 20);
                break;
            case "dict":
                Dict();
                break;
            case "collide":
                Collide();
                break;
            default:
                Program.Fail($"unknown text-amp case {which}");
                break;
        }
    }

    // A field of `chars` Russian 'о' (code 000, 3 bits for 2 UTF-8 bytes: the densest symbol), then `tail`.
    internal static byte[] RussianO(int chars, string tail = "")
    {
        var w = new BitWriter(1);
        var ru = TextModes.All[1];
        var o = Array.IndexOf(ru.Letters, 'о');
        for (var i = 0; i < chars; i++)
            w.Symbol(ru, o);
        foreach (var c in tail)
            w.Symbol(ru, ru.SharedBase + Array.IndexOf(ru.Shared, (int)c));
        return w.Field();
    }

    private static void Max()
    {
        var field = RussianO(32_767, " ");
        var payload = PayloadLength(field);
        var packet = Program.Concat([1], field);
        string? got = null;
        var handler = Schemes.Single.On(row => got = row.Name);
        var (median, max, alloc) = Measure(() => BinaryPacker.Unpack(packet, handler), 30);
        var utf8 = Program.Utf8Count(got ?? "");
        Console.WriteLine($"max: payload {payload} B decodes to {utf8} UTF-8 bytes ({(double)utf8 / payload:F3} per payload byte, " +
                          $"bound 6N+8 = {6 * payload + 8}); Unpack median {median:F2} ms, max {max:F2} ms, allocated {alloc / 1024.0:F0} KiB per call");
        Program.Check(utf8 == 65_535, "max: the 65,535-byte compact text is accepted");
        var over = Program.Concat([1], RussianO(32_768));
        object? error = null;
        var (m2, x2, a2) = Measure(() => error = BinaryPacker.Unpack(over, handler), 30);
        Console.WriteLine($"max+1: 32,768 x 'о' (65,536 B) refused in median {m2:F2} ms, max {x2:F2} ms, allocated {a2 / 1024.0:F0} KiB");
        Program.Check(error is ShortPacket, "max+1: a compact text of 65,536 bytes is refused");
    }

    private static void Over()
    {
        var payload = new byte[2_097_151];
        payload[0] = (byte)((((8 * payload.Length - 6) % 3) << 5) | (1 << 2));
        var packet = Program.Concat([1], Program.Varint(payload.Length), payload);
        object? error = null;
        var handler = Schemes.Single.On(_ => { });
        var (median, max, alloc) = Measure(() => error = BinaryPacker.Unpack(packet, handler), 30);
        Console.WriteLine($"over: count 2,097,151, a payload of 'о' codes ({packet.Length} B packet): {error?.GetType().Name}, " +
                          $"median {median:F2} ms, max {max:F2} ms, allocated {alloc / 1024.0:F0} KiB per call");
        Program.Check(error is ShortPacket, "over: refused at the 65,535-byte limit");
    }

    // 2,097,151 bytes of SW num / SW ua pairs (8 + 6 bits, no output): the longest payload that decodes to "".
    private static void Silent()
    {
        var w = new BitWriter(0);
        var ua = TextModes.All[0];
        var num = TextModes.All[3];
        while (w.Bits < 8 * 2_097_151 - 14 - 7)
        {
            w.Symbol(ua, ua.SwitchSymbol(0, 3));
            w.Symbol(num, num.SwBase);
        }
        var field = w.Field();
        var packet = Program.Concat([1], field);
        string? got = null;
        object? error = null;
        var handler = Schemes.Single.On(row => got = row.Name);
        var (median, max, alloc) = Measure(() => error = BinaryPacker.Unpack(packet, handler), 10);
        var length = PayloadLength(field);
        Console.WriteLine($"silent: payload {length} B of switch pairs -> {error?.GetType().Name ?? "ok"} '{got}', " +
                          $"median {median:F1} ms, max {max:F1} ms, allocated {alloc / 1024.0:F0} KiB per call " +
                          $"({median * 1e6 / length:F1} ns per payload byte)");
        Program.Check(error is null && got == "", "silent: a payload of switches only decodes to the empty text");
    }

    // A list of as many 65,535-byte texts as fit in `size` bytes, typed Unpack.
    private static void Packet(int size)
    {
        var field = RussianO(32_767, " ");
        var k = Math.Min(65_535, (size - 3) / field.Length);
        var parts = new List<byte[]> { new byte[] { 3, (byte)k, (byte)(k >> 8) } };
        for (var i = 0; i < k; i++)
            parts.Add(field);
        var packet = Program.Concat(parts.ToArray());
        long decoded = 0;
        object? error = null;
        var handler = Schemes.List.On(row => decoded = row.L!.Sum(e => (long)Program.Utf8Count((string)e!)));
        var (median, max, alloc) = Measure(() => error = BinaryPacker.Unpack(packet, handler), 3);
        Console.WriteLine($"packet: {packet.Length} B list of {k} texts -> {error?.GetType().Name ?? "ok"}, decoded {decoded} UTF-8 B " +
                          $"({(double)decoded / packet.Length:F2} per packet byte); median {median:F0} ms, max {max:F0} ms, " +
                          $"allocated {alloc / 1048576.0:F0} MiB per call; managed heap now {GC.GetTotalMemory(false) / 1048576.0:F0} MiB");
        Program.Check(error is null, $"packet: the {packet.Length}-byte list of 65,535-byte texts unpacks");
    }

    // 65,535 distinct 3-byte keys (dict of u8) and 65,535 copies of one key (refused at the second).
    private static void Dict()
    {
        var parts = new List<byte[]> { new byte[] { 2, 0xff, 0xff } };
        for (var i = 0; i < 65_535; i++)
            parts.Add([5, 0x10, (byte)('a' + i % 26), (byte)('a' + i / 26 % 26), (byte)('a' + i / 676 % 26), (byte)('a' + i / 17_576), 1]);
        var packet = Program.Concat(parts.ToArray());
        object? error = null;
        int keys = 0;
        var handler = Schemes.Map.On(row => keys = row.M!.Count);
        var (median, max, alloc) = Measure(() => error = BinaryPacker.Unpack(packet, handler), 5);
        Console.WriteLine($"dict: {packet.Length} B, 65,535 keys -> {error?.GetType().Name ?? "ok"} ({keys} keys), " +
                          $"median {median:F1} ms, max {max:F1} ms, allocated {alloc / 1048576.0:F1} MiB per call");
        var same = new List<byte[]> { new byte[] { 2, 0xff, 0xff } };
        for (var i = 0; i < 65_535; i++)
            same.Add([2, 0x10, 0x61, 1]);
        var dup = Program.Concat(same.ToArray());
        var (m2, x2, _) = Measure(() => error = BinaryPacker.Unpack(dup, handler), 5);
        Console.WriteLine($"dict: 65,535 copies of key 'a' -> {error?.GetType().Name}, median {m2:F3} ms, max {x2:F3} ms");
        Program.Check(error is ShortPacket, "dict: a repeated key is refused");
    }

    // The keys of the Java collision case ("Aa" / "BB" blocks share one Java hashCode); .NET hashes strings with a
    // per-process random seed, so this is the parity check of the same packet, not an attack on .NET.
    private static void Collide()
    {
        var parts = new List<byte[]> { new byte[] { 2, 0xff, 0xff } };
        for (var i = 0; i < 65_535; i++)
        {
            var key = string.Concat(Enumerable.Range(0, 16).Select(j => ((i >> j) & 1) != 0 ? "Aa" : "BB"));
            parts.Add(Program.Concat([33, 0x10], System.Text.Encoding.ASCII.GetBytes(key), [1]));
        }
        var packet = Program.Concat(parts.ToArray());
        object? error = null;
        var keys = 0;
        var handler = Schemes.Map.On(row => keys = row.M!.Count);
        var (median, max, alloc) = Measure(() => error = BinaryPacker.Unpack(packet, handler), 5);
        Console.WriteLine($"collide: {packet.Length} B, 65,535 keys -> {error?.GetType().Name ?? "ok"} ({keys} keys), " +
                          $"median {median:F1} ms, max {max:F1} ms, allocated {alloc / 1048576.0:F1} MiB per call");
        Program.Check(error is null && keys == 65_535 && median < 1000, "collide: 65,535 keys of the Java collision set unpack in under 1 s");
    }

    internal static int PayloadLength(byte[] field)
    {
        var count = 0;
        for (var k = 0; k < 3; k++)
        {
            count |= (field[k] & 0x7f) << (7 * k);
            if ((field[k] & 0x80) == 0)
                break;
        }
        return count;
    }

    private static (double MedianMs, double MaxMs, long AllocatedPerCall) Measure(Func<object?> call, int runs)
    {
        call();
        call();
        var times = new List<double>();
        var before = GC.GetAllocatedBytesForCurrentThread();
        for (var i = 0; i < runs; i++)
        {
            var t0 = Stopwatch.GetTimestamp();
            call();
            times.Add(Stopwatch.GetElapsedTime(t0).TotalMilliseconds);
        }
        var alloc = (GC.GetAllocatedBytesForCurrentThread() - before) / runs;
        times.Sort();
        return (times[times.Count / 2], times[^1], alloc);
    }
}

// Writes a compact payload bit by bit with the package's own canonical codes (TextModes.All[m].Codes / Bits).
internal sealed class BitWriter
{
    private readonly List<bool> _bits = [];

    internal BitWriter(int mode)
    {
        for (var i = 2; i >= 0; i--)
            _bits.Add(false);
        for (var i = 2; i >= 0; i--)
            _bits.Add(((mode >> i) & 1) != 0);
    }

    internal int Bits => _bits.Count;

    internal void Symbol(TextModes.Mode mode, int symbol)
    {
        var code = mode.Codes[symbol];
        for (var i = mode.Bits[symbol] - 1; i >= 0; i--)
            _bits.Add(((code >> i) & 1) != 0);
    }

    internal void Byte(int value)
    {
        for (var i = 7; i >= 0; i--)
            _bits.Add(((value >> i) & 1) != 0);
    }

    internal void Raw(bool bit) => _bits.Add(bit);

    // The payload: the pad written into the first 3 bits, the last byte filled with zero bits.
    internal byte[] Payload()
    {
        var pad = (8 - _bits.Count % 8) % 8;
        var bytes = new byte[(_bits.Count + 7) / 8];
        for (var i = 0; i < _bits.Count; i++)
        {
            if (_bits[i])
                bytes[i >> 3] |= (byte)(0x80 >> (i & 7));
        }
        bytes[0] = (byte)((bytes[0] & 0x1f) | (pad << 5));
        return bytes;
    }

    internal byte[] Field() => Field(Payload());

    internal static byte[] Field(byte[] payload) => Program.Concat(Program.Varint(payload.Length), payload);
}
