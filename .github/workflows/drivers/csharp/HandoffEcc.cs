using Packbin;

// The message ECC commands of Handoff (AZ-2689; contract message-ecc.md).
//
//   ecc-protect <n> <clear hex>   prints the clear position message packed again with n parity bytes, or the error kind
//   ecc-repair <n> <t> <hex>      prints the position message repaired (hex, then the repaired count), or the error kind
//   ecc-batch <file>              one line per line of the file: `protect <n> <hex>` or `repair <n> <t> <hex>`
//
// "-" is the empty buffer. The kind names are the ones of fixtures/ecc/vectors.txt (uncorrectable, short, too_long,
// bad_parity, bad_limit) plus trailing, type_mismatch and unpack_failed for the walk of the unprotected fields.
static class HandoffEcc
{
    static byte[] BytesOf(string token) => token == "-" ? [] : Convert.FromHexString(token);

    static string HexOf(byte[] bytes) => Convert.ToHexString(bytes).ToLowerInvariant();

    static string KindOf(object error) => error switch
    {
        Uncorrectable => "uncorrectable",
        TooLong => "too_long",
        ShortPacket { Field: "parity" } => "short",
        ShortPacket => "unpack_failed",
        TrailingBytes => "trailing",
        TypeMismatch => "type_mismatch",
        _ => "unpack_failed",
    };

    static string Protect<T>(Scheme<T> position, int n, byte[] clear) where T : class, new()
    {
        T? row = null;
        if (BinaryPacker.Unpack(clear, position.On(v => row = v)) is not null || row is null)
            return "unpack_failed";
        Scheme<T> protectedScheme;
        try
        {
            protectedScheme = position.WithParity(n);
        }
        catch (ArgumentOutOfRangeException)
        {
            return "bad_parity";
        }
        return HexOf(BinaryPacker.Pack(protectedScheme, row));
    }

    static string Repair<T>(Scheme<T> position, int n, int t, byte[] received) where T : class, new()
    {
        Scheme<T> protectedScheme;
        try
        {
            protectedScheme = position.WithParity(n);
        }
        catch (ArgumentOutOfRangeException)
        {
            return "bad_parity";
        }
        T? row = null;
        object? error;
        int repaired;
        try
        {
            error = BinaryPacker.Unpack(received, t, out repaired, protectedScheme.On(v => row = v));
        }
        catch (ArgumentOutOfRangeException)
        {
            return "bad_limit";
        }
        if (error is not null || row is null)
            return error is null ? "unpack_failed" : KindOf(error);
        return $"{HexOf(BinaryPacker.Pack(position, row))} {repaired}";
    }

    static string Line<T>(Scheme<T> position, string[] words) where T : class, new() => words switch
    {
        ["protect", var n, var hex] => Protect(position, int.Parse(n), BytesOf(hex)),
        ["repair", var n, var t, var hex] => Repair(position, int.Parse(n), int.Parse(t), BytesOf(hex)),
        _ => throw new ArgumentException($"ecc line: {string.Join(' ', words)}"),
    };

    // Returns the exit status; `position` is the unprotected position scheme of Handoff.
    internal static int Run<T>(string[] args, Scheme<T> position) where T : class, new()
    {
        switch (args)
        {
            case ["ecc-protect", var n, var hex]:
                Console.WriteLine(Line(position, ["protect", n, hex]));
                return 0;
            case ["ecc-repair", var n, var t, var hex]:
                Console.WriteLine(Line(position, ["repair", n, t, hex]));
                return 0;
            case ["ecc-batch", var file]:
                foreach (var text in File.ReadLines(file))
                {
                    if (text.Trim().Length > 0)
                        Console.WriteLine(Line(position, text.Split(' ', StringSplitOptions.RemoveEmptyEntries)));
                }
                return 0;
            default:
                return 2;
        }
    }
}
