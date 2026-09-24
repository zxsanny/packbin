using System.Diagnostics;
using Packbin;

namespace Packbin.Tests;

public class SchemeTests
{
    public sealed class MarkerRow
    {
        public byte sid { get; set; }
    }

    public sealed class UserModifiedEvent
    {
        public int userId { get; set; }
        public string userNameChange { get; set; } = "";
        public string userEmailChange { get; set; } = "";
        public byte userStatusChange { get; set; }
    }

    public sealed class UserPositionEvent
    {
        public int userId { get; set; }
        public int latitude { get; set; }
        public int longitude { get; set; }
    }

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

    private static readonly Scheme<MarkerRow> MarkerScheme = new(32, Field.U8<MarkerRow>(0, x => x.sid));

    private static readonly Scheme<UserModifiedEvent> ModifiedScheme = new(1,
        Field.I32<UserModifiedEvent>(0, x => x.userId),
        Field.Utf8<UserModifiedEvent>(1, x => x.userNameChange),
        Field.Utf8<UserModifiedEvent>(2, x => x.userEmailChange),
        Field.U8<UserModifiedEvent>(3, x => x.userStatusChange));

    private static readonly Scheme<UserPositionEvent> PositionEventScheme = new(2,
        Field.I32<UserPositionEvent>(0, x => x.userId),
        Field.I32<UserPositionEvent>(1, x => x.latitude),
        Field.I32<UserPositionEvent>(2, x => x.longitude));

    private static readonly Scheme<PositionRow> PositionScheme = new(0x40,
        Field.U16<PositionRow>(0, x => x.sid),
        Field.I32<PositionRow>(1, x => x.lat),
        Field.I32<PositionRow>(2, x => x.lon),
        Field.U8<PositionRow>(3, x => x.profile),
        Field.Flags(
            Field.U16<PositionRow>(4, x => x.heading),
            Field.U8<PositionRow>(5, x => x.speed),
            Field.I16<PositionRow>(6, x => x.altitude)));

    private static readonly Dictionary<string, object?> PositionValues = new()
    {
        ["sid"] = (ushort)1,
        ["lat"] = 500_000_000,
        ["lon"] = 300_000_000,
        ["profile"] = (byte)1,
    };

    private const string GoldenHex = "4001000065cd1d00a3e1110100";
    private const string Ac4Hex = "02070000000800000009000000";

    [Fact]
    public void Ac1_SchemeReplacesPacket()
    {
        Assert.Null(typeof(Packbin.Scheme<MarkerRow>).Assembly.GetType("Packbin.Packet"));
        Assert.Null(typeof(Packbin.Scheme<MarkerRow>).Assembly.GetType("Packbin.BinaryPacker"));
        Assert.Null(typeof(Packbin.Scheme<MarkerRow>).Assembly.GetType("Packbin.TypeNum"));
        var scheme = new Scheme<MarkerRow>(32, Field.U8<MarkerRow>(0, x => x.sid));
        Assert.Equal(32, scheme.TypeNumber);
        Assert.Single(scheme.Fields);
        Assert.ThrowsAny<ArgumentException>(() => new Scheme<MarkerRow>(-1, Field.U8<MarkerRow>(0, x => x.sid)));
        Assert.ThrowsAny<ArgumentException>(() => new Scheme<MarkerRow>(256, Field.U8<MarkerRow>(0, x => x.sid)));
        var bytes = Pack.Run(scheme, new MarkerRow { sid = 23 });
        Assert.Equal("2017", Convert.ToHexString(bytes).ToLowerInvariant());
    }

    [Fact]
    public void Ac2_RowHasNoTypeMember()
    {
        var bytes = Pack.Run(PositionScheme, PositionValues);
        Assert.Equal(GoldenHex, Convert.ToHexString(bytes).ToLowerInvariant());
        var fixture = ParseHex(File.ReadAllText(FindGoldenFixture()).Trim());
        Assert.Equal(0, MismatchedBytes(bytes, fixture));
        Assert.Null(typeof(PositionRow).GetProperty("type"));
        Assert.Null(typeof(PositionRow).GetField("type"));
        var back = Unpack.Run(PositionScheme, bytes);
        Assert.True(back.Ok);
        Assert.NotNull(back.Value);
        Assert.Equal((ushort)1, back.Value.sid);
        Assert.Equal(500_000_000, back.Value.lat);
        Assert.Equal(300_000_000, back.Value.lon);
        Assert.Equal((byte)1, back.Value.profile);
    }

    [Fact]
    public void Ac3_KnownSchemeChecksLeadingByte()
    {
        var scheme = new Scheme<MarkerRow>(1, Field.U8<MarkerRow>(0, x => x.sid));
        var back = Unpack.Run(scheme, ParseHex("0217"));
        Assert.False(back.Ok);
        Assert.Null(back.Value);
        var mismatch = Assert.IsType<TypeMismatch>(back.Error);
        Assert.Equal(1, mismatch.Expected);
        Assert.Equal(2, mismatch.Actual);
    }

    [Fact]
    public void Ac4_UnknownBufferCallsMatchingHandler()
    {
        UserModifiedEvent? modified = null;
        UserPositionEvent? position = null;
        var err = Unpack.Run(
            ParseHex(Ac4Hex),
            ModifiedScheme.On(ev => modified = ev),
            PositionEventScheme.On(ev => position = ev));
        Assert.Null(err);
        Assert.Null(modified);
        Assert.NotNull(position);
        Assert.Equal(7, position.userId);
        Assert.Equal(8, position.latitude);
        Assert.Equal(9, position.longitude);
        Assert.Null(typeof(UserPositionEvent).GetProperty("type"));
        Assert.Null(typeof(UserPositionEvent).GetField("type"));
        var packed = Pack.Run(PositionEventScheme, new UserPositionEvent
        {
            userId = 7,
            latitude = 8,
            longitude = 9,
        });
        Assert.Equal(Ac4Hex, Convert.ToHexString(packed).ToLowerInvariant());
    }

    [Fact]
    public void Ac5_UnknownTypeNumber()
    {
        var modifiedRan = false;
        var positionRan = false;
        var err = Unpack.Run(
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
            Field.I32<UserModifiedEvent>(0, x => x.userId),
            Field.Utf8<UserModifiedEvent>(1, x => x.userNameChange),
            Field.Utf8<UserModifiedEvent>(2, x => x.userEmailChange),
            Field.U8<UserModifiedEvent>(3, x => x.userStatusChange));
        Assert.ThrowsAny<ArgumentException>(() =>
            Unpack.Run(
                ParseHex(Ac4Hex),
                ModifiedScheme.On(_ => { }),
                other.On(_ => { })));
    }

    [Fact]
    public void EmptyBufferIsShortPacket()
    {
        var back = Unpack.Run(MarkerScheme, ReadOnlySpan<byte>.Empty);
        Assert.False(back.Ok);
        Assert.Null(back.Value);
        var missing = Assert.IsType<ShortPacket>(back.Error);
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
