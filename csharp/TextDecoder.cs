using System.Text;
using static Packbin.TextModes;

namespace Packbin;

// The decoder of the compact text format: accepts every stream the rules allow; its work and memory are bounded by the
// payload (at most 6 output bytes per payload byte plus 8, and never more than MaxText).
internal static class TextDecoder
{
    // Reads one string at `offset` and moves `offset` past it. Returns null on success; a ShortPacket naming `name`
    // when the buffer ends inside the count or the payload, or when the payload is refused.
    internal static ShortPacket? Read(string name, ReadOnlySpan<byte> bytes, ref int offset, out string text)
    {
        text = "";
        var start = offset;
        var count = 0;
        var at = start;
        for (var k = 0; ; k++)
        {
            if (at >= bytes.Length)
                return new ShortPacket(name, k + 1, bytes.Length - start);
            int b = bytes[at++];
            count |= (b & 0x7f) << (7 * k);
            if ((b & 0x80) == 0)
            {
                if (k > 0 && b == 0)
                    return Walker.InterimBadValue(name, bytes.Length - at);
                break;
            }
            if (k == 2)
                return Walker.InterimBadValue(name, bytes.Length - at);
        }
        if (count == 0)
        {
            offset = at;
            return null;
        }
        var left = bytes.Length - at;
        if (left < count)
            return new ShortPacket(name, count, left);
        var decoded = DecodePayload(bytes.Slice(at, count));
        if (decoded is null)
            return Walker.InterimBadValue(name, left);
        text = decoded;
        offset = at + count;
        return null;
    }

    // The text of one payload, or null when the payload is refused.
    private static string? DecodePayload(ReadOnlySpan<byte> payload)
    {
        int first = payload[0];
        var startMode = (first >> 2) & 7;
        if (startMode == 4)
        {
            if (first != RawPrefix || payload.Length - 1 > MaxText)
                return null;
            return payload.Length == 1 ? "" : Compat.TryUtf8(payload.Slice(1), out var raw) ? raw : null;
        }
        if (startMode > 4)
            return null;
        var pad = first >> 5;
        var total = 8 * payload.Length - pad;
        if (total < 6 || (payload[payload.Length - 1] & ((1 << pad) - 1)) != 0)
            return null;
        var cap = Math.Min(MaxText, 6 * payload.Length + 8);
        var output = new byte[cap];
        var size = 0;
        var pos = 6;
        var mode = startMode;
        var lockOn = false;
        var pending = false;
        while (pos < total)
        {
            var table = All[mode];
            var code = 0;
            var len = 0;
            var sym = -1;
            while (len < MaxCode)
            {
                if (pos + len >= total)
                    return null;
                var p = pos + len;
                code = (code << 1) | ((payload[p >> 3] >> (7 - (p & 7))) & 1);
                len++;
                var into = code - table.FirstCode[len];
                if (table.CountOf[len] > 0 && into >= 0 && into < table.CountOf[len])
                {
                    sym = table.BySlot[table.FirstSlot[len] + into];
                    break;
                }
            }
            if (sym < 0)
                return null;
            pos += len;
            int cp;
            if (sym < table.SharedBase)
            {
                cp = table.Letters[sym];
                var up = table.Upper[sym];
                if (pending)
                {
                    if (up == 0)
                        return null;
                    cp = up;
                    pending = false;
                }
                else if (lockOn && up != 0)
                {
                    cp = up;
                }
            }
            else if (sym < table.SwBase)
            {
                if (pending)
                    return null;
                cp = table.Shared[sym - table.SharedBase];
            }
            else if (sym < table.SwBase + 3)
            {
                if (pending)
                    return null;
                mode = table.SwitchTarget(sym, mode);
                continue;
            }
            else if (sym == table.Cap)
            {
                if (lockOn || pending)
                    return null;
                pending = true;
                continue;
            }
            else if (sym == table.Lock)
            {
                if (pending)
                    return null;
                lockOn = !lockOn;
                continue;
            }
            else
            {
                if (pending)
                    return null;
                cp = ReadEscaped(payload, pos, total);
                if (cp < 0)
                    return null;
                pos += 8 * Utf8Length(cp);
            }
            var width = Utf8Length(cp);
            if (size + width > MaxText)
                return null;
            if (size + width > output.Length)
                Array.Resize(ref output, Math.Min(MaxText, Math.Max(output.Length * 2, size + width)));
            size = PutUtf8(output, size, cp);
        }
        return pending ? null : Encoding.UTF8.GetString(output, 0, size);
    }

    private static int PutUtf8(byte[] output, int at, int cp)
    {
        if (cp < 0x80)
        {
            output[at++] = (byte)cp;
        }
        else if (cp < 0x800)
        {
            output[at++] = (byte)(0xc0 | (cp >> 6));
            output[at++] = (byte)(0x80 | (cp & 0x3f));
        }
        else if (cp < 0x10000)
        {
            output[at++] = (byte)(0xe0 | (cp >> 12));
            output[at++] = (byte)(0x80 | ((cp >> 6) & 0x3f));
            output[at++] = (byte)(0x80 | (cp & 0x3f));
        }
        else
        {
            output[at++] = (byte)(0xf0 | (cp >> 18));
            output[at++] = (byte)(0x80 | ((cp >> 12) & 0x3f));
            output[at++] = (byte)(0x80 | ((cp >> 6) & 0x3f));
            output[at++] = (byte)(0x80 | (cp & 0x3f));
        }
        return at;
    }

    private static int ByteAt(ReadOnlySpan<byte> payload, int pos)
    {
        var shift = pos & 7;
        var index = pos >> 3;
        var high = payload[index] << shift;
        if (shift == 0)
            return high & 0xff;
        return (high | (payload[index + 1] >> (8 - shift))) & 0xff;
    }

    // One scalar of 1 to 4 UTF-8 bytes at bit `pos`, 8 bits each; -1 when cut short or not valid UTF-8.
    private static int ReadEscaped(ReadOnlySpan<byte> payload, int pos, int total)
    {
        if (pos + 8 > total)
            return -1;
        var b0 = ByteAt(payload, pos);
        var n = b0 < 0x80 ? 1 : (b0 >> 5) == 6 ? 2 : (b0 >> 4) == 14 ? 3 : (b0 >> 3) == 30 ? 4 : 0;
        if (n == 0 || pos + 8 * n > total)
            return -1;
        var cp = n == 1 ? b0 : n == 2 ? b0 & 0x1f : n == 3 ? b0 & 0x0f : b0 & 0x07;
        for (var j = 1; j < n; j++)
        {
            var b = ByteAt(payload, pos + 8 * j);
            if ((b & 0xc0) != 0x80)
                return -1;
            cp = (cp << 6) | (b & 0x3f);
        }
        var overlong = cp < (n == 2 ? 0x80 : n == 3 ? 0x800 : n == 4 ? 0x10000 : 0);
        if (overlong || (cp >= 0xd800 && cp <= 0xdfff) || cp > 0x10ffff)
            return -1;
        return cp;
    }
}
