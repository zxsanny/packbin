using System.Buffers.Binary;
using System.Security.Cryptography;

namespace Packbin;

internal static class SessionPad
{
    internal static void Xor(ReadOnlySpan<byte> key, ulong packet, Span<byte> data)
    {
        Span<byte> nonce = stackalloc byte[12];
        BinaryPrimitives.WriteUInt64LittleEndian(nonce, packet);
        Xor(key, nonce, 0, data);
    }

    internal static void Xor(ReadOnlySpan<byte> key, ReadOnlySpan<byte> nonce, uint counter, Span<byte> data)
    {
        Span<byte> block = stackalloc byte[64];
        var offset = 0;
        while (offset < data.Length)
        {
            Block(key, nonce, counter, block);
            var n = Math.Min(64, data.Length - offset);
            for (var i = 0; i < n; i++)
                data[offset + i] ^= block[i];
            offset += n;
            counter++;
        }
    }

    private static void Block(ReadOnlySpan<byte> key, ReadOnlySpan<byte> nonce, uint counter, Span<byte> output)
    {
        Span<uint> state = stackalloc uint[16];
        state[0] = 0x61707865;
        state[1] = 0x3320646e;
        state[2] = 0x79622d32;
        state[3] = 0x6b206574;
        for (var i = 0; i < 8; i++)
            state[4 + i] = BinaryPrimitives.ReadUInt32LittleEndian(key.Slice(i * 4));
        state[12] = counter;
        state[13] = BinaryPrimitives.ReadUInt32LittleEndian(nonce);
        state[14] = BinaryPrimitives.ReadUInt32LittleEndian(nonce.Slice(4));
        state[15] = BinaryPrimitives.ReadUInt32LittleEndian(nonce.Slice(8));

        Span<uint> work = stackalloc uint[16];
        state.CopyTo(work);
        for (var i = 0; i < 10; i++)
        {
            Quarter(work, 0, 4, 8, 12);
            Quarter(work, 1, 5, 9, 13);
            Quarter(work, 2, 6, 10, 14);
            Quarter(work, 3, 7, 11, 15);
            Quarter(work, 0, 5, 10, 15);
            Quarter(work, 1, 6, 11, 12);
            Quarter(work, 2, 7, 8, 13);
            Quarter(work, 3, 4, 9, 14);
        }

        for (var i = 0; i < 16; i++)
        {
            unchecked
            {
                work[i] += state[i];
            }
            BinaryPrimitives.WriteUInt32LittleEndian(output.Slice(i * 4), work[i]);
        }
    }

    private static void Quarter(Span<uint> w, int a, int b, int c, int d)
    {
        unchecked
        {
            w[a] += w[b];
            w[d] ^= w[a];
            w[d] = Rot(w[d], 16);
            w[c] += w[d];
            w[b] ^= w[c];
            w[b] = Rot(w[b], 12);
            w[a] += w[b];
            w[d] ^= w[a];
            w[d] = Rot(w[d], 8);
            w[c] += w[d];
            w[b] ^= w[c];
            w[b] = Rot(w[b], 7);
        }
    }

    private static uint Rot(uint value, int bits) => (value << bits) | (value >> (32 - bits));
}
