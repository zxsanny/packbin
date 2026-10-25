namespace Packbin;

// The keys of one (key, epoch) for the loaded directions: K_enc(d) and K_mac(d), derived once at load.
internal sealed class FrameKeys
{
    private readonly byte[]?[] _enc = new byte[]?[3];
    private readonly byte[]?[] _mac = new byte[]?[3];

    private FrameKeys(uint epoch) => Epoch = epoch;

    internal uint Epoch { get; }

    internal byte[] Enc(FrameDirection direction) => _enc[(int)direction - 1]!;

    internal byte[] Mac(FrameDirection direction) => _mac[(int)direction - 1]!;

    internal static FrameKeys Derive(ReadOnlySpan<byte> key, uint epoch, FrameDirections directions)
    {
        var keys = new FrameKeys(epoch);
        Span<byte> salt = stackalloc byte[17];
        FrameCrypto.Salt(epoch, salt);
        Span<byte> info = stackalloc byte[4];
        for (var d = 1; d <= 3; d++)
        {
            if (((int)directions & (1 << (d - 1))) == 0)
                continue;
            info[0] = (byte)d;
            keys._enc[d - 1] = Expand(key, salt, info, "enc"u8);
            keys._mac[d - 1] = Expand(key, salt, info, "mac"u8);
        }
        return keys;
    }

    private static byte[] Expand(ReadOnlySpan<byte> key, ReadOnlySpan<byte> salt, Span<byte> info, ReadOnlySpan<byte> use)
    {
        use.CopyTo(info.Slice(1));
        var output = new byte[32];
        Compat.HkdfSha256(key, output, salt, info);
        return output;
    }

    // Overwrites every key array (best effort: the runtime may have copied a key before this ran).
    internal void Wipe()
    {
        foreach (var array in Arrays())
            Compat.Zero(array);
    }

    internal IEnumerable<byte[]> Arrays()
    {
        foreach (var array in _enc)
            if (array is not null)
                yield return array;
        foreach (var array in _mac)
            if (array is not null)
                yield return array;
    }
}
