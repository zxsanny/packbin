using System.Security.Cryptography;
using System.Text;
#if NETSTANDARD2_0
using System.Runtime.CompilerServices;
using System.Runtime.InteropServices;
#else
using System.Text.Unicode;
#endif

namespace Packbin;

// The .NET 10 APIs the netstandard2.0 build lacks. net10.0 calls the framework; netstandard2.0 does the same work by hand.
internal static class Compat
{
#if NETSTANDARD2_0
    private static readonly UTF8Encoding StrictUtf8 = new(encoderShouldEmitUTF8Identifier: false, throwOnInvalidBytes: true);
#endif

    // HKDF-SHA256 (RFC 5869) filling all of `output`.
    internal static void HkdfSha256(ReadOnlySpan<byte> ikm, Span<byte> output, ReadOnlySpan<byte> salt, ReadOnlySpan<byte> info)
    {
#if NETSTANDARD2_0
        var key = ikm.ToArray();
        byte[] prk;
        using (var extract = new HMACSHA256(salt.ToArray()))
            prk = extract.ComputeHash(key);
        Zero(key);
        using var expand = new HMACSHA256(prk);
        Zero(prk);
        var previous = Array.Empty<byte>();
        for (var counter = 1; !output.IsEmpty; counter++)
        {
            var input = new byte[previous.Length + info.Length + 1];
            previous.CopyTo(input, 0);
            info.CopyTo(input.AsSpan(previous.Length));
            input[input.Length - 1] = (byte)counter;
            Zero(previous);
            previous = expand.ComputeHash(input);
            Zero(input);
            var n = Math.Min(previous.Length, output.Length);
            previous.AsSpan(0, n).CopyTo(output);
            output = output.Slice(n);
        }
        Zero(previous);
#else
        HKDF.DeriveKey(HashAlgorithmName.SHA256, ikm, output, salt, info);
#endif
    }

    // Strict UTF-8: an overlong form, an encoded surrogate, a code point above U+10FFFF or a cut sequence is refused.
    internal static bool TryUtf8(ReadOnlySpan<byte> raw, out string text)
    {
#if NETSTANDARD2_0
        try
        {
            text = StrictUtf8.GetString(raw.ToArray());
            return true;
        }
        catch (DecoderFallbackException)
        {
            text = "";
            return false;
        }
#else
        text = "";
        if (!Utf8.IsValid(raw))
            return false;
        text = Encoding.UTF8.GetString(raw);
        return true;
#endif
    }

#if NETSTANDARD2_0
    // As CryptographicOperations.ZeroMemory: kept from the optimizer so the clear is not dropped.
    [MethodImpl(MethodImplOptions.NoInlining | MethodImplOptions.NoOptimization)]
    internal static void Zero(Span<byte> buffer) => buffer.Clear();

    internal static int SingleToInt32Bits(float value)
    {
        Span<float> one = stackalloc float[] { value };
        return MemoryMarshal.Cast<float, int>(one)[0];
    }

    internal static float Int32BitsToSingle(int value)
    {
        Span<int> one = stackalloc int[] { value };
        return MemoryMarshal.Cast<int, float>(one)[0];
    }

    internal static bool TryAdd<TKey, TValue>(this Dictionary<TKey, TValue> dictionary, TKey key, TValue value)
        where TKey : notnull
    {
        if (dictionary.ContainsKey(key))
            return false;
        dictionary.Add(key, value);
        return true;
    }
#else
    internal static void Zero(Span<byte> buffer) => CryptographicOperations.ZeroMemory(buffer);

    internal static int SingleToInt32Bits(float value) => BitConverter.SingleToInt32Bits(value);

    internal static float Int32BitsToSingle(int value) => BitConverter.Int32BitsToSingle(value);
#endif
}
