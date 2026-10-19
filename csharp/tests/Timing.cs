using System.Diagnostics;
using System.Runtime.CompilerServices;

namespace Packbin.Tests;

/// <summary>
/// Load-aware wall-clock bounds (AZ-2723). A bound is the nominal figure times the load factor: the smallest of three runs of
/// a fixed integer loop, measured right before the timed code, over the time that loop takes on an idle host, never below 1
/// and capped at <see cref="MaxFactor"/>. A host as fast as the idle one keeps the nominal bound; a host busy with other work
/// gets more time, but a real slowdown beyond the cap still fails.
/// </summary>
internal static class Timing
{
    // The loop on the arm64 Mac, fully optimised: the smallest of 24 fresh processes was 31.6 ms (AZ-2723 calibration).
    internal const double ReferenceSeconds = 0.0316;
    internal const double MaxFactor = 8.0;

    private const int Iterations = 12_000_000;
    private const int Runs = 3;
    private static readonly object Gate = new();
    private static bool _warm;
    private static long _recentAt;
    private static double _recentFactor = 1.0;
    private static long _sink;

    /// <summary>The bound for a timed section that starts now: measures the load factor first.</summary>
    internal static Limit Bound(double nominalSeconds) => new(nominalSeconds, Factor());

    /// <summary>The bound for a probe that starts many times: the factor of the last two seconds, measured again after that.</summary>
    internal static Limit RecentBound(double nominalSeconds)
    {
        lock (Gate)
        {
            if (Stopwatch.GetElapsedTime(_recentAt).TotalSeconds >= 2.0 || _recentAt == 0)
            {
                _recentFactor = Factor();
                _recentAt = Stopwatch.GetTimestamp();
            }
            return new Limit(nominalSeconds, _recentFactor);
        }
    }

    internal static double Factor() => Math.Clamp(ReferenceLoopSeconds() / ReferenceSeconds, 1.0, MaxFactor);

    internal static double ReferenceLoopSeconds()
    {
        lock (Gate)
        {
            if (!_warm)
            {
                for (var i = 0; i < 4; i++)
                    Spin();
                _warm = true;
            }
            var best = double.MaxValue;
            for (var run = 0; run < Runs; run++)
            {
                var start = Stopwatch.GetTimestamp();
                Spin();
                best = Math.Min(best, Stopwatch.GetElapsedTime(start).TotalSeconds);
            }
            return best;
        }
    }

    [MethodImpl(MethodImplOptions.NoInlining | MethodImplOptions.AggressiveOptimization)]
    private static void Spin()
    {
        var x = 0x9E3779B97F4A7C15UL;
        for (var i = 0; i < Iterations; i++)
        {
            x ^= x << 13;
            x ^= x >> 7;
            x ^= x << 17;
            x += (ulong)i;
        }
        _sink = (long)x;
    }

    internal readonly record struct Limit(double NominalSeconds, double Factor)
    {
        internal double Seconds => NominalSeconds * Factor;

        internal TimeSpan Span => TimeSpan.FromSeconds(Seconds);

        internal void AssertWithin(double elapsedSeconds, string what) =>
            Assert.True(elapsedSeconds <= Seconds, Describe(elapsedSeconds, what));

        internal void AssertWithin(TimeSpan elapsed, string what) => AssertWithin(elapsed.TotalSeconds, what);

        internal string Describe(double elapsedSeconds, string what) =>
            $"{what}: {elapsedSeconds:F3} s elapsed, nominal bound {NominalSeconds:F3} s x load factor {Factor:F2} = {Seconds:F3} s";
    }
}
