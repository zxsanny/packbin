namespace Packbin;

// The compact text format of every string (contract compact-text 1.0.0): a LEB128 count, then a payload that is either
// Huffman-coded symbols in one of four modes or the raw UTF-8 escape (0x10, then the text).
internal static class TextModes
{
    internal const int MaxText = 65535;
    internal const int MaxCode = 16;
    internal const byte RawPrefix = 0x10;
    internal const int Inf = 1 << 29;
    internal const int States = 8;
    // Letters, capitals and shared characters are all below U+0530; anything else is coded with ESC.
    internal const int TableSpan = 0x530;

    // One mode: its code lengths and codes by symbol index, and the canonical decoding arrays.
    internal sealed class Mode
    {
        internal readonly int[] Letters;
        internal readonly int[] Upper;
        internal readonly int[] Shared;
        internal readonly int SharedBase;
        internal readonly int SwBase;
        internal readonly int Cap;
        internal readonly int Lock;
        internal readonly int Esc;
        internal readonly int[] Bits;
        internal readonly int[] Codes;
        internal readonly int[] FirstCode = new int[MaxCode + 2];
        internal readonly int[] FirstSlot = new int[MaxCode + 2];
        internal readonly int[] CountOf = new int[MaxCode + 2];
        internal readonly int[] BySlot;
        internal readonly byte[] LetterAt = new byte[TableSpan];
        internal readonly byte[] CapitalAt = new byte[TableSpan];
        internal readonly byte[] SharedAt = new byte[TableSpan];

        internal Mode(int[] letters, int[] upper, int[] shared, int[] lengths, bool text)
        {
            Letters = letters;
            Upper = upper;
            Shared = shared;
            SharedBase = letters.Length;
            SwBase = SharedBase + shared.Length;
            Cap = text ? SwBase + 3 : -1;
            Lock = text ? SwBase + 4 : -1;
            Esc = text ? SwBase + 5 : SwBase + 3;
            if (lengths.Length != Esc + 1)
                throw new InvalidOperationException($"text table has {lengths.Length} lengths");
            Bits = lengths;
            Codes = new int[lengths.Length];
            BySlot = new int[lengths.Length];
            Build();
            for (var i = 0; i < letters.Length; i++)
            {
                if (letters[i] < TableSpan)
                    LetterAt[letters[i]] = (byte)(i + 1);
                if (upper[i] != 0 && upper[i] < TableSpan)
                    CapitalAt[upper[i]] = (byte)(i + 1);
            }
            for (var i = 0; i < shared.Length; i++)
            {
                if (shared[i] < TableSpan)
                    SharedAt[shared[i]] = (byte)(i + 1);
            }
        }

        // Canonical Huffman: symbols by (length, index); each code is the previous plus 1, shifted by the growth.
        private void Build()
        {
            var slot = 0;
            var code = 0;
            var prev = 0;
            for (var len = 1; len <= MaxCode; len++)
            {
                FirstSlot[len] = slot;
                for (var sym = 0; sym < Bits.Length; sym++)
                {
                    if (Bits[sym] != len)
                        continue;
                    if (CountOf[len] == 0)
                    {
                        code <<= len - prev;
                        prev = len;
                        FirstCode[len] = code;
                    }
                    Codes[sym] = code++;
                    BySlot[slot++] = sym;
                    CountOf[len]++;
                }
            }
        }

        // The mode a SW symbol of this table leads to.
        internal int SwitchTarget(int sym, int self)
        {
            var j = sym - SwBase;
            return self == 3 || j < self ? j : j + 1;
        }

        // The SW symbol of this table that leads to `target`.
        internal int SwitchSymbol(int self, int target) => SwBase + (self == 3 || target < self ? target : target - 1);
    }

    internal static readonly Mode[] All =
    {
        new(TextTables.Ua, TextTables.UaUpper, TextTables.Shared, TextTables.LengthsUa, true),
        new(TextTables.Ru, TextTables.RuUpper, TextTables.Shared, TextTables.LengthsRu, true),
        new(TextTables.En, TextTables.EnUpper, TextTables.Shared, TextTables.LengthsEn, true),
        new(Array.Empty<int>(), Array.Empty<int>(), TextTables.Numset, TextTables.LengthsNum, false),
    };

    internal static readonly bool[] Codable = new bool[TableSpan];
    internal static readonly bool[] Capital = new bool[TableSpan];
    internal static readonly int ShortestCode;
    internal static readonly int ShortestEsc;

    static TextModes()
    {
        var code = MaxCode;
        var esc = int.MaxValue;
        foreach (var mode in All)
        {
            foreach (var len in mode.Bits)
                code = Math.Min(code, len);
            esc = Math.Min(esc, mode.Bits[mode.Esc]);
            for (var c = 0; c < TableSpan; c++)
            {
                if (mode.LetterAt[c] != 0 || mode.CapitalAt[c] != 0 || mode.SharedAt[c] != 0)
                    Codable[c] = true;
                if (mode.CapitalAt[c] != 0)
                    Capital[c] = true;
            }
        }
        ShortestCode = code;
        ShortestEsc = esc;
        LockMin = int.MaxValue;
        for (var m = 0; m < 3; m++)
        {
            CapMax = Math.Max(CapMax, All[m].Bits[All[m].Cap]);
            LockMin = Math.Min(LockMin, All[m].Bits[All[m].Lock]);
        }
    }

    // The dearest CAP and the cheapest LOCK over the text modes, in bits (see the parse in TextEncoder).
    internal static readonly int CapMax;
    internal static readonly int LockMin;

    internal static int Utf8Length(int cp) => cp < 0x80 ? 1 : cp < 0x800 ? 2 : cp < 0x10000 ? 3 : 4;
}
