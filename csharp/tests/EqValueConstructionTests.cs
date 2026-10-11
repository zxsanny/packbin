using Packbin;

namespace Packbin.Tests;

// AZ-2338: `Eq(integerSource, value)` is checked when the scheme is built. A string, a bool, NaN, a fraction or a number
// outside the source field's range could never match, so it fails construction naming the `when` and the member.
public class EqValueConstructionTests
{
    private sealed class Row
    {
        public byte Mode { get; set; }
        public sbyte S { get; set; }
        public ushort W16 { get; set; }
        public uint W32 { get; set; }
        public ulong Big { get; set; }
        public int Slot { get; set; }
        public byte? Speed { get; set; }
        public bool? Mark { get; set; }
    }

    private static Field Source(string kind) => kind switch
    {
        "u8" => Field.U8<Row>(0, x => x.Mode),
        "i8" => Field.I8<Row>(0, x => x.S),
        "u16" => Field.U16<Row>(0, x => x.W16),
        "u32" => Field.U32<Row>(0, x => x.W32),
        "u64" => Field.U64<Row>(0, x => x.Big),
        _ => Field.U2<Row>((0, x => x.Slot)),
    };

    private static Scheme<Row> Build(string kind, object? value) => new(1,
        Source(kind),
        Field.When(1, Condition.Eq(0, value!), Field.U8<Row>(1, x => x.Speed)));

    public static TheoryData<string, object?> Refused() => new()
    {
        { "u8", 300 },
        { "u8", -1 },
        { "u8", "x" },
        { "u8", double.NaN },
        { "u8", 1.5 },
        { "u8", true },
        { "u8", null },
        { "u8", 1e30 },
        { "i8", 128 },
        { "i8", -129 },
        { "u16", 65_536 },
        { "u32", 4_294_967_296L },
        { "u64", -1 },
        { "u64", 1e20 },
        { "u8", 255.00000000000003 },
        { "u8", 5.000000000000001 },
        { "u64", 18446744073709551616.0 },
        { "u8", 5.5m },
        { "u2", 4 },
        { "u2", -1 },
    };

    public static TheoryData<string, object?> Built() => new()
    {
        { "u8", 5 },
        { "u8", (byte)255 },
        { "i8", -128 },
        { "i8", (sbyte)127 },
        { "u16", 65_535 },
        { "u32", uint.MaxValue },
        { "u64", ulong.MaxValue },
        { "u2", 3 },
    };

    [Theory]
    [MemberData(nameof(Refused))]
    public void Construct_EqValueTheSourceCannotHold_IsRefusedNamingTheWhenAndTheMember(string kind, object? value)
    {
        // Act
        var thrown = Record.Exception(() => Build(kind, value));

        // Assert
        var error = Assert.IsType<ArgumentException>(thrown);
        Assert.StartsWith($"when 1 tests {kind} field 0 ('", error.Message, StringComparison.Ordinal);
        Assert.Contains("the value must be a whole number from ", error.Message, StringComparison.Ordinal);
    }

    // AZ-2358: `5.0` is not the integer 5, as Java, Python and Rust already say.
    public static TheoryData<string, object?> WholeFloats() => new()
    {
        { "u8", 5.0 },
        { "u8", 255.0 },
        { "u8", 0.0 },
        { "u8", 5m },
        { "u8", 5.0f },
        { "i8", -128.0 },
        { "u16", 65_535.0 },
        { "u32", 1.0 },
        { "u64", 1.0 },
        { "u2", 3.0 },
    };

    [Theory]
    [MemberData(nameof(WholeFloats))]
    public void Construct_EqWholeFloatForAnIntegerSource_IsRefusedNamingTheWhenAndTheMember(string kind, object? value)
    {
        // Act
        var thrown = Record.Exception(() => Build(kind, value));

        // Assert
        var error = Assert.IsType<ArgumentException>(thrown);
        Assert.StartsWith($"when 1 tests {kind} field 0 ('", error.Message, StringComparison.Ordinal);
        Assert.Contains("not a float, double or decimal", error.Message, StringComparison.Ordinal);
    }

    [Theory]
    [MemberData(nameof(Built))]
    public void Construct_EqValueInTheSourceRange_Builds(string kind, object? value)
    {
        // Act
        var thrown = Record.Exception(() => Build(kind, value));

        // Assert
        Assert.Null(thrown);
    }

    [Fact]
    public void Construct_EqValueOutOfRangeInAListElement_IsRefused()
    {
        // Act
        var thrown = Record.Exception(() => new Scheme<Holder>(1,
            Field.List((Holder x) => x.Xs,
                Field.Group(0, (Row x) => x.Mark,
                    Field.U8<Row>(0, x => x.Mode),
                    Field.When(1, Condition.Eq(0, 300), Field.U8<Row>(1, x => x.Speed))))));

        // Assert
        Assert.Contains("'Mode'", Assert.IsType<ArgumentException>(thrown).Message);
    }

    [Fact]
    public void Pack_EqValueInRange_BytesAreUnchanged()
    {
        // Arrange
        var scheme = Build("u8", 5);

        // Act
        var held = BinaryPacker.Pack(scheme, new Row { Mode = 5, Speed = 9 });
        var other = BinaryPacker.Pack(scheme, new Row { Mode = 4, Speed = 9 });

        // Assert
        Assert.Equal("010509", Convert.ToHexString(held).ToLowerInvariant());
        Assert.Equal("0104", Convert.ToHexString(other).ToLowerInvariant());
    }

    private sealed class Holder
    {
        public List<object?>? Xs { get; set; }
    }
}
