namespace Packbin.Tests;

public class FrameMacOnlyTests
{
    public static IEnumerable<object[]> Examples() => new[] { "E4.mac", "E5.mac" }.Select(n => new object[] { n });

    private static FrameVectors.Row RowOf(string name) => FrameVectors.Load(FrameVectors.FixturePath()).Single(r => r.Case == name);

    private static ReadOnlyMemory<byte>[] Split(byte[] message, params int[] cuts)
    {
        var parts = new List<ReadOnlyMemory<byte>>();
        var at = 0;
        foreach (var cut in cuts.Append(message.Length))
        {
            parts.Add(message.AsMemory(at, cut - at));
            at = cut;
        }
        return parts.ToArray();
    }

    [Theory]
    [MemberData(nameof(Examples))]
    public void Ac7_EverySplitInOneTwoAndThreePartsGivesTheSameTagAndItVerifies(string name)
    {
        var row = RowOf(name);
        var message = row.Bytes("message");
        var expected = row.Bytes("tag");
        using var key = MacKey.Derive(row.Bytes("key"), uint.Parse(row["epoch"]), row.Bytes("label"))!;
        var tag = new byte[expected.Length];
        var checkedSplits = 0;

        void Check(ReadOnlyMemory<byte>[] parts)
        {
            Array.Clear(tag);
            Assert.Null(key.Tag(parts, tag));
            Assert.Equal(expected, tag);
            Assert.True(key.Verify(parts, expected));
            checkedSplits++;
        }

        Check(Split(message));
        for (var i = 0; i <= message.Length; i++)
        {
            Check(Split(message, i));
            for (var j = i; j <= message.Length; j++)
                Check(Split(message, i, j));
        }
        Assert.Equal(1 + (message.Length + 1) + (message.Length + 1) * (message.Length + 2) / 2, checkedSplits);
        Assert.Null(key.Tag(message, tag));
        Assert.Equal(expected, tag);
    }

    [Theory]
    [MemberData(nameof(Examples))]
    public void Ac7_AFlippedTagBitVerifiesFalseAndAWrongLengthVerifiesFalse(string name)
    {
        var row = RowOf(name);
        var message = row.Bytes("message");
        var expected = row.Bytes("tag");
        using var key = MacKey.Derive(row.Bytes("key"), uint.Parse(row["epoch"]), row.Bytes("label"))!;

        for (var bit = 0; bit < expected.Length * 8; bit++)
        {
            var tag = (byte[])expected.Clone();
            tag[bit / 8] ^= (byte)(1 << (bit % 8));
            Assert.False(key.Verify(message, tag), $"bit {bit}");
        }

        Assert.True(key.Verify(message, expected));
        Assert.False(key.Verify(message, expected.AsSpan(0, expected.Length - 1)));
        Assert.False(key.Verify(message, ReadOnlySpan<byte>.Empty));
    }

    [Fact]
    public void Ac7_ALabelOfZeroOrThirtyThreeBytesAndALengthOfZeroTwoOrFiveAreBadValue()
    {
        var master = new byte[32];
        using var key = MacKey.Derive(master, 1, "net"u8)!;

        var noLabel = MacKey.Derive(master, 1, ReadOnlySpan<byte>.Empty);
        var longLabel = MacKey.Derive(master, 1, new byte[33]);
        var longestLabel = MacKey.Derive(master, 1, new byte[32]);
        var badEpoch = MacKey.Derive(master, 0x1000000, "net"u8);
        var badKey = MacKey.Derive(new byte[31], 1, "net"u8);

        Assert.Null(noLabel);
        Assert.Null(longLabel);
        Assert.NotNull(longestLabel);
        Assert.Null(badEpoch);
        Assert.Null(badKey);
        longestLabel!.Dispose();
        foreach (var n in new[] { 0, 2, 5, 33 })
        {
            var tag = new byte[n];
            Array.Fill(tag, FrameVectors.Sentinel);
            Assert.IsType<BadValue>(key.Tag("x"u8, tag));
            Assert.All(tag, b => Assert.Equal(FrameVectors.Sentinel, b));
            Assert.False(key.Verify("x"u8, tag));
        }
    }

    [Fact]
    public void Ac7_TheFourTagLengthsAreAcceptedAndAreTheLeadingBytesOfTheLongestTag()
    {
        using var key = MacKey.Derive(new byte[32], 3, "fp"u8)!;
        var full = new byte[32];
        Assert.Null(key.Tag("message"u8, full));

        foreach (var n in new[] { 4, 8, 16, 32 })
        {
            var tag = new byte[n];
            Assert.Null(key.Tag("message"u8, tag));
            Assert.Equal(full.AsSpan(0, n).ToArray(), tag);
            Assert.True(key.Verify("message"u8, tag));
        }
        Assert.Equal(3u, key.Epoch);
    }
}
