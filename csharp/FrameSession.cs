using System.Security.Cryptography;

namespace Packbin;

/// <summary>
/// Frame mode of the session (<c>pack-session.md</c> 2.0.0): sealed, authenticated frames for links that lose, reorder and
/// duplicate messages. A frame body is <c>clear ‖ ciphertext ‖ tag</c>: ChaCha20 under a key per (key, epoch, direction),
/// a nonce built from the caller's <c>msg_id</c>, the <c>kind</c>, the direction and the epoch, and a tag that is the first
/// 4, 8 or 16 bytes of HMAC-SHA256 over the nonce, the associated data, the clear part and the ciphertext. It is a separate
/// type beside the stream <see cref="PackSession"/>; the two never share state.
/// <para>
/// <see cref="Seal"/> is deterministic, stateless and safe to call from many threads. <see cref="Open"/> reads the
/// previous slot, which <see cref="SetPrevious"/> and <see cref="ClearPrevious"/> replace: call those while no open runs.
/// </para>
/// <para>
/// Limits of a managed runtime: the tag compare folds every byte with no early exit, but the JIT is not promised to keep that;
/// <see cref="Dispose"/> overwrites the key arrays this object owns, but the runtime, the platform HMAC and the garbage
/// collector may hold copies it cannot reach. Both are best effort.
/// </para>
/// </summary>
public sealed class FrameSession : IDisposable
{
    public const int KeySize = 32;
    public const int MaxBody = 255;

    private readonly int _tagLength;
    private readonly FrameDirections _directions;
    private readonly FrameKeys _current;
    private FrameKeys? _previous;
    private volatile bool _disposed;
    // long because netstandard2.0 has no ulong Interlocked.Increment.
    private long _macComputations;

    private FrameSession(int tagLength, FrameDirections directions, FrameKeys current)
    {
        _tagLength = tagLength;
        _directions = directions;
        _current = current;
    }

    public int TagLength => _tagLength;

    public uint Epoch => _current.Epoch;

    /// <summary>
    /// Derives the keys of each loaded direction from a 32-byte key and an epoch of at most 0xFFFFFF. Returns null (the
    /// contract's <see cref="BadValue"/>, as <see cref="PackSession.Load"/> returns null) for a key that is not 32 bytes, an
    /// epoch above 0xFFFFFF, a tag length that is not 4, 8 or 16, or no direction.
    /// </summary>
    public static FrameSession? Load(ReadOnlySpan<byte> key, uint epoch, FrameConfig config)
    {
        var directions = config.Directions;
        if (key.Length != KeySize || epoch > FrameCrypto.MaxEpoch || (config.TagLength != 4 && config.TagLength != 8 && config.TagLength != 16)
            || directions == FrameDirections.None || ((int)directions & ~(int)FrameDirections.All) != 0)
            return null;
        return new FrameSession(config.TagLength, directions, FrameKeys.Derive(key, epoch, directions));
    }

    /// <summary>
    /// Keeps a previous (key, epoch) that <see cref="Open"/> tries when the current key's tag does not match: the key just
    /// replaced, for frames sealed before the change. Seal never uses it. False (<see cref="BadValue"/>) for a key that is not
    /// 32 bytes, an epoch above 0xFFFFFF or a released session. A frame that opens under it commits into the same replay
    /// window, so keep it only for the changeover and call <see cref="ClearPrevious"/> when that ends.
    /// </summary>
    public bool SetPrevious(ReadOnlySpan<byte> key, uint epoch)
    {
        if (_disposed || key.Length != KeySize || epoch > FrameCrypto.MaxEpoch)
            return false;
        var replaced = _previous;
        _previous = FrameKeys.Derive(key, epoch, _directions);
        replaced?.Wipe();
        return true;
    }

    /// <summary>Drops the previous (key, epoch) and overwrites its keys.</summary>
    public void ClearPrevious()
    {
        var replaced = _previous;
        _previous = null;
        replaced?.Wipe();
    }

    /// <summary>
    /// Seals <c>clear ‖ plain</c> into <paramref name="output"/> as <c>clear ‖ ciphertext ‖ tag</c> and gives the body length in
    /// <paramref name="written"/>. The same inputs give the same bytes; the session does not change and the previous key is not
    /// used. Returns null on success. A direction not loaded, a <c>kind</c> above 15, a default <see cref="MsgContext"/> or a
    /// released session is <see cref="BadValue"/>; <paramref name="ad"/> above 255 bytes, or <c>clear + plain + tag</c> above 255,
    /// is <see cref="TooLong"/>; an <paramref name="output"/> shorter than the body is <see cref="BufferFull"/>. On any refusal
    /// nothing is written, and on a failure after writing started the written bytes are zeroed.
    /// <para>
    /// <b>For one (key, epoch, direction), never seal two different messages with the same <c>msg_id</c>.</b> Reuse breaks the
    /// confidentiality of both messages, and the library cannot check it (see <see cref="MsgContext"/>). A new epoch derives new
    /// keys and nonces.
    /// </para>
    /// </summary>
    public object? Seal(FrameDirection direction, MsgContext message, ReadOnlySpan<byte> ad, ReadOnlySpan<byte> clear,
        ReadOnlySpan<byte> plain, Span<byte> output, out int written)
    {
        written = 0;
        if (!CallAllowed(direction, message))
            return new BadValue("direction not loaded, kind above 15, no msg_id or released session");
        if (ad.Length > MaxBody)
            return new TooLong(ad.Length, MaxBody);
        var length = (long)clear.Length + plain.Length + _tagLength;
        if (length > MaxBody)
            return new TooLong((int)Math.Min(length, int.MaxValue), MaxBody);
        var bodyLength = (int)length;
        if (output.Length < bodyLength)
            return new BufferFull(bodyLength);

        var keys = _current;
        Span<byte> nonce = stackalloc byte[12];
        WriteNonce(message, direction, keys.Epoch, nonce);
        var done = false;
        try
        {
            clear.CopyTo(output);
            plain.CopyTo(output.Slice(clear.Length));
            var cipher = output.Slice(clear.Length, plain.Length);
            SessionPad.Xor(keys.Enc(direction), nonce, 0, cipher);
            Span<byte> full = stackalloc byte[FrameCrypto.HashSize];
            Tag(keys.Mac(direction), nonce, ad, output.Slice(0, clear.Length), cipher, full);
            full.Slice(0, _tagLength).CopyTo(output.Slice(clear.Length + plain.Length));
            done = true;
        }
        finally
        {
            if (!done)
                Compat.Zero(output.Slice(0, bodyLength));
        }
        written = bodyLength;
        return null;
    }

    /// <summary>
    /// Opens <paramref name="body"/> (<c>clear ‖ ciphertext ‖ tag</c>, the first <paramref name="clearLength"/> bytes clear) in
    /// the contract's order: argument checks, the replay window (when given, with the message's counter: <see cref="Duplicate"/>
    /// or <see cref="TooOld"/> before any hashing), the tag with the current key and then once with the previous key
    /// (<see cref="TagMismatch"/>), decryption into <paramref name="plain"/>, and only then the window commit. Returns null on
    /// success. <paramref name="plain"/> and the window are untouched unless the result is null.
    /// A direction not loaded, a <c>kind</c> above 15, a negative <paramref name="clearLength"/> or a released session is
    /// <see cref="BadValue"/>; <paramref name="ad"/>, <paramref name="body"/> or <paramref name="clearLength"/> above 255 is
    /// <see cref="TooLong"/> (before any hashing); a body shorter than <c>clearLength + tag</c> is <see cref="ShortPacket"/>; a
    /// <paramref name="plain"/> shorter than the plaintext is <see cref="BufferFull"/>.
    /// <para>
    /// The counter must come from bytes the tag covers, never from an unauthenticated wire field: it is not part of the tag.
    /// </para>
    /// </summary>
    public object? Open(FrameDirection direction, MsgContext message, ReadOnlySpan<byte> ad, ReadOnlySpan<byte> body,
        int clearLength, Span<byte> plain, out FrameOpened opened, ReplayWindow? window = null, ulong counter = 0)
    {
        opened = default;
        if (!CallAllowed(direction, message) || clearLength < 0)
            return new BadValue("direction not loaded, kind above 15, no msg_id, negative clear length or released session");
        if (ad.Length > MaxBody)
            return new TooLong(ad.Length, MaxBody);
        if (body.Length > MaxBody)
            return new TooLong(body.Length, MaxBody);
        if (clearLength > MaxBody)
            return new TooLong(clearLength, MaxBody);
        var framing = clearLength + _tagLength;
        if (body.Length < framing)
            return new ShortPacket("body", framing, body.Length);
        var plainLength = body.Length - framing;
        if (plain.Length < plainLength)
            return new BufferFull(plainLength);

        if (window is not null)
        {
            var freshness = window.Check(counter);
            if (freshness == Freshness.Duplicate)
                return new Duplicate();
            if (freshness == Freshness.TooOld)
                return new TooOld();
        }

        var clear = body.Slice(0, clearLength);
        var cipher = body.Slice(clearLength, plainLength);
        var tag = body.Slice(clearLength + plainLength);
        Span<byte> nonce = stackalloc byte[12];
        var keys = _current;
        var slot = FrameSlot.Current;
        if (!Matches(keys, direction, message, ad, clear, cipher, tag, nonce))
        {
            keys = _previous;
            if (keys is null || !Matches(keys, direction, message, ad, clear, cipher, tag, nonce))
                return new TagMismatch();
            slot = FrameSlot.Previous;
        }

        var text = plain.Slice(0, plainLength);
        cipher.CopyTo(text);
        SessionPad.Xor(keys.Enc(direction), nonce, 0, text);
        window?.Commit(counter);
        opened = new FrameOpened(slot, clearLength, plainLength);
        return null;
    }

    /// <summary>Overwrites the keys of both slots (best effort, see the type remarks). Every later call is refused as <see cref="BadValue"/>.</summary>
    public void Dispose()
    {
        _disposed = true;
        _current.Wipe();
        _previous?.Wipe();
    }

    // Test access: the key arrays this object owns (so a test can keep them and read them after Dispose), and the count of
    // HMAC computations seal and open ran.
    internal IReadOnlyList<byte[]> KeyArrays() => _current.Arrays().Concat(_previous?.Arrays() ?? []).ToList();

    internal FrameKeys CurrentKeys => _current;

    internal long MacComputations => Interlocked.Read(ref _macComputations);

    private bool CallAllowed(FrameDirection direction, MsgContext message) =>
        !_disposed && message.IsValid && message.Kind >= 0 && message.Kind <= 15
        && direction >= FrameDirection.Up && direction <= FrameDirection.Group
        && ((int)_directions & (1 << ((int)direction - 1))) != 0;

    // msg_id (8) ‖ ((kind << 4) | direction) (1) ‖ epoch as 24 bits (3).
    private static void WriteNonce(MsgContext message, FrameDirection direction, uint epoch, Span<byte> nonce)
    {
        var id = message.IdBits;
        for (var i = 0; i < 8; i++)
            nonce[i] = (byte)(id >> (8 * i));
        nonce[8] = (byte)((message.Kind << 4) | (int)direction);
        nonce[9] = (byte)epoch;
        nonce[10] = (byte)(epoch >> 8);
        nonce[11] = (byte)(epoch >> 16);
    }

    // The full HMAC over M = N ‖ len(ad) ‖ ad ‖ len(clear) ‖ clear ‖ ciphertext, hashed piece by piece with no joined copy.
    private void Tag(byte[] macKey, ReadOnlySpan<byte> nonce, ReadOnlySpan<byte> ad, ReadOnlySpan<byte> clear,
        ReadOnlySpan<byte> cipher, Span<byte> full)
    {
        Interlocked.Increment(ref _macComputations);
        var hash = FrameCrypto.StartHmac(macKey);
        try
        {
            FrameCrypto.Append(hash, nonce);
            Span<byte> length = stackalloc byte[1];
            length[0] = (byte)ad.Length;
            FrameCrypto.Append(hash, length);
            FrameCrypto.Append(hash, ad);
            length[0] = (byte)clear.Length;
            FrameCrypto.Append(hash, length);
            FrameCrypto.Append(hash, clear);
            FrameCrypto.Append(hash, cipher);
            FrameCrypto.Finish(hash, full);
        }
        finally
        {
            hash.Dispose();
        }
    }

    private bool Matches(FrameKeys keys, FrameDirection direction, MsgContext message, ReadOnlySpan<byte> ad,
        ReadOnlySpan<byte> clear, ReadOnlySpan<byte> cipher, ReadOnlySpan<byte> tag, Span<byte> nonce)
    {
        WriteNonce(message, direction, keys.Epoch, nonce);
        Span<byte> full = stackalloc byte[FrameCrypto.HashSize];
        Tag(keys.Mac(direction), nonce, ad, clear, cipher, full);
        var equal = FrameCrypto.FixedEquals(full.Slice(0, tag.Length), tag);
        Compat.Zero(full);
        return equal;
    }
}
