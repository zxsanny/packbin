namespace Packbin;

// Message error correction (contract message-ecc 1.0.0): a Reed-Solomon code over GF(256), polynomial 0x11D, alpha = 2,
// generator roots alpha^0 .. alpha^(n-1). The code word is one byte longer than the sent bytes: the clear length comes
// first, is covered by the code and is not sent. The parity (n bytes) follows the clear bytes.
internal static partial class Ecc
{
    internal const int MaxParity = 32;

    // Sent bytes of one protected message; the code word is 255, one byte of it (the clear length) is not sent.
    internal const int MaxBlock = 254;

    private const int Polynomial = 0x11D;

    // Doubled, so a sum of two logarithms indexes it without a modulo.
    internal static readonly byte[] Exp = new byte[512];
    internal static readonly byte[] Log = new byte[256];

    private static readonly byte[][] Generators = new byte[MaxParity + 1][];

    static Ecc()
    {
        var x = 1;
        for (var i = 0; i < 255; i++)
        {
            Exp[i] = (byte)x;
            Log[x] = (byte)i;
            x <<= 1;
            if ((x & 0x100) != 0)
                x ^= Polynomial;
        }
        for (var i = 255; i < Exp.Length; i++)
            Exp[i] = Exp[i - 255];
        for (var n = 0; n <= MaxParity; n++)
            Generators[n] = Generator(n);
    }

    internal static byte Mul(int a, int b) => a == 0 || b == 0 ? (byte)0 : Exp[Log[a] + Log[b]];

    internal static byte Inverse(int a) => Exp[255 - Log[a]];

    // Monic, highest degree first.
    private static byte[] Generator(int n)
    {
        var g = new byte[] { 1 };
        for (var i = 0; i < n; i++)
        {
            var next = new byte[g.Length + 1];
            for (var j = 0; j < g.Length; j++)
            {
                next[j] ^= g[j];
                next[j + 1] ^= Mul(g[j], Exp[i]);
            }
            g = next;
        }
        return g;
    }

    internal static void RequireParity(int parity)
    {
        if (parity is < 0 or > MaxParity)
            throw new ArgumentOutOfRangeException(
                nameof(parity), parity, $"parity bytes n = {parity}, above the limit of {MaxParity} (0..{MaxParity})");
    }

    // With parity, a clear message above 254 - n bytes is refused before anything is written; without parity
    // there is no block, so no limit.
    internal static void RequireFits(int clearLength, int parity)
    {
        var limit = MaxBlock - parity;
        if (parity > 0 && clearLength > limit)
            throw new ArgumentException(
                $"the clear message is {clearLength} bytes, above the limit of {limit} bytes with {parity} parity bytes");
    }

    // The clear message followed by its parity; the same array when there is no parity.
    internal static byte[] Protect(byte[] clear, int parity)
    {
        if (parity == 0)
            return clear;
        RequireFits(clear.Length, parity);
        var g = Generators[parity];
        var rem = new byte[1 + clear.Length + parity];
        rem[0] = (byte)clear.Length;
        Buffer.BlockCopy(clear, 0, rem, 1, clear.Length);
        for (var i = 0; i <= clear.Length; i++)
        {
            int c = rem[i];
            if (c == 0)
                continue;
            for (var j = 1; j <= parity; j++)
                rem[i + j] ^= Mul(g[j], c);
        }
        var protectedBytes = new byte[clear.Length + parity];
        Buffer.BlockCopy(clear, 0, protectedBytes, 0, clear.Length);
        Buffer.BlockCopy(rem, 1 + clear.Length, protectedBytes, clear.Length, parity);
        return protectedBytes;
    }

    // The parity every handler of one dispatch shares. A mix is refused naming both counts, and a limit above n / 2
    // (or below 0) is refused before any byte is read.
    internal static int SharedParity(SchemeHandler[] handlers, int limit)
    {
        var parity = handlers.Length == 0 ? 0 : handlers[0].Parity;
        foreach (var handler in handlers)
        {
            if (handler.Parity != parity)
                throw new ArgumentException(
                    $"handlers declare different parity counts: {parity} and {handler.Parity}");
        }
        if (limit < 0 || limit > parity / 2)
            throw new ArgumentOutOfRangeException(
                nameof(limit), limit, $"correction limit {limit} is outside 0..{parity / 2} for {parity} parity bytes");
        return parity;
    }
}
