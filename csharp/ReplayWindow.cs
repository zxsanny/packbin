namespace Packbin;

/// <summary>
/// The replay window of frame mode: the highest counter a sender's frames reached (<see cref="Top"/>) and which of the 64 counters
/// up to it were committed (<see cref="Bits"/>: bit i set means counter <c>Top - i</c> was committed; 0 is an empty window).
/// The caller owns one per sender and passes it, with the message's counter, to <see cref="FrameSession.Open"/>. Not thread safe.
/// <para>
/// The counter must come from bytes the tag covers (for example the <c>msg_id</c> or the associated data), never from an
/// unauthenticated field of the wire: it is an argument of open and not part of the tag.
/// </para>
/// </summary>
public sealed class ReplayWindow
{
    public const int Size = 64;

    public ReplayWindow()
    {
    }

    /// <summary>A window restored from stored state. <paramref name="bits"/> 0 is empty whatever <paramref name="top"/> is: a caller validates stored state (bit 0 set when the bits are not 0).</summary>
    public ReplayWindow(ulong top, ulong bits)
    {
        Top = top;
        Bits = bits;
    }

    public ulong Top { get; private set; }

    public ulong Bits { get; private set; }

    /// <summary>What the window says about <paramref name="counter"/>. Never changes the state.</summary>
    public Freshness Check(ulong counter)
    {
        if (Bits == 0 || counter > Top)
            return Freshness.Fresh;
        var behind = Top - counter;
        if (behind >= Size)
            return Freshness.TooOld;
        return ((Bits >> (int)behind) & 1) == 1 ? Freshness.Duplicate : Freshness.Fresh;
    }

    /// <summary>Records <paramref name="counter"/>. Open calls this only after a frame opened; a counter 64 or more behind the highest is ignored.</summary>
    public void Commit(ulong counter)
    {
        if (Bits == 0)
        {
            Top = counter;
            Bits = 1;
        }
        else if (counter > Top)
        {
            var shift = counter - Top;
            Bits = (shift >= Size ? 0 : Bits << (int)shift) | 1;
            Top = counter;
        }
        else
        {
            var behind = Top - counter;
            if (behind < Size)
                Bits |= 1UL << (int)behind;
        }
    }
}
