namespace PackbinProbe;

// An independent GF(256) Reed-Solomon reference (polynomial 0x11D, alpha = 2), written from message-ecc.md and not
// shared with the package: it builds hostile inputs (any first symbol, errors at the unsent length byte) and checks the
// package's repaired words.
internal static class Gf
{
    internal static readonly int[] Exp = new int[512];
    internal static readonly int[] Log = new int[256];

    static Gf()
    {
        var x = 1;
        for (var i = 0; i < 255; i++)
        {
            Exp[i] = x;
            Log[x] = i;
            x <<= 1;
            if ((x & 0x100) != 0)
                x ^= 0x11D;
        }
        for (var i = 255; i < 512; i++)
            Exp[i] = Exp[i - 255];
    }

    internal static int Mul(int a, int b) => a == 0 || b == 0 ? 0 : Exp[Log[a] + Log[b]];

    internal static int[] Generator(int n)
    {
        var g = new[] { 1 };
        for (var i = 0; i < n; i++)
        {
            var next = new int[g.Length + 1];
            for (var j = 0; j < g.Length; j++)
            {
                next[j] ^= g[j];
                next[j + 1] ^= Mul(g[j], Exp[i]);
            }
            g = next;
        }
        return g;
    }

    // The sent bytes of a code word whose unsent first symbol is `first` (the contract puts len(clear) there).
    internal static byte[] Encode(int first, byte[] clear, int n)
    {
        var g = Generator(n);
        var rem = new int[1 + clear.Length + n];
        rem[0] = first;
        for (var i = 0; i < clear.Length; i++)
            rem[i + 1] = clear[i];
        for (var i = 0; i <= clear.Length; i++)
        {
            var c = rem[i];
            if (c == 0)
                continue;
            for (var j = 1; j <= n; j++)
                rem[i + j] ^= Mul(g[j], c);
        }
        var sent = new byte[clear.Length + n];
        clear.CopyTo(sent, 0);
        for (var j = 0; j < n; j++)
            sent[clear.Length + j] = (byte)rem[clear.Length + 1 + j];
        return sent;
    }

    internal static byte[] Protect(byte[] clear, int n) => Encode(clear.Length, clear, n);

    // All n syndromes zero over [N - n] + word.
    internal static bool Valid(byte[] word, int n)
    {
        for (var i = 0; i < n; i++)
        {
            var s = word.Length - n;
            foreach (var b in word)
                s = (s == 0 ? 0 : Exp[Log[s] + i]) ^ b;
            if (s != 0)
                return false;
        }
        return true;
    }

    // Flips `count` distinct positions of `word` by nonzero values.
    internal static int[] Corrupt(byte[] word, int count, Random r)
    {
        var picked = new HashSet<int>();
        count = Math.Min(count, word.Length);
        while (picked.Count < count)
            picked.Add(r.Next(word.Length));
        foreach (var p in picked)
            word[p] ^= (byte)(1 + r.Next(255));
        return picked.ToArray();
    }
}
