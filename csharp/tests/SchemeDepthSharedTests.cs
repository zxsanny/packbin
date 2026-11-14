using System.Diagnostics;
using Packbin;

namespace Packbin.Tests;

// AZ-4306: the depth check of a scheme measures a Field object that stands in several places once (again only when it is
// reached deeper than before). A scheme that holds the next level's field twice on every level has two to the power of
// its depth paths, and the depth check runs before the field-id check that would refuse it.
public class SchemeDepthSharedTests
{
    private const int Levels = 60;

    // Each level holds the next one twice: the same object in two places.
    private static Field[] WhenDiamond(int levels)
    {
        var inner = Field.U8<SchemeDepthTests.WhenRow>(1, x => x.B);
        for (var i = 0; i < levels; i++)
            inner = Field.When(1, Condition.Eq(0, 1), inner, inner);
        return [Field.U8<SchemeDepthTests.WhenRow>(0, x => x.A), inner];
    }

    private static Field[] GroupDiamond(int levels)
    {
        var inner = Field.U8<SchemeDepthTests.Node>(0, x => x.B);
        for (var i = 0; i < levels; i++)
            inner = Field.Group((SchemeDepthTests.Node x) => x.M, inner, inner);
        return [inner];
    }

    [Fact]
    public void Ac1_Construct_WhenDiamondOf60Levels_IsRefusedQuickly()
    {
        // Arrange
        var fields = WhenDiamond(Levels);
        var clock = Stopwatch.StartNew();

        // Act
        var refused = Record.Exception(() => new Scheme<SchemeDepthTests.WhenRow>(1, fields));

        // Assert
        clock.Stop();
        Assert.IsType<ArgumentException>(refused);
        Assert.True(clock.Elapsed < TimeSpan.FromSeconds(1), $"the diamond took {clock.Elapsed.TotalSeconds:F1} s");
    }

    [Fact]
    public void Ac1_Construct_GroupDiamondOf60Levels_IsRefusedQuickly()
    {
        // Arrange
        var fields = GroupDiamond(Levels);
        var clock = Stopwatch.StartNew();

        // Act
        var refused = Record.Exception(() => new Scheme<SchemeDepthTests.Node>(1, fields));

        // Assert
        clock.Stop();
        Assert.IsType<ArgumentException>(refused);
        Assert.True(clock.Elapsed < TimeSpan.FromSeconds(1), $"the diamond took {clock.Elapsed.TotalSeconds:F1} s");
    }

    // A `when` holding a u8, placed once at the top (depth 1) and again at the bottom of a chain of `whens` nested whens.
    private static Field[] SharedShallowThenDeep(int whens)
    {
        var shared = Field.When(1, Condition.Eq(0, 1), Field.U8<SchemeDepthTests.WhenRow>(1, x => x.B));
        var inner = shared;
        for (var i = 0; i < whens; i++)
            inner = Field.When(1, Condition.Eq(0, 1), inner);
        return [Field.U8<SchemeDepthTests.WhenRow>(0, x => x.A), shared, inner];
    }

    [Fact]
    public void Ac3_Construct_FieldReachedShallowFirstAndDeeperLater_IsMeasuredAtItsDeepest()
    {
        // Arrange: the shared `when` is met at depth 1 first; at the bottom of 256 whens it is at depth 257.
        var fields = SharedShallowThenDeep(SchemeDepthTests.Limit);

        // Act
        var refused = Record.Exception(() => new Scheme<SchemeDepthTests.WhenRow>(1, fields));

        // Assert
        Assert.Equal(SchemeDepthTests.Refusal, Assert.IsType<ArgumentException>(refused).Message);
    }

    [Fact]
    public void Ac3_Construct_FieldReachedDeeperLaterAt256Levels_IsNotRefusedByDepth()
    {
        // Arrange: 255 whens and the shared `when` below them make 256 levels; the scheme may fail another rule (the same
        // field object twice), but not the depth rule.
        var fields = SharedShallowThenDeep(SchemeDepthTests.Limit - 1);

        // Act
        var refused = Record.Exception(() => new Scheme<SchemeDepthTests.WhenRow>(1, fields));

        // Assert
        Assert.NotEqual(SchemeDepthTests.Refusal, refused?.Message);
    }
}
