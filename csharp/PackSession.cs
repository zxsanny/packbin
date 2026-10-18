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
        var clear = BinaryPacker.PackClear(scheme, value);
        Ecc.RequireFits(clear.Length, scheme.Parity);
        // Each call takes its own counter, so concurrent packs never reuse a keystream.
        SessionPad.Xor(_send, (ulong)(Interlocked.Increment(ref _sendCount) - 1), clear);
        // The code covers the padded bytes.
        return Ecc.Protect(clear, scheme.Parity);
    }

    public object? Unpack(ReadOnlySpan<byte> bytes, params SchemeHandler[] handlers) =>
        Unpack(bytes, 0, out _, handlers);

    // With parity bytes the payload is repaired (up to `limit` wrong bytes) before the pad is removed. The receive
    // index advances for every payload, a refused one included.
    public object? Unpack(ReadOnlySpan<byte> bytes, int limit, out int repaired, params SchemeHandler[] handlers)
    {
        repaired = 0;
        // A duplicate type number is refused before any byte is read and before the receive index advances.
        BinaryPacker.RequireDistinct(handlers);
        if (_recv is null)
            return new ShortPacket("", 1, 0);
        var parity = Ecc.SharedParity(handlers, limit);
        var counter = _recvCount;
        _recvCount++;
        if (parity == 0)
        {
            var clear = new byte[bytes.Length];
            bytes.CopyTo(clear);
            SessionPad.Xor(_recv, counter, clear);
            return BinaryPacker.Unpack(clear, handlers);
        }
        var error = Ecc.Repair(bytes, parity, limit, out var word, out repaired);
        if (error is not null)
            return error;
        var padded = word.AsSpan(0, word.Length - parity);
        SessionPad.Xor(_recv, counter, padded);
        return BinaryPacker.Dispatch(padded, handlers);
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
