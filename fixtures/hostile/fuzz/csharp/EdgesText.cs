using System.Diagnostics;
using System.Text;
using Packbin;

namespace PackbinProbe;

// AC-1 probe (d): the text edge cases a random run is unlikely to hit.
internal static class EdgesText
{
    private static readonly TextModes.Mode Ua = TextModes.All[0];
    private static readonly TextModes.Mode Ru = TextModes.All[1];
    private static readonly TextModes.Mode En = TextModes.All[2];

    internal static void Run()
    {
        Varints();
        Headers();
        Raw();
        EscapeSweep();
        CodeCut();
        Lengths();
        DictKeys();
        Exhaustive();
    }

    private static (ShortPacket? Error, string Text, int Offset, Exception? Thrown) Read(byte[] field)
    {
        var offset = 0;
        try
        {
            var error = TextDecoder.Read("x", field, ref offset, out var text);
            return (error, text, offset, null);
        }
        catch (Exception ex)
        {
            return (null, "", offset, ex);
        }
    }

    private static void Expect(string name, byte[] field, string? text)
    {
        var got = Read(field);
        if (got.Thrown is not null)
        {
            Program.Fail($"{name}: {got.Thrown.GetType().Name} escaped: {got.Thrown.Message}");
            return;
        }
        if (text is null)
            Program.Check(got.Error is not null, $"{name}: refused");
        else
            Program.Check(got.Error is null && got.Text == text && got.Offset == field.Length, $"{name}: accepted as expected");
    }

    private static void Varints()
    {
        Read([0xff, 0xff, 0x7f]); // static initialisation (the tables) is not counted
        var before = GC.GetAllocatedBytesForCurrentThread();
        var got = Read([0xff, 0xff, 0x7f]);
        var alloc = GC.GetAllocatedBytesForCurrentThread() - before;
        Program.Check(got.Error is { Needed: 2_097_151, Left: 0 } && alloc < 4096,
            $"varint ff ff 7f with no payload: short, needed {got.Error?.Needed}, {alloc} B allocated");
        Expect("varint 80 00 (not minimal)", [0x80, 0x00], null);
        Expect("varint 81 80 00 (not minimal)", [0x81, 0x80, 0x00], null);
        Expect("varint 80 80 80 01 (four bytes)", [0x80, 0x80, 0x80, 0x01], null);
        Program.Check(Read([]).Error is { Needed: 1 }, "varint: empty buffer is short, needed 1");
        Program.Check(Read([0xff]).Error is { Needed: 2 }, "varint: ff is short, needed 2");
        Program.Check(Read([0xff, 0xff]).Error is { Needed: 3 }, "varint: ff ff is short, needed 3");
        var big = Program.Concat([0x80, 0x80, 0x01, 0x10], Enumerable.Repeat((byte)'a', 16_383).ToArray());
        Expect("varint 80 80 01 (16,384, three bytes): raw 16,383 'a'", big, new string('a', 16_383));
    }

    private static void Headers()
    {
        Expect("payload 00 (two symbol bits)", [0x01, 0x00], null);
        Expect("payload e0 (pad 7 covers the prefix)", [0x01, 0xe0], null);
        for (var mode = 5; mode <= 7; mode++)
            Expect($"start mode {mode}", [0x01, (byte)(mode << 2)], null);
        Expect("raw 10 alone is the empty text", [0x01, 0x10], "");
        Expect("raw prefix 11", [0x02, 0x11, 0x41], null);
        for (var low = 1; low <= 3; low++)
            Expect($"raw prefix with low bits {low}", [0x02, (byte)(0x10 | low), 0x41], null);
        var w = new BitWriter(0);
        w.Symbol(Ua, 0);
        var p = w.Payload();
        var pad = p[0] >> 5;
        if (pad > 0)
        {
            p[^1] |= 1;
            Expect($"pad bits not zero (pad {pad})", BitWriter.Field(p), null);
        }
    }

    private static void Raw()
    {
        Expect("raw 65,535 'a'", Program.Concat(Program.Varint(65_536), [0x10], Enumerable.Repeat((byte)'a', 65_535).ToArray()), new string('a', 65_535));
        Expect("raw 65,536 'a'", Program.Concat(Program.Varint(65_537), [0x10], Enumerable.Repeat((byte)'a', 65_536).ToArray()), null);
        string[] bad = ["eda080", "edbfbf", "c080", "c1bf", "e08080", "e09fbf", "f0808080", "f08fbfbf", "f4908080", "f5808080", "f8", "ff", "80", "e282", "f09f98", "e228a1", "c328"];
        foreach (var hex in bad)
        {
            var raw = Program.Bytes(hex);
            Expect($"raw {hex}", Program.Concat(Program.Varint(raw.Length + 1), [0x10], raw), null);
        }
        Expect("raw efbbbf61 keeps the BOM", Program.Concat([0x05, 0x10], Program.Bytes("efbbbf61")), "﻿a");
        Expect("raw 00 is NUL", [0x02, 0x10, 0x00], "\0");
        Expect("raw f48fbfbf is U+10FFFF", Program.Concat([0x05, 0x10], Program.Bytes("f48fbfbf")), char.ConvertFromUtf32(0x10FFFF));
        Expect("raw efbfbf is U+FFFF", Program.Concat([0x04, 0x10], Program.Bytes("efbfbf")), "￿");
    }

    // ESC at every bit alignment (k spaces of 3 bits before it), every UTF-8 length, cut by one byte, and invalid.
    private static void EscapeSweep()
    {
        var space = Ua.SharedBase + Array.IndexOf(Ua.Shared, ' ');
        string[] good = ["41", "c3a9", "e282ac", "f09f9880", "00", "f48fbfbf"];
        string[] invalid = ["eda080", "c181", "e09fbf", "f08fbfbf", "f4908080", "f8888080", "80", "e228a1", "ff"];
        var failures = 0;
        var cases = 0;
        for (var k = 0; k < 8; k++)
        {
            foreach (var hex in good.Concat(invalid))
            {
                var bytes = Program.Bytes(hex);
                var ok = good.Contains(hex);
                for (var cut = 0; cut <= (ok ? 1 : 0); cut++)
                {
                    var w = new BitWriter(0);
                    for (var i = 0; i < k; i++)
                        w.Symbol(Ua, space);
                    w.Symbol(Ua, Ua.Esc);
                    for (var i = 0; i < bytes.Length - cut; i++)
                        w.Byte(bytes[i]);
                    var field = w.Field();
                    var got = Read(field);
                    cases++;
                    var expected = ok && cut == 0 ? new string(' ', k) + Encoding.UTF8.GetString(bytes) : null;
                    var pass = got.Thrown is null && (expected is null ? got.Error is not null : got.Error is null && got.Text == expected);
                    if (!pass)
                    {
                        failures++;
                        Program.Fail($"esc sweep k={k} {hex} cut={cut}: {got.Thrown?.GetType().Name ?? got.Error?.GetType().Name ?? "ok " + got.Text}");
                    }
                }
            }
        }
        Program.Check(failures == 0, $"esc sweep: {cases} cases at 8 alignments, valid, cut short and invalid scalars");
    }

    // A 16-bit code cut by 1 to 15 bits at the end of the stream: a prefix code has no shorter code there, so "code".
    private static void CodeCut()
    {
        var longest = Enumerable.Range(0, Ua.Bits.Length).First(s => Ua.Bits[s] == 16);
        var refused = 0;
        for (var drop = 1; drop < 16; drop++)
        {
            var w = new BitWriter(0);
            var code = Ua.Codes[longest];
            for (var i = 15; i >= drop; i--)
                w.Raw(((code >> i) & 1) != 0);
            var got = Read(BitWriter.Field(w.Payload()));
            if (got.Thrown is not null)
                Program.Fail($"code cut by {drop} bits: {got.Thrown.GetType().Name}");
            else if (got.Error is not null)
                refused++;
        }
        Program.Check(refused == 15, $"code cut at the end of the stream: {refused} of 15 cuts refused");
    }

    private static void Lengths()
    {
        var o = Array.IndexOf(Ru.Letters, 'о');
        byte[] Build(int chars, Action<BitWriter>? tail)
        {
            var w = new BitWriter(1);
            for (var i = 0; i < chars; i++)
                w.Symbol(Ru, o);
            tail?.Invoke(w);
            return w.Field();
        }
        void Esc(BitWriter w, string hex)
        {
            w.Symbol(Ru, Ru.Esc);
            foreach (var b in Program.Bytes(hex))
                w.Byte(b);
        }
        Expect("compact 32,767 'о' + space (65,535 B)", Build(32_767, w => w.Symbol(Ru, Ru.SharedBase)), new string('о', 32_767) + " ");
        Expect("compact 32,768 'о' (65,536 B)", Build(32_768, null), null);
        Expect("compact 32,766 'о' + ESC 4-byte (65,536 B)", Build(32_766, w => Esc(w, "f09f9880")), null);
        Expect("compact 32,766 'о' + ESC 3-byte (65,535 B)", Build(32_766, w => Esc(w, "e282ac")), new string('о', 32_766) + "€");
        Expect("compact 32,767 'о' + ESC 1-byte (65,535 B)", Build(32_767, w => Esc(w, "41")), new string('о', 32_767) + "A");
        Expect("compact 32,767 'о' + ESC 2-byte (65,536 B)", Build(32_767, w => Esc(w, "c3a9")), null);
    }

    private static void DictKeys()
    {
        var a = Array.IndexOf(En.Letters, 'a');
        var w = new BitWriter(2);
        w.Symbol(En, a);
        var compactA = w.Field();
        object? Unpack(params byte[][] keys)
        {
            var parts = new List<byte[]> { new byte[] { 2, (byte)keys.Length, 0 } };
            foreach (var key in keys)
            {
                parts.Add(key);
                parts.Add([7]);
            }
            int got = -1;
            var error = BinaryPacker.Unpack(Program.Concat(parts.ToArray()), Schemes.Map.On(row => got = row.M!.Count));
            return error ?? got;
        }
        Program.Check(Unpack([0x02, 0x10, 0x61], compactA) is ShortPacket, $"dict: key 'a' raw and 'a' compact ({Program.Hex(compactA)}) is a repeated key");
        Program.Check(Unpack([0x02, 0x10, 0x61], [0x02, 0x10, 0x61]) is ShortPacket, "dict: key 'a' twice is refused");
        Program.Check(Unpack([0x00], [0x00]) is ShortPacket, "dict: empty key twice is refused");
        Program.Check(Unpack([0x00]) is 1, "dict: one empty key is accepted");
        Program.Check(Unpack(Program.Bytes("0310c3a9"), Program.Bytes("041065cc81")) is 2, "dict: NFC and NFD forms of é are two keys (bytes compared)");
    }

    // Every payload of 1 and 2 bytes, and every 3-byte payload: no exception, the 6N+8 bound, well-formed text.
    private static void Exhaustive()
    {
        long calls = 0, accepted = 0, thrown = 0, overBound = 0;
        var clock = Stopwatch.StartNew();
        for (var n = 1; n <= 3; n++)
        {
            var field = new byte[1 + n];
            field[0] = (byte)n;
            var limit = 1 << (8 * n);
            for (var v = 0; v < limit; v++)
            {
                for (var i = 0; i < n; i++)
                    field[1 + i] = (byte)(v >> (8 * (n - 1 - i)));
                var got = Read(field);
                calls++;
                if (got.Thrown is not null)
                {
                    if (thrown++ < 5)
                        Program.Fail($"exhaustive: {got.Thrown.GetType().Name} on {Program.Hex(field)}");
                    continue;
                }
                if (got.Error is not null)
                    continue;
                accepted++;
                if (Program.Utf8Count(got.Text) > 6 * n + 8 || !Program.WellFormed(got.Text))
                    overBound++;
            }
        }
        Program.Check(thrown == 0 && overBound == 0,
            $"exhaustive 1-3 byte payloads: {calls} calls, {accepted} accepted, thrown {thrown}, over 6N+8 or ill-formed {overBound}, {clock.Elapsed.TotalSeconds:F1} s");
    }
}
