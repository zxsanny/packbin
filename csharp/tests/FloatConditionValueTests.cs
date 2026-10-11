using Packbin;

namespace Packbin.Tests;

// AZ-2126: a `when` names an integer or a bool, so a float, utf8 or byte source is refused (EqBoolTrueOnlyTests). What
// stays is an integer source against an integer of another width, which compares as the same number. Any float value
// is refused at construction (AZ-2338, and AZ-2358 for a whole one such as 1.0).
public class FloatConditionValueTests
{
    private sealed class CountRow
    {
        public long K { get; set; }
        public byte? B { get; set; }
    }

    private static Scheme<CountRow> CountScheme(object match) => new(1,
        Field.I64<CountRow>(0, x => x.K),
        Field.When(1, Condition.Eq(0, match), Field.U8<CountRow>(1, x => x.B)));

    private static Dictionary<string, object?> Count(object k) => new() { ["K"] = k, ["B"] = (byte)1 };

    public static TheoryData<double> FloatConditionsAnIntegerFieldCannotHold() => new()
    {
        double.NaN, double.PositiveInfinity, double.NegativeInfinity, 1e30, -1e30, 1.5,
    };

    // AZ-2338: such a value could never match, so the scheme is refused when it is built (it used to build and never match).
    [Theory]
    [MemberData(nameof(FloatConditionsAnIntegerFieldCannotHold))]
    public void Construct_IntegerSourceWithAFloatConditionThatIsNotAWholeNumberInRange_IsRefused(double match)
    {
        // Act
        var thrown = Record.Exception(() => CountScheme(match));

        // Assert
        var error = Assert.IsType<ArgumentException>(thrown);
        Assert.StartsWith("when 1 tests i64 field 0 ('K') against ", error.Message, StringComparison.Ordinal);
    }

    [Theory]
    [InlineData(1L, true)]
    [InlineData(2L, false)]
    public void PackAndUnpack_IntegerSourceWithAnIntegerCondition_MatchesOnTheSameNumber(long match, bool holds)
    {
        // Arrange
        var scheme = CountScheme(match);

        // Act
        var raw = BinaryPacker.Pack(scheme, Count((byte)1));
        var got = BinaryPacker.Read(scheme, raw);

        // Assert
        Assert.Equal(1 + 8 + (holds ? 1 : 0), raw.Length);
        Assert.Null(got.Error);
        Assert.Equal(holds, got.Values.ContainsKey("B"));
    }
}
