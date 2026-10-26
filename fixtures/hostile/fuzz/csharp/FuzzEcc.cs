using System.Diagnostics;
using System.Text;
using Packbin;

namespace PackbinProbe;

// AC-2 probe (a): seeded random and corrupted protected messages against Ecc.Repair and the public Unpack (dispatch after
// repair, then the text decoder). Seeds: fixtures/ecc/vectors.txt rows.
internal static class FuzzEcc
{
    private static readonly Scheme<NameRow>[] Single = new Scheme<NameRow>[33];
    private static readonly SchemeHandler[][] Handlers = new SchemeHandler[33][];

    internal static void Run(int seed, int count)
    {
        var r = new Random(seed);
        for (var n = 0; n <= 32; n++)
        {
            Single[n] = Schemes.Single.WithParity(n);
            Handlers[n] = [Single[n].On(_ => { }), Schemes.Map.WithParity(n).On(_ => { }),
                Schemes.List.WithParity(n).On(_ => { }), Schemes.MapText.WithParity(n).On(_ => { })];
        }
        var vectors = Vectors();
        Console.WriteLine($"vector rows {vectors.Count}, iterations {count}");
        var repair = new Stats("Ecc.Repair");
        var unpack = new Stats("Unpack (4 handlers)");
        long repairedOk = 0, countDiffers = 0, missed = 0, miscorrected = 0;
        foreach (var (n, t, received) in vectors)
            RepairOnce(received, n, t, null, -1, repair, ref repairedOk, ref countDiffers, ref missed, ref miscorrected);
        for (var i = 0; i < count; i++)
        {
            var n = r.Next(5) == 0 ? new[] { 1, 2, 31, 32 }[r.Next(4)] : r.Next(1, 33);
            var t = r.Next(3) == 0 ? n / 2 : r.Next(n / 2 + 1);
            var clear = Clear(r, n);
            var sent = Gf.Protect(clear, n);
            var received = (byte[])sent.Clone();
            var k = Damage(r, ref received, n, t, clear);
            RepairOnce(received, n, t, k >= 0 ? sent : null, k, repair, ref repairedOk, ref countDiffers, ref missed, ref miscorrected);
            if (i % 4 == 0)
            {
                var packet = received;
                unpack.Context = (n, t);
                Timed(unpack, packet, () => BinaryPacker.Unpack(packet, t, out _, Handlers[n]));
            }
        }
        repair.Retime(b => Ecc.Repair(b, repair.SlowestContext.N, repair.SlowestContext.T, out _, out _));
        unpack.Retime(b => BinaryPacker.Unpack(b, unpack.SlowestContext.T, out _, Handlers[unpack.SlowestContext.N]));
        repair.Print();
        unpack.Print();
        Console.WriteLine($"repairs that returned a word: {repairedOk}; changed bytes != repaired count: {countDiffers}; " +
                          $"damage within t not repaired: {missed}; repaired to another code word (beyond n - t, R06): {miscorrected}");
        if (missed > 0)
            Program.Fail($"{missed} messages with at most t wrong bytes were not repaired");
    }

    private static void Timed(Stats stats, byte[] packet, Func<object?> call)
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
            Program.Fail($"unpack wrote its {packet.Length}-byte input");
    }

    private static void RepairOnce(byte[] received, int n, int t, byte[]? sent, int k, Stats stats,
        ref long repairedOk, ref long countDiffers, ref long missed, ref long miscorrected)
    {
        var copy = (byte[])received.Clone();
        object? error;
        byte[] word;
        int repaired;
        stats.Context = (n, t);
        var t0 = Stopwatch.GetTimestamp();
        try
        {
            error = Ecc.Repair(received, n, t, out word, out repaired);
        }
        catch (Exception ex)
        {
            stats.Threw(ex, received);
            stats.Time(t0, received);
            return;
        }
        stats.Time(t0, received);
        stats.Outcome(error);
        if (!copy.AsSpan().SequenceEqual(received))
            Program.Fail("Ecc.Repair wrote its input");
        var tag = $"n={n} t={t} N={received.Length} {Program.Hex(received, 16)}";
        if ((received.Length > Ecc.MaxBlock) != (error is TooLong))
            Program.Fail($"too_long mismatch: {error?.GetType().Name} for {tag}");
        if (received.Length <= Ecc.MaxBlock && (received.Length < n) != (error is ShortPacket { Field: "parity" }))
            Program.Fail($"short mismatch: {error?.GetType().Name} for {tag}");
        if (error is null)
        {
            repairedOk++;
            if (repaired < 0 || repaired > t || word.Length != received.Length || !Gf.Valid(word, n))
                Program.Fail($"bad repair result: repaired {repaired}, word valid {Gf.Valid(word, n)} for {tag}");
            var changed = 0;
            for (var i = 0; i < Math.Min(word.Length, received.Length); i++)
                changed += word[i] != received[i] ? 1 : 0;
            if (changed != repaired)
                countDiffers++;
            if (changed > repaired)
                Program.Fail($"changed {changed} bytes but reports {repaired} for {tag}");
            if (sent is not null && !word.AsSpan().SequenceEqual(sent))
                miscorrected++;
        }
        if (sent is not null && k <= t && (error is not null || !word.AsSpan().SequenceEqual(sent) || repaired != k))
            missed++;
    }

    // Damages `received` in place or replaces it. Returns the number of wrong bytes in a code word of the same length,
    // or -1 when the buffer is not one (cut, extended, random, or wrong at the unsent length byte).
    private static int Damage(Random r, ref byte[] received, int n, int t, byte[] clear)
    {
        switch (r.Next(12))
        {
            case < 7:
                var pick = new[] { 0, t, t + 1, n - t, n - t + 1, n, n + 1, r.Next(n + 4) }[r.Next(8)];
                Gf.Corrupt(received, Math.Max(0, pick), r);
                return Math.Min(Math.Max(0, pick), received.Length);
            case 7:
                received = received[..Math.Max(0, received.Length - r.Next(1, 4))];
                return -1;
            case 8:
                received = Program.Concat(received, Enumerable.Range(0, r.Next(1, 4)).Select(_ => (byte)r.Next(256)).ToArray());
                return -1;
            case 9:
                received = new byte[r.Next(0, 300)];
                r.NextBytes(received);
                return -1;
            case 10:
                received = Enumerable.Repeat(r.Next(2) == 0 ? (byte)0 : (byte)0xff, r.Next(0, 257)).ToArray();
                return -1;
            default:
                // A code word whose unsent first symbol is not the clear length, plus a few wrong sent bytes.
                received = Gf.Encode(clear.Length ^ (1 + r.Next(255)), clear, n);
                Gf.Corrupt(received, r.Next(Math.Max(1, t)), r);
                return -1;
        }
    }

    // A clear message for n parity bytes: a packet of the protected single-text scheme (type 1) or random bytes.
    private static byte[] Clear(Random r, int n)
    {
        var room = Ecc.MaxBlock - n;
        if (r.Next(2) == 0)
        {
            var chars = r.Next(0, Math.Max(1, room / 3));
            var sb = new StringBuilder();
            for (var i = 0; i < chars; i++)
                sb.Append(r.Next(4) switch { 0 => (char)('а' + r.Next(32)), 1 => ' ', 2 => (char)('0' + r.Next(10)), _ => (char)('a' + r.Next(26)) });
            var text = sb.ToString();
            var packet = BinaryPacker.PackClear(Schemes.Single, new NameRow { Name = text });
            if (packet.Length <= room)
                return packet;
        }
        var clear = new byte[r.Next(0, room + 1)];
        r.NextBytes(clear);
        return clear;
    }

    // fix and bad rows of fixtures/ecc/vectors.txt: (n, t, received).
    private static List<(int N, int T, byte[] Received)> Vectors()
    {
        var rows = new List<(int, int, byte[])>();
        foreach (var row in Program.Rows("fixtures/ecc/vectors.txt"))
        {
            if (row[0] is "fix" or "bad" && row.Length > 4)
                rows.Add((int.Parse(row[2]), int.Parse(row[3]), Program.Bytes(row[4])));
        }
        return rows;
    }
}
