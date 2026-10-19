using System.Diagnostics;
using System.Text;
using Packbin;

namespace PackbinProbe;

// AC-1 probe (a): seeded random and mutated text fields against the decoder and the public unpack. Seeds are every
// field and buffer of fixtures/text/vectors.txt and every packet body of fixtures/hostile/fuzz/corpus.txt.
internal static class FuzzText
{
    private static readonly byte[] Interesting = [0x00, 0x01, 0x10, 0x7f, 0x80, 0x81, 0xbf, 0xc0, 0xc2, 0xe0, 0xed, 0xef, 0xf0, 0xf4, 0xf5, 0xff];

    internal static void Run(int seed, int count)
    {
        var r = new Random(seed);
        var seeds = LoadSeeds();
        Console.WriteLine($"seeds {seeds.Count}, iterations {count}");
        var direct = new Stats("TextDecoder.Read");
        var single = new Stats("Unpack single utf8");
        var collections = new Stats("Unpack list/dict");
        long roundTrips = 0;
        var maxRatio = 0.0;
        for (var i = 0; i < count; i++)
        {
            var field = Make(r, seeds);
            if (r.Next(4) == 0)
                field = Program.Concat(field, [0x5a]);
            ReadDirect(field, direct, ref roundTrips, ref maxRatio);
            var one = Program.Concat([1], field);
            RunUnpack(one, single, () => BinaryPacker.Unpack(one, Schemes.Single.On(_ => { })));
            if (i % 4 == 0)
            {
                var packet = Collection(r, seeds);
                RunUnpack(packet, collections, () => BinaryPacker.Unpack(packet,
                    Schemes.Map.On(_ => { }), Schemes.List.On(_ => { }), Schemes.MapText.On(_ => { })));
            }
        }
        direct.Retime(b => { var at = 0; return TextDecoder.Read("x", b, ref at, out _); });
        single.Retime(b => BinaryPacker.Unpack(b, Schemes.Single.On(_ => { })));
        collections.Retime(b => BinaryPacker.Unpack(b, Schemes.Map.On(_ => { }), Schemes.List.On(_ => { }), Schemes.MapText.On(_ => { })));
        direct.Print();
        single.Print();
        collections.Print();
        Console.WriteLine($"accepted texts round-tripped through the encoder: {roundTrips}; most decoded UTF-8 bytes per payload byte: {maxRatio:F3}");
    }

    private static void RunUnpack(byte[] packet, Stats stats, Func<object?> call)
    {
        var copy = (byte[])packet.Clone();
        var t0 = Stopwatch.GetTimestamp();
        try
        {
            stats.Outcome(call());
        }
        catch (Exception ex)
        {
            stats.Threw(ex, packet);
        }
        stats.Time(t0, packet);
        if (!copy.AsSpan().SequenceEqual(packet))
            Program.Fail($"{packet.Length}-byte packet was written by unpack");
    }

    private static void ReadDirect(byte[] field, Stats stats, ref long roundTrips, ref double maxRatio)
    {
        var offset = 0;
        string text;
        ShortPacket? error;
        var t0 = Stopwatch.GetTimestamp();
        try
        {
            error = TextDecoder.Read("x", field, ref offset, out text);
        }
        catch (Exception ex)
        {
            stats.Threw(ex, field);
            stats.Time(t0, field);
            return;
        }
        stats.Time(t0, field);
        stats.Outcome(error);
        if (error is not null)
        {
            if (offset != 0)
                Program.Fail($"refused read moved the offset to {offset}: {Program.Hex(field)}");
            return;
        }
        var (header, payload) = Header(field);
        if (offset != header + payload)
            Program.Fail($"accepted read ended at {offset}, header {header} + payload {payload}: {Program.Hex(field)}");
        if (!Program.WellFormed(text))
            Program.Fail($"accepted text has a lone surrogate: {Program.Hex(field)}");
        var utf8 = Program.Utf8Count(text);
        if (utf8 > 65_535 || utf8 > 6 * payload + 8)
            Program.Fail($"accepted text of {utf8} UTF-8 bytes from a {payload}-byte payload: {Program.Hex(field)}");
        if (payload > 0)
            maxRatio = Math.Max(maxRatio, (double)utf8 / payload);
        if (utf8 <= 4096)
        {
            var again = TextEncoder.Encode(Encoding.UTF8.GetBytes(text));
            var at = 0;
            var back = TextDecoder.Read("x", again, ref at, out var text2);
            if (back is not null || text2 != text || at != again.Length)
                Program.Fail($"encode/decode round trip differs for {Program.Hex(field)}");
            roundTrips++;
        }
    }

    // The varint header length and the count it states (only called on a field the decoder accepted).
    private static (int Header, int Count) Header(byte[] field)
    {
        var count = 0;
        for (var k = 0; k < 3; k++)
        {
            count |= (field[k] & 0x7f) << (7 * k);
            if ((field[k] & 0x80) == 0)
                return (k + 1, count);
        }
        return (3, count);
    }

    private static List<byte[]> LoadSeeds()
    {
        var seeds = new List<byte[]>();
        foreach (var row in Program.Rows("fixtures/text/vectors.txt"))
        {
            switch (row[0])
            {
                case "enc" or "alt" when row.Length > 3:
                    seeds.Add(Program.Bytes(row[3]));
                    break;
                case "bad":
                    seeds.Add(row.Length > 3 ? Program.Bytes(row[3]) : []);
                    break;
                case "ref" when row.Length > 2:
                    seeds.Add(Program.Bytes(row[2])[1..]);
                    break;
            }
        }
        foreach (var row in Program.Rows("fixtures/hostile/fuzz/corpus.txt"))
        {
            var packet = Program.Bytes(row[2]);
            if (packet.Length > 1)
                seeds.Add(packet[1..]);
        }
        return seeds;
    }

    internal static byte[] Make(Random r, List<byte[]> seeds)
    {
        return r.Next(10) switch
        {
            < 5 => Mutate(seeds[r.Next(seeds.Count)], r),
            < 7 => Fresh(r),
            < 8 => Mutate(Program.Concat(seeds[r.Next(seeds.Count)], seeds[r.Next(seeds.Count)]), r),
            _ => Rehead(Mutate(seeds[r.Next(seeds.Count)], r), r),
        };
    }

    // A field whose count header states the payload that follows (or a near miss of it).
    private static byte[] Rehead(byte[] body, Random r)
    {
        var payload = body.Length > 1 ? body[1..] : body;
        var count = payload.Length + (r.Next(4) == 0 ? r.Next(-2, 3) : 0);
        return Program.Concat(Program.Varint(Math.Max(0, count)), payload);
    }

    // A random payload with a valid-looking first byte: any pad, a start mode 0 to 7, or the raw prefix.
    private static byte[] Fresh(Random r)
    {
        var length = r.Next(10) switch
        {
            < 6 => r.Next(1, 24),
            < 9 => r.Next(24, 600),
            _ => r.Next(600, 70_000),
        };
        var payload = new byte[length];
        r.NextBytes(payload);
        if (r.Next(3) == 0)
            Array.Clear(payload, 1, payload.Length - 1);
        payload[0] = r.Next(6) == 0 ? (byte)0x10 : (byte)((r.Next(8) << 5) | (r.Next(r.Next(5) == 0 ? 8 : 4) << 2));
        if (payload[0] == 0x10 && r.Next(2) == 0)
        {
            var utf8 = Encoding.UTF8.GetBytes(RandomText(r, length));
            utf8.AsSpan(0, Math.Min(length - 1, utf8.Length)).CopyTo(payload.AsSpan(1));
        }
        return Program.Concat(Program.Varint(length), payload);
    }

    private static string RandomText(Random r, int chars)
    {
        var sb = new StringBuilder();
        for (var i = 0; i < chars; i++)
            sb.Append((char)(r.Next(3) == 0 ? 'а' + r.Next(32) : 'a' + r.Next(26)));
        return sb.ToString();
    }

    internal static byte[] Mutate(byte[] source, Random r)
    {
        var b = new List<byte>(source);
        var ops = 1 + r.Next(4);
        for (var k = 0; k < ops; k++)
        {
            switch (r.Next(9))
            {
                case 0 when b.Count > 0:
                    b[r.Next(b.Count)] ^= (byte)(1 << r.Next(8));
                    break;
                case 1 when b.Count > 0:
                    b[r.Next(b.Count)] = (byte)r.Next(256);
                    break;
                case 2:
                    b.Insert(r.Next(b.Count + 1), (byte)r.Next(256));
                    break;
                case 3 when b.Count > 0:
                    b.RemoveAt(r.Next(b.Count));
                    break;
                case 4 when b.Count > 0:
                    var cut = r.Next(b.Count + 1);
                    b.RemoveRange(cut, b.Count - cut);
                    break;
                case 5:
                    for (var j = r.Next(1, 17); j > 0; j--)
                        b.Add((byte)r.Next(256));
                    break;
                case 6 when b.Count > 1:
                    var from = r.Next(b.Count);
                    var len = r.Next(1, Math.Min(32, b.Count - from) + 1);
                    b.InsertRange(r.Next(b.Count + 1), b.GetRange(from, len));
                    break;
                case 7 when b.Count > 0:
                    b[r.Next(b.Count)] = Interesting[r.Next(Interesting.Length)];
                    break;
                case 8 when b.Count > 1:
                    b[1] = (byte)((r.Next(8) << 5) | (r.Next(8) << 2) | r.Next(4));
                    break;
            }
        }
        return b.ToArray();
    }

    // A list, dict-of-u8 or dict-of-text packet of 1 to 4 random fields (type 3, 2 or 4).
    private static byte[] Collection(Random r, List<byte[]> seeds)
    {
        var kind = r.Next(3);
        var n = r.Next(1, 5);
        var type = kind switch { 0 => (byte)3, 1 => (byte)2, _ => (byte)4 };
        var parts = new List<byte[]> { new[] { type }, new[] { (byte)n, (byte)0 } };
        byte[]? previous = null;
        for (var i = 0; i < n; i++)
        {
            var field = previous is not null && r.Next(4) == 0 ? previous : Make(r, seeds);
            previous = field;
            parts.Add(field);
            if (kind == 1)
                parts.Add([(byte)r.Next(256)]);
            else if (kind == 2)
                parts.Add(Make(r, seeds));
        }
        return Program.Concat(parts.ToArray());
    }
}
