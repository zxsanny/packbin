using System.Security.Cryptography;

namespace Packbin;

public sealed class PackSession
{
    public const int SeedSize = 32;
    public const int NonceSize = 16;

    private byte[]? _seed;
    private byte[]? _send;
    private byte[]? _recv;
    private ulong _sendCount;
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
        return Start(RandomNumberGenerator.GetBytes(NonceSize));
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
        SessionPad.Xor(_send, _sendCount, clear);
        _sendCount++;
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
        HKDF.DeriveKey(HashAlgorithmName.SHA256, _seed, both, nonce, "packbin"u8);
        var first = both[..SeedSize].ToArray();
        var second = both[SeedSize..].ToArray();
        _send = initiator ? first : second;
        _recv = initiator ? second : first;
        CryptographicOperations.ZeroMemory(both);
        CryptographicOperations.ZeroMemory(_seed);
        _seed = null;
        return true;
    }
}
