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
