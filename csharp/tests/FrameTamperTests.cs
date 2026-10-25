namespace Packbin.Tests;

public class FrameTamperTests
{
    public static IEnumerable<object[]> Examples() => new[] { "E1", "E2", "E3" }.Select(n => new object[] { n });

    private static FrameExample Example(string name) => FrameExample.Worked().Single(e => e.Name == name);

    private static void AssertRefused(FrameSession session, FrameDirection direction, MsgContext message, byte[] ad, byte[] body, int clearLength, string what)
    {
        var window = new ReplayWindow(50, 0b111);
        var plain = new byte[300];
        Array.Fill(plain, FrameVectors.Sentinel);

        var error = session.Open(direction, message, ad, body, clearLength, plain, out _, window, 51);

        Assert.True(error is TagMismatch, $"{what}: {FrameVectors.KindName(error)}");
        Assert.All(plain, b => Assert.Equal(FrameVectors.Sentinel, b));
        Assert.Equal((50UL, 0b111UL), (window.Top, window.Bits));
    }

    [Theory]
    [MemberData(nameof(Examples))]
    public void Ac4_TheUntouchedExampleOpens(string name)
    {
        var example = Example(name);
        using var session = example.Session();
        var plain = new byte[300];

        var error = session.Open(example.Direction, example.Context, example.Ad, example.Body, example.ClearLength, plain, out var opened);

        Assert.Null(error);
        Assert.Equal(example.Plain, plain.AsSpan(0, opened.PlainLength).ToArray());
    }

    [Theory]
    [MemberData(nameof(Examples))]
    public void Ac4_EverySingleBitOfAdClearCiphertextAndTagGivesTagMismatch(string name)
    {
        var example = Example(name);
        using var session = example.Session();

        for (var bit = 0; bit < example.Body.Length * 8; bit++)
        {
            var body = (byte[])example.Body.Clone();
            body[bit / 8] ^= (byte)(1 << (bit % 8));
            AssertRefused(session, example.Direction, example.Context, example.Ad, body, example.ClearLength, $"{name} body bit {bit}");
        }
        for (var bit = 0; bit < example.Ad.Length * 8; bit++)
        {
            var ad = (byte[])example.Ad.Clone();
            ad[bit / 8] ^= (byte)(1 << (bit % 8));
            AssertRefused(session, example.Direction, example.Context, ad, example.Body, example.ClearLength, $"{name} ad bit {bit}");
        }
    }

    [Theory]
    [MemberData(nameof(Examples))]
    public void Ac4_AChangedMsgIdKindDirectionEpochOrKeyGivesTagMismatch(string name)
    {
        var example = Example(name);
        using var session = example.Session();

        for (var bit = 0; bit < 64; bit++)
        {
            var id = (byte[])example.MsgId.Clone();
            id[bit / 8] ^= (byte)(1 << (bit % 8));
            AssertRefused(session, example.Direction, new MsgContext(id, example.Kind), example.Ad, example.Body, example.ClearLength, $"msg_id bit {bit}");
        }
        AssertRefused(session, example.Direction, new MsgContext(example.MsgId, example.Kind ^ 1), example.Ad, example.Body, example.ClearLength, "kind");
        foreach (var other in new[] { FrameDirection.Up, FrameDirection.Down, FrameDirection.Group }.Where(d => d != example.Direction))
            AssertRefused(session, other, example.Context, example.Ad, example.Body, example.ClearLength, $"direction {other}");
        using (var otherEpoch = example.Session(epoch: example.Epoch + 1))
            AssertRefused(otherEpoch, example.Direction, example.Context, example.Ad, example.Body, example.ClearLength, "epoch");
        var key = (byte[])example.Key.Clone();
        key[0] ^= 1;
        using (var otherKey = example.Session(key: key))
            AssertRefused(otherKey, example.Direction, example.Context, example.Ad, example.Body, example.ClearLength, "key");
    }

    [Theory]
    [MemberData(nameof(Examples))]
    public void Ac4_AWrongClearLengthGivesTagMismatchOrShortPacketAndNothingIsWritten(string name)
    {
        var example = Example(name);
        using var session = example.Session();

        AssertRefused(session, example.Direction, example.Context, example.Ad, example.Body, example.ClearLength + 1, "clear_len up");
        if (example.ClearLength > 0)
            AssertRefused(session, example.Direction, example.Context, example.Ad, example.Body, example.ClearLength - 1, "clear_len down");
    }
}
