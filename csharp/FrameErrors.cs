namespace Packbin;

// The error values of frame mode (contract pack-session 2.0.0). `TooLong` and `ShortPacket` are the existing classes;
// `BadValue` and `BufferFull` are new here because frame calls report them as values too, and `TagMismatch`, `Duplicate`
// and `TooOld` are the three kinds frame mode adds. Seal and open return one of these, or null on success.

/// <summary>A configuration or argument is out of range (epoch above 0xFFFFFF, direction not loaded, kind above 15, a label or tag length that is not allowed, a call after release).</summary>
public sealed class BadValue
{
    public string Reason { get; }

    public BadValue(string reason) => Reason = reason;
}

/// <summary>The caller's output buffer is shorter than the bytes the call needs to write.</summary>
public sealed class BufferFull
{
    public int Needed { get; }

    public BufferFull(int needed) => Needed = needed;
}

/// <summary>The tag does not match with the current key, nor with the previous key when one is loaded. Nothing was decrypted.</summary>
public sealed class TagMismatch
{
}

/// <summary>The replay window has already committed this counter. No tag was computed.</summary>
public sealed class Duplicate
{
}

/// <summary>The counter is 64 or more behind the highest committed counter of the replay window. No tag was computed.</summary>
public sealed class TooOld
{
}
