using static Packbin.TextModes;

namespace Packbin;

// What the optimal parse looks up instead of recomputing: for every code point a table codes and every state
// (mode * 2 + capital lock), the edges that consume it; and the cheapest chain of control symbols between two states.
internal static class TextEdges
{
    internal const int Per = 3;

    internal static readonly byte[] Count = new byte[TableSpan * States];
    internal static readonly short[] First = new short[TableSpan * States * Per];
    internal static readonly short[] Second = new short[TableSpan * States * Per];
    internal static readonly short[] Bits = new short[TableSpan * States * Per];
    internal static readonly int[] Min = new int[TableSpan * States];

    // Dist[from * 8 + to]: the fewest bits of control symbols (SW and LOCK) that lead from one state to another.
    internal static readonly int[] Dist = new int[States * States];

    // The same over the states without capital lock only, for a text that has no capital letter (see TextEncoder).
    internal static readonly int[] Dist4 = new int[States * States];

    internal static readonly int[] EscBits = new int[4];

    static TextEdges()
    {
        for (var m = 0; m < 4; m++)
            EscBits[m] = All[m].Bits[All[m].Esc];
        for (var c = 0; c < TableSpan; c++)
        {
            for (var s = 0; s < States; s++)
                Build(c, s);
        }
        Closure(Dist, withLock: true);
        Closure(Dist4, withLock: false);
    }

    private static void Build(int c, int s)
    {
        var mode = All[s >> 1];
        var k = s & 1;
        var slot = c * States + s;
        var n = 0;
        void Add(int first, int second, int bits)
        {
            if (n == Per)
                throw new InvalidOperationException("too many edges");
            First[slot * Per + n] = (short)first;
            Second[slot * Per + n] = (short)second;
            Bits[slot * Per + n] = (short)bits;
            n++;
        }
        int at = mode.LetterAt[c];
        if (at != 0 && (mode.Upper[at - 1] == 0 || k == 0))
            Add(at - 1, -1, mode.Bits[at - 1]);
        at = mode.CapitalAt[c];
        if (at != 0)
        {
            if (k == 1)
                Add(at - 1, -1, mode.Bits[at - 1]);
            else
                Add(mode.Cap, at - 1, mode.Bits[mode.Cap] + mode.Bits[at - 1]);
        }
        at = mode.SharedAt[c];
        if (at != 0)
        {
            var sym = mode.SharedBase + at - 1;
            Add(sym, -1, mode.Bits[sym]);
        }
        Add(mode.Esc, -1, mode.Bits[mode.Esc] + 8 * Utf8Length(c));
        Count[slot] = (byte)n;
        var min = Inf;
        for (var e = 0; e < n; e++)
            min = Math.Min(min, Bits[slot * Per + e]);
        Min[slot] = min;
    }

    private static void Closure(int[] dist, bool withLock)
    {
        for (var i = 0; i < dist.Length; i++)
            dist[i] = Inf;
        for (var s = 0; s < States; s++)
        {
            dist[s * States + s] = 0;
            var mode = All[s >> 1];
            for (var t = 0; t < 4; t++)
            {
                if (t != s >> 1)
                    Lower(dist, s, t * 2 + (s & 1), mode.Bits[mode.SwitchSymbol(s >> 1, t)]);
            }
            if (withLock && mode.Lock >= 0)
                Lower(dist, s, s ^ 1, mode.Bits[mode.Lock]);
        }
        for (var via = 0; via < States; via++)
        {
            for (var from = 0; from < States; from++)
            {
                for (var to = 0; to < States; to++)
                    Lower(dist, from, to, dist[from * States + via] + dist[via * States + to]);
            }
        }
    }

    private static void Lower(int[] dist, int from, int to, int value)
    {
        if (value < dist[from * States + to])
            dist[from * States + to] = value;
    }
}
