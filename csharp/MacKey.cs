using System.Security.Cryptography;

namespace Packbin;

/// <summary>
/// The MAC-only call of frame mode: a tag without encryption, for a per-hop network check and for key fingerprints.
/// <c>K_label = HKDF(key, "packbin-frame" ‖ epoch, 0x00 ‖ label)</c> and <c>tag = first n bytes of HMAC(K_label, message)</c>,
/// with <c>n</c> of 4, 8, 16 or 32. The message is passed in parts and hashed piece by piece with no joined copy; the tag does
/// not depend on how it is split.
/// <para>
/// This object holds the 32-byte <c>K_label</c> (the platform HMAC keeps its own pad state, which it does not expose), and
/// <see cref="Dispose"/> overwrites it, best effort: the runtime may have copied it. Verification compares every byte with no
/// early exit, best effort on a managed runtime.
/// </para>
/// </summary>
public sealed class MacKey : IDisposable
{
    private readonly byte[] _key;
    private volatile bool _disposed;

    private MacKey(byte[] key, uint epoch)
    {
        _key = key;
        Epoch = epoch;
    }

    public uint Epoch { get; }

    /// <summary>The key of a label. Returns null (<see cref="BadValue"/>) for a key that is not 32 bytes, an epoch above 0xFFFFFF or a label that is not 1 to 32 bytes.</summary>
    public static MacKey? Derive(ReadOnlySpan<byte> key, uint epoch, ReadOnlySpan<byte> label)
    {
        if (key.Length != FrameSession.KeySize || epoch > FrameCrypto.MaxEpoch || label.Length < 1 || label.Length > 32)
            return null;
        Span<byte> salt = stackalloc byte[17];
        FrameCrypto.Salt(epoch, salt);
        Span<byte> info = stackalloc byte[33];
        info[0] = 0;
        label.CopyTo(info.Slice(1));
        var derived = new byte[32];
        Compat.HkdfSha256(key, derived, salt, info.Slice(0, label.Length + 1));
        return new MacKey(derived, epoch);
    }

    /// <summary>Writes the first <c>tag.Length</c> bytes of the HMAC of the message. A tag length other than 4, 8, 16 or 32, or a released key, is <see cref="BadValue"/> and nothing is written. Returns null on success.</summary>
    public object? Tag(ReadOnlySpan<byte> message, Span<byte> tag)
    {
        if (!TagLengthAllowed(tag.Length) || _disposed)
            return new BadValue("tag length not 4, 8, 16 or 32, or released key");
        Span<byte> full = stackalloc byte[FrameCrypto.HashSize];
        FrameCrypto.Hmac(_key, message, full);
        full.Slice(0, tag.Length).CopyTo(tag);
        Compat.Zero(full);
        return null;
    }

    /// <summary>As <see cref="Tag(ReadOnlySpan{byte}, Span{byte})"/> for a message given in parts.</summary>
    public object? Tag(ReadOnlySpan<ReadOnlyMemory<byte>> parts, Span<byte> tag)
    {
        if (!TagLengthAllowed(tag.Length) || _disposed)
            return new BadValue("tag length not 4, 8, 16 or 32, or released key");
        Span<byte> full = stackalloc byte[FrameCrypto.HashSize];
        Compute(parts, full);
        full.Slice(0, tag.Length).CopyTo(tag);
        Compat.Zero(full);
        return null;
    }

    /// <summary>True when <paramref name="tag"/> (4, 8, 16 or 32 bytes) is the tag of the message. False for any other length and for a released key.</summary>
    public bool Verify(ReadOnlySpan<byte> message, ReadOnlySpan<byte> tag)
    {
        if (!TagLengthAllowed(tag.Length) || _disposed)
            return false;
        Span<byte> full = stackalloc byte[FrameCrypto.HashSize];
        FrameCrypto.Hmac(_key, message, full);
        var equal = FrameCrypto.FixedEquals(full.Slice(0, tag.Length), tag);
        Compat.Zero(full);
        return equal;
    }

    /// <summary>As <see cref="Verify(ReadOnlySpan{byte}, ReadOnlySpan{byte})"/> for a message given in parts.</summary>
    public bool Verify(ReadOnlySpan<ReadOnlyMemory<byte>> parts, ReadOnlySpan<byte> tag)
    {
        if (!TagLengthAllowed(tag.Length) || _disposed)
            return false;
        Span<byte> full = stackalloc byte[FrameCrypto.HashSize];
        Compute(parts, full);
        var equal = FrameCrypto.FixedEquals(full.Slice(0, tag.Length), tag);
        Compat.Zero(full);
        return equal;
    }

    /// <summary>Overwrites the key (best effort). Every later call is refused.</summary>
    public void Dispose()
    {
        _disposed = true;
        Compat.Zero(_key);
    }

    // Test access: the key array, so a test can keep it and read it after Dispose.
    internal byte[] KeyArray => _key;

    private static bool TagLengthAllowed(int length) => length == 4 || length == 8 || length == 16 || length == 32;

    private void Compute(ReadOnlySpan<ReadOnlyMemory<byte>> parts, Span<byte> full)
    {
        var hash = FrameCrypto.StartHmac(_key);
        try
        {
            foreach (var part in parts)
                FrameCrypto.Append(hash, part.Span);
            FrameCrypto.Finish(hash, full);
        }
        finally
        {
            hash.Dispose();
        }
    }
}
