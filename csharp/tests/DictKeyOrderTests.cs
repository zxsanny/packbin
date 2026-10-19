using System.Diagnostics;
using System.Text;
using Packbin;
using Xunit.Abstractions;

namespace Packbin.Tests;

// AZ-2713: a decoded dict key must be strictly greater than the key before it, by UTF-8 bytes.
public sealed class DictKeyOrderTests
{
    private sealed class MapRow
    {
        public Dictionary<string, object?>? M { get; set; }
    }

    private sealed class MapEl
    {
        public byte V { get; set; }
    }

    private static readonly Scheme<MapRow> MapScheme = new(1, Field.Dict((MapRow x) => x.M, Field.U8<MapEl>(0, e => e.V)));

    // A key as the raw payload (prefix 10, then the UTF-8 bytes; the keys here stay under 127 bytes) and a value 00.
    private static string Pair(string key)
    {
        var utf8 = Encoding.UTF8.GetBytes(key);
        return (utf8.Length + 1).ToString("x2") + "10" + Convert.ToHexString(utf8).ToLowerInvariant() + "00";
    }

    private static string Packet(params string[] keys) =>
        "01" + keys.Length.ToString("x2") + "00" + string.Concat(keys.Select(Pair));

    private static UnpackResult Read(string hex) => BinaryPacker.Read(MapScheme, Convert.FromHexString(hex));

    [Fact]
    public void Unpack_KeysAscendingByUtf8Bytes_AreAccepted()
    {
        // Arrange (U+FF5E is 3 bytes ef bd 9e, U+10000 is f0 90 80 80: ascending in UTF-8, descending in UTF-16 units)
        var packet = Packet("", "a", "ab", "b", "～", "\U00010000");

        // Act
        var read = Read(packet);

        // Assert
        Assert.Null(read.Error);
        Assert.Equal(6, ((Dictionary<string, object?>)read.Values["M"]!).Count);
    }

    [Theory]
    [InlineData("\U00010000", "～")]
    [InlineData("b", "a")]
    [InlineData("ab", "a")]
    [InlineData("a", "a")]
    [InlineData("～", "～")]
    public void Unpack_KeysNotStrictlyAscending_AreRefused(string first, string second)
    {
        // Arrange
        var packet = Packet(first, second);

        // Act
        var read = Read(packet);

        // Assert
        Assert.IsType<ShortPacket>(read.Error);
    }

    [Fact]
    public void Unpack_AKeyOutOfOrderBehindTwoGoodKeys_IsRefused()
    {
        // Arrange
        var packet = Packet("a", "c", "b");

        // Act
        var read = Read(packet);

        // Assert
        Assert.IsType<ShortPacket>(read.Error);
    }

    [Collection("Timing")]
    public sealed class Speed(ITestOutputHelper output)
    {
        [Fact]
        public void Unpack_65535DistinctAscendingKeys_TakesAtMostOneSecond()
        {
            // Arrange
            var map = new Dictionary<string, object?>();
            for (var i = 0; i < 65_535; i++)
                map[i.ToString("D5")] = (byte)(i & 0xff);
            var packet = BinaryPacker.Pack(MapScheme, new Dictionary<string, object?> { ["M"] = map });
            Assert.Null(BinaryPacker.Read(MapScheme, packet).Error);

            // Act
            var limit = Timing.Bound(1.0);
            var watch = Stopwatch.StartNew();
            var read = BinaryPacker.Read(MapScheme, packet);
            watch.Stop();

            // Assert
            output.WriteLine($"AZ-2713 AC-3: {watch.Elapsed.TotalMilliseconds:F0} ms to unpack 65535 keys ({packet.Length} bytes)");
            Assert.Null(read.Error);
            Assert.Equal(65_535, ((Dictionary<string, object?>)read.Values["M"]!).Count);
            limit.AssertWithin(watch.Elapsed, "unpack of 65535 keys");
        }
    }
}
