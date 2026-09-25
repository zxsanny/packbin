using System.Diagnostics;
using System.Globalization;
using Packbin;

namespace Packbin.Tests;

public class PackbinTests
{
    private sealed class FlagWideRow
    {
        public byte? B0 { get; set; }
        public byte? B1 { get; set; }
        public byte? B2 { get; set; }
        public byte? B3 { get; set; }
        public byte? B4 { get; set; }
        public ushort? Wide { get; set; }
    }

    public static readonly Scheme<PositionRow> Target = new(0x40,
        Field.U16<PositionRow>(0, x => x.Sid),
        Field.I32<PositionRow>(1, x => x.Lat),
        Field.I32<PositionRow>(2, x => x.Lon),
        Field.U8<PositionRow>(3, x => x.Profile),
        Field.Flags(
            Field.U16<PositionRow>(4, x => x.Heading),
            Field.U8<PositionRow>(5, x => x.Speed),
            Field.I16<PositionRow>(6, x => x.Altitude)));

    private static readonly Dictionary<string, object?> Position = new()
    {
        ["Sid"] = (ushort)1,
        ["Lat"] = 500_000_000,
        ["Lon"] = 300_000_000,
        ["Profile"] = (byte)1,
    };

    private const string GoldenHex = "4001000065cd1d00a3e1110100";

    public sealed class PositionRow
    {
        public ushort Sid { get; set; }
        public int Lat { get; set; }
        public int Lon { get; set; }
        public byte Profile { get; set; }
        public ushort? Heading { get; set; }
        public byte? Speed { get; set; }
        public short? Altitude { get; set; }
    }

    [Fact]
    public void Ac1_PositionPack()
    {
        var bytes = BinaryPacker.Pack(Target, Position);
        var hex = Convert.ToHexString(bytes).ToLowerInvariant();
        var mismatched = MismatchedBytes(bytes, ParseHex(GoldenHex));
        Assert.Equal(GoldenHex, hex);
        Assert.Equal(0, mismatched);
        Assert.Equal(13, bytes.Length);
        var again = BinaryPacker.Pack(Target, Position);
        Assert.Equal(0, MismatchedBytes(bytes, again));
    }

    [Fact]
    public void Ac2_PositionUnpack()
    {
        var got = BinaryPacker.Read(Target, ParseHex(GoldenHex));
        Assert.Null(got.Error);
        Assert.Equal((ushort)1, Convert.ToUInt16(got.Values["Sid"]!, CultureInfo.InvariantCulture));
        Assert.Equal(500_000_000, Convert.ToInt32(got.Values["Lat"]!, CultureInfo.InvariantCulture));
        Assert.Equal(300_000_000, Convert.ToInt32(got.Values["Lon"]!, CultureInfo.InvariantCulture));
        Assert.Equal((byte)1, Convert.ToByte(got.Values["Profile"]!, CultureInfo.InvariantCulture));
        Assert.False(got.Values.ContainsKey("type"));
        var motionFields = 0;
        if (got.Values.ContainsKey("Heading")) motionFields++;
        if (got.Values.ContainsKey("Speed")) motionFields++;
        if (got.Values.ContainsKey("Altitude")) motionFields++;
        Assert.Equal(0, motionFields);
    }

    [Fact]
    public void Ac3_BytesMatchFixture()
    {
        var bytes = BinaryPacker.Pack(Target, Position);
        var fixture = ParseHex(File.ReadAllText(FindGoldenFixture()).Trim());
        Assert.Equal(0, MismatchedBytes(bytes, fixture));
    }

    [Fact]
    public void Ac4_FlagsAndStoredZero()
    {
        var scheme = new Scheme<FlagWideRow>(1,
            Field.Flags(
                Field.U8<FlagWideRow>(0, x => x.B0),
                Field.U8<FlagWideRow>(1, x => x.B1),
                Field.U8<FlagWideRow>(2, x => x.B2),
                Field.U8<FlagWideRow>(3, x => x.B3),
                Field.U8<FlagWideRow>(4, x => x.B4),
                Field.U16<FlagWideRow>(5, x => x.Wide)));

        var clear = BinaryPacker.Pack(scheme, new Dictionary<string, object?>());
        Assert.Equal(2, clear.Length);
        Assert.Equal(0x01, clear[0]);
        Assert.Equal(0x00, clear[1]);

        var setBit5 = BinaryPacker.Pack(scheme, new Dictionary<string, object?>
        {
            ["Wide"] = (ushort)0x1234,
        });
        Assert.Equal(4, setBit5.Length);
        Assert.Equal(0x01, setBit5[0]);
        Assert.Equal(0x20, setBit5[1]);
        Assert.Equal(2, setBit5.Length - clear.Length);

        var presentZero = BinaryPacker.Pack(scheme, new Dictionary<string, object?>
        {
            ["Wide"] = (ushort)0,
        });
        Assert.Equal(4, presentZero.Length);
        Assert.Equal(0x01, presentZero[0]);
        Assert.Equal(0x20, presentZero[1]);
        Assert.Equal(0x00, presentZero[2]);
        Assert.Equal(0x00, presentZero[3]);

        var absent = BinaryPacker.Pack(scheme, new Dictionary<string, object?>());
        Assert.Equal(2, absent.Length);
        Assert.Equal(0x01, absent[0]);
        Assert.Equal(0x00, absent[1]);
    }

    [Fact]
    public void Ac5_ShortBufferThenPositionPack()
    {
        var scheme = new Scheme<FlagWideRow>(1,
            Field.Flags(
                Field.U8<FlagWideRow>(0, x => x.B0),
                Field.U8<FlagWideRow>(1, x => x.B1),
                Field.U8<FlagWideRow>(2, x => x.B2),
                Field.U8<FlagWideRow>(3, x => x.B3),
                Field.U8<FlagWideRow>(4, x => x.B4),
                Field.U16<FlagWideRow>(5, x => x.Wide)));
        var got = BinaryPacker.Read(scheme, new byte[] { 0x01, 0x20, 0x34 });
        Assert.Empty(got.Values);
        var missing = Assert.IsType<ShortPacket>(got.Error);
        Assert.Equal("Wide", missing.Field);
        Assert.Equal(2, missing.Needed);
        Assert.Equal(1, missing.Left);

        var bytes = BinaryPacker.Pack(Target, Position);
        Assert.Equal(GoldenHex, Convert.ToHexString(bytes).ToLowerInvariant());
    }

    [Fact]
    public void Nfr_RoundTripsWithinOneSecond()
    {
        var watch = Stopwatch.StartNew();
        for (var i = 0; i < 100_000; i++)
        {
            var bytes = BinaryPacker.Pack(Target, Position);
            var got = BinaryPacker.Read(Target, bytes);
            Assert.Null(got.Error);
            Assert.Equal(500_000_000, Convert.ToInt32(got.Values["Lat"]!, CultureInfo.InvariantCulture));
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
            Sid = 1,
            Lat = 500_000_000,
            Lon = 300_000_000,
            Profile = 1,
        };
        var bytes = BinaryPacker.Pack(Target, row);
        Assert.Equal(GoldenHex, Convert.ToHexString(bytes).ToLowerInvariant());
        PositionRow? got = null;
        var err = BinaryPacker.Unpack(bytes, Target.On(v => got = v));
        Assert.Null(err);
        Assert.NotNull(got);
        Assert.Equal((ushort)1, got.Sid);
        Assert.Equal(500_000_000, got.Lat);
        Assert.Equal(300_000_000, got.Lon);
        Assert.Equal((byte)1, got.Profile);
        Assert.Null(got.Heading);
        Assert.Null(got.Speed);
        Assert.Null(got.Altitude);
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
