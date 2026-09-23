using System.Diagnostics;
using System.Globalization;
using Packbin;

namespace Packbin.Tests;

public class PackbinTests
{
    public static readonly Packet Target = Packet.Of(
        Field.U8("type"),
        Field.U16("sid"),
        Field.I32("lat"),
        Field.I32("lon"),
        Field.U8("profile"),
        Field.Flags("motion", Field.U16("heading"), Field.U8("speed"), Field.I16("altitude")));

    private static readonly Dictionary<string, object?> Position = new()
    {
        ["type"] = (byte)0x40,
        ["sid"] = (ushort)1,
        ["lat"] = 500_000_000,
        ["lon"] = 300_000_000,
        ["profile"] = (byte)1,
    };

    private const string GoldenHex = "4001000065cd1d00a3e1110100";

    [Fact]
    public void Ac1_PositionPack()
    {
        var bytes = Pack.Run(Target, Position);
        var hex = Convert.ToHexString(bytes).ToLowerInvariant();
        var mismatched = MismatchedBytes(bytes, ParseHex(GoldenHex));
        Assert.Equal(GoldenHex, hex);
        Assert.Equal(0, mismatched);
        Assert.Equal(13, bytes.Length);
        var again = Pack.Run(Target, Position);
        Assert.Equal(0, MismatchedBytes(bytes, again));
    }

    [Fact]
    public void Ac2_PositionUnpack()
    {
        var got = Unpack.Run(Target, ParseHex(GoldenHex));
        Assert.Null(got.Error);
        Assert.Equal((byte)0x40, Convert.ToByte(got.Values["type"]!, CultureInfo.InvariantCulture));
        Assert.Equal((ushort)1, Convert.ToUInt16(got.Values["sid"]!, CultureInfo.InvariantCulture));
        Assert.Equal(500_000_000, Convert.ToInt32(got.Values["lat"]!, CultureInfo.InvariantCulture));
        Assert.Equal(300_000_000, Convert.ToInt32(got.Values["lon"]!, CultureInfo.InvariantCulture));
        Assert.Equal((byte)1, Convert.ToByte(got.Values["profile"]!, CultureInfo.InvariantCulture));
        var motionFields = 0;
        if (got.Values.ContainsKey("heading")) motionFields++;
        if (got.Values.ContainsKey("speed")) motionFields++;
        if (got.Values.ContainsKey("altitude")) motionFields++;
        Assert.Equal(0, motionFields);
    }

    [Fact]
    public void Ac3_BytesMatchFixture()
    {
        var bytes = Pack.Run(Target, Position);
        var fixture = ParseHex(File.ReadAllText(FindGoldenFixture()).Trim());
        Assert.Equal(0, MismatchedBytes(bytes, fixture));
    }

    [Fact]
    public void Ac4_FlagsAndStoredZero()
    {
        var packet = Packet.Of(
            Field.Flags("flags",
                Field.U8("b0"),
                Field.U8("b1"),
                Field.U8("b2"),
                Field.U8("b3"),
                Field.U8("b4"),
                Field.U16("wide")));

        var clear = Pack.Run(packet, new Dictionary<string, object?>());
        Assert.Single(clear);
        Assert.Equal(0x00, clear[0]);

        var setBit5 = Pack.Run(packet, new Dictionary<string, object?>
        {
            ["wide"] = (ushort)0x1234,
        });
        Assert.Equal(3, setBit5.Length);
        Assert.Equal(0x20, setBit5[0]);
        Assert.Equal(2, setBit5.Length - clear.Length);

        var presentZero = Pack.Run(packet, new Dictionary<string, object?>
        {
            ["wide"] = (ushort)0,
        });
        Assert.Equal(3, presentZero.Length);
        Assert.Equal(0x20, presentZero[0]);
        Assert.Equal(0x00, presentZero[1]);
        Assert.Equal(0x00, presentZero[2]);

        var absent = Pack.Run(packet, new Dictionary<string, object?>());
        Assert.Single(absent);
        Assert.Equal(0x00, absent[0]);
    }

    [Fact]
    public void Ac5_ShortBufferThenPositionPack()
    {
        var packet = Packet.Of(
            Field.Flags("flags",
                Field.U8("b0"),
                Field.U8("b1"),
                Field.U8("b2"),
                Field.U8("b3"),
                Field.U8("b4"),
                Field.U16("wide")));
        var got = Unpack.Run(packet, new byte[] { 0x20, 0x34 });
        Assert.Empty(got.Values);
        var missing = Assert.IsType<ShortPacket>(got.Error);
        Assert.Equal("wide", missing.Field);
        Assert.Equal(2, missing.Needed);
        Assert.Equal(1, missing.Left);

        var bytes = Pack.Run(Target, Position);
        Assert.Equal(GoldenHex, Convert.ToHexString(bytes).ToLowerInvariant());
    }

    [Fact]
    public void WhenGroupWidth()
    {
        var packet = Packet.Of(
            Field.U8("profile"),
            Field.When(Condition.Eq("profile", (byte)0), Field.U8("shape")));

        var miss = Pack.Run(packet, new Dictionary<string, object?> { ["profile"] = (byte)1 });
        Assert.Single(miss);

        var hit = Pack.Run(packet, new Dictionary<string, object?>
        {
            ["profile"] = (byte)0,
            ["shape"] = (byte)9,
        });
        Assert.Equal(2, hit.Length);
        Assert.Equal(1, hit.Length - miss.Length);
    }

    [Fact]
    public void RepeatBoundary()
    {
        var packet = Packet.Of(Field.Repeat(Field.U8("a"), Field.U8("b")));

        var ok = Unpack.Run(packet, new byte[] { 1, 2 });
        Assert.Null(ok.Error);
        var groups = Assert.IsType<List<object?>>(ok.Values["a"]);
        Assert.Single(groups);

        var bad = Unpack.Run(packet, new byte[] { 1, 2, 3 });
        Assert.Empty(bad.Values);
        Assert.IsType<ShortPacket>(bad.Error);
    }

    [Fact]
    public void TrailingBytesAreError()
    {
        var packet = Packet.Of(Field.U8("type"));
        var got = Unpack.Run(packet, new byte[] { 0x40, 0x99 });
        Assert.Empty(got.Values);
        var trailing = Assert.IsType<TrailingBytes>(got.Error);
        Assert.Equal(1, trailing.Left);
    }

    [Fact]
    public void FlagGroup_EmptyMark()
    {
        var packet = Packet.Of(Field.Flags("f", Field.Group("mark")));
        var setBit = Pack.Run(packet, new Dictionary<string, object?> { ["mark"] = true });
        Assert.Equal(new byte[] { 0x01 }, setBit);
        var clear = Pack.Run(packet, new Dictionary<string, object?>());
        Assert.Equal(new byte[] { 0x00 }, clear);
    }

    [Fact]
    public void FlagGroup_FiveU8ThenU16()
    {
        var packet = Packet.Of(Field.Flags("f",
            Field.U8("a"), Field.U8("b"), Field.U8("c"), Field.U8("d"), Field.U8("e"), Field.U16("b5")));
        Assert.Equal(2, Pack.Run(packet, new Dictionary<string, object?> { ["a"] = (byte)1 }).Length);
        var empty = Pack.Run(packet, new Dictionary<string, object?>());
        var wide = Pack.Run(packet, new Dictionary<string, object?> { ["b5"] = (ushort)1 });
        Assert.Equal(0x20, wide[0]);
        Assert.Equal(2, wide.Length - empty.Length);
    }

    [Fact]
    public void FlagGroup_Session()
    {
        var packet = Packet.Of(Field.Flags("f",
            Field.Group("session", Field.U16("login"), Field.U32("ts"))));
        var raw = Pack.Run(packet, new Dictionary<string, object?>
        {
            ["login"] = (ushort)7,
            ["ts"] = 1000u,
        });
        Assert.Equal("0700e8030000", Convert.ToHexString(raw.AsSpan(1)).ToLowerInvariant());
        Assert.Equal(6, raw.Length - 1);
        var absent = Pack.Run(packet, new Dictionary<string, object?>());
        Assert.Equal(new byte[] { 0x00 }, absent);
        var got = Unpack.Run(packet, absent);
        Assert.Null(got.Error);
        Assert.False(got.Values.ContainsKey("login"));
        Assert.False(got.Values.ContainsKey("ts"));
    }

    [Fact]
    public void FlagGroup_ZeroU8()
    {
        var packet = Packet.Of(Field.Flags("f", Field.Group("g", Field.U8("b"))));
        var stored = Pack.Run(packet, new Dictionary<string, object?> { ["b"] = (byte)0 });
        Assert.Equal(new byte[] { 0x01, 0x00 }, stored);
    }

    [Fact]
    public void FlagGroup_SessionShort()
    {
        var packet = Packet.Of(Field.Flags("f",
            Field.Group("session", Field.U16("login"), Field.U32("ts"))));
        var got = Unpack.Run(packet, new byte[] { 0x01, 0x07 });
        Assert.Empty(got.Values);
        var missing = Assert.IsType<ShortPacket>(got.Error);
        Assert.Equal("login", missing.Field);
        Assert.Equal(2, missing.Needed);
        Assert.Equal(1, missing.Left);
    }

    [Fact]
    public void SizedPayload()
    {
        var packet = Packet.Of(Field.U16("n"), Field.Sized("payload", "n"));
        var raw = Pack.Run(packet, new Dictionary<string, object?>
        {
            ["n"] = (ushort)3,
            ["payload"] = ParseHex("756176"),
        });
        Assert.Equal("0300756176", Convert.ToHexString(raw).ToLowerInvariant());
        var empty = Pack.Run(packet, new Dictionary<string, object?>
        {
            ["n"] = (ushort)0,
            ["payload"] = Array.Empty<byte>(),
        });
        Assert.Equal("0000", Convert.ToHexString(empty).ToLowerInvariant());
        var emptyGot = Unpack.Run(packet, empty);
        Assert.Null(emptyGot.Error);
        Assert.Empty((byte[])emptyGot.Values["payload"]!);
        var shortGot = Unpack.Run(packet, ParseHex("030075"));
        Assert.Empty(shortGot.Values);
        var missing = Assert.IsType<ShortPacket>(shortGot.Error);
        Assert.Equal("payload", missing.Field);
        Assert.Equal(3, missing.Needed);
        Assert.Equal(1, missing.Left);
    }

    [Fact]
    public void Utf8String()
    {
        var packet = Packet.Of(Field.Utf8("name"));
        var raw = Pack.Run(packet, new Dictionary<string, object?> { ["name"] = "zxsanny" });
        Assert.Equal("07007a7873616e6e79", Convert.ToHexString(raw).ToLowerInvariant());
        Assert.Equal(9, raw.Length);
        var got = Unpack.Run(packet, raw);
        Assert.Null(got.Error);
        Assert.Equal("zxsanny", got.Values["name"]);

        var empty = Pack.Run(packet, new Dictionary<string, object?> { ["name"] = "" });
        Assert.Equal("0000", Convert.ToHexString(empty).ToLowerInvariant());
        var emptyGot = Unpack.Run(packet, empty);
        Assert.Null(emptyGot.Error);
        Assert.Equal("", emptyGot.Values["name"]);

        Assert.Throws<ArgumentException>(() =>
            Pack.Run(packet, new Dictionary<string, object?> { ["name"] = new string('a', 65536) }));

        var shortGot = Unpack.Run(packet, new byte[] { 0x07, 0x00, 0x7a, 0x78 });
        Assert.Empty(shortGot.Values);
        var missing = Assert.IsType<ShortPacket>(shortGot.Error);
        Assert.Equal("name", missing.Field);
        Assert.Equal(7, missing.Needed);
        Assert.Equal(2, missing.Left);
    }

    [Fact]
    public void U2AndBits()
    {
        var kinds = Packet.Of(Field.U2("a", "b", "c", "d"));
        var raw = Pack.Run(kinds, new Dictionary<string, object?>
        {
            ["a"] = 0, ["b"] = 1, ["c"] = 2, ["d"] = 3,
        });
        Assert.Equal("e4", Convert.ToHexString(raw).ToLowerInvariant());
        var got = Unpack.Run(kinds, raw);
        Assert.Null(got.Error);
        Assert.Equal(0, Convert.ToInt32(got.Values["a"]!, CultureInfo.InvariantCulture));
        Assert.Equal(1, Convert.ToInt32(got.Values["b"]!, CultureInfo.InvariantCulture));
        Assert.Equal(2, Convert.ToInt32(got.Values["c"]!, CultureInfo.InvariantCulture));
        Assert.Equal(3, Convert.ToInt32(got.Values["d"]!, CultureInfo.InvariantCulture));
        var one = Pack.Run(Packet.Of(Field.U2("a")), new Dictionary<string, object?> { ["a"] = 1 });
        Assert.Equal("01", Convert.ToHexString(one).ToLowerInvariant());

        var layout = Packet.Of(Field.U8("n"), Field.Bits("segs", "n"));
        var eight = Pack.Run(layout, new Dictionary<string, object?>
        {
            ["n"] = (byte)8,
            ["segs"] = new List<int> { 1, 1, 1, 1, 1, 1, 1, 1 },
        });
        Assert.Equal("ff", Convert.ToHexString(eight.AsSpan(1)).ToLowerInvariant());
        Assert.Equal(1, eight.Length - 1);
        var nine = Pack.Run(layout, new Dictionary<string, object?>
        {
            ["n"] = (byte)9,
            ["segs"] = new List<int> { 1, 1, 1, 1, 1, 1, 1, 1, 1 },
        });
        Assert.Equal(2, nine.Length - 1);
        Assert.Equal(0xFF, nine[1]);
        Assert.Equal(0, nine[2] & 0xFE);
        var shortGot = Unpack.Run(layout, new byte[] { 9, 1 });
        Assert.Empty(shortGot.Values);
        var missing = Assert.IsType<ShortPacket>(shortGot.Error);
        Assert.Equal("segs", missing.Field);
        Assert.Equal(2, missing.Needed);
        Assert.Equal(1, missing.Left);
    }

    [Fact]
    public void Nfr_RoundTripsWithinOneSecond()
    {
        var watch = Stopwatch.StartNew();
        for (var i = 0; i < 100_000; i++)
        {
            var bytes = Pack.Run(Target, Position);
            var got = Unpack.Run(Target, bytes);
            Assert.Null(got.Error);
            Assert.Equal(500_000_000, Convert.ToInt32(got.Values["lat"]!, CultureInfo.InvariantCulture));
        }
        watch.Stop();
        AssertNoGpuLibrary();
        Assert.True(watch.Elapsed.TotalSeconds <= 1.0, $"elapsed {watch.Elapsed.TotalMilliseconds} ms");
    }

    [Fact]
    public void Object_round_trip_leaves_absent_flags_null()
    {
        var row = new PositionRow
        {
            type = 0x40,
            sid = 1,
            lat = 500_000_000,
            lon = 300_000_000,
            profile = 1,
        };
        var bytes = Pack.Run(Target, row);
        Assert.Equal(GoldenHex, Convert.ToHexString(bytes).ToLowerInvariant());
        var got = Unpack.Run<PositionRow>(Target, bytes);
        Assert.True(got.Ok);
        Assert.NotNull(got.Value);
        Assert.Equal((byte)0x40, got.Value.type);
        Assert.Equal((ushort)1, got.Value.sid);
        Assert.Equal(500_000_000, got.Value.lat);
        Assert.Equal(300_000_000, got.Value.lon);
        Assert.Equal((byte)1, got.Value.profile);
        Assert.Null(got.Value.heading);
        Assert.Null(got.Value.speed);
        Assert.Null(got.Value.altitude);
    }

    [Fact]
    public void Object_zero_is_present_and_null_is_absent()
    {
        var packet = Packet.Of(Field.Flags(
            "f", Field.U8("a"), Field.U8("b"), Field.U8("c"), Field.U8("d"), Field.U8("e"), Field.U16("b5")));
        var absent = Pack.Run(packet, new WideRow());
        Assert.Equal(new byte[] { 0x00 }, absent);
        var present = Pack.Run(packet, new WideRow { b5 = 0 });
        Assert.Equal(new byte[] { 0x20, 0x00, 0x00 }, present);
    }

    [Fact]
    public void Object_nested_group_and_short_packet()
    {
        var packet = Packet.Of(Field.Flags("f", Field.Group("session", Field.U16("login"), Field.U32("ts"))));
        var clear = Pack.Run(packet, new SessionRow());
        Assert.Equal(new byte[] { 0x00 }, clear);
        var set = Pack.Run(packet, new SessionRow { session = new Session { login = 7, ts = 1000 } });
        Assert.Equal("010700e8030000", Convert.ToHexString(set).ToLowerInvariant());
        var got = Unpack.Run<SessionRow>(packet, set);
        Assert.True(got.Ok);
        Assert.NotNull(got.Value);
        Assert.NotNull(got.Value.session);
        Assert.Equal((ushort)7, got.Value.session.login);
        Assert.Equal(1000u, got.Value.session.ts);
        var shortPacket = Unpack.Run<SessionRow>(packet, new byte[] { 0x01, 0x07 });
        Assert.False(shortPacket.Ok);
        Assert.Null(shortPacket.Value);
        var err = Assert.IsType<ShortPacket>(shortPacket.Error);
        Assert.Equal("login", err.Field);
        Assert.Equal(2, err.Needed);
        Assert.Equal(1, err.Left);
    }

    private sealed class PositionRow
    {
        public byte type { get; set; }
        public ushort sid { get; set; }
        public int lat { get; set; }
        public int lon { get; set; }
        public byte profile { get; set; }
        public ushort? heading { get; set; }
        public byte? speed { get; set; }
        public short? altitude { get; set; }
    }

    private sealed class WideRow
    {
        public ushort? b5 { get; set; }
    }

    private sealed class Session
    {
        public ushort login { get; set; }
        public uint ts { get; set; }
    }

    private sealed class SessionRow
    {
        public Session? session { get; set; }
    }

    private static void AssertNoGpuLibrary()
    {
        var blob = new System.Text.StringBuilder();
        if (File.Exists("/proc/self/maps"))
            blob.Append(File.ReadAllText("/proc/self/maps"));
        foreach (ProcessModule module in Process.GetCurrentProcess().Modules)
        {
            blob.Append(module.ModuleName);
            blob.Append(module.FileName);
        }
        var text = blob.ToString().ToLowerInvariant();
        foreach (var bad in new[] { "libcuda", "libnvidia", "libvulkan", "libopencl", "metal.framework" })
            Assert.DoesNotContain(bad, text);
    }

    private static int MismatchedBytes(byte[] actual, byte[] expected)
    {
        var n = Math.Max(actual.Length, expected.Length);
        var mismatches = Math.Abs(actual.Length - expected.Length);
        var shared = Math.Min(actual.Length, expected.Length);
        for (var i = 0; i < shared; i++)
        {
            if (actual[i] != expected[i])
                mismatches++;
        }
        return mismatches;
    }

    private static byte[] ParseHex(string hex)
    {
        hex = hex.Trim();
        var bytes = new byte[hex.Length / 2];
        for (var i = 0; i < bytes.Length; i++)
            bytes[i] = Convert.ToByte(hex.Substring(i * 2, 2), 16);
        return bytes;
    }

    private static string FindGoldenFixture()
    {
        var dir = new DirectoryInfo(AppContext.BaseDirectory);
        while (dir is not null)
        {
            var path = Path.Combine(dir.FullName, "fixtures", "golden.hex");
            if (File.Exists(path))
                return path;
            dir = dir.Parent;
        }
        throw new FileNotFoundException("fixtures/golden.hex");
    }
}
