using System.Diagnostics;
using System.Globalization;
using Packbin;

namespace Packbin.Tests;

public class PackbinTests
{
    private sealed class FlagWideRow
    {
        public byte? b0 { get; set; }
        public byte? b1 { get; set; }
        public byte? b2 { get; set; }
        public byte? b3 { get; set; }
        public byte? b4 { get; set; }
        public ushort? wide { get; set; }
    }

    public static readonly Scheme<PositionRow> Target = new(0x40,
        Field.U16<PositionRow>(0, x => x.sid),
        Field.I32<PositionRow>(1, x => x.lat),
        Field.I32<PositionRow>(2, x => x.lon),
        Field.U8<PositionRow>(3, x => x.profile),
        Field.Flags(
            Field.U16<PositionRow>(4, x => x.heading),
            Field.U8<PositionRow>(5, x => x.speed),
            Field.I16<PositionRow>(6, x => x.altitude)));

    private static readonly Dictionary<string, object?> Position = new()
    {
        ["sid"] = (ushort)1,
        ["lat"] = 500_000_000,
        ["lon"] = 300_000_000,
        ["profile"] = (byte)1,
    };

    private const string GoldenHex = "4001000065cd1d00a3e1110100";

    public sealed class PositionRow
    {
        public ushort sid { get; set; }
        public int lat { get; set; }
        public int lon { get; set; }
        public byte profile { get; set; }
        public ushort? heading { get; set; }
        public byte? speed { get; set; }
        public short? altitude { get; set; }
    }

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
        var got = Unpack.Read(Target, ParseHex(GoldenHex));
        Assert.Null(got.Error);
        Assert.Equal((ushort)1, Convert.ToUInt16(got.Values["sid"]!, CultureInfo.InvariantCulture));
        Assert.Equal(500_000_000, Convert.ToInt32(got.Values["lat"]!, CultureInfo.InvariantCulture));
        Assert.Equal(300_000_000, Convert.ToInt32(got.Values["lon"]!, CultureInfo.InvariantCulture));
        Assert.Equal((byte)1, Convert.ToByte(got.Values["profile"]!, CultureInfo.InvariantCulture));
        Assert.False(got.Values.ContainsKey("type"));
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
        var scheme = new Scheme<FlagWideRow>(1,
            Field.Flags(
                Field.U8<FlagWideRow>(0, x => x.b0),
                Field.U8<FlagWideRow>(1, x => x.b1),
                Field.U8<FlagWideRow>(2, x => x.b2),
                Field.U8<FlagWideRow>(3, x => x.b3),
                Field.U8<FlagWideRow>(4, x => x.b4),
                Field.U16<FlagWideRow>(5, x => x.wide)));

        var clear = Pack.Run(scheme, new Dictionary<string, object?>());
        Assert.Equal(2, clear.Length);
        Assert.Equal(0x01, clear[0]);
        Assert.Equal(0x00, clear[1]);

        var setBit5 = Pack.Run(scheme, new Dictionary<string, object?>
        {
            ["wide"] = (ushort)0x1234,
        });
        Assert.Equal(4, setBit5.Length);
        Assert.Equal(0x01, setBit5[0]);
        Assert.Equal(0x20, setBit5[1]);
        Assert.Equal(2, setBit5.Length - clear.Length);

        var presentZero = Pack.Run(scheme, new Dictionary<string, object?>
        {
            ["wide"] = (ushort)0,
        });
        Assert.Equal(4, presentZero.Length);
        Assert.Equal(0x01, presentZero[0]);
        Assert.Equal(0x20, presentZero[1]);
        Assert.Equal(0x00, presentZero[2]);
        Assert.Equal(0x00, presentZero[3]);

        var absent = Pack.Run(scheme, new Dictionary<string, object?>());
        Assert.Equal(2, absent.Length);
        Assert.Equal(0x01, absent[0]);
        Assert.Equal(0x00, absent[1]);
    }

    [Fact]
    public void Ac5_ShortBufferThenPositionPack()
    {
        var scheme = new Scheme<FlagWideRow>(1,
            Field.Flags(
                Field.U8<FlagWideRow>(0, x => x.b0),
                Field.U8<FlagWideRow>(1, x => x.b1),
                Field.U8<FlagWideRow>(2, x => x.b2),
                Field.U8<FlagWideRow>(3, x => x.b3),
                Field.U8<FlagWideRow>(4, x => x.b4),
                Field.U16<FlagWideRow>(5, x => x.wide)));
        var got = Unpack.Read(scheme, new byte[] { 0x01, 0x20, 0x34 });
        Assert.Empty(got.Values);
        var missing = Assert.IsType<ShortPacket>(got.Error);
        Assert.Equal("wide", missing.Field);
        Assert.Equal(2, missing.Needed);
        Assert.Equal(1, missing.Left);

        var bytes = Pack.Run(Target, Position);
        Assert.Equal(GoldenHex, Convert.ToHexString(bytes).ToLowerInvariant());
    }

    [Fact]
    public void Nfr_RoundTripsWithinOneSecond()
    {
        var watch = Stopwatch.StartNew();
        for (var i = 0; i < 100_000; i++)
        {
            var bytes = Pack.Run(Target, Position);
            var got = Unpack.Read(Target, bytes);
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
            sid = 1,
            lat = 500_000_000,
            lon = 300_000_000,
            profile = 1,
        };
        var bytes = Pack.Run(Target, row);
        Assert.Equal(GoldenHex, Convert.ToHexString(bytes).ToLowerInvariant());
        var got = Unpack.Run(Target, bytes);
        Assert.True(got.Ok);
        Assert.NotNull(got.Value);
        Assert.Equal((ushort)1, got.Value.sid);
        Assert.Equal(500_000_000, got.Value.lat);
        Assert.Equal(300_000_000, got.Value.lon);
        Assert.Equal((byte)1, got.Value.profile);
        Assert.Null(got.Value.heading);
        Assert.Null(got.Value.speed);
        Assert.Null(got.Value.altitude);
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

    internal static int MismatchedBytes(byte[] actual, byte[] expected)
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

    internal static byte[] ParseHex(string hex)
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
