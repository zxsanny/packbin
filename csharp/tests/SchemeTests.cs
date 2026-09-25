using System.Diagnostics;
using Packbin;

namespace Packbin.Tests;

public class SchemeTests
{
    public sealed class MarkerRow
    {
        public byte Sid { get; set; }
    }

    public sealed class UserModifiedEvent
    {
        public int UserId { get; set; }
        public string UserNameChange { get; set; } = "";
        public string UserEmailChange { get; set; } = "";
        public byte UserStatusChange { get; set; }
    }

    public sealed class UserPositionEvent
    {
        public int UserId { get; set; }
        public int Latitude { get; set; }
        public int Longitude { get; set; }
    }

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

    private static readonly Scheme<MarkerRow> MarkerScheme = new(32, f => [f.U8(0, x => x.Sid)]);

    private static readonly Scheme<UserModifiedEvent> ModifiedScheme = new(1, f => [
        f.I32(0, x => x.UserId),
        f.Utf8(1, x => x.UserNameChange),
        f.Utf8(2, x => x.UserEmailChange),
        f.U8(3, x => x.UserStatusChange)]);

    private static readonly Scheme<UserPositionEvent> PositionEventScheme = new(2, f => [
        f.I32(0, x => x.UserId),
        f.I32(1, x => x.Latitude),
        f.I32(2, x => x.Longitude)]);

    private static readonly Scheme<PositionRow> PositionScheme = new(0x40, f => [
        f.U16(0, x => x.Sid),
        f.I32(1, x => x.Lat),
        f.I32(2, x => x.Lon),
        f.U8(3, x => x.Profile),
        f.Flags(
            f.U16(4, x => x.Heading),
            f.U8(5, x => x.Speed),
            f.I16(6, x => x.Altitude))]);

    private static readonly Dictionary<string, object?> PositionValues = new()
    {
        ["Sid"] = (ushort)1,
        ["Lat"] = 500_000_000,
        ["Lon"] = 300_000_000,
        ["Profile"] = (byte)1,
    };

    private const string GoldenHex = "4001000065cd1d00a3e1110100";
    private const string Ac4Hex = "02070000000800000009000000";

    [Fact]
    public void Ac1_SchemeReplacesPacket()
    {
        Assert.Null(typeof(Packbin.Scheme<MarkerRow>).Assembly.GetType("Packbin.Packet"));
        Assert.NotNull(typeof(Packbin.Scheme<MarkerRow>).Assembly.GetType("Packbin.BinaryPacker"));
        Assert.Null(typeof(Packbin.Scheme<MarkerRow>).Assembly.GetType("Packbin.TypeNum"));
        var scheme = new Scheme<MarkerRow>(32, Field.U8<MarkerRow>(0, x => x.Sid));
        Assert.Equal(32, scheme.TypeNumber);
        Assert.Single(scheme.Fields);
        Assert.ThrowsAny<ArgumentException>(() => new Scheme<MarkerRow>(-1, Field.U8<MarkerRow>(0, x => x.Sid)));
        Assert.ThrowsAny<ArgumentException>(() => new Scheme<MarkerRow>(256, Field.U8<MarkerRow>(0, x => x.Sid)));
        var bytes = BinaryPacker.Pack(scheme, new MarkerRow { Sid = 23 });
        Assert.Equal("2017", Convert.ToHexString(bytes).ToLowerInvariant());
    }

    [Fact]
    public void Ac2_RowHasNoTypeMember()
    {
        var bytes = BinaryPacker.Pack(PositionScheme, PositionValues);
        Assert.Equal(GoldenHex, Convert.ToHexString(bytes).ToLowerInvariant());
        var fixture = ParseHex(File.ReadAllText(FindGoldenFixture()).Trim());
        Assert.Equal(0, MismatchedBytes(bytes, fixture));
        Assert.Null(typeof(PositionRow).GetProperty("type"));
        Assert.Null(typeof(PositionRow).GetField("type"));
        PositionRow? row = null;
        var err = BinaryPacker.Unpack(bytes, PositionScheme.On(v => row = v));
        Assert.Null(err);
        Assert.NotNull(row);
        Assert.Equal((ushort)1, row.Sid);
        Assert.Equal(500_000_000, row.Lat);
        Assert.Equal(300_000_000, row.Lon);
        Assert.Equal((byte)1, row.Profile);
    }

    [Fact]
    public void Ac3_KnownSchemeChecksLeadingByte()
    {
        var scheme = new Scheme<MarkerRow>(1, Field.U8<MarkerRow>(0, x => x.Sid));
        MarkerRow? row = null;
        var err = BinaryPacker.Unpack(ParseHex("0217"), scheme.On(v => row = v));
        Assert.Null(row);
        var mismatch = Assert.IsType<TypeMismatch>(err);
        Assert.Equal(2, mismatch.Actual);
    }

    [Fact]
    public void Ac4_UnknownBufferCallsMatchingHandler()
    {
        UserModifiedEvent? modified = null;
        UserPositionEvent? position = null;
        var err = BinaryPacker.Unpack(
            ParseHex(Ac4Hex),
            ModifiedScheme.On(ev => modified = ev),
            PositionEventScheme.On(ev => position = ev));
        Assert.Null(err);
        Assert.Null(modified);
        Assert.NotNull(position);
        Assert.Equal(7, position.UserId);
        Assert.Equal(8, position.Latitude);
        Assert.Equal(9, position.Longitude);
        Assert.Null(typeof(UserPositionEvent).GetProperty("type"));
        Assert.Null(typeof(UserPositionEvent).GetField("type"));
        var packed = BinaryPacker.Pack(PositionEventScheme, new UserPositionEvent
        {
            UserId = 7,
            Latitude = 8,
            Longitude = 9,
        });
        Assert.Equal(Ac4Hex, Convert.ToHexString(packed).ToLowerInvariant());
    }

    [Fact]
    public void Ac5_UnknownTypeNumber()
    {
        var modifiedRan = false;
        var positionRan = false;
        var err = BinaryPacker.Unpack(
            ParseHex("09070000000800000009000000"),
            ModifiedScheme.On(_ => modifiedRan = true),
            PositionEventScheme.On(_ => positionRan = true));
        Assert.False(modifiedRan);
        Assert.False(positionRan);
        var mismatch = Assert.IsType<TypeMismatch>(err);
        Assert.Equal(9, mismatch.Actual);
    }

    [Fact]
    public void Ac6_TypeNumbersInOneCallAreUnique()
    {
        var other = new Scheme<UserModifiedEvent>(1,
            Field.I32<UserModifiedEvent>(0, x => x.UserId),
            Field.Utf8<UserModifiedEvent>(1, x => x.UserNameChange),
            Field.Utf8<UserModifiedEvent>(2, x => x.UserEmailChange),
            Field.U8<UserModifiedEvent>(3, x => x.UserStatusChange));
        Assert.ThrowsAny<ArgumentException>(() =>
            BinaryPacker.Unpack(
                ParseHex(Ac4Hex),
                ModifiedScheme.On(_ => { }),
                other.On(_ => { })));
    }

    [Fact]
    public void EmptyBufferIsShortPacket()
    {
        MarkerRow? row = null;
        var err = BinaryPacker.Unpack(ReadOnlySpan<byte>.Empty, MarkerScheme.On(v => row = v));
        Assert.Null(row);
        var missing = Assert.IsType<ShortPacket>(err);
        Assert.Equal("", missing.Field);
        Assert.Equal(1, missing.Needed);
        Assert.Equal(0, missing.Left);
    }

    [Fact]
    public void CompileFailRequiresScheme()
    {
        var fixtureDir = FindCompileFailDir();
        var project = Path.Combine(fixtureDir, "PackWithoutScheme.csproj");
        Assert.True(File.Exists(project), project);
        var start = new ProcessStartInfo
        {
            FileName = "dotnet",
            Arguments = $"build \"{project}\" --nologo -v q",
            RedirectStandardOutput = true,
            RedirectStandardError = true,
            UseShellExecute = false,
        };
        using var process = Process.Start(start) ?? throw new InvalidOperationException("dotnet start failed");
        var stdout = process.StandardOutput.ReadToEnd();
        var stderr = process.StandardError.ReadToEnd();
        process.WaitForExit();
        Assert.True(
            process.ExitCode != 0,
            $"expected compile failure, exit={process.ExitCode}\n{stdout}\n{stderr}");
    }

    private static int MismatchedBytes(byte[] actual, byte[] expected)
    {
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

    private static string FindCompileFailDir()
    {
        var dir = new DirectoryInfo(AppContext.BaseDirectory);
        while (dir is not null)
        {
            var path = Path.Combine(dir.FullName, "csharp", "tests", "compile-fail");
            if (Directory.Exists(path))
                return path;
            path = Path.Combine(dir.FullName, "tests", "compile-fail");
            if (Directory.Exists(path))
                return path;
            dir = dir.Parent;
        }
        throw new DirectoryNotFoundException("csharp/tests/compile-fail");
    }
}
