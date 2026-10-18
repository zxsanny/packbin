using System.Buffers;
using static Packbin.TextModes;

namespace Packbin;

// The encoder of the compact text format: the optimal parse of the contract, then the raw escape when it is not smaller.
internal static class TextEncoder
{
    // The field bytes (count, then payload) of a text given as the UTF-8 bytes the package already produces.
    internal static byte[] Encode(byte[] utf8)
    {
        if (utf8.Length == 0)
            return new byte[] { 0 };
        if (utf8.Length > MaxText)
            throw new ArgumentException($"text longer than {MaxText} UTF-8 bytes");
        if (CannotBeatRaw(utf8))
            return RawField(utf8);
        using var parse = new Parse(utf8);
        var size = (6 + parse.Total + 7) / 8;
        if (size >= 1 + utf8.Length)
            return RawField(utf8);
        var head = VarintLength(size);
        var field = new byte[head + size];
        PutVarint(field, size);
        parse.Write(field, head, size);
        return field;
    }

    // A lower bound on the compact size: a character no table can code costs at least its ESC and bytes, any other at
    // least the shortest code. When even that is not smaller than the raw payload, the parse cannot win.
    private static bool CannotBeatRaw(byte[] utf8)
    {
        long bits = 6;
        var codable = Codable;
        var i = 0;
        while (i < utf8.Length)
        {
            int b = utf8[i];
            int cp;
            int len;
            if (b < 0x80)
            {
                cp = b;
                len = 1;
            }
            else if (b < 0xe0)
            {
                cp = ((b & 0x1f) << 6) | (utf8[i + 1] & 0x3f);
                len = 2;
            }
            else if (b < 0xf0)
            {
                cp = 0x800;
                len = 3;
            }
            else
            {
                cp = 0x10000;
                len = 4;
            }
            i += len;
            bits += cp < TableSpan && codable[cp] ? ShortestCode : ShortestEsc + 8 * len;
        }
        return (bits + 7) / 8 >= 1 + (long)utf8.Length;
    }

    private static byte[] RawField(byte[] utf8)
    {
        var size = 1 + utf8.Length;
        var head = VarintLength(size);
        var field = new byte[head + size];
        PutVarint(field, size);
        field[head] = RawPrefix;
        Buffer.BlockCopy(utf8, 0, field, head + 1, utf8.Length);
        return field;
    }

    private static int VarintLength(int n) => n < 0x80 ? 1 : n < 0x4000 ? 2 : 3;

    private static void PutVarint(byte[] field, int n)
    {
        var i = 0;
        while (n >= 0x80)
        {
            field[i++] = (byte)(n | 0x80);
            n >>= 7;
        }
        field[i] = (byte)n;
    }

    // The optimal parse: cheapest finish cost per (position, mode, lock), ties to the smallest first symbol.
    //
    // A text whose capital letters would cost less as CAP symbols than the cheapest LOCK never uses LOCK: lowercase
    // letters need the lock off and every other symbol costs the same with the lock on or off, so replacing the LOCK
    // symbols of any parse by a CAP before each capital letter gives a strictly cheaper parse. Such a text is solved
    // over the four lock-off states only.
    private sealed class Parse : IDisposable
    {
        private readonly int[] _cps;
        private readonly int _n;
        private readonly int[] _cost;
        private readonly int _start;
        private readonly int[] _energy = new int[States];
        private readonly int[] _first = new int[TextEdges.Per];
        private readonly int[] _second = new int[TextEdges.Per];
        private readonly int[] _bits = new int[TextEdges.Per];

        internal int Total { get; }

        internal Parse(byte[] utf8)
        {
            _cps = ArrayPool<int>.Shared.Rent(utf8.Length);
            _n = CodePoints(utf8, _cps, out var capitals);
            _cost = ArrayPool<int>.Shared.Rent((_n + 1) * States);
            var lockNeverWins = capitals * CapMax < LockMin;
            var step = lockNeverWins ? 2 : 1;
            var dist = lockNeverWins ? TextEdges.Dist4 : TextEdges.Dist;
            for (var s = 0; s < States; s++)
                _cost[_n * States + s] = s % step == 0 ? 0 : Inf;
            Solve(step, dist);
            var best = 0;
            for (var m = 1; m < 4; m++)
            {
                if (_cost[m * 2] < _cost[best * 2])
                    best = m;
            }
            _start = best;
            Total = _cost[best * 2];
        }

        public void Dispose()
        {
            ArrayPool<int>.Shared.Return(_cps);
            ArrayPool<int>.Shared.Return(_cost);
        }

        // Fills `points` with the code points of the UTF-8 bytes; `capitals` counts the capital letters among them.
        private static int CodePoints(byte[] utf8, int[] points, out int capitals)
        {
            capitals = 0;
            var capital = Capital;
            var n = 0;
            var i = 0;
            while (i < utf8.Length)
            {
                int b = utf8[i];
                int cp;
                if (b < 0x80)
                {
                    cp = b;
                    i += 1;
                }
                else if (b < 0xe0)
                {
                    cp = ((b & 0x1f) << 6) | (utf8[i + 1] & 0x3f);
                    i += 2;
                }
                else if (b < 0xf0)
                {
                    cp = ((b & 0x0f) << 12) | ((utf8[i + 1] & 0x3f) << 6) | (utf8[i + 2] & 0x3f);
                    i += 3;
                }
                else
                {
                    cp = ((b & 0x07) << 18) | ((utf8[i + 1] & 0x3f) << 12) | ((utf8[i + 2] & 0x3f) << 6)
                        | (utf8[i + 3] & 0x3f);
                    i += 4;
                }
                if (cp < TableSpan && capital[cp])
                    capitals++;
                points[n++] = cp;
            }
            return n;
        }

        private void Solve(int step, int[] dist)
        {
            var cps = _cps;
            var cost = _cost;
            var energy = _energy;
            var min = TextEdges.Min;
            var escBits = TextEdges.EscBits;
            for (var i = _n - 1; i >= 0; i--)
            {
                var c = cps[i];
                var here = i * States;
                var next = here + States;
                if (c < TableSpan)
                {
                    var at = c * States;
                    for (var s = 0; s < States; s += step)
                        energy[s] = min[at + s] + cost[next + s];
                }
                else
                {
                    var extra = 8 * Utf8Length(c);
                    for (var s = 0; s < States; s += step)
                        energy[s] = escBits[s >> 1] + extra + cost[next + s];
                }
                for (var s = 0; s < States; s += step)
                {
                    var best = Inf;
                    var row = s * States;
                    for (var t = 0; t < States; t += step)
                    {
                        var v = dist[row + t] + energy[t];
                        if (v < best)
                            best = v;
                    }
                    cost[here + s] = best;
                }
                if (step == 2)
                {
                    for (var s = 1; s < States; s += 2)
                        cost[here + s] = Inf;
                }
            }
        }

        // Fills _first, _second, _bits with the edges that consume `c` in state `s`; returns the count.
        private int Emissions(int s, int c)
        {
            if (c >= TableSpan)
            {
                _first[0] = All[s >> 1].Esc;
                _second[0] = -1;
                _bits[0] = TextEdges.EscBits[s >> 1] + 8 * Utf8Length(c);
                return 1;
            }
            var slot = c * States + s;
            var count = TextEdges.Count[slot];
            for (var e = 0; e < count; e++)
            {
                _first[e] = TextEdges.First[slot * TextEdges.Per + e];
                _second[e] = TextEdges.Second[slot * TextEdges.Per + e];
                _bits[e] = TextEdges.Bits[slot * TextEdges.Per + e];
            }
            return count;
        }

        // Walks the winning parse and writes the payload: pad and start mode, then the codes.
        internal void Write(byte[] field, int baseAt, int size)
        {
            var sink = new BitSink(field, baseAt);
            sink.Put(8 * size - 6 - Total, 3);
            sink.Put(_start, 3);
            var state = _start * 2;
            var i = 0;
            while (i < _n)
            {
                var m = state >> 1;
                var k = state & 1;
                var mode = All[m];
                var want = _cost[i * States + state];
                var bestFirst = int.MaxValue;
                var bestKind = 0;
                var bestArg = 0;
                for (var t = 0; t < 4; t++)
                {
                    if (t == m)
                        continue;
                    var sym = mode.SwitchSymbol(m, t);
                    if (sym < bestFirst && mode.Bits[sym] + _cost[i * States + t * 2 + k] == want)
                    {
                        bestFirst = sym;
                        bestKind = 1;
                        bestArg = t * 2 + k;
                    }
                }
                if (mode.Lock >= 0 && mode.Lock < bestFirst
                    && mode.Bits[mode.Lock] + _cost[i * States + (state ^ 1)] == want)
                {
                    bestFirst = mode.Lock;
                    bestKind = 1;
                    bestArg = state ^ 1;
                }
                var count = Emissions(state, _cps[i]);
                for (var e = 0; e < count; e++)
                {
                    if (_first[e] < bestFirst && _bits[e] + _cost[(i + 1) * States + state] == want)
                    {
                        bestFirst = _first[e];
                        bestKind = 2;
                        bestArg = e;
                    }
                }
                if (bestKind == 0)
                    throw new InvalidOperationException("no optimal edge");
                sink.Put(mode.Codes[bestFirst], mode.Bits[bestFirst]);
                if (bestKind == 1)
                {
                    state = bestArg;
                    continue;
                }
                if (_second[bestArg] >= 0)
                    sink.Put(mode.Codes[_second[bestArg]], mode.Bits[_second[bestArg]]);
                else if (bestFirst == mode.Esc)
                    PutUtf8(ref sink, _cps[i]);
                i++;
            }
            sink.Flush();
        }

        private static void PutUtf8(ref BitSink sink, int cp)
        {
            if (cp < 0x80)
            {
                sink.Put(cp, 8);
            }
            else if (cp < 0x800)
            {
                sink.Put(0xc0 | (cp >> 6), 8);
                sink.Put(0x80 | (cp & 0x3f), 8);
            }
            else if (cp < 0x10000)
            {
                sink.Put(0xe0 | (cp >> 12), 8);
                sink.Put(0x80 | ((cp >> 6) & 0x3f), 8);
                sink.Put(0x80 | (cp & 0x3f), 8);
            }
            else
            {
                sink.Put(0xf0 | (cp >> 18), 8);
                sink.Put(0x80 | ((cp >> 12) & 0x3f), 8);
                sink.Put(0x80 | ((cp >> 6) & 0x3f), 8);
                sink.Put(0x80 | (cp & 0x3f), 8);
            }
        }
    }

    // Most significant bit first.
    private struct BitSink
    {
        private readonly byte[] _out;
        private int _at;
        private ulong _acc;
        private int _held;

        internal BitSink(byte[] output, int baseAt)
        {
            _out = output;
            _at = baseAt;
            _acc = 0;
            _held = 0;
        }

        internal void Put(int value, int count)
        {
            _acc = (_acc << count) | (uint)value;
            _held += count;
            while (_held >= 8)
            {
                _out[_at++] = (byte)(_acc >> (_held - 8));
                _held -= 8;
            }
        }

        // The last partial byte, padded with zero bits.
        internal void Flush()
        {
            if (_held > 0)
                _out[_at] = (byte)(_acc << (8 - _held));
        }
    }
}
