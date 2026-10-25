namespace Packbin.Tests;

public class FrameRefusalTests
{
    private static readonly byte[] Key = Enumerable.Range(0, 32).Select(i => (byte)i).ToArray();
    private static readonly byte[] Id = [1, 2, 3, 4, 5, 6, 7, 8];

    private static FrameSession Session(int tag = 4, FrameDirections dirs = FrameDirections.All) =>
        FrameSession.Load(Key, 5, new FrameConfig(tag, dirs))!;

    private static byte[] Sentinels(int n)
    {
        var buffer = new byte[n];
        Array.Fill(buffer, FrameVectors.Sentinel);
        return buffer;
    }

    private static void AssertUntouched(byte[] buffer) => Assert.All(buffer, b => Assert.Equal(FrameVectors.Sentinel, b));

    private static object? Seal(FrameSession s, FrameDirection d, int kind, int ad, int clear, int plain, byte[] output, out int written) =>
        s.Seal(d, new MsgContext(Id, kind), new byte[ad], new byte[clear], new byte[plain], output, out written);

    [Fact]
    public void Ac8_LoadRefusesWhatTheContractCallsBadValue()
    {
        Assert.Null(FrameSession.Load(Key, 0x1000000, new FrameConfig(4, FrameDirections.All)));
        Assert.NotNull(FrameSession.Load(Key, 0xFFFFFF, new FrameConfig(4, FrameDirections.All)));
        foreach (var tag in new[] { 0, 1, 5, 12, 17, 32, -4 })
            Assert.Null(FrameSession.Load(Key, 1, new FrameConfig(tag, FrameDirections.All)));
        Assert.Null(FrameSession.Load(Key.AsSpan(0, 31), 1, new FrameConfig(4, FrameDirections.All)));
        Assert.Null(FrameSession.Load(Key, 1, new FrameConfig(4, FrameDirections.None)));
    }

    [Theory]
    [InlineData(0)]
    [InlineData(4)]
    [InlineData(255)]
    public void Ac8_ADirectionOutsideOneToThreeIsBadValueForSealAndOpen(int direction)
    {
        using var session = Session();
        var output = Sentinels(64);

        var seal = Seal(session, (FrameDirection)direction, 1, 0, 0, 4, output, out var written);
        var open = session.Open((FrameDirection)direction, new MsgContext(Id, 1), [], new byte[16], 0, output, out _);

        Assert.IsType<BadValue>(seal);
        Assert.IsType<BadValue>(open);
        Assert.Equal(0, written);
        AssertUntouched(output);
    }

    [Fact]
    public void Ac8_ADirectionNotLoadedAKindAbove15AndNoMsgIdAreBadValue()
    {
        using var session = Session(4, FrameDirections.Up);
        var output = Sentinels(64);

        var unloaded = Seal(session, FrameDirection.Down, 1, 0, 0, 4, output, out _);
        var kind16 = Seal(session, FrameDirection.Up, 16, 0, 0, 4, output, out _);
        var kindNegative = Seal(session, FrameDirection.Up, -1, 0, 0, 4, output, out _);
        var noId = session.Seal(FrameDirection.Up, default, [], [], new byte[4], output, out _);
        var shortId = session.Seal(FrameDirection.Up, new MsgContext(new byte[7], 1), [], [], new byte[4], output, out _);
        var openKind = session.Open(FrameDirection.Up, new MsgContext(Id, 16), [], new byte[16], 0, output, out _);
        var openUnloaded = session.Open(FrameDirection.Group, new MsgContext(Id, 1), [], new byte[16], 0, output, out _);
        var openNegative = session.Open(FrameDirection.Up, new MsgContext(Id, 1), [], new byte[16], -1, output, out _);

        Assert.All(new[] { unloaded, kind16, kindNegative, noId, shortId, openKind, openUnloaded, openNegative }, e => Assert.IsType<BadValue>(e));
        AssertUntouched(output);
    }

    [Fact]
    public void Ac8_ATooLongAdOrBodyIsTooLongForSealAndOpenBeforeAnyHashing()
    {
        using var session = Session();
        var output = Sentinels(600);

        var sealAd = Seal(session, FrameDirection.Up, 1, 256, 0, 4, output, out _);
        var sealBody = Seal(session, FrameDirection.Up, 1, 0, 100, 152, output, out _);
        var sealHuge = Seal(session, FrameDirection.Up, 1, 0, 0, 300, output, out _);
        var openAd = session.Open(FrameDirection.Up, new MsgContext(Id, 1), new byte[256], new byte[20], 0, output, out _);
        var openBody = session.Open(FrameDirection.Up, new MsgContext(Id, 1), [], new byte[256], 0, output, out _);
        var openClear = session.Open(FrameDirection.Up, new MsgContext(Id, 1), [], new byte[20], 256, output, out _);

        Assert.All(new[] { sealAd, sealBody, sealHuge, openAd, openBody, openClear }, e => Assert.IsType<TooLong>(e));
        Assert.Equal(255, ((TooLong)sealBody!).Limit);
        Assert.Equal(0, session.MacComputations);
        AssertUntouched(output);
    }

    [Fact]
    public void Ac8_TheLongestBodyOf255BytesSealsAndOpens()
    {
        using var session = Session();
        var output = new byte[255];

        var error = Seal(session, FrameDirection.Up, 15, 255, 10, 241, output, out var written);
        var plain = new byte[300];
        var open = session.Open(FrameDirection.Up, new MsgContext(Id, 15), new byte[255], output, 10, plain, out var opened);

        Assert.Null(error);
        Assert.Equal(255, written);
        Assert.Null(open);
        Assert.Equal(241, opened.PlainLength);
    }

    [Fact]
    public void Ac8_AShortOutputIsBufferFullAndSealWritesNothing()
    {
        using var session = Session();
        var output = Sentinels(15);

        var error = Seal(session, FrameDirection.Up, 1, 0, 0, 12, output, out var written);

        Assert.Equal(16, Assert.IsType<BufferFull>(error).Needed);
        Assert.Equal(0, written);
        AssertUntouched(output);
        var body = new byte[16];
        Assert.Null(Seal(session, FrameDirection.Up, 1, 0, 0, 12, body, out _));
        var plain = Sentinels(11);
        var open = session.Open(FrameDirection.Up, new MsgContext(Id, 1), new byte[0], body, 0, plain, out _);
        Assert.Equal(12, Assert.IsType<BufferFull>(open).Needed);
        AssertUntouched(plain);
    }

    [Fact]
    public void Ac8_ABodyShorterThanClearPlusTagIsShortPacket()
    {
        using var session = Session(8);
        var output = Sentinels(32);

        var noTag = session.Open(FrameDirection.Up, new MsgContext(Id, 1), [], new byte[7], 0, output, out _);
        var shortClear = session.Open(FrameDirection.Up, new MsgContext(Id, 1), [], new byte[10], 3, output, out _);
        var empty = session.Open(FrameDirection.Up, new MsgContext(Id, 1), [], [], 0, output, out _);

        var first = Assert.IsType<ShortPacket>(noTag);
        Assert.Equal((8, 7), (first.Needed, first.Left));
        Assert.Equal(11, Assert.IsType<ShortPacket>(shortClear).Needed);
        Assert.IsType<ShortPacket>(empty);
        AssertUntouched(output);
    }

    [Fact]
    public void Ac8_ADuplicateAndATooOldCounterAreTheirOwnKindsAndAnUnmatchedTagIsTagMismatch()
    {
        using var session = Session();
        var window = new ReplayWindow(100, 1);
        var output = Sentinels(32);

        var duplicate = session.Open(FrameDirection.Up, new MsgContext(Id, 1), [], new byte[8], 0, output, out _, window, 100);
        var old = session.Open(FrameDirection.Up, new MsgContext(Id, 1), [], new byte[8], 0, output, out _, window, 30);
        var mismatch = session.Open(FrameDirection.Up, new MsgContext(Id, 1), [], new byte[8], 0, output, out _, window, 101);

        Assert.IsType<Duplicate>(duplicate);
        Assert.IsType<TooOld>(old);
        Assert.IsType<TagMismatch>(mismatch);
        Assert.Equal((100UL, 1UL), (window.Top, window.Bits));
        AssertUntouched(output);
    }

    [Fact]
    public void Ac8_ASessionOfOneTagLengthOpensNothingOfAnother()
    {
        using var four = Session(4);
        using var eight = Session(8);
        var body = new byte[32];
        Assert.Null(Seal(four, FrameDirection.Up, 1, 0, 0, 10, body, out var written));

        var open = eight.Open(FrameDirection.Up, new MsgContext(Id, 1), [], body.AsSpan(0, written), 0, new byte[32], out _);

        Assert.IsType<TagMismatch>(open);
    }

    [Fact]
    public void Ac8_ARandomHostileCorpusCausesNoUnhandledException()
    {
        var random = new Random(0x3232_0001);
        using var session = Session(8);
        Assert.True(session.SetPrevious(Key, 4));
        var kinds = new Dictionary<string, int>();
        var window = new ReplayWindow();

        for (var i = 0; i < 1000; i++)
        {
            var body = new byte[random.Next(0, 301)];
            random.NextBytes(body);
            var ad = new byte[random.Next(0, 300)];
            random.NextBytes(ad);
            var id = new byte[8];
            random.NextBytes(id);
            var message = new MsgContext(id, random.Next(-2, 20));
            var direction = (FrameDirection)random.Next(0, 6);
            var clearLength = random.Next(-3, 300);
            var plain = Sentinels(random.Next(0, 300));
            var before = (window.Top, window.Bits);

            var open = session.Open(direction, message, ad, body, clearLength, plain, out _, i % 2 == 0 ? window : null, (ulong)random.Next(0, 200));
            var name = FrameVectors.KindName(open);
            kinds[name] = kinds.GetValueOrDefault(name) + 1;

            Assert.NotNull(open);
            AssertUntouched(plain);
            Assert.Equal(before, (window.Top, window.Bits));

            var output = Sentinels(random.Next(0, 300));
            var seal = session.Seal(direction, message, ad, body.AsSpan(0, Math.Min(body.Length, random.Next(0, 300))), body, output, out var written);
            if (seal is not null)
            {
                AssertUntouched(output);
                Assert.Equal(0, written);
            }
        }

        Assert.True(kinds.Count >= 4, string.Join(",", kinds.Keys));
        Assert.Equal(0, kinds.GetValueOrDefault("Ok"));
    }

    [Fact]
    public void Ac8_ARandomRoundTripOfValidInputsAlwaysOpens()
    {
        var random = new Random(0x3232_0002);
        foreach (var tag in new[] { 4, 8, 16 })
        {
            using var session = Session(tag);
            for (var i = 0; i < 100; i++)
            {
                var clear = new byte[random.Next(0, 4)];
                var plain = new byte[random.Next(0, 255 - tag - clear.Length + 1)];
                var ad = new byte[random.Next(0, 256)];
                var id = new byte[8];
                random.NextBytes(clear);
                random.NextBytes(plain);
                random.NextBytes(ad);
                random.NextBytes(id);
                var message = new MsgContext(id, random.Next(0, 16));
                var direction = (FrameDirection)random.Next(1, 4);
                var body = new byte[255];
                var text = new byte[255];

                var sealError = session.Seal(direction, message, ad, clear, plain, body, out var written);
                var openError = session.Open(direction, message, ad, body.AsSpan(0, written), clear.Length, text, out var opened);

                Assert.Null(sealError);
                Assert.Null(openError);
                Assert.Equal(clear.Length + plain.Length + tag, written);
                Assert.Equal(clear, body.AsSpan(0, clear.Length).ToArray());
                Assert.Equal(plain, text.AsSpan(0, opened.PlainLength).ToArray());
            }
        }
    }
}
