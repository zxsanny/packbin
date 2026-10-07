using System.Security.Cryptography;

namespace Packbin;

public sealed class PackSession
{
    public const int SeedSize = 32;
    public const int NonceSize = 16;

    private byte[]? _seed;
    private byte[]? _send;
    private byte[]? _recv;
    // long because netstandard2.0 has no ulong Interlocked.Increment; cast back, the bits count the same.
    private long _sendCount;
    private ulong _recvCount;

    private PackSession(byte[] seed) => _seed = seed;

    public static PackSession? Load(ReadOnlySpan<byte> seed)
    {
        if (seed.Length != SeedSize)
            return null;
        return new PackSession(seed.ToArray());
    }

    public byte[]? Start()
    {
        if (_send is not null || _seed is null)
            return null;
        var nonce = new byte[NonceSize];
        using (var random = RandomNumberGenerator.Create())
            random.GetBytes(nonce);
        return Start(nonce);
    }

    public byte[]? Start(ReadOnlySpan<byte> nonce)
    {
        if (!Open(nonce, initiator: true))
            return null;
        return nonce.ToArray();
    }

    public bool Join(ReadOnlySpan<byte> nonce) => Open(nonce, initiator: false);

    public byte[]? Pack<T>(Scheme<T> scheme, T? value) where T : class, new()
    {
        if (_send is null)
            return null;
        var clear = BinaryPacker.Pack(scheme, value);
        // Each call takes its own counter, so concurrent packs never reuse a keystream.
        SessionPad.Xor(_send, (ulong)(Interlocked.Increment(ref _sendCount) - 1), clear);
        return clear;
    }

    public object? Unpack(ReadOnlySpan<byte> bytes, params SchemeHandler[] handlers)
    {
        if (_recv is null)
            return new ShortPacket("", 1, 0);
        var clear = new byte[bytes.Length];
        bytes.CopyTo(clear);
        SessionPad.Xor(_recv, _recvCount, clear);
        _recvCount++;
        return BinaryPacker.Unpack(clear, handlers);
    }

    private bool Open(ReadOnlySpan<byte> nonce, bool initiator)
    {
        if (_seed is null || _send is not null || nonce.Length != NonceSize)
            return false;
        Span<byte> both = stackalloc byte[SeedSize * 2];
        Compat.HkdfSha256(_seed, both, nonce, "packbin"u8);
        var first = both.Slice(0, SeedSize).ToArray();
        var second = both.Slice(SeedSize).ToArray();
        _send = initiator ? first : second;
        _recv = initiator ? second : first;
        Compat.Zero(both);
        Compat.Zero(_seed);
        _seed = null;
        return true;
    }
}
