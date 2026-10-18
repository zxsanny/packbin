using Packbin;

namespace Packbin.Tests;

// AZ-2682: the position fixture and helpers shared by the message ECC tests (contract message-ecc 1.0.0).
internal static class EccFixture
{
    internal sealed class PositionRow
    {
        public ushort Sid { get; set; }
        public int Lat { get; set; }
        public int Lon { get; set; }
        public byte Profile { get; set; }
        public ushort? Heading { get; set; }
        public byte? Speed { get; set; }
        public short? Altitude { get; set; }
    }

    internal sealed class BlobRow
    {
        public byte[] Data { get; set; } = [];
    }

    internal const string GoldenHex = "4001000065cd1d00a3e1110100";

    internal static readonly Scheme<PositionRow> Position = Positions(0x40);

    internal static readonly PositionRow Row = new() { Sid = 1, Lat = 500_000_000, Lon = 300_000_000, Profile = 1 };

    internal static Scheme<PositionRow> Positions(int type) => new(type,
        Field.U16<PositionRow>(0, x => x.Sid),
        Field.I32<PositionRow>(1, x => x.Lat),
        Field.I32<PositionRow>(2, x => x.Lon),
        Field.U8<PositionRow>(3, x => x.Profile),
        Field.Flags(4,
            Field.U16<PositionRow>(4, x => x.Heading),
            Field.U8<PositionRow>(5, x => x.Speed),
            Field.I16<PositionRow>(6, x => x.Altitude)));

    // A scheme whose clear message (type byte included) is `clearLength` bytes.
    internal static Scheme<BlobRow> Blob(int clearLength) =>
        new(7, Field.Bytes<BlobRow>(0, x => x.Data, clearLength - 1));

    internal static BlobRow BlobOf(int clearLength) => new() { Data = new byte[clearLength - 1] };

    internal static byte[] Bytes(string hex) => hex == "-" ? [] : Convert.FromHexString(hex);

    internal static string Hex(byte[] bytes) => Convert.ToHexString(bytes).ToLowerInvariant();

    internal static bool IsRow(PositionRow? got) =>
        got is { Sid: 1, Lat: 500_000_000, Lon: 300_000_000, Profile: 1, Heading: null, Speed: null, Altitude: null };

    // Flips `count` distinct positions, each by a nonzero random XOR, and returns the positions.
    internal static int[] Corrupt(byte[] message, int count, Random random)
    {
        var positions = new List<int>();
        while (positions.Count < count)
        {
            var p = random.Next(message.Length);
            if (!positions.Contains(p))
                positions.Add(p);
        }
        foreach (var p in positions)
            message[p] ^= (byte)random.Next(1, 256);
        return [.. positions];
    }

    // One unpack of `message` into a position row: the error, the row (null when no handler ran) and the repaired count.
    internal static (object? Error, PositionRow? Row, int Repaired) Unpack(byte[] message, Scheme<PositionRow> scheme, int limit)
    {
        PositionRow? got = null;
        var error = BinaryPacker.Unpack(message, limit, out var repaired, scheme.On(v => got = v));
        return (error, got, repaired);
    }
}
