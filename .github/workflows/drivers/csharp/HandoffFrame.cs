using Packbin;

static class HandoffFrame
{
    static byte[] BytesOf(string token) =>
        token == "-" ? [] : Convert.FromHexString(token);

    static string HexOf(byte[] data) =>
        data.Length == 0 ? "-" : Convert.ToHexString(data).ToLowerInvariant();

    static string Kind(object error) => error switch
    {
        BadValue => "BadValue",
        TooLong => "TooLong",
        BufferFull => "BufferFull",
        ShortPacket => "ShortPacket",
        TagMismatch => "TagMismatch",
        _ => "error",
    };

    const long MaxByte = 255, MaxLength = 65535, MaxEpoch = 4294967295;

    // A number is decimal digits only (no sign, space or `_`) and at most top, or the line is malformed; no digit string
    // wraps or overflows into another value.
    static long Number(string token, long top)
    {
        var bad = new FormatException($"bad number: {token} (digits of 0 to {top})");
        if (token.Length == 0) throw bad;
        long n = 0;
        foreach (var c in token)
        {
            if (c is < '0' or > '9') throw bad;
            n = n * 10 + (c - '0');
            if (n > top) throw bad;
        }
        return n;
    }

    static int Small(string token, long top) => (int)Number(token, top);

    // The package takes the byte as it comes (0 to 255 here): a direction outside 1 to 3 is its BadValue to give.
    static FrameDirection Direction(int d) => (FrameDirection)(byte)d;

    // The optional trailing fields of a seal or open line: the directions loaded (digits 1 to 3) and the output buffer size.
    static (FrameDirections Directions, int Size) Loaded(string[] w)
    {
        var digits = w.Length > 9 ? w[9] : "123";
        if (digits.Length == 0 || digits.Any(c => c is < '1' or > '3')) throw new FormatException($"bad dirs: {digits}");
        var size = w.Length > 10 ? Small(w[10], MaxLength) : 300;
        var mask = 0;
        foreach (var digit in digits) mask |= 1 << (digit - '1');
        return ((FrameDirections)mask, size);
    }

    static string Seal(string[] w)
    {
        var key = BytesOf(w[0]);
        uint epoch = (uint)Number(w[1], MaxEpoch);
        int d = Small(w[2], MaxByte), tagLen = Small(w[3], MaxByte);
        var msgId = BytesOf(w[4]);
        int kind = Small(w[5], MaxByte);
        var ad = BytesOf(w[6]);
        var clear = BytesOf(w[7]);
        var plain = BytesOf(w[8]);
        var (directions, size) = Loaded(w);
        var session = FrameSession.Load(key, epoch, new FrameConfig(tagLen, directions));
        if (session is null) return "BadValue";
        var buf = new byte[size];
        var err = session.Seal(Direction(d), new MsgContext(msgId, kind), ad, clear, plain, buf, out int written);
        if (err is not null) return Kind(err);
        return HexOf(buf[..written]);
    }

    static string Open(string[] w)
    {
        var key = BytesOf(w[0]);
        uint epoch = (uint)Number(w[1], MaxEpoch);
        int d = Small(w[2], MaxByte), tagLen = Small(w[3], MaxByte);
        var msgId = BytesOf(w[4]);
        int kind = Small(w[5], MaxByte);
        var ad = BytesOf(w[6]);
        int clearLen = Small(w[7], MaxLength);
        var body = BytesOf(w[8]);
        var (directions, size) = Loaded(w);
        var session = FrameSession.Load(key, epoch, new FrameConfig(tagLen, directions));
        if (session is null) return "BadValue";
        var buf = new byte[size];
        var err = session.Open(Direction(d), new MsgContext(msgId, kind), ad, body, clearLen, buf, out var opened);
        if (err is not null) return Kind(err);
        return HexOf(buf[..opened.PlainLength]);
    }

    static string Mac(string[] w)
    {
        var key = BytesOf(w[0]);
        uint epoch = (uint)Number(w[1], MaxEpoch);
        var label = BytesOf(w[2]);
        int n = Small(w[3], MaxByte);
        var message = BytesOf(w[4]);
        var mk = MacKey.Derive(key, epoch, label);
        if (mk is null) return "BadValue";
        var tag = new byte[n];
        var err = mk.Tag((ReadOnlySpan<byte>)message, tag);
        if (err is not null) return Kind(err);
        return HexOf(tag);
    }

    static string Verify(string[] w)
    {
        var key = BytesOf(w[0]);
        uint epoch = (uint)Number(w[1], MaxEpoch);
        var label = BytesOf(w[2]);
        _ = Number(w[3], MaxByte); // n: checked, not used (the tag length comes from the tag)
        var message = BytesOf(w[4]);
        var tag = BytesOf(w[5]);
        var mk = MacKey.Derive(key, epoch, label);
        if (mk is null) return "BadValue";
        return mk.Verify((ReadOnlySpan<byte>)message, tag) ? "valid" : "invalid";
    }

    static string Line(string[] words) => words[0] switch
    {
        "seal" => Seal(words[1..]),
        "open" => Open(words[1..]),
        "mac" => Mac(words[1..]),
        "verify" => Verify(words[1..]),
        "open-skip" or "verify-skip" => "skip",
        _ => throw new ArgumentException($"unknown word {words[0]}"),
    };

    public static int Run(string[] args)
    {
        if (args is ["frame-batch", var path])
        {
            var number = 0;
            foreach (var text in File.ReadAllLines(path))
            {
                number++;
                if (string.IsNullOrWhiteSpace(text)) continue;
                try
                {
                    Console.WriteLine(Line(text.Trim().Split((char[]?)null, StringSplitOptions.RemoveEmptyEntries)));
                }
                catch (Exception x) when (x is FormatException or IndexOutOfRangeException or ArgumentException or OverflowException)
                {
                    Console.Error.WriteLine($"frame line {number}: {x.Message}");
                    return 1;
                }
            }
            return 0;
        }
        return 2;
    }
}
