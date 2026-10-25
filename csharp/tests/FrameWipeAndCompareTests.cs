namespace Packbin.Tests;

public class FrameWipeAndCompareTests
{
    private static readonly byte[] Key = Enumerable.Repeat((byte)0x42, 32).ToArray();

    [Fact]
    public void Ac9_TheCompareHelperSeparatesEqualFirstByteAndLastByteDifferences()
    {
        byte[] tag = [1, 2, 3, 4, 5, 6, 7, 8];
        var first = (byte[])tag.Clone();
        first[0] ^= 0x80;
        var last = (byte[])tag.Clone();
        last[^1] ^= 1;

        Assert.True(FrameCrypto.FixedEquals(tag, (byte[])tag.Clone()));
        Assert.False(FrameCrypto.FixedEquals(tag, first));
        Assert.False(FrameCrypto.FixedEquals(tag, last));
        Assert.False(FrameCrypto.FixedEquals(tag, tag.AsSpan(0, 7)));
        Assert.True(FrameCrypto.FixedEquals([], []));
    }

    [Fact]
    public void Ac9_TheCompareHelperHasNoEarlyReturnInItsLoop()
    {
        var source = File.ReadAllText(TextVectors.RepositoryFile("csharp", "FrameCrypto.cs"));
        var start = source.IndexOf("internal static bool FixedEquals", StringComparison.Ordinal);
        var body = source.Substring(start, source.IndexOf("\n    }", start, StringComparison.Ordinal) - start);

        var loop = body.Substring(body.IndexOf("for (", StringComparison.Ordinal));
        var returns = body.Split("return ").Length - 1;

        Assert.DoesNotContain("return", loop.Substring(0, loop.LastIndexOf("return difference", StringComparison.Ordinal)));
        Assert.DoesNotContain("break", body);
        Assert.Equal(2, returns);
    }

    [Fact]
    public void Ac10_AReleasedSessionHasZeroedKeysAndRefusesEveryCall()
    {
        var session = FrameSession.Load(Key, 9, new FrameConfig(8, FrameDirections.All))!;
        Assert.True(session.SetPrevious(Key, 8));
        var arrays = session.KeyArrays();
        Assert.Equal(12, arrays.Count);
        Assert.Contains(arrays, a => a.Any(b => b != 0));
        var message = new MsgContext(new byte[8], 1);
        var body = new byte[32];
        Assert.Null(session.Seal(FrameDirection.Up, message, [], [], new byte[4], body, out _));

        session.Dispose();
        var output = new byte[32];
        Array.Fill(output, FrameVectors.Sentinel);
        var seal = session.Seal(FrameDirection.Up, message, [], [], new byte[4], output, out var written);
        var open = session.Open(FrameDirection.Up, message, [], body, 0, output, out _);

        Assert.All(arrays, a => Assert.All(a, b => Assert.Equal(0, b)));
        Assert.IsType<BadValue>(seal);
        Assert.IsType<BadValue>(open);
        Assert.Equal(0, written);
        Assert.All(output, b => Assert.Equal(FrameVectors.Sentinel, b));
        Assert.False(session.SetPrevious(Key, 1));
        session.Dispose();
    }

    [Fact]
    public void Ac10_AReleasedMacKeyHasAZeroedKeyAndRefusesEveryCall()
    {
        var mac = MacKey.Derive(Key, 9, "net"u8)!;
        var array = mac.KeyArray;
        var tag = new byte[4];
        Assert.Null(mac.Tag("m"u8, tag));
        Assert.Contains(array, b => b != 0);

        mac.Dispose();
        var after = new byte[4];
        var error = mac.Tag("m"u8, after);

        Assert.All(array, b => Assert.Equal(0, b));
        Assert.IsType<BadValue>(error);
        Assert.False(mac.Verify("m"u8, tag));
        Assert.All(after, b => Assert.Equal(0, b));
    }

    [Fact]
    public void Ac10_ReplacingThePreviousSlotZeroesTheOldOne()
    {
        using var session = FrameSession.Load(Key, 9, new FrameConfig(4, FrameDirections.Up))!;
        Assert.True(session.SetPrevious(Key, 1));
        var old = session.KeyArrays().Skip(2).ToList();

        Assert.True(session.SetPrevious(Key, 2));

        Assert.All(old, a => Assert.All(a, b => Assert.Equal(0, b)));
        Assert.Contains(session.KeyArrays().Skip(2), a => a.Any(b => b != 0));
    }
}
