using System.Diagnostics;
using Packbin;
using Xunit.Abstractions;

namespace Packbin.Tests;

// A timing test is measured on its own: xunit runs this collection after the parallel ones, so the pass does not compete
// with the rest of the suite for the cores (inside the suite the same pass took 2.3 times as long).
[CollectionDefinition("Timing", DisableParallelization = true)]
public sealed class TimingCollection;

[Collection("Timing")]
public class Ac10TimingTests(ITestOutputHelper output)
{
    // AC-10 on the path a caller runs: the public typed Pack(scheme, row) and Unpack(bytes, scheme.On(...)). The internal
    // Read and the dictionary overload skip the row binding and the handler dispatch, so they are not timed. One call
    // before the timer, one timed pass, bound exactly 1.0 s (AZ-2093).
    [Fact]
    public void Nfr_PublicTypedPackAndUnpack_RoundTripsWithinOneSecond()
    {
        var row = new PackbinTests.PositionRow { Sid = 1, Lat = 500_000_000, Lon = 300_000_000, Profile = 1 };
        RoundTrip(row);

        var watch = Stopwatch.StartNew();
        for (var i = 0; i < 100_000; i++)
            RoundTrip(row);
        watch.Stop();

        var elapsed = watch.Elapsed.TotalMilliseconds;
        output.WriteLine($"AC-10 public typed path: {elapsed:F0} ms for 100000 round trips");
        PackbinTests.AssertNoGpuLibrary();
        Assert.True(elapsed <= 1000.0, $"100000 public typed round trips took {elapsed:F0} ms, the bound is 1000 ms");
    }

    private static void RoundTrip(PackbinTests.PositionRow row)
    {
        PackbinTests.PositionRow? got = null;
        var bytes = BinaryPacker.Pack(PackbinTests.Target, row);
        var err = BinaryPacker.Unpack(bytes, PackbinTests.Target.On(r => got = r));
        Assert.Null(err);
        Assert.Equal(500_000_000, got!.Lat);
    }
}
