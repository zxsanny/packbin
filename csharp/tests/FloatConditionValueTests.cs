using Packbin;

namespace Packbin.Tests;

// AZ-2126: a `when` names an integer or a bool, so a float, utf8 or byte source is refused (EqBoolTrueOnlyTests). What
// stays is an integer source against a float condition value: it compares as the same number and never throws.
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

    public static TheoryData<object, double> IntegerSourcesWithFloatConditions()
    {
        var data = new TheoryData<object, double>();
        object[] sources = [(byte)1, 1, 1L, 1UL, 1u];
        double[] conditions = [double.NaN, double.PositiveInfinity, double.NegativeInfinity, 1e30, -1e30];
        foreach (var source in sources)
        {
            foreach (var condition in conditions)
                data.Add(source, condition);
        }
        return data;
    }

    [Theory]
    [MemberData(nameof(IntegerSourcesWithFloatConditions))]
    public void PackAndUnpack_IntegerSourceWithAFloatConditionOutsideDecimalRange_NeverThrowsAndNeverMatches(
        object source, double match)
    {
        // Arrange
        var scheme = CountScheme(match);

        // Act
        var raw = BinaryPacker.Pack(scheme, Count(source));
        var got = BinaryPacker.Read(scheme, raw);

        // Assert
        Assert.Equal(1 + 8, raw.Length);
        Assert.Null(got.Error);
        Assert.False(got.Values.ContainsKey("B"));
    }

    [Theory]
    [InlineData(1.0, true)]
    [InlineData(1.5, false)]
    [InlineData(2.0, false)]
    public void PackAndUnpack_IntegerSourceWithAFloatCondition_MatchesOnTheSameNumber(double match, bool holds)
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
