using System.Diagnostics;
using System.Reflection;
using Packbin;

namespace Packbin.Tests;

public class SchemeTests
{
    public sealed class MarkerRow
    {
        public byte sid { get; set; }
    }

    private static readonly Scheme<MarkerRow> MarkerRowScheme = Scheme<MarkerRow>.Of(
        TypeNum.Set(32),
        Field.U8("sid"));

    private static readonly Packet Position = Packet.Of(
        Field.U8("type"),
        Field.U16("sid"),
        Field.I32("lat"),
        Field.I32("lon"),
        Field.U8("profile"),
        Field.Flags("motion", Field.U16("heading"), Field.U8("speed"), Field.I16("altitude")));

    private static readonly Dictionary<string, object?> PositionValues = new()
    {
        ["type"] = (byte)0x40,
        ["sid"] = (ushort)1,
        ["lat"] = 500_000_000,
        ["lon"] = 300_000_000,
        ["profile"] = (byte)1,
    };

    [Fact]
    public void Ac1_PackTakesTheScheme()
    {
        var row = new MarkerRow { sid = 23 };
        var bytes = BinaryPacker.Pack(MarkerRowScheme, row);
        Assert.Equal("2017", Convert.ToHexString(bytes).ToLowerInvariant());
        Assert.Equal(new byte[] { 0x20, 0x17 }, bytes);
    }

    [Fact]
    public void Ac2_UnpackTakesTheSameScheme()
    {
        var back = BinaryPacker.Unpack(MarkerRowScheme, ParseHex("2017"));
        Assert.True(back.Ok);
        Assert.NotNull(back.Value);
        Assert.Equal((byte)23, back.Value.sid);
        Assert.Null(typeof(MarkerRow).GetProperty("type"));
        Assert.Null(typeof(MarkerRow).GetField("type"));
        Assert.Single(typeof(MarkerRow).GetProperties(BindingFlags.Instance | BindingFlags.Public));
    }

    [Fact]
    public void Ac3_SchemeArgumentIsRequired()
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

    [Fact]
    public void Ac4_WrongTypeByte()
    {
        var back = BinaryPacker.Unpack(MarkerRowScheme, ParseHex("2117"));
        Assert.False(back.Ok);
        Assert.Null(back.Value);
        var mismatch = Assert.IsType<TypeMismatch>(back.Error);
        Assert.Equal(32, mismatch.Expected);
        Assert.Equal(33, mismatch.Actual);
    }

    [Fact]
    public void Ac5_UntypedPath()
    {
        var bytes = Pack.Run(Position, PositionValues);
        var fixture = ParseHex(File.ReadAllText(FindGoldenFixture()).Trim());
        Assert.Equal(0, MismatchedBytes(bytes, fixture));
    }

    [Fact]
    public void Ac6_RowStaysData()
    {
        var source = File.ReadAllText(FindMarkerRowSource());
        var classStart = source.IndexOf("public sealed class MarkerRow", StringComparison.Ordinal);
        Assert.True(classStart >= 0);
        var brace = source.IndexOf('{', classStart);
        var depth = 0;
        var end = brace;
        for (var i = brace; i < source.Length; i++)
        {
            if (source[i] == '{')
                depth++;
            else if (source[i] == '}')
            {
                depth--;
                if (depth == 0)
                {
                    end = i;
                    break;
                }
            }
        }
        var body = source[classStart..(end + 1)];
        Assert.Contains("public byte sid", body);
        Assert.DoesNotContain("Scheme", body);
        Assert.DoesNotContain("Pack", body);
        Assert.DoesNotContain("interface", body, StringComparison.OrdinalIgnoreCase);
        Assert.DoesNotContain("IPack", body);
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

    private static string FindMarkerRowSource()
    {
        var dir = new DirectoryInfo(AppContext.BaseDirectory);
        while (dir is not null)
        {
            var path = Path.Combine(dir.FullName, "csharp", "tests", "SchemeTests.cs");
            if (File.Exists(path))
                return path;
            path = Path.Combine(dir.FullName, "tests", "SchemeTests.cs");
            if (File.Exists(path))
                return path;
            dir = dir.Parent;
        }
        throw new FileNotFoundException("SchemeTests.cs");
    }
}
