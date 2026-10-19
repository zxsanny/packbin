namespace Packbin;

public sealed class Uncorrectable
{
}

public sealed class TooLong
{
    public int Length { get; }
    public int Limit { get; }

    public TooLong(int length, int limit)
    {
        Length = length;
        Limit = limit;
    }
}

internal static partial class Ecc
{
    // Checks the received bytes of a protected message and repairs up to `limit` wrong bytes. Returns the error value, or
    // null with `word` holding the repaired bytes (the clear message is its first word.Length - parity bytes) and
    // `repaired` the number of bytes changed. Never throws: the work is at most about 3 x 255 x 32 field operations.
    internal static object? Repair(ReadOnlySpan<byte> received, int parity, int limit, out byte[] word, out int repaired)
    {
        word = [];
        repaired = 0;
        if (received.Length > MaxBlock)
            return new TooLong(received.Length, MaxBlock);
        if (received.Length < parity)
            return new ShortPacket("parity", parity, received.Length);
        word = received.ToArray();
        var syndromes = Syndromes(word, parity);
        if (!AnyNonZero(syndromes))
            return null;
        if (limit == 0)
            return new Uncorrectable();
        var count = Correct(word, parity, limit, syndromes);
        if (count == 0)
            return new Uncorrectable();
        repaired = count;
        return null;
    }

    private static byte[] Syndromes(byte[] word, int parity)
    {
        var syndromes = new byte[parity];
        var length = word.Length - parity;
        for (var i = 0; i < parity; i++)
        {
            int s = length;
            foreach (var b in word)
                s = (s == 0 ? 0 : Exp[Log[s] + i]) ^ b;
            syndromes[i] = (byte)s;
        }
        return syndromes;
    }

    private static bool AnyNonZero(byte[] values)
    {
        foreach (var v in values)
        {
            if (v != 0)
                return true;
        }
        return false;
    }

    // The number of bytes repaired, or 0 when the damage is beyond the limit (the word is left changed only on success).
    private static int Correct(byte[] word, int parity, int limit, byte[] syndromes)
    {
        var lambda = Locator(syndromes, parity);
        var degree = lambda.Length - 1;
        if (degree == 0 || degree > limit)
            return 0;
        var size = word.Length;
        var positions = new int[degree];
        var found = 0;
        for (var p = 0; p < size; p++)
        {
            if (Evaluate(lambda, Exp[(255 - (size - 1 - p)) % 255]) != 0)
                continue;
            if (found == degree)
                return 0;
            positions[found++] = p;
        }
        if (found != degree)
            return 0;

        var omega = new byte[parity];
        for (var i = 0; i < parity; i++)
        {
            for (var j = 0; j < lambda.Length && i + j < parity; j++)
                omega[i + j] ^= Mul(syndromes[i], lambda[j]);
        }
        var derivative = new byte[degree];
        for (var i = 1; i < lambda.Length; i += 2)
            derivative[i - 1] = lambda[i];

        var fixedWord = (byte[])word.Clone();
        foreach (var p in positions)
        {
            var x = Exp[(size - 1 - p) % 255];
            var xi = Inverse(x);
            var denominator = Evaluate(derivative, xi);
            if (denominator == 0)
                return 0;
            fixedWord[p] ^= Mul(x, Mul(Evaluate(omega, xi), Inverse(denominator)));
        }
        if (AnyNonZero(Syndromes(fixedWord, parity)))
            return 0;
        Buffer.BlockCopy(fixedWord, 0, word, 0, size);
        return degree;
    }

    // Berlekamp-Massey. The error locator, lowest degree first, without trailing zeros.
    private static byte[] Locator(byte[] syndromes, int parity)
    {
        var lambda = new byte[2 * parity + 2];
        var previous = new byte[2 * parity + 2];
        lambda[0] = 1;
        previous[0] = 1;
        var length = 0;
        var shift = 1;
        var scale = 1;
        for (var r = 0; r < parity; r++)
        {
            int d = syndromes[r];
            for (var i = 1; i <= length; i++)
                d ^= Mul(lambda[i], syndromes[r - i]);
            if (d == 0)
            {
                shift++;
                continue;
            }
            var saved = (byte[])lambda.Clone();
            var coefficient = Mul(d, Inverse(scale));
            for (var i = 0; i + shift < lambda.Length; i++)
                lambda[i + shift] ^= Mul(coefficient, previous[i]);
            if (2 * length <= r)
            {
                length = r + 1 - length;
                previous = saved;
                scale = d;
                shift = 1;
            }
            else
            {
                shift++;
            }
        }
        var degree = lambda.Length - 1;
        while (degree > 0 && lambda[degree] == 0)
            degree--;
        var trimmed = new byte[degree + 1];
        Buffer.BlockCopy(lambda, 0, trimmed, 0, degree + 1);
        return trimmed;
    }

    // Lowest degree first.
    private static byte Evaluate(byte[] polynomial, int x)
    {
        byte y = 0;
        for (var i = polynomial.Length - 1; i >= 0; i--)
            y = (byte)(Mul(y, x) ^ polynomial[i]);
        return y;
    }
}
