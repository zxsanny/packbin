using Packbin;

namespace Packbin.Tests;

// AZ-2309: u2 slots, bits items and packed items take only a whole number that fits, like every integer field since
// AZ-2191. A fraction, bool, string, char, enum or object is refused with the member named (owner decision 7).
public class StrictSlotTests
{
    private sealed class Row
    {
        public int A { get; set; }
        public int B { get; set; }
        public byte N { get; set; }
        public List<int>? Bits { get; set; }
        public List<int>? Packed1 { get; set; }
        public List<int>? Packed2 { get; set; }
    }

    private static string Hex(byte[] raw) => Convert.ToHexString(raw).ToLowerInvariant();

    private static Scheme<Row> For(string kind) => kind switch
    {
        "u2" => new Scheme<Row>(1, Field.U2<Row>((0, x => x.A), (1, x => x.B))),
        "bits" => new Scheme<Row>(1, Field.U8<Row>(0, x => x.N), Field.Bits<Row>(1, x => x.Bits, 0)),
        "packed1" => new Scheme<Row>(1, Field.U8<Row>(0, x => x.N), Field.Packed<Row>(1, 1, x => x.Packed1, 0)),
        _ => new Scheme<Row>(1, Field.U8<Row>(0, x => x.N), Field.Packed<Row>(2, 1, x => x.Packed2, 0)),
    };

    private static string Member(string kind) => kind switch
    {
        "u2" => "A",
        "bits" => "Bits",
        "packed1" => "Packed1",
        _ => "Packed2",
    };

    private static Dictionary<string, object?> Slot(string kind, object? value) => kind == "u2"
        ? new() { ["A"] = value, ["B"] = 0 }
        : new() { ["N"] = (byte)2, [Member(kind)] = new List<object?> { 0, value } };

    private static void ExpectRefused(string kind, object? value)
    {
        var error = Assert.Throws<ArgumentException>(() => BinaryPacker.Pack(For(kind), Slot(kind, value)));

        Assert.Contains(kind == "u2" ? "A:" : Member(kind) + ":", error.Message, StringComparison.Ordinal);
    }

    public static TheoryData<string, object> Fractions() => new()
    {
        { "u2", 1.5 },
        { "bits", 2.5 },
        { "bits", 0.5 },
        { "packed1", 0.5 },
        { "packed2", 0.5 },
        { "packed2", 2.5f },
        { "u2", 1.5m },
    };

    [Theory]
    [MemberData(nameof(Fractions))]
    public void Ac1_Pack_FractionInASlot_ThrowsNamingTheMember(string kind, object value) => ExpectRefused(kind, value);

    public static TheoryData<string, object> OutOfRange() => new()
    {
        { "u2", 4 },
        { "u2", -1 },
        { "u2", 4.0 },
        { "u2", ulong.MaxValue },
        { "bits", 2 },
        { "bits", -1L },
        { "packed1", 2 },
        { "packed1", double.NaN },
        { "packed2", 4 },
        { "packed2", -1 },
        { "packed2", double.PositiveInfinity },
    };

    [Theory]
    [MemberData(nameof(OutOfRange))]
    public void Ac2_Pack_ValueThatDoesNotFit_ThrowsNamingTheMember(string kind, object value) => ExpectRefused(kind, value);

    public static TheoryData<string, object?> WrongTypes()
    {
        var data = new TheoryData<string, object?>();
        foreach (var kind in new[] { "u2", "bits", "packed1", "packed2" })
        {
            data.Add(kind, true);
            data.Add(kind, "1");
            data.Add(kind, 'a');
            data.Add(kind, DayOfWeek.Monday);
            data.Add(kind, new object());
            data.Add(kind, null);
        }
        return data;
    }

    [Theory]
    [MemberData(nameof(WrongTypes))]
    public void Ac3_Pack_BoolStringCharEnumObjectOrNull_ThrowsNamingTheMember(string kind, object? value) =>
        ExpectRefused(kind, value);

    [Theory]
    [InlineData("u2", 0, "0100")]
    [InlineData("u2", 3, "0103")]
    [InlineData("u2", 3.0, "0103")]
    [InlineData("u2", 2L, "0102")]
    [InlineData("u2", (byte)1, "0101")]
    [InlineData("bits", 1, "010202")]
    [InlineData("bits", 1.0, "010202")]
    [InlineData("packed1", 1L, "010202")]
    [InlineData("packed2", 3, "01020c")]
    [InlineData("packed2", 3.0, "01020c")]
    public void Ac4_Pack_RangeEdgesAndWholeNumbers_KeepTheirBytes(string kind, object value, string hex)
    {
        // Act
        var raw = BinaryPacker.Pack(For(kind), Slot(kind, value));

        // Assert
        Assert.Equal(hex, Hex(raw));
    }

    [Fact]
    public void Ac4_Pack_WholeNumbersAsDoubleOrLong_EqualTheIntegerBytes()
    {
        // Arrange
        object?[][] equal =
        [
            [1, 1.0, 1L, 1m],
            [0, 0.0, 0L, (byte)0],
        ];

        foreach (var values in equal)
        {
            // Act
            var bytes = values.Select(v => Hex(BinaryPacker.Pack(For("packed2"), Slot("packed2", v)))).Distinct().ToList();

            // Assert
            Assert.Single(bytes);
        }
    }

    [Fact]
    public void Ac4_Pack_TypedRowOfInts_KeepsItsBytes()
    {
        // Arrange
        var scheme = For("bits");

        // Act
        var raw = BinaryPacker.Pack(scheme, new Row { N = 3, Bits = [1, 0, 1] });

        // Assert
        Assert.Equal("010305", Hex(raw));
    }

    [Fact]
    public void Ac1_Pack_FractionInsideFlagsRepeatAndListElement_IsRefused()
    {
        // Arrange
        var inFlags = new Scheme<Row>(1, Field.Flags(0, Field.U2<Row>((0, x => x.A))));
        var inRepeat = new Scheme<Row>(1, Field.Repeat(0, Field.U2<Row>((0, x => x.A))));
        var inWhen = new Scheme<Row>(1, Field.U8<Row>(0, x => x.N), Field.When(1, Condition.Eq(0, 1), Field.U2<Row>((1, x => x.A))));

        // Act
        var flags = Record.Exception(() => BinaryPacker.Pack(inFlags, new Dictionary<string, object?> { ["A"] = 1.5 }));
        var repeat = Record.Exception(() => BinaryPacker.Pack(inRepeat, new Dictionary<string, object?> { ["A"] = new object?[] { 1, 1.5 } }));
        var when = Record.Exception(() => BinaryPacker.Pack(inWhen, new Dictionary<string, object?> { ["N"] = (byte)1, ["A"] = 2.5 }));

        // Assert
        Assert.All([flags, repeat, when], e => Assert.IsType<ArgumentException>(e));
    }
}
