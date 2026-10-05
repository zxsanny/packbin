using Packbin;

namespace Packbin.Tests;

// A `when` on a float compares as double with Java's Double.compare rule: NaN equals NaN and -0.0 differs from 0.0.
// No float, however large or odd, makes pack or unpack throw.
public class FloatWhenTests
{
    private sealed class FloatRow
    {
        public double F { get; set; }
        public byte? B { get; set; }
    }

    private sealed class CountRow
    {
        public long K { get; set; }
        public byte? B { get; set; }
    }

    private sealed class SingleRow
    {
        public float F { get; set; }
        public byte? B { get; set; }
    }

    private static Scheme<FloatRow> Scheme(double match) => new(1,
        Field.F64<FloatRow>(0, x => x.F),
        Field.When(1, Condition.Eq(0, match), Field.U8<FloatRow>(1, x => x.B)));

    private static Scheme<CountRow> CountScheme(object match) => new(1,
        Field.I64<CountRow>(0, x => x.K),
        Field.When(1, Condition.Eq(0, match), Field.U8<CountRow>(1, x => x.B)));

    private static Dictionary<string, object?> Count(object k) => new() { ["K"] = k, ["B"] = (byte)1 };

    private static string Hex(byte[] raw) => Convert.ToHexString(raw).ToLowerInvariant();

    public static TheoryData<double, bool> Rows() => new()
    {
        { double.NaN, false },
        { double.PositiveInfinity, false },
        { double.NegativeInfinity, false },
        { 1e30, false },
        { -1e30, false },
        { double.MaxValue, false },
        { 1.0, true },
    };

    [Theory]
    [MemberData(nameof(Rows))]
    public void PackAndUnpack_FloatWhen_NeverThrowsAndWritesOnlyOnAMatch(double f, bool writes)
    {
        // Arrange
        var scheme = Scheme(1.0);
        var row = new FloatRow { F = f, B = 1 };
        var expectedLength = 1 + 8 + (writes ? 1 : 0);

        // Act
        var raw = BinaryPacker.Pack(scheme, row);
        var got = BinaryPacker.Read(scheme, raw);

        // Assert
        Assert.Equal(expectedLength, raw.Length);
        Assert.Null(got.Error);
        Assert.Equal(writes, got.Values.ContainsKey("B"));
        Assert.Equal(Hex(raw), Hex(BinaryPacker.Pack(scheme, got.Values)));
    }

    [Theory]
    [InlineData(double.NaN)]
    [InlineData(double.PositiveInfinity)]
    [InlineData(1e30)]
    public void PackAndUnpack_ConditionValueOutsideDecimalRange_NeverThrows(double match)
    {
        // Arrange
        var scheme = Scheme(match);

        // Act
        var raw = BinaryPacker.Pack(scheme, new FloatRow { F = 1.0, B = 1 });
        var got = BinaryPacker.Read(scheme, raw);

        // Assert
        Assert.Equal(1 + 8, raw.Length);
        Assert.Null(got.Error);
        Assert.False(got.Values.ContainsKey("B"));
    }

    [Fact]
    public void Pack_HugeFloatEqualToAHugeCondition_WritesTheGroup()
    {
        // Arrange
        var scheme = Scheme(1e30);

        // Act
        var raw = BinaryPacker.Pack(scheme, new FloatRow { F = 1e30, B = 1 });
        var got = BinaryPacker.Read(scheme, raw);

        // Assert
        Assert.Equal(1 + 8 + 1, raw.Length);
        Assert.Null(got.Error);
        Assert.True(got.Values.ContainsKey("B"));
    }

    [Fact]
    public void Pack_MatchingFloat_WritesTheGroup()
    {
        // Arrange
        var scheme = Scheme(1.0);

        // Act
        var raw = BinaryPacker.Pack(scheme, new FloatRow { F = 1.0, B = 9 });

        // Assert
        Assert.Equal("01" + "000000000000f03f" + "09", Hex(raw));
    }

    [Fact]
    public void Pack_NaNConditionOnANaNValue_Holds()
    {
        // Arrange
        var scheme = Scheme(double.NaN);

        // Act
        var raw = BinaryPacker.Pack(scheme, new FloatRow { F = double.NaN, B = 3 });
        var got = BinaryPacker.Read(scheme, raw);

        // Assert
        Assert.Equal(1 + 8 + 1, raw.Length);
        Assert.Null(got.Error);
        Assert.True(got.Values.ContainsKey("B"));
    }

    [Fact]
    public void Pack_NegativeZeroAgainstAZeroCondition_DoesNotHold()
    {
        // Arrange
        var scheme = Scheme(0.0);

        // Act
        var negative = BinaryPacker.Pack(scheme, new FloatRow { F = -0.0, B = 3 });
        var positive = BinaryPacker.Pack(scheme, new FloatRow { F = 0.0, B = 3 });

        // Assert
        Assert.Equal(1 + 8, negative.Length);
        Assert.Equal(1 + 8 + 1, positive.Length);
    }

    [Fact]
    public void Unpack_NegativeZeroAgainstAZeroCondition_ReadsNoGroup()
    {
        // Arrange
        var scheme = Scheme(0.0);
        var raw = Convert.FromHexString("01" + "0000000000000080");

        // Act
        var got = BinaryPacker.Read(scheme, raw);

        // Assert
        Assert.Null(got.Error);
        Assert.False(got.Values.ContainsKey("B"));
    }

    [Fact]
    public void PackAndUnpack_Float32Source_AgreeOnAMatch()
    {
        // Arrange
        var scheme = new Scheme<SingleRow>(1,
            Field.F32<SingleRow>(0, x => x.F),
            Field.When(1, Condition.Eq(0, 1.5), Field.U8<SingleRow>(1, x => x.B)));

        // Act
        var raw = BinaryPacker.Pack(scheme, new SingleRow { F = 1.5f, B = 4 });
        var got = BinaryPacker.Read(scheme, raw);

        // Assert
        Assert.Equal("01" + "0000c03f" + "04", Hex(raw));
        Assert.Null(got.Error);
        Assert.True(got.Values.ContainsKey("B"));
    }

    [Fact]
    public void Unpack_HugeFloatBytes_ReturnsNoError()
    {
        // Arrange
        var scheme = Scheme(1.0);
        var raw = Convert.FromHexString("01" + "000000000000f07f");

        // Act
        var got = BinaryPacker.Read(scheme, raw);

        // Assert
        Assert.Null(got.Error);
    }

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

    [Theory]
    [InlineData(double.NaN)]
    [InlineData(double.PositiveInfinity)]
    [InlineData(1e30)]
    public void PackAndUnpack_FloatSourceWithAnIntegerCondition_NeverThrowsAndNeverMatches(double f)
    {
        // Arrange
        var scheme = new Scheme<FloatRow>(1,
            Field.F64<FloatRow>(0, x => x.F),
            Field.When(1, Condition.Eq(0, 1), Field.U8<FloatRow>(1, x => x.B)));

        // Act
        var raw = BinaryPacker.Pack(scheme, new FloatRow { F = f, B = 1 });
        var got = BinaryPacker.Read(scheme, raw);

        // Assert
        Assert.Equal(1 + 8, raw.Length);
        Assert.Null(got.Error);
        Assert.False(got.Values.ContainsKey("B"));
    }
}
