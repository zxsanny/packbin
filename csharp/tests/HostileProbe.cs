using Packbin;

namespace Packbin.Tests;

internal static class HostileProbe
{
    internal sealed record Outcome(object? Error, bool HandlerCalled);

    // Runs unpack on its own background thread so a hang fails the test after the guard instead of blocking CI.
    internal static Outcome Unpack<T>(Scheme<T> scheme, string hex, double guardSeconds = 2) where T : class, new()
    {
        var bytes = Convert.FromHexString(hex);
        Outcome? outcome = null;
        Exception? thrown = null;
        var worker = new Thread(() =>
        {
            try
            {
                var called = false;
                var error = BinaryPacker.Unpack(bytes, scheme.On(_ => called = true));
                outcome = new Outcome(error, called);
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
        if (!worker.Join(TimeSpan.FromSeconds(guardSeconds)))
            Assert.Fail($"unpack of {hex} did not return within {guardSeconds} s");
        if (thrown is not null)
            Assert.Fail($"unpack of {hex} threw {thrown.GetType().Name}: {thrown.Message}");
        return outcome!;
    }

    // Until C15 adds a bad-value error, C# answers a bad value with ShortPacket (see HostileUnpackTests).
    internal static ShortPacket ExpectShort(Outcome outcome, string field)
    {
        Assert.False(outcome.HandlerCalled);
        var error = Assert.IsType<ShortPacket>(outcome.Error);
        Assert.Equal(field, error.Field);
        return error;
    }
}
