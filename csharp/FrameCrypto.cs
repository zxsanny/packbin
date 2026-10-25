using System.Runtime.CompilerServices;
using System.Security.Cryptography;

namespace Packbin;

// The platform HMAC-SHA256 and the tag compare of frame mode.
internal static class FrameCrypto
{
    internal const int MaxEpoch = 0xFFFFFF;
    internal const int HashSize = 32;

    private static readonly byte[] SaltLabel = "packbin-frame"u8.ToArray();

    // "packbin-frame" followed by the epoch as a 32-bit little-endian integer (17 bytes).
    internal static void Salt(uint epoch, Span<byte> salt)
    {
        SaltLabel.CopyTo(salt);
        salt[13] = (byte)epoch;
        salt[14] = (byte)(epoch >> 8);
        salt[15] = (byte)(epoch >> 16);
        salt[16] = (byte)(epoch >> 24);
    }

    internal static IncrementalHash StartHmac(byte[] key) => IncrementalHash.CreateHMAC(HashAlgorithmName.SHA256, key);

    internal static void Append(IncrementalHash hash, ReadOnlySpan<byte> data)
    {
#if NETSTANDARD2_0
        if (!data.IsEmpty)
            hash.AppendData(data.ToArray());
#else
        hash.AppendData(data);
#endif
    }

    // Writes the 32-byte HMAC and ends the hash.
    internal static void Finish(IncrementalHash hash, Span<byte> full)
    {
        var bytes = hash.GetHashAndReset();
        bytes.CopyTo(full);
        Compat.Zero(bytes);
        hash.Dispose();
    }

    // HMAC-SHA256 of one message.
    internal static void Hmac(byte[] key, ReadOnlySpan<byte> data, Span<byte> full)
    {
        var hash = StartHmac(key);
        Append(hash, data);
        Finish(hash, full);
    }

    // The tag compare: folds every byte of both spans into one value and decides only at the end. A different length is
    // public (the tag length is fixed per key), so it is the one early exit. NoOptimization keeps the JIT from turning the
    // fold into a loop that stops at the first difference; the guarantee is best effort on a managed runtime.
    [MethodImpl(MethodImplOptions.NoInlining | MethodImplOptions.NoOptimization)]
    internal static bool FixedEquals(ReadOnlySpan<byte> left, ReadOnlySpan<byte> right)
    {
        if (left.Length != right.Length)
            return false;
        var difference = 0;
        for (var i = 0; i < left.Length; i++)
            difference |= left[i] ^ right[i];
        return difference == 0;
    }
}
