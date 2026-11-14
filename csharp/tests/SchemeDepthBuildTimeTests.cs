using System.Diagnostics;
using Packbin;
using Xunit.Abstractions;

namespace Packbin.Tests;

// AZ-4307 item 4: building a scheme nested 250 levels deep (just under the limit of 256) takes time in its size. Every step of
// the build that looks at a field's whole subtree, once per level, makes a chain quadratic; the guard times the whole build.
[Collection("Timing")]
public class SchemeDepthBuildTimeTests(ITestOutputHelper output)
{
    private const int Levels = 250;
    private const int Runs = 9;

    private static Field[] WhenChain()
    {
        var inner = Field.U8<SchemeDepthTests.WhenRow>(1, x => x.B);
        for (var i = 0; i < Levels; i++)
            inner = Field.When(1, Condition.Eq(0, 1), inner);
        return [Field.U8<SchemeDepthTests.WhenRow>(0, x => x.A), inner];
    }

    private static Field[] GroupChain()
    {
        var inner = Field.U8<SchemeDepthTests.Node>(0, x => x.B);
        for (var i = 0; i < Levels; i++)
            inner = Field.Group((SchemeDepthTests.Node x) => x.M, inner);
        return [inner];
    }

    private double BestBuild(Action build)
    {
        build();
        var best = double.MaxValue;
        for (var run = 0; run < Runs; run++)
        {
            var watch = Stopwatch.StartNew();
            build();
            best = Math.Min(best, watch.Elapsed.TotalSeconds);
        }
        return best;
    }

    [Fact]
    public void Construct_ChainOf250NestedWhens_BuildsInTimeLinearInItsDepth()
    {
        // Arrange
        var fields = WhenChain();
        var limit = Timing.Bound(0.002);

        // Act
        var best = BestBuild(() => _ = new Scheme<SchemeDepthTests.WhenRow>(1, fields));

        // Assert
        output.WriteLine($"250 nested whens: {best * 1000:F3} ms, bound {limit.Seconds * 1000:F2} ms (load factor {limit.Factor:F2})");
        limit.AssertWithin(best, "building 250 nested whens");
    }

    [Fact]
    public void Construct_ChainOf250NestedGroups_BuildsInTimeLinearInItsDepth()
    {
        // Arrange
        var fields = GroupChain();
        var limit = Timing.Bound(0.002);

        // Act
        var best = BestBuild(() => _ = new Scheme<SchemeDepthTests.Node>(1, fields));

        // Assert
        output.WriteLine($"250 nested groups: {best * 1000:F3} ms, bound {limit.Seconds * 1000:F2} ms (load factor {limit.Factor:F2})");
        limit.AssertWithin(best, "building 250 nested groups");
    }
}
