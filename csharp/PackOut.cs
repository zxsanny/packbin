namespace Packbin;

// The packet one pack call writes. Every write reserves its bytes first, naming the member being written, and a write
// that would take the packet past `maxBytes` is refused before it grows the buffer, so the buffer never holds more
// than `maxBytes` bytes (the type byte included).
internal sealed class PackOut
{
    private const int MaxArray = 0x7FFFFFC7;

    private readonly long _maxBytes;
    private byte[] _data;

    public PackOut(long maxBytes)
    {
        _maxBytes = maxBytes;
        _data = new byte[Math.Min(32, maxBytes)];
    }

    public int Count { get; private set; }

    public void Reserve(int size, string member)
    {
        var total = (long)Count + size;
        if (total > _maxBytes)
            throw new ArgumentException(
                $"'{member}': the packet would be {total} bytes, above the limit of {_maxBytes} bytes");
    }

    public void Add(byte value)
    {
        Grow(1);
        _data[Count++] = value;
    }

    public void AddU16(int value)
    {
        Add((byte)value);
        Add((byte)(value >> 8));
    }

    public void AddRange(byte[] raw)
    {
        Grow(raw.Length);
        Buffer.BlockCopy(raw, 0, _data, Count, raw.Length);
        Count += raw.Length;
    }

    // A byte already written, such as a combined flags byte that its bits fill in afterwards.
    public void Set(int at, byte value) => _data[at] = value;

    public byte[] ToArray()
    {
        var packet = new byte[Count];
        Buffer.BlockCopy(_data, 0, packet, 0, Count);
        return packet;
    }

    // Doubles, but never past `maxBytes` (every caller has reserved its bytes, so the need is within it).
    private void Grow(int size)
    {
        var need = Count + size;
        if (need <= _data.Length)
            return;
        var next = (int)Math.Min(Math.Min((long)_data.Length * 2, _maxBytes), MaxArray);
        Array.Resize(ref _data, Math.Max(next, need));
    }
}
