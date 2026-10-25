using System.Buffers.Binary;

namespace Packbin;

/// <summary>The direction of a frame: the nonce and the keys depend on it.</summary>
public enum FrameDirection : byte
{
    Up = 1,
    Down = 2,
    Group = 3,
}

/// <summary>The directions a frame session loaded keys for.</summary>
[Flags]
public enum FrameDirections
{
    None = 0,
    Up = 1,
    Down = 2,
    Group = 4,
    All = 7,
}

/// <summary>Which loaded key opened a frame.</summary>
public enum FrameSlot
{
    Current,
    Previous,
}

/// <summary>What a replay window says about a counter.</summary>
public enum Freshness
{
    Fresh,
    Duplicate,
    TooOld,
}

/// <summary>What a frame session is loaded with besides the key. A <see cref="TagLength"/> other than 4, 8 or 16 makes load fail.</summary>
public readonly struct FrameConfig
{
    public int TagLength { get; }

    public FrameDirections Directions { get; }

    public FrameConfig(int tagLength, FrameDirections directions)
    {
        TagLength = tagLength;
        Directions = directions;
    }
}

/// <summary>What <see cref="FrameSession.Open"/> reports for a frame that opened.</summary>
public readonly struct FrameOpened
{
    public FrameSlot Slot { get; }

    public int ClearLength { get; }

    public int PlainLength { get; }

    public FrameOpened(FrameSlot slot, int clearLength, int plainLength)
    {
        Slot = slot;
        ClearLength = clearLength;
        PlainLength = plainLength;
    }
}

/// <summary>
/// What the caller supplies per message: the 8-byte <c>msg_id</c> and the 4-bit <c>kind</c> (0 to 15).
/// <para>
/// <b>For one (key, epoch, direction), a <c>msg_id</c> is never sealed twice with different contents.</b> Reuse breaks the
/// confidentiality of both messages, and packbin cannot check it. A new epoch derives new keys and nonces. meshbell builds the
/// id as source (2 bytes), id field (2 bytes) and creation wave (4 bytes), so it is unique by construction.
/// </para>
/// A default value, or one built from a span that is not 8 bytes long, is refused by seal and open as <see cref="BadValue"/>.
/// </summary>
public readonly struct MsgContext
{
    public const int IdSize = 8;

    private readonly ulong _id;
    private readonly bool _set;

    public MsgContext(ReadOnlySpan<byte> msgId, int kind)
    {
        _set = msgId.Length == IdSize;
        _id = _set ? BinaryPrimitives.ReadUInt64LittleEndian(msgId) : 0;
        Kind = kind;
    }

    public int Kind { get; }

    internal bool IsValid => _set;

    internal ulong IdBits => _id;
}
