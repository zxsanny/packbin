using System.Text;
using Packbin;

namespace Packbin.Tests;

// AZ-4169: two keys that differ only in unpaired surrogates are one key on the wire (each half is written as U+FFFD,
// as the TypeScript, Dart and Java packages write it), and unpack refuses a repeated key, so pack refuses them: it
// never writes a packet its own unpack cannot read. The packets below were written by this package before the check.
public sealed class DictCollidingKeysTests
{
    private sealed class MapRow
    {
        public Dictionary<string, object?>? D { get; set; }
    }

    private sealed class MapEl
    {
        public byte V { get; set; }
    }

    private static readonly Scheme<MapRow> MapScheme = new(1, Field.Dict((MapRow x) => x.D, Field.U8<MapEl>(0, e => e.V)));

    private const string Message = "D: two keys are the same once an unpaired surrogate is written as U+FFFD";

    private static byte[] Pack(Dictionary<string, object?> keys) =>
        BinaryPacker.Pack(MapScheme, new Dictionary<string, object?> { ["D"] = keys });

    private static string Hex(byte[] bytes) => Convert.ToHexString(bytes).ToLowerInvariant();

    // The cases are built here, not in [InlineData] or [MemberData]: an attribute or a serialized theory row cannot carry
    // an unpaired surrogate (it comes back as U+FFFD).
    [Fact]
    public void Pack_KeysThatCollideAfterTheSwap_AreRefusedNamingTheDictionary()
    {
        // Arrange
        string[][] collisions =
        [
            ["\ud800", "\udc00"],
            ["\ufffd", "\ud800"],
            ["a", "\ud800", "\udc00"],
            ["\udc00\ud800", "\ufffd\ufffd"],
        ];

        foreach (var keys in collisions)
        {
            var map = new Dictionary<string, object?>();
            for (var i = 0; i < keys.Length; i++)
                map[keys[i]] = (byte)(i + 1);

            // Act
            var thrown = Assert.Throws<ArgumentException>(() => Pack(map));

            // Assert
            Assert.Equal(Message, thrown.Message);
        }
    }

    [Fact]
    public void Pack_KeysWithoutACollision_WriteTheBytesTheyAlwaysWrote()
    {
        // Arrange
        (string First, string Second, string Packet)[] cases =
        [
            ("\ud800", "\uffff", "0102000410efbfbd010410efbfbf02"),
            ("a", "\ud800", "010200021061010410efbfbd02"),
            ("?", "\ud800", "01020002103f010410efbfbd02"),
        ];

        foreach (var (first, second, packet) in cases)
        {
            var map = new Dictionary<string, object?> { [first] = (byte)1, [second] = (byte)2 };

            // Act
            var bytes = Pack(map);

            // Assert
            Assert.Equal(packet, Hex(bytes));
            Assert.Null(BinaryPacker.Read(MapScheme, bytes).Error);
        }
    }

    [Fact]
    public void Pack_OneLoneHalf_IsWrittenAsU_FFFD()
    {
        // Arrange
        var map = new Dictionary<string, object?> { ["\ud800"] = (byte)1 };

        // Act
        var bytes = Pack(map);
        var read = BinaryPacker.Read(MapScheme, bytes);

        // Assert
        Assert.Equal("0101000410efbfbd01", Hex(bytes));
        Assert.Equal(new[] { "�" }, ((Dictionary<string, object?>)read.Values["D"]!).Keys.ToArray());
    }

    [Fact]
    public void Pack_20000SeededDictionaries_NeverWritesAPacketItsOwnUnpackRefuses()
    {
        // Arrange: a fixed seed, so a failure replays
        var random = new Random(20261111);
        string[] alphabet = ["a", "z", "?", "\ud800", "\udbff", "\udc00", "\udfff", "�", "￿", "\U0001F600", ""];
        string Swap(string s) => Encoding.UTF8.GetString(Encoding.UTF8.GetBytes(s));
        var written = 0;
        var refused = 0;

        for (var n = 0; n < 20_000; n++)
        {
            var map = new Dictionary<string, object?>();
            for (var k = 1 + random.Next(4); k > 0; k--)
            {
                var key = new StringBuilder();
                for (var u = random.Next(4); u > 0; u--)
                    key.Append(alphabet[random.Next(alphabet.Length)]);
                map[key.ToString()] = (byte)(1 + random.Next(200));
            }
            var swapped = map.Keys.Select(Swap).ToList();
            var collides = swapped.Distinct().Count() != swapped.Count;

            // Act
            byte[]? packet = null;
            try
            {
                packet = Pack(map);
            }
            catch (ArgumentException e)
            {
                Assert.Equal(Message, e.Message);
            }

            // Assert
            if (packet is null)
            {
                Assert.True(collides, "refused without a collision");
                refused++;
                continue;
            }
            Assert.False(collides, "wrote a colliding dictionary");
            var read = BinaryPacker.Read(MapScheme, packet);
            Assert.Null(read.Error);
            Assert.Equal(
                swapped.OrderBy(x => x, StringComparer.Ordinal),
                ((Dictionary<string, object?>)read.Values["D"]!).Keys.OrderBy(x => x, StringComparer.Ordinal));
            written++;
        }
        Assert.True(written > 5_000 && refused > 500, $"{written} written, {refused} refused");
    }
}
