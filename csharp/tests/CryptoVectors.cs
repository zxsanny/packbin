using System.Security.Cryptography;

namespace Packbin.Tests;

// Replays fixtures/crypto/vectors.txt (AZ-3201, PB-02) through the primitives the package uses: the platform SHA-256, the
// platform HMAC-SHA256 as FrameCrypto starts it, Compat.HkdfSha256 and the ChaCha20 of SessionPad that frame mode uses.
internal static class CryptoVectors
{
    internal sealed record Row(string Primitive, string Id, Dictionary<string, string> Fields);

    internal static string FixturePath() => TextVectors.RepositoryFile("fixtures", "crypto", "vectors.txt");

    internal static List<Row> Load(string path)
    {
        var rows = new List<Row>();
        foreach (var line in File.ReadAllLines(path))
        {
            if (line.Length == 0 || line[0] == '#')
                continue;
            var tokens = line.Split(' ');
            var fields = new Dictionary<string, string>();
            foreach (var token in tokens.Skip(2))
            {
                var at = token.IndexOf('=');
                fields[token.Substring(0, at)] = token.Substring(at + 1);
            }
            rows.Add(new Row(tokens[0], tokens[1], fields));
        }
        return rows;
    }

    // "primitive source field": expected X, got Y, for every row the package's primitives get wrong.
    internal static List<string> Mismatches(IEnumerable<Row> rows)
    {
        var problems = new List<string>();
        foreach (var row in rows)
        {
            var (name, expected, got) = Run(row);
            if (got != expected)
                problems.Add($"{row.Primitive} {row.Id} {name}: expected {expected}, got {got}");
        }
        return problems;
    }

    private static byte[] Bytes(Row row, string name) => FrameVectors.Hex(row.Fields[name]);

    private static string Text(ReadOnlySpan<byte> bytes) => FrameVectors.Unhex(bytes);

    private static (string Name, string Expected, string Got) Run(Row row) => row.Primitive switch
    {
        "sha256" => Sha256(row),
        "hmac256" => Hmac(row),
        "hkdf256" => Hkdf(row),
        "chacha-block" => Block(row),
        "chacha-xor" => Cipher(row),
        _ => throw new InvalidOperationException("unknown primitive " + row.Primitive),
    };

    private static (string, string, string) Sha256(Row row)
    {
        var message = row.Fields.ContainsKey("msg") ? Bytes(row, "msg") : Enumerable.Repeat(Bytes(row, "byte")[0], int.Parse(row.Fields["repeat"])).ToArray();
        var whole = Text(SHA256.HashData(message));
        using var pieces = IncrementalHash.CreateHash(HashAlgorithmName.SHA256);
        for (var at = 0; at < message.Length; at += 37)
            pieces.AppendData(message, at, Math.Min(37, message.Length - at));
        var split = Text(pieces.GetHashAndReset());
        return ("digest", row.Fields["digest"], whole == split ? whole : "pieces " + split + " whole " + whole);
    }

    private static (string, string, string) Hmac(Row row)
    {
        var full = new byte[32];
        FrameCrypto.Hmac(Bytes(row, "key"), Bytes(row, "data"), full);
        var keep = row.Fields.TryGetValue("truncate", out var n) ? int.Parse(n) : 32;
        return ("mac", row.Fields["mac"], Text(full.AsSpan(0, keep)));
    }

    private static (string, string, string) Hkdf(Row row)
    {
        var (ikm, salt, info) = (Bytes(row, "ikm"), Bytes(row, "salt"), Bytes(row, "info"));
        var prk = new byte[32];
        FrameCrypto.Hmac(salt, ikm, prk);
        var okm = new byte[int.Parse(row.Fields["len"])];
        Compat.HkdfSha256(ikm, okm, salt, info);
        return ("prk,okm", row.Fields["prk"] + "," + row.Fields["okm"], Text(prk) + "," + Text(okm));
    }

    private static (string, string, string) Block(Row row)
    {
        var block = new byte[64];
        SessionPad.Xor(Bytes(row, "key"), Bytes(row, "nonce"), uint.Parse(row.Fields["counter"]), block);
        return ("block", row.Fields["block"], Text(block));
    }

    private static (string, string, string) Cipher(Row row)
    {
        var (key, nonce, counter) = (Bytes(row, "key"), Bytes(row, "nonce"), uint.Parse(row.Fields["counter"]));
        var data = Bytes(row, "plain");
        SessionPad.Xor(key, nonce, counter, data);
        var cipher = Text(data);
        SessionPad.Xor(key, nonce, counter, data);
        return ("cipher", row.Fields["cipher"], cipher + (Text(data) == row.Fields["plain"] ? "" : " (decrypt differs)"));
    }
}
