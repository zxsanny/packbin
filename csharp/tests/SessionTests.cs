using System.Globalization;
using Packbin;

namespace Packbin.Tests;

public class SessionTests
{
    private sealed class PositionRow
    {
        public ushort Sid { get; set; }
        public int Lat { get; set; }
        public int Lon { get; set; }
        public byte Profile { get; set; }
        public ushort? Heading { get; set; }
        public byte? Speed { get; set; }
        public short? Altitude { get; set; }
    }

    private static readonly Scheme<PositionRow> Position = new(0x40,
        Field.U16<PositionRow>(0, x => x.Sid),
        Field.I32<PositionRow>(1, x => x.Lat),
        Field.I32<PositionRow>(2, x => x.Lon),
        Field.U8<PositionRow>(3, x => x.Profile),
        Field.Flags(4,
            Field.U16<PositionRow>(4, x => x.Heading),
            Field.U8<PositionRow>(5, x => x.Speed),
            Field.I16<PositionRow>(6, x => x.Altitude)));

    private static readonly PositionRow Row = new()
    {
        Sid = 1,
        Lat = 500_000_000,
        Lon = 300_000_000,
        Profile = 1,
    };

    private const string GoldenHex = "4001000065cd1d00a3e1110100";

    [Fact]
    public void Ac1_ClearPackUnchanged()
    {
        var bytes = BinaryPacker.Pack(Position, Row);
        Assert.Equal(GoldenHex, Convert.ToHexString(bytes).ToLowerInvariant());
        Assert.Equal(0, Mismatched(bytes, Parse(GoldenHex)));
    }

    // The same bytes every package pins (python test_ac1_ciphertext_matches_csharp and its twins).
    [Fact]
    public void Ac1_CiphertextMatchesTheSharedVector()
    {
        // Arrange
        var opener = PackSession.Load(Seed())!;
        opener.Start(Nonce(1));

        // Act
        var payload = opener.Pack(Position, Row)!;

        // Assert
        Assert.Equal("b55d0a29c56c203712b241232e", Convert.ToHexString(payload).ToLowerInvariant());
    }

    [Fact]
    public void S7_ClearUnpackStillReturnsTheRow()
    {
        var got = BinaryPacker.Read(Position, Parse(GoldenHex));
        Assert.Null(got.Error);
        Assert.Equal(0, FieldMismatches(got.Values));
    }

    [Fact]
    public void Ac2_OpenerPackWaiterUnpack()
    {
        var seed = Seed();
        var opener = PackSession.Load(seed);
        var waiter = PackSession.Load(seed);
        Assert.NotNull(opener);
        Assert.NotNull(waiter);
        var nonce = opener!.Start();
        Assert.NotNull(nonce);
        Assert.Equal(PackSession.NonceSize, nonce!.Length);
        Assert.True(waiter!.Join(nonce));

        var payload = opener.Pack(Position, Row);
        Assert.NotNull(payload);
        Assert.Equal(13, payload!.Length);
        Assert.Equal(0, payload.Length - 13);

        PositionRow? got = null;
        var err = waiter.Unpack(payload, Position.On(v => got = v));
        Assert.Null(err);
        Assert.NotNull(got);
        Assert.Equal(0, FieldMismatches(got!));
    }

    [Fact]
    public void Ac3_WaiterPackOpenerUnpack()
    {
        var (opener, waiter) = OpenPair(Seed());
        var forward = opener.Pack(Position, Row);
        Assert.NotNull(forward);
        PositionRow? forwardRow = null;
        Assert.Null(waiter.Unpack(forward, Position.On(v => forwardRow = v)));
        Assert.NotNull(forwardRow);

        var payload = waiter.Pack(Position, Row);
        Assert.NotNull(payload);
        PositionRow? got = null;
        var err = opener.Unpack(payload, Position.On(v => got = v));
        Assert.Null(err);
        Assert.NotNull(got);
        Assert.Equal(0, FieldMismatches(got!));
    }

    [Fact]
    public void Ac4_SecondPacket()
    {
        var (opener, waiter) = OpenPair(Seed());
        var first = opener.Pack(Position, Row);
        Assert.NotNull(first);
        PositionRow? ignored = null;
        Assert.Null(waiter.Unpack(first, Position.On(v => ignored = v)));

        var secondRow = new PositionRow { Sid = 2, Lat = 1, Lon = 2, Profile = 3 };
        var second = opener.Pack(Position, secondRow);
        Assert.NotNull(second);
        PositionRow? got = null;
        var err = waiter.Unpack(second, Position.On(v => got = v));
        Assert.Null(err);
        Assert.NotNull(got);
        Assert.Equal((ushort)2, got!.Sid);
        Assert.Equal(1, got.Lat);
        Assert.Equal(2, got.Lon);
        Assert.Equal((byte)3, got.Profile);
    }

    [Fact]
    public void Ac5_TwoSessionsStayApart()
    {
        var seed = Seed();
        var a = PackSession.Load(seed);
        var b = PackSession.Load(seed);
        Assert.NotNull(a);
        Assert.NotNull(b);
        var nonceA = a!.Start(Nonce(1));
        var nonceB = b!.Start(Nonce(2));
        Assert.NotNull(nonceA);
        Assert.NotNull(nonceB);
        var waiterB = PackSession.Load(seed);
        Assert.NotNull(waiterB);
        Assert.True(waiterB!.Join(nonceB));

        var payload = a.Pack(Position, Row);
        Assert.NotNull(payload);
        var originals = 0;
        PositionRow? got = null;
        waiterB.Unpack(payload, Position.On(v => got = v));
        if (got is not null && FieldMismatches(got) == 0)
            originals++;
        Assert.Equal(0, originals);
    }

    [Fact]
    public void Ac6_BadLengthsCreateNothing()
    {
        var created = 0;
        if (PackSession.Load(new byte[31]) is not null)
            created++;
        if (PackSession.Load(new byte[33]) is not null)
            created++;
        var loaded = PackSession.Load(Seed());
        Assert.NotNull(loaded);
        if (loaded!.Join(new byte[15]))
            created++;
        if (loaded.Join(new byte[17]))
            created++;
        if (loaded.Start(new byte[15]) is not null)
            created++;
        Assert.Equal(0, created);
        Assert.Null(loaded.Pack(Position, Row));
    }

    [Fact]
    public void Ac7_PackBeforeOpenProducesNothing()
    {
        var session = PackSession.Load(Seed());
        Assert.NotNull(session);
        var payload = session!.Pack(Position, Row);
        var produced = payload is null ? 0 : 1;
        Assert.Equal(0, produced);
    }

    [Fact]
    public void ChaCha20MatchesRfc8439Block()
    {
        var key = new byte[32];
        for (var i = 0; i < key.Length; i++)
            key[i] = (byte)i;
        var nonce = Convert.FromHexString("000000090000004a00000000");
        var block = new byte[64];
        SessionPad.Xor(key, nonce, 1, block);
        Assert.Equal("10f1e7e4d13b5915500fdd1fa32071c4c7d1f4c733c068030422aa9ac3d46c4e", Convert.ToHexString(block.AsSpan(0, 32)).ToLowerInvariant());
    }

    private static (PackSession opener, PackSession waiter) OpenPair(byte[] seed)
    {
        var opener = PackSession.Load(seed)!;
        var waiter = PackSession.Load(seed)!;
        var nonce = opener.Start()!;
        Assert.True(waiter.Join(nonce));
        return (opener, waiter);
    }

    private static byte[] Seed()
    {
        var seed = new byte[32];
        for (var i = 0; i < seed.Length; i++)
            seed[i] = (byte)(i + 1);
        return seed;
    }

    private static byte[] Nonce(byte mark)
    {
        var nonce = new byte[16];
        nonce[0] = mark;
        return nonce;
    }

    private static int FieldMismatches(PositionRow row)
    {
        var n = 0;
        if (row.Sid != 1) n++;
        if (row.Lat != 500_000_000) n++;
        if (row.Lon != 300_000_000) n++;
        if (row.Profile != 1) n++;
        if (row.Heading is not null) n++;
        if (row.Speed is not null) n++;
        if (row.Altitude is not null) n++;
        return n;
    }

    private static int FieldMismatches(IReadOnlyDictionary<string, object?> values)
    {
        var n = 0;
        if (!values.TryGetValue("Sid", out var sid) || Convert.ToUInt16(sid, CultureInfo.InvariantCulture) != 1) n++;
        if (!values.TryGetValue("Lat", out var lat) || Convert.ToInt32(lat, CultureInfo.InvariantCulture) != 500_000_000) n++;
        if (!values.TryGetValue("Lon", out var lon) || Convert.ToInt32(lon, CultureInfo.InvariantCulture) != 300_000_000) n++;
        if (!values.TryGetValue("Profile", out var profile) || Convert.ToByte(profile, CultureInfo.InvariantCulture) != 1) n++;
        if (values.ContainsKey("Heading")) n++;
        if (values.ContainsKey("Speed")) n++;
        if (values.ContainsKey("Altitude")) n++;
        return n;
    }

    private static int Mismatched(ReadOnlySpan<byte> left, ReadOnlySpan<byte> right)
    {
        var n = Math.Abs(left.Length - right.Length);
        var len = Math.Min(left.Length, right.Length);
        for (var i = 0; i < len; i++)
            if (left[i] != right[i]) n++;
        return n;
    }

    private static byte[] Parse(string hex) => Convert.FromHexString(hex);
}
