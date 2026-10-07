using Packbin;

namespace Packbin.Tests;

// AZ-2114, C# part: a session waiter that unpacks a session-padded hostile payload returns the same error as a clear
// unpack of the same bytes, within 1 s, and the next valid message still unpacks (the receive counter advanced by one).
//
// The README scheme for `01 00 ff` (a `when` in a repeat body naming a field outside it) is refused at construction in
// C# as well, so the zero-progress case uses the stand-in of the Rust and Java tests: a repeat of a zero-width `bytes`.
public class HostileSessionTests
{
    private sealed class ZeroRow
    {
        public byte K { get; set; }
        public byte[] B { get; set; } = [];
    }

    private sealed class El
    {
        public byte[] B { get; set; } = [];
    }

    private sealed class Mid
    {
        public List<object?>? Inner { get; set; }
    }

    private sealed class NestedRow
    {
        public List<object?>? Outer { get; set; }
    }

    private sealed class MapRow
    {
        public Dictionary<string, object?>? M { get; set; }
    }

    private sealed class OkRow
    {
        public byte N { get; set; }
    }

    private static readonly Scheme<OkRow> Ok = new(2, Field.U8<OkRow>(0, x => x.N));

    public static TheoryData<string> Kinds() => new() { "zero-progress", "list-of-lists", "dict-zero-width-value" };

    private static (string ClearHex, SchemeHandler Handler) Hostile(string kind, Action called) => kind switch
    {
        "zero-progress" => ("0100ff", new Scheme<ZeroRow>(1,
            Field.U8<ZeroRow>(0, x => x.K),
            Field.Repeat(1, Field.Bytes<ZeroRow>(1, x => x.B, 0))).On(_ => called())),
        "list-of-lists" => ("01ffffffff", new Scheme<NestedRow>(1,
            Field.List((NestedRow x) => x.Outer, Field.List((Mid m) => m.Inner, Field.Bytes<El>(0, e => e.B, 0)))).On(_ => called())),
        _ => ("01ffff010061", new Scheme<MapRow>(1,
            Field.Dict((MapRow x) => x.M, Field.Bytes<El>(0, e => e.B, 0))).On(_ => called())),
    };

    private static string ClearError(string kind) => kind switch
    {
        "zero-progress" => "trailing 1",
        "list-of-lists" => "short Inner needed 0 left 0",
        _ => "short M needed 0 left 0",
    };

    private static (PackSession Opener, PackSession Waiter) OpenPair()
    {
        var seed = Enumerable.Range(1, 32).Select(i => (byte)i).ToArray();
        var nonce = Enumerable.Range(1, 16).Select(i => (byte)i).ToArray();
        var opener = PackSession.Load(seed)!;
        var waiter = PackSession.Load(seed)!;
        opener.Start(nonce);
        Assert.True(waiter.Join(nonce));
        return (opener, waiter);
    }

    // The packet the opener would send for these clear bytes at its next counter. The opener is then moved past that
    // counter, so its next real message is padded with the keystream the waiter expects.
    private static byte[] PadAsOpener(PackSession opener, string clearHex)
    {
        var padded = Convert.FromHexString(clearHex);
        SessionPad.Xor((byte[])SessionPrivates.Get(opener, "_send"), (ulong)(long)SessionPrivates.Get(opener, "_sendCount"), padded);
        Assert.NotNull(opener.Pack(Ok, new OkRow()));
        return padded;
    }

    // Runs on its own thread so a hang fails the test after the guard instead of blocking CI.
    private static object? Within(double seconds, Func<object?> unpack)
    {
        object? result = null;
        Exception? thrown = null;
        var worker = new Thread(() =>
        {
            try
            {
                result = unpack();
            }
            catch (Exception ex)
            {
                thrown = ex;
            }
        })
        {
            IsBackground = true,
        };
        worker.Start();
        if (!worker.Join(TimeSpan.FromSeconds(seconds)))
            Assert.Fail($"unpack did not return within {seconds} s");
        if (thrown is not null)
            Assert.Fail($"unpack threw {thrown.GetType().Name}: {thrown.Message}");
        return result;
    }

    private static string Describe(object? error) => error switch
    {
        null => "none",
        ShortPacket s => $"short {s.Field} needed {s.Needed} left {s.Left}",
        TrailingBytes t => $"trailing {t.Left}",
        TypeMismatch m => $"mismatch {m.Expected} {m.Actual}",
        _ => error.GetType().Name,
    };

    [Theory]
    [MemberData(nameof(Kinds))]
    public void Unpack_HostilePayloadThroughASessionWaiter_ReturnsTheClearError(string kind)
    {
        // Arrange
        var handlerCalls = 0;
        var (clearHex, handler) = Hostile(kind, () => handlerCalls++);
        var clearError = BinaryPacker.Unpack(Convert.FromHexString(clearHex), handler);
        var (opener, waiter) = OpenPair();
        var padded = PadAsOpener(opener, clearHex);

        // Act
        var sessionError = Within(1, () => waiter.Unpack(padded, handler, Ok.On(_ => { })));

        // Assert
        Assert.NotEqual(Convert.ToHexString(padded), clearHex.ToUpperInvariant());
        Assert.Equal(ClearError(kind), Describe(clearError));
        Assert.Equal(Describe(clearError), Describe(sessionError));
        Assert.Equal(0, handlerCalls);
    }

    [Theory]
    [MemberData(nameof(Kinds))]
    public void Unpack_ValidMessageAfterAHostileOne_StillUnpacksAndTheReceiveCounterAdvancedByOne(string kind)
    {
        // Arrange
        var (clearHex, handler) = Hostile(kind, () => { });
        var (opener, waiter) = OpenPair();
        var hostile = PadAsOpener(opener, clearHex);
        OkRow? got = null;
        var ok = Ok.On(v => got = v);

        // Act
        var hostileError = Within(1, () => waiter.Unpack(hostile, handler, ok));
        var countAfterHostile = (ulong)SessionPrivates.Get(waiter, "_recvCount");
        var valid = opener.Pack(Ok, new OkRow { N = 7 })!;
        var validError = Within(1, () => waiter.Unpack(valid, handler, ok));

        // Assert
        Assert.NotNull(hostileError);
        Assert.Equal(1UL, countAfterHostile);
        Assert.Null(validError);
        Assert.Equal((byte)7, got!.N);
        Assert.Equal(2UL, (ulong)SessionPrivates.Get(waiter, "_recvCount"));
    }
}
