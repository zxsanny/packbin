namespace Packbin.Tests;

public class FrameReplayTests
{
    private static FrameExample E1() => FrameExample.Worked().Single(e => e.Name == "E1");

    private static object? Open(FrameSession session, FrameExample e, byte[] body, ReplayWindow window, ulong counter, byte[] plain) =>
        session.Open(e.Direction, e.Context, e.Ad, body, e.ClearLength, plain, out _, window, counter);

    [Fact]
    public void Ac5_ADuplicateAndATooOldCounterComputeNoMacAndLeaveTheWindow()
    {
        var e = E1();
        using var session = e.Session();
        var window = new ReplayWindow();
        var plain = new byte[300];
        Assert.Null(Open(session, e, e.Body, window, 100, plain));
        var macs = session.MacComputations;
        var state = (window.Top, window.Bits);

        var duplicate = Open(session, e, e.Body, window, 100, plain);
        var tooOld = Open(session, e, e.Body, window, 36, plain);
        var wayOld = Open(session, e, e.Body, window, 0, plain);

        Assert.IsType<Duplicate>(duplicate);
        Assert.IsType<TooOld>(tooOld);
        Assert.IsType<TooOld>(wayOld);
        Assert.Equal(macs, session.MacComputations);
        Assert.Equal(state, (window.Top, window.Bits));
    }

    [Fact]
    public void Ac5_AFreshValidBodyCommitsItsCounterAndAFreshTamperedBodyDoesNot()
    {
        var e = E1();
        using var session = e.Session();
        var window = new ReplayWindow();
        var plain = new byte[300];
        Assert.Null(Open(session, e, e.Body, window, 100, plain));
        var macs = session.MacComputations;
        var tampered = (byte[])e.Body.Clone();
        tampered[0] ^= 1;

        var bad = Open(session, e, tampered, window, 101, plain);
        var afterBad = (window.Top, window.Bits);
        var good = Open(session, e, e.Body, window, 37, plain);
        var again = Open(session, e, e.Body, window, 37, plain);

        Assert.IsType<TagMismatch>(bad);
        Assert.Equal((100UL, 1UL), afterBad);
        Assert.Equal(macs + 2, session.MacComputations);
        Assert.Null(good);
        Assert.Equal(1UL | (1UL << 63), window.Bits);
        Assert.IsType<Duplicate>(again);
        Assert.Equal(macs + 2, session.MacComputations);
    }

    [Fact]
    public void Ac5_AnOpenWithoutAWindowIsNotReplayChecked()
    {
        var e = E1();
        using var session = e.Session();
        var plain = new byte[300];

        var first = session.Open(e.Direction, e.Context, e.Ad, e.Body, e.ClearLength, plain, out _);
        var second = session.Open(e.Direction, e.Context, e.Ad, e.Body, e.ClearLength, plain, out _);

        Assert.Null(first);
        Assert.Null(second);
    }

    [Fact]
    public void Ac5_TheWindowSlidesAndForgetsLikeTheContractTable()
    {
        var window = new ReplayWindow();

        window.Commit(10);
        window.Commit(12);
        window.Commit(9);
        window.Commit(200);

        Assert.Equal((200UL, 1UL), (window.Top, window.Bits));
        Assert.Equal(Freshness.TooOld, window.Check(136));
        Assert.Equal(Freshness.Fresh, window.Check(137));
        Assert.Equal(Freshness.Duplicate, window.Check(200));
        Assert.Equal(Freshness.Fresh, window.Check(201));
    }

    [Fact]
    public void Ac5_AShiftOfSixtyFourOrMoreEmptiesTheOldBitsAndAnEmptyWindowIsFreshForEverything()
    {
        var window = new ReplayWindow(5, 0);
        Assert.Equal(Freshness.Fresh, window.Check(5));
        Assert.Equal(Freshness.Fresh, window.Check(0));

        window.Commit(ulong.MaxValue - 1);
        window.Commit(ulong.MaxValue);

        Assert.Equal((ulong.MaxValue, 3UL), (window.Top, window.Bits));
        Assert.Equal(Freshness.Duplicate, window.Check(ulong.MaxValue - 1));
        Assert.Equal(Freshness.TooOld, window.Check(ulong.MaxValue - 64));
        window.Commit(0);
        Assert.Equal((ulong.MaxValue, 3UL), (window.Top, window.Bits));
    }

    [Fact]
    public void Ac6_ThePreviousSlotOpensOldFramesAndTheCurrentSlotOpensNewOnes()
    {
        var keyA = Enumerable.Repeat((byte)0xAA, 32).ToArray();
        var keyB = Enumerable.Repeat((byte)0xBB, 32).ToArray();
        var config = new FrameConfig(8, FrameDirections.All);
        var message = new MsgContext(new byte[] { 1, 2, 3, 4, 5, 6, 7, 8 }, 3);
        byte[] ad = [9, 9];
        byte[] plain = "hello"u8.ToArray();
        using var sealerA = FrameSession.Load(keyA, 6, config)!;
        using var sealerB = FrameSession.Load(keyB, 7, config)!;
        var underA = new byte[40];
        var underB = new byte[40];
        Assert.Null(sealerA.Seal(FrameDirection.Down, message, ad, [], plain, underA, out var lengthA));
        Assert.Null(sealerB.Seal(FrameDirection.Down, message, ad, [], plain, underB, out var lengthB));
        using var session = FrameSession.Load(keyB, 7, config)!;
        Assert.True(session.SetPrevious(keyA, 6));
        var window = new ReplayWindow();
        var output = new byte[40];

        var errorA = session.Open(FrameDirection.Down, message, ad, underA.AsSpan(0, lengthA), 0, output, out var openedA, window, 1);
        var textA = output.AsSpan(0, openedA.PlainLength).ToArray();
        var errorB = session.Open(FrameDirection.Down, message, ad, underB.AsSpan(0, lengthB), 0, output, out var openedB, window, 2);

        Assert.Null(errorA);
        Assert.Equal(FrameSlot.Previous, openedA.Slot);
        Assert.Equal(plain, textA);
        Assert.Null(errorB);
        Assert.Equal(FrameSlot.Current, openedB.Slot);
        Assert.Equal(plain, output.AsSpan(0, openedB.PlainLength).ToArray());
        Assert.Equal((2UL, 3UL), (window.Top, window.Bits));
    }

    [Fact]
    public void Ac6_WithNoPreviousSlotOrAfterClearingItAnOldFrameIsATagMismatch()
    {
        var keyA = Enumerable.Repeat((byte)0xAA, 32).ToArray();
        var keyB = Enumerable.Repeat((byte)0xBB, 32).ToArray();
        var config = new FrameConfig(4, FrameDirections.Up);
        var message = new MsgContext(new byte[8], 0);
        using var sealerA = FrameSession.Load(keyA, 6, config)!;
        var body = new byte[20];
        Assert.Null(sealerA.Seal(FrameDirection.Up, message, [], [], new byte[] { 1, 2, 3 }, body, out var length));
        using var session = FrameSession.Load(keyB, 7, config)!;
        var output = new byte[20];

        var without = session.Open(FrameDirection.Up, message, [], body.AsSpan(0, length), 0, output, out _);
        Assert.True(session.SetPrevious(keyA, 6));
        var previousKeys = session.KeyArrays().Skip(2).ToList();
        var with = session.Open(FrameDirection.Up, message, [], body.AsSpan(0, length), 0, output, out var opened);
        session.ClearPrevious();
        var cleared = session.Open(FrameDirection.Up, message, [], body.AsSpan(0, length), 0, output, out _);

        Assert.IsType<TagMismatch>(without);
        Assert.Null(with);
        Assert.Equal(FrameSlot.Previous, opened.Slot);
        Assert.IsType<TagMismatch>(cleared);
        Assert.Equal(2, previousKeys.Count);
        Assert.All(previousKeys, key => Assert.All(key, b => Assert.Equal(0, b)));
    }

    [Fact]
    public void Ac6_SealNeverUsesThePreviousKeyAndARefusedPreviousIsFalse()
    {
        var keyA = Enumerable.Repeat((byte)0xAA, 32).ToArray();
        var keyB = Enumerable.Repeat((byte)0xBB, 32).ToArray();
        var config = new FrameConfig(4, FrameDirections.Up);
        var message = new MsgContext(new byte[8], 0);
        using var plainSession = FrameSession.Load(keyB, 7, config)!;
        using var withPrevious = FrameSession.Load(keyB, 7, config)!;
        Assert.True(withPrevious.SetPrevious(keyA, 6));
        var one = new byte[20];
        var two = new byte[20];

        plainSession.Seal(FrameDirection.Up, message, [], [], new byte[] { 1 }, one, out var n1);
        withPrevious.Seal(FrameDirection.Up, message, [], [], new byte[] { 1 }, two, out var n2);

        Assert.Equal(one.AsSpan(0, n1).ToArray(), two.AsSpan(0, n2).ToArray());
        Assert.False(withPrevious.SetPrevious(keyA, 0x1000000));
        Assert.False(withPrevious.SetPrevious(new byte[31], 1));
    }
}
