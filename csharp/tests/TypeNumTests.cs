using System.Globalization;
using Packbin;

namespace Packbin.Tests;

public class TypeNumTests
{
    private static readonly Packet Marker = Packet.Of(TypeNum.Set(32), Field.U8("sid"));

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

    private const string GoldenHex = "4001000065cd1d00a3e1110100";

    [Fact]
    public void Ac1_ConstantU8IsNotAValue()
    {
        var bytes = Pack.Run(Marker, new Dictionary<string, object?> { ["sid"] = (byte)23 });
        Assert.Equal("2017", Convert.ToHexString(bytes).ToLowerInvariant());
        Assert.Equal(new byte[] { 0x20, 0x17 }, bytes);
    }

    [Fact]
    public void Ac2_UnpackDropsTheConstant()
    {
        var got = Unpack.Run(Marker, ParseHex("2017"));
        Assert.Null(got.Error);
        Assert.Equal(23, Convert.ToInt32(got.Values["sid"]!, CultureInfo.InvariantCulture));
        Assert.False(got.Values.ContainsKey("type"));
        Assert.Single(got.Values);
    }

    [Fact]
    public void Ac3_WrongTypeByte()
    {
        var got = Unpack.Run(Marker, ParseHex("2117"));
        Assert.Empty(got.Values);
        var mismatch = Assert.IsType<TypeMismatch>(got.Error);
        Assert.Equal(32, mismatch.Expected);
        Assert.Equal(33, mismatch.Actual);
    }

    [Fact]
    public void Ac4_AbsentTypeNumber()
    {
        var bytes = Pack.Run(Position, PositionValues);
        var fixture = ParseHex(File.ReadAllText(FindGoldenFixture()).Trim());
        Assert.Equal(0, MismatchedBytes(bytes, fixture));
        Assert.Equal(GoldenHex, Convert.ToHexString(bytes).ToLowerInvariant());
        var got = Unpack.Run(Position, fixture);
        Assert.Null(got.Error);
        Assert.Equal((byte)0x40, Convert.ToByte(got.Values["type"]!, CultureInfo.InvariantCulture));
    }

    [Fact]
    public void Ac5_SchemeRejected()
    {
        Assert.ThrowsAny<ArgumentException>(() =>
            Packet.Of(Field.U8("sid"), TypeNum.Set(32)));
        Assert.ThrowsAny<ArgumentException>(() =>
            Packet.Of(TypeNum.Set(32), TypeNum.Set(33), Field.U8("sid")));
        Assert.ThrowsAny<ArgumentException>(() =>
            Packet.Of(Field.Flags("f", TypeNum.Set(32))));
        Assert.ThrowsAny<ArgumentException>(() =>
            Packet.Of(Field.When(Condition.Eq("x", 1), TypeNum.Set(32))));
        Assert.ThrowsAny<ArgumentException>(() =>
            Packet.Of(Field.Repeat(TypeNum.Set(32))));
        Assert.ThrowsAny<ArgumentException>(() =>
            Packet.Of(Field.Group("g", TypeNum.Set(32))));
        Assert.ThrowsAny<ArgumentException>(() =>
            Packet.Of(Field.List("xs", TypeNum.Set(32))));
        Assert.ThrowsAny<ArgumentException>(() =>
            Packet.Of(Field.Dict("d", TypeNum.Set(32))));
        Assert.ThrowsAny<ArgumentException>(() => TypeNum.Set(256));
        Assert.ThrowsAny<ArgumentException>(() => TypeNum.Set(-1));
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
}
