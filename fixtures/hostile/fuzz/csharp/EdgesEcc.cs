using Packbin;

namespace PackbinProbe;

// AC-2 probe (d): the ECC and dispatch edge cases a random run is unlikely to hit.
internal static class EdgesEcc
{
    internal static void Run()
    {
        Sweep();
        Lengths();
        CallerChecks();
        Dispatch();
    }

    // Every n = 1..32 and N = n..254: intact, t wrong bytes, t + 1, random, wrong unsent length byte, all 0xff, all zero.
    private static void Sweep()
    {
        var r = new Random(4101);
        long calls = 0, thrown = 0, wrong = 0;
        for (var n = 1; n <= 32; n++)
        {
            var t = n / 2;
            for (var size = n; size <= Ecc.MaxBlock; size++)
            {
                var clear = new byte[size - n];
                r.NextBytes(clear);
                var sent = Gf.Protect(clear, n);
                var inputs = new List<(byte[] Input, bool MustRepair)>();
                inputs.Add((sent, true));
                var damaged = (byte[])sent.Clone();
                Gf.Corrupt(damaged, t, r);
                inputs.Add((damaged, true));
                damaged = (byte[])sent.Clone();
                Gf.Corrupt(damaged, t + 1, r);
                inputs.Add((damaged, false));
                var random = new byte[size];
                r.NextBytes(random);
                inputs.Add((random, false));
                var lengthByte = Gf.Encode(clear.Length ^ (1 + r.Next(255)), clear, n);
                Gf.Corrupt(lengthByte, Math.Max(0, t - 1), r);
                inputs.Add((lengthByte, false));
                inputs.Add((Enumerable.Repeat((byte)0xff, size).ToArray(), false));
                inputs.Add((new byte[size], false));
                foreach (var (input, must) in inputs)
                {
                    calls++;
                    try
                    {
                        var error = Ecc.Repair(input, n, t, out var word, out _);
                        if (must && (error is not null || !word.AsSpan().SequenceEqual(sent)))
                            wrong++;
                        if (error is null && !Gf.Valid(word, n))
                            wrong++;
                        if (error is not (null or Uncorrectable))
                            wrong++;
                    }
                    catch (Exception ex)
                    {
                        if (thrown++ < 5)
                            Program.Fail($"sweep n={n} N={size}: {ex.GetType().Name}: {ex.Message}");
                    }
                }
            }
        }
        Program.Check(thrown == 0 && wrong == 0, $"sweep n=1..32, N=n..254: {calls} repairs, thrown {thrown}, wrong {wrong}");
    }

    private static void Lengths()
    {
        for (var n = 1; n <= 32; n++)
        {
            var empty = Gf.Protect([], n);
            var ok = Ecc.Repair(empty, n, n / 2, out var word, out _) is null && word.Length == n;
            var dispatched = BinaryPacker.Unpack(empty, n / 2, out _, Schemes.Single.WithParity(n).On(_ => { }));
            var shorter = Ecc.Repair(empty[..^1], n, n / 2, out _, out _);
            var none = Ecc.Repair([], n, 0, out _, out _);
            if (!ok || dispatched is not ShortPacket { Field: "", Needed: 1 } || shorter is not ShortPacket { Field: "parity" } ||
                none is not ShortPacket { Field: "parity", Left: 0 })
                Program.Fail($"lengths n={n}: empty clear ok={ok}, dispatch {dispatched?.GetType().Name}, N=n-1 {shorter?.GetType().Name}");
        }
        Program.Check(true, "lengths: N = n (empty clear), N = n - 1 and N = 0 for n = 1..32");
        var big = new byte[255];
        Program.Check(Ecc.Repair(big, 32, 16, out _, out _) is TooLong { Length: 255, Limit: 254 }, "length 255: too_long before arithmetic");
        var huge = new byte[1 << 20];
        Program.Check(BinaryPacker.Unpack(huge, 1, out _, Schemes.Single.WithParity(2).On(_ => { })) is TooLong { Length: 1 << 20 },
            "length 1 MiB with parity: too_long");
    }

    private static void CallerChecks()
    {
        var h4 = Schemes.Single.WithParity(4).On(_ => { });
        var h2 = Schemes.Map.WithParity(2).On(_ => { });
        var h4b = Schemes.Single.WithParity(4).On(_ => { });
        string Thrown(Action call)
        {
            try
            {
                call();
                return "nothing";
            }
            catch (Exception ex)
            {
                return ex.GetType().Name + ": " + ex.Message;
            }
        }
        var bytes = new byte[10];
        Console.WriteLine("caller: t = 3 for n = 4 -> " + Thrown(() => BinaryPacker.Unpack(bytes, 3, out _, h4)));
        Console.WriteLine("caller: t = -1 -> " + Thrown(() => BinaryPacker.Unpack(bytes, -1, out _, h4)));
        Console.WriteLine("caller: mixed 4 and 2 -> " + Thrown(() => BinaryPacker.Unpack(bytes, 0, out _, h4, h2)));
        Console.WriteLine("caller: duplicate type and mixed -> " + Thrown(() => BinaryPacker.Unpack(bytes, 0, out _, h4, h2, h4b)));
        Console.WriteLine("caller: no handlers -> " + Thrown(() => BinaryPacker.Unpack(bytes, 0, out _)));
        Console.WriteLine("caller: mixed and bad limit -> " + Thrown(() => BinaryPacker.Unpack(bytes, 9, out _, h4, h2)));
        Console.WriteLine("caller: n = 0, t = 1 -> " + Thrown(() => BinaryPacker.Unpack(bytes, 1, out _, Schemes.Single.On(_ => { }))));
        Program.Check(Thrown(() => Schemes.Single.WithParity(33)).StartsWith("ArgumentOutOfRange"), "caller: parity 33 is not built");
    }

    private static void Dispatch()
    {
        var single = Schemes.Single.WithParity(4);
        var clear = BinaryPacker.PackClear(Schemes.Single, new NameRow { Name = "abc" });
        var sent = Ecc.Protect(clear, 4);
        var wrongType = (byte[])sent.Clone();
        wrongType[0] = 0x63;
        string? got = null;
        var error = BinaryPacker.Unpack(wrongType, 2, out var repaired, single.On(row => got = row.Name));
        Program.Check(error is null && got == "abc" && repaired == 1, "dispatch: a wrong type byte is repaired before the handler is picked");
        var other = Gf.Protect(Program.Concat([0x63], clear[1..]), 4);
        error = BinaryPacker.Unpack(other, 2, out _, single.On(_ => { }));
        Program.Check(error is TypeMismatch { Actual: 0x63 }, "dispatch: an intact message of an unknown type is a type mismatch");
        var copy = (byte[])wrongType.Clone();
        BinaryPacker.Unpack(wrongType, 2, out _, single.On(_ => { }));
        Program.Check(copy.AsSpan().SequenceEqual(wrongType), "dispatch: the repaired input buffer is not written");
    }
}
