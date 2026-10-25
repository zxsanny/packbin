using System.Diagnostics;

namespace Packbin.Tests;

public class FrameConcurrencyTests
{
    private const int Threads = 8;
    private const int PerThread = 1000;

    private static (MsgContext Message, byte[] Ad, byte[] Clear, byte[] Plain) Input(int thread, int i)
    {
        var id = new byte[8];
        BitConverter.GetBytes(thread).CopyTo(id, 0);
        BitConverter.GetBytes(i).CopyTo(id, 4);
        var plain = new byte[i % 80];
        for (var k = 0; k < plain.Length; k++)
            plain[k] = (byte)(thread * 31 + i + k);
        return (new MsgContext(id, i % 16), [(byte)thread, (byte)i], [(byte)i, 7], plain);
    }

    [Fact]
    public void Ac11_EightThreadsSealingTheSameSessionGiveTheSingleThreadBodies()
    {
        using var session = FrameSession.Load(new byte[32], 3, new FrameConfig(8, FrameDirections.All))!;
        var expected = new byte[Threads][][];
        for (var t = 0; t < Threads; t++)
        {
            expected[t] = new byte[PerThread][];
            for (var i = 0; i < PerThread; i++)
                expected[t][i] = SealOne(session, t, i);
        }
        var actual = new byte[Threads][][];
        var start = Stopwatch.GetTimestamp();

        Parallel.For(0, Threads, new ParallelOptions { MaxDegreeOfParallelism = Threads }, t =>
        {
            actual[t] = new byte[PerThread][];
            for (var i = 0; i < PerThread; i++)
                actual[t][i] = SealOne(session, t, i);
        });
        var elapsed = Stopwatch.GetElapsedTime(start);

        var differing = 0;
        for (var t = 0; t < Threads; t++)
            for (var i = 0; i < PerThread; i++)
            {
                if (!expected[t][i].AsSpan().SequenceEqual(actual[t][i]))
                    differing++;
                var (message, ad, clear, plain) = Input(t, i);
                var text = new byte[255];
                Assert.Null(session.Open(FrameDirection.Group, message, ad, actual[t][i], clear.Length, text, out var opened));
                Assert.Equal(plain, text.AsSpan(0, opened.PlainLength).ToArray());
                Assert.Equal(clear, actual[t][i].AsSpan(0, clear.Length).ToArray());
            }
        Assert.Equal(0, differing);
        Timing.Bound(20).AssertWithin(elapsed, "8 x 1000 seals on 8 threads");
    }

    private static byte[] SealOne(FrameSession session, int thread, int i)
    {
        var (message, ad, clear, plain) = Input(thread, i);
        var body = new byte[255];
        Assert.Null(session.Seal(FrameDirection.Group, message, ad, clear, plain, body, out var written));
        return body.AsSpan(0, written).ToArray();
    }
}
