using System.Diagnostics;
using System.Text;
using Packbin;
using Xunit.Abstractions;

namespace Packbin.Tests;

public partial class CompactTextTests
{
    // ---- AC-5: limits and headers

    [Fact]
    public void Ac5_Pack_65535Bytes_IsAcceptedAnd65536Refused()
    {
        // Arrange
        var fits = new string('中', 21_845);
        var over = fits + "a";

        // Act
        var raw = PackName(fits);
        var error = Assert.Throws<ArgumentException>(() => PackName(over));
        var read = BinaryPacker.Read(Single, raw);

        // Assert
        Assert.Equal(1 + 3 + 65_536, raw.Length);
        Assert.StartsWith("01" + "808004" + "10", Hex(raw));
        Assert.Contains("Name", error.Message);
        Assert.Null(read.Error);
        Assert.Equal(fits, read.Values["Name"]);
    }

    [Fact]
    public void Ac5_Pack_CompactTextOf65535Bytes_RoundTrips()
    {
        // Arrange
        var text = new string('a', 65_535);

        // Act
        var raw = PackName(text);
        var read = BinaryPacker.Read(Single, raw);

        // Assert
        Assert.True(raw.Length < 40_000);
        Assert.Null(read.Error);
        Assert.Equal(text, read.Values["Name"]);
    }

    [Theory]
    [InlineData(42, "", 1, "7f10")]
    [InlineData(42, "a", 2, "800110")]
    public void Ac5_Pack_PayloadOf127And128Bytes_HasAOneAndATwoByteHeader(int cjk, string tail, int head, string prefix)
    {
        // Arrange (a character no table codes: the raw payload is 1 + the UTF-8 bytes, 127 or 128 here)
        var text = new string('中', cjk) + tail;

        // Act
        var raw = PackName(text);

        // Assert
        Assert.Equal(1 + head + (head == 1 ? 127 : 128), raw.Length);
        Assert.StartsWith("01" + prefix, Hex(raw));
    }

    [Fact]
    public void Ac5_Pack_MaxBytes_StillBoundsThePacket()
    {
        // Arrange
        var text = new string('中', 20) + "a";
        var fits = new Scheme<NameRow>(1, Field.Utf8<NameRow>(0, x => x.Name)).WithLimits(maxBytes: 64);
        var tight = new Scheme<NameRow>(1, Field.Utf8<NameRow>(0, x => x.Name)).WithLimits(maxBytes: 63);

        // Act
        var raw = BinaryPacker.Pack(fits, new Dictionary<string, object?> { ["Name"] = text });
        var error = Assert.Throws<ArgumentException>(() =>
            BinaryPacker.Pack(tight, new Dictionary<string, object?> { ["Name"] = text }));

        // Assert
        Assert.Equal(64, raw.Length);
        Assert.Contains("'Name': the packet would be 64 bytes, above the limit of 63 bytes", error.Message);
    }

    // ---- AC-6: invalid UTF-8 refused

    public static IEnumerable<object[]> Utf8BadRows() =>
        TextVectors.Of("bad").Where(r => r.Args[0] == "utf8").Select(r => new object[] { r.Id });

    [Theory]
    [MemberData(nameof(Utf8BadRows))]
    public void Ac6_Unpack_InvalidUtf8_IsRefusedNamingTheField(string id)
    {
        // Arrange
        var row = TextVectors.Find(id);

        // Act
        var got = BinaryPacker.Read(Single, Packet(row.Args[1]));

        // Assert
        Assert.Equal("Name", Assert.IsType<ShortPacket>(got.Error).Field);
    }

    // ---- AC-7: dictionary keys

    private sealed class MapRow
    {
        public Dictionary<string, object?>? M { get; set; }
    }

    private sealed class MapEl
    {
        public byte V { get; set; }
    }

    private static readonly Scheme<MapRow> MapScheme = new(1, Field.Dict((MapRow x) => x.M, Field.U8<MapEl>(0, e => e.V)));

    [Fact]
    public void Ac7_Pack_KeysInTwoOrders_GiveIdenticalBytesSortedByUtf8()
    {
        // Arrange
        var first = new Dictionary<string, object?>();
        foreach (var key in new[] { "яблуко", "b", "Карта", "a", "канал" })
            first[key] = (byte)key.Length;
        var second = new Dictionary<string, object?>();
        foreach (var key in new[] { "a", "канал", "яблуко", "Карта", "b" })
            second[key] = (byte)key.Length;

        // Act
        var one = BinaryPacker.Pack(MapScheme, new Dictionary<string, object?> { ["M"] = first });
        var two = BinaryPacker.Pack(MapScheme, new Dictionary<string, object?> { ["M"] = second });
        var read = BinaryPacker.Read(MapScheme, one);

        // Assert (the pairs are in the order of the key's UTF-8 bytes, each key a compact field)
        var sorted = first.Keys.OrderBy(k => Encoding.UTF8.GetBytes(k), Comparer<byte[]>.Create(Compare)).ToList();
        var expected = "01" + "0500" + string.Concat(sorted.Select(k => Hex(PackName(k)[1..]) + ((byte)k.Length).ToString("x2")));
        Assert.Equal(expected, Hex(one));
        Assert.Equal(Hex(one), Hex(two));
        Assert.Null(read.Error);
        Assert.Equal(5, ((Dictionary<string, object?>)read.Values["M"]!).Count);
    }

    private static int Compare(byte[] a, byte[] b) => a.AsSpan().SequenceCompareTo(b);

    [Fact]
    public void Ac7_Unpack_ARepeatedDecodedKey_IsRefused()
    {
        // Arrange (the key "a" twice, once as the compact field and once as the same text; both decode to "a")
        var a = Hex(PackName("a")[1..]);
        var packet = Convert.FromHexString("01" + "0200" + a + "00" + a + "00");

        // Act
        var read = BinaryPacker.Read(MapScheme, packet);

        // Assert
        var error = Assert.IsType<ShortPacket>(read.Error);
        Assert.Equal("M", error.Field);
    }

    // ---- AC-8: speed

    [Collection("Timing")]
    public sealed class Speed(ITestOutputHelper output)
    {
        [Fact]
        public void Ac8_TwentyCharacterUkrainianString_100000RoundTripsWithinOneSecond()
        {
            // Arrange
            var scheme = new Scheme<NameRow>(1, Field.Utf8<NameRow>(0, x => x.Name));
            var row = new NameRow { Name = "Доброго ранку, друже" };
            RoundTrip(scheme, row);

            // Act
            var limit = Timing.Bound(1.0);
            var watch = Stopwatch.StartNew();
            for (var i = 0; i < 100_000; i++)
                RoundTrip(scheme, row);
            watch.Stop();

            // Assert
            output.WriteLine($"AZ-2650 AC-8: {watch.Elapsed.TotalMilliseconds:F0} ms for 100000 round trips of 20 characters");
            limit.AssertWithin(watch.Elapsed, "100000 round trips of 20 characters");
        }

        private static void RoundTrip(Scheme<NameRow> scheme, NameRow row)
        {
            NameRow? got = null;
            var bytes = BinaryPacker.Pack(scheme, row);
            var error = BinaryPacker.Unpack(bytes, scheme.On(r => got = r));
            Assert.Null(error);
            Assert.Equal(row.Name, got!.Name);
        }
    }
}
