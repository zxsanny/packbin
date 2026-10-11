using System.Globalization;
using Packbin;

namespace Packbin.Tests;

// AZ-2120 AC-3, AZ-2128: a `when` that is a member of a `flags` container (directly, in a group under it, or as the field
// of a split flag bit) is a value like any other. Its bit is on exactly when the condition holds and its body holds a
// value; unpack of a set bit reads the body; a set member that cannot be written in full fails pack naming the value.
public class FlagsWhenMemberTests
{
    private sealed class Row
    {
        public byte Mode { get; set; }
        public byte? Speed { get; set; }
        public byte? Extra { get; set; }
        public ushort? Heading { get; set; }
        public bool? Mark { get; set; }
    }

    private static string Hex(byte[] raw) => Convert.ToHexString(raw).ToLowerInvariant();

    private static int Int(object? value) => Convert.ToInt32(value, CultureInfo.InvariantCulture);

    private static Scheme<Row> Direct() => new(1,
        Field.U8<Row>(0, x => x.Mode),
        Field.Flags(1,
            Field.When(1, Condition.Eq(0, 1), Field.U8<Row>(1, x => x.Speed)),
            Field.U16<Row>(2, x => x.Heading)));

    private static Scheme<Row> TwoValueBody() => new(1,
        Field.U8<Row>(0, x => x.Mode),
        Field.Flags(1,
            Field.When(1, Condition.Eq(0, 1), Field.U8<Row>(1, x => x.Speed), Field.U8<Row>(2, x => x.Extra)),
            Field.U16<Row>(3, x => x.Heading)));

    private static Scheme<Row> InGroup() => new(1,
        Field.U8<Row>(0, x => x.Mode),
        Field.Flags(1,
            Field.Group(1, (Row x) => x.Mark, Field.When(1, Condition.Eq(0, 1), Field.U8<Row>(1, x => x.Speed))),
            Field.U16<Row>(2, x => x.Heading)));

    private static Scheme<Row> InGroupWithSibling() => new(1,
        Field.U8<Row>(0, x => x.Mode),
        Field.Flags(1,
            Field.Group(1, (Row x) => x.Mark,
                Field.U8<Row>(1, x => x.Extra),
                Field.When(2, Condition.Eq(0, 1), Field.U8<Row>(2, x => x.Speed))),
            Field.U16<Row>(3, x => x.Heading)));

    private static Scheme<Row> SplitBit()
    {
        var m = Field.FlagByte();
        return new Scheme<Row>(1,
            Field.U8<Row>(0, x => x.Mode),
            m,
            m.Bit(Field.When(1, Condition.Eq(0, 1), Field.U8<Row>(1, x => x.Speed))),
            m.Bit(Field.U16<Row>(2, x => x.Heading)));
    }

    private static Scheme<Row> AfterEarlierMember() => new(1,
        Field.Flags(0,
            Field.U8<Row>(0, x => x.Mode),
            Field.When(1, Condition.Eq(0, 1), Field.U8<Row>(1, x => x.Speed))));

    private static Row Typed(Scheme<Row> scheme, string hex)
    {
        Row? got = null;
        var err = BinaryPacker.Unpack(Convert.FromHexString(hex), scheme.On(v => got = v));
        Assert.Null(err);
        return got!;
    }

    private static Dictionary<string, object?> Dict(byte mode, byte? speed, ushort? heading)
    {
        var row = new Dictionary<string, object?> { ["Mode"] = mode };
        if (speed is not null)
            row["Speed"] = speed;
        if (heading is not null)
            row["Heading"] = heading;
        return row;
    }

    public static TheoryData<string> Shapes() => new() { "direct", "in group", "split bit" };

    private static Scheme<Row> Build(string shape) => shape switch
    {
        "direct" => Direct(),
        "in group" => InGroup(),
        _ => SplitBit(),
    };

    [Theory]
    [MemberData(nameof(Shapes))]
    public void Ac3_Typed_ConditionHoldsAndBodyPresent_WritesTheBodyAndRoundTrips(string shape)
    {
        // Arrange
        var scheme = Build(shape);

        // Act
        var raw = BinaryPacker.Pack(scheme, new Row { Mode = 1, Speed = 7, Heading = 90 });
        var got = Typed(scheme, Hex(raw));

        // Assert
        Assert.Equal("01" + "01" + "03" + "07" + "5a00", Hex(raw));
        Assert.Equal((1, (byte?)7, (ushort?)90), (got.Mode, got.Speed, got.Heading));
    }

    [Theory]
    [MemberData(nameof(Shapes))]
    public void Ac3_Dictionary_ConditionHoldsAndBodyPresent_WritesTheBodyAndRoundTrips(string shape)
    {
        // Arrange
        var scheme = Build(shape);

        // Act
        var raw = BinaryPacker.Pack(scheme, Dict(1, 7, 90));
        var got = BinaryPacker.Read(scheme, raw);

        // Assert
        Assert.Equal("01" + "01" + "03" + "07" + "5a00", Hex(raw));
        Assert.Null(got.Error);
        Assert.Equal((1, 7, 90), (Int(got.Values["Mode"]), Int(got.Values["Speed"]), Int(got.Values["Heading"])));
    }

    [Theory]
    [MemberData(nameof(Shapes))]
    public void Ac3_Typed_ConditionFalse_LeavesTheBitClearAndRoundTrips(string shape)
    {
        // Arrange
        var scheme = Build(shape);

        // Act
        var raw = BinaryPacker.Pack(scheme, new Row { Mode = 0, Heading = 90 });
        var got = Typed(scheme, Hex(raw));

        // Assert
        Assert.Equal("01" + "00" + "02" + "5a00", Hex(raw));
        Assert.Equal((0, (byte?)null, (ushort?)90), (got.Mode, got.Speed, got.Heading));
    }

    [Theory]
    [MemberData(nameof(Shapes))]
    public void Ac3_Dictionary_ConditionFalse_LeavesTheBitClearAndRoundTrips(string shape)
    {
        // Arrange
        var scheme = Build(shape);

        // Act
        var raw = BinaryPacker.Pack(scheme, Dict(0, null, 90));
        var got = BinaryPacker.Read(scheme, raw);

        // Assert
        Assert.Equal("01" + "00" + "02" + "5a00", Hex(raw));
        Assert.Null(got.Error);
        Assert.False(got.Values.ContainsKey("Speed"));
        Assert.Equal(90, Int(got.Values["Heading"]));
    }

    [Theory]
    [InlineData("direct")]
    [InlineData("in group")]
    public void Ac3_ConditionFalseBodyGiven_IsNotWritten(string shape)
    {
        // Arrange
        var scheme = Build(shape);

        // Act
        var typed = BinaryPacker.Pack(scheme, new Row { Mode = 0, Speed = 7, Heading = 90 });
        var dict = BinaryPacker.Pack(scheme, Dict(0, 7, 90));

        // Assert
        Assert.Equal("01" + "00" + "02" + "5a00", Hex(typed));
        Assert.Equal(Hex(typed), Hex(dict));
    }

    // AZ-2331: a split flag byte decides its bit where it is written, so a body given with a false condition would be
    // dropped without a word; pack names the member instead (the combined `flags` form keeps the reference reading).
    [Fact]
    public void Ac3_SplitBit_ConditionFalseBodyGiven_NamesTheMember()
    {
        // Arrange
        var scheme = SplitBit();

        // Act
        var typed = Record.Exception(() => BinaryPacker.Pack(scheme, new Row { Mode = 0, Speed = 7, Heading = 90 }));
        var dict = Record.Exception(() => BinaryPacker.Pack(scheme, Dict(0, 7, 90)));

        // Assert
        Assert.Contains("'Speed'", Assert.IsType<ArgumentException>(typed).Message);
        Assert.Contains("'Speed'", Assert.IsType<ArgumentException>(dict).Message);
    }

    [Theory]
    [MemberData(nameof(Shapes))]
    public void Ac3_ConditionHoldsBodyAbsent_LeavesTheBitClear(string shape)
    {
        // Arrange
        var scheme = Build(shape);

        // Act
        var typed = BinaryPacker.Pack(scheme, new Row { Mode = 1, Heading = 90 });
        var dict = BinaryPacker.Pack(scheme, Dict(1, null, 90));
        var got = Typed(scheme, Hex(typed));

        // Assert
        Assert.Equal("01" + "01" + "02" + "5a00", Hex(typed));
        Assert.Equal(Hex(typed), Hex(dict));
        Assert.Null(got.Speed);
    }

    [Theory]
    [MemberData(nameof(Shapes))]
    public void Ac3_OldPacketWithTheBitClear_StillUnpacksToARowWithoutTheMember(string shape)
    {
        // Arrange
        var scheme = Build(shape);

        // Act
        var got = Typed(scheme, "01" + "01" + "02" + "5a00");

        // Assert
        Assert.Equal((1, (byte?)null, (ushort?)90), (got.Mode, got.Speed, got.Heading));
    }

    [Fact]
    public void Ac3_Typed_RowWithOnlyTheWhenBody_SetsOnlyTheWhenBit()
    {
        // Arrange
        var scheme = Direct();

        // Act
        var raw = BinaryPacker.Pack(scheme, new Row { Mode = 1, Speed = 7 });
        var got = Typed(scheme, Hex(raw));

        // Assert
        Assert.Equal("01" + "01" + "01" + "07", Hex(raw));
        Assert.Equal((byte?)7, got.Speed);
        Assert.Null(got.Heading);
    }

    [Fact]
    public void Ac3_ConditionOnAnEarlierMemberOfTheSameFlags_IsDecidedOnWhatWasWritten()
    {
        // Arrange
        var scheme = AfterEarlierMember();

        // Act
        var holds = BinaryPacker.Pack(scheme, new Row { Mode = 1, Speed = 7 });
        var absent = BinaryPacker.Pack(scheme, new Dictionary<string, object?> { ["Speed"] = (byte)7 });
        var got = Typed(scheme, Hex(holds));

        // Assert
        Assert.Equal("01" + "03" + "01" + "07", Hex(holds));
        Assert.Equal("01" + "00", Hex(absent));
        Assert.Equal((1, (byte?)7), (got.Mode, got.Speed));
    }

    [Fact]
    public void Ac3_SetWhenWithAMissingBodyValue_FailsNamingTheValue()
    {
        // Arrange
        var scheme = TwoValueBody();

        // Act
        var typed = Assert.Throws<ArgumentException>(() =>
            BinaryPacker.Pack(scheme, new Row { Mode = 1, Speed = 7, Heading = 90 }));
        var dict = Assert.Throws<ArgumentException>(() => BinaryPacker.Pack(scheme, Dict(1, 7, 90)));

        // Assert
        Assert.Contains("Extra", typed.Message, StringComparison.Ordinal);
        Assert.Contains("Extra", dict.Message, StringComparison.Ordinal);
    }

    [Fact]
    public void Ac3_TwoValueBody_RoundTrips()
    {
        // Arrange
        var scheme = TwoValueBody();

        // Act
        var raw = BinaryPacker.Pack(scheme, new Row { Mode = 1, Speed = 7, Extra = 8, Heading = 90 });
        var got = Typed(scheme, Hex(raw));

        // Assert
        Assert.Equal("01" + "01" + "03" + "07" + "08" + "5a00", Hex(raw));
        Assert.Equal(((byte?)7, (byte?)8, (ushort?)90), (got.Speed, got.Extra, got.Heading));
    }

    [Fact]
    public void Ac3_GroupWithAWhenAndASiblingValue_WritesTheWhenBodyOrFailsNamingIt()
    {
        // Arrange
        var scheme = InGroupWithSibling();

        // Act
        var raw = BinaryPacker.Pack(scheme, new Row { Mode = 1, Extra = 4, Speed = 7, Heading = 90 });
        var got = Typed(scheme, Hex(raw));
        var ex = Assert.Throws<ArgumentException>(() => BinaryPacker.Pack(scheme, new Row { Mode = 1, Extra = 4 }));

        // Assert
        Assert.Equal("01" + "01" + "03" + "04" + "07" + "5a00", Hex(raw));
        Assert.Equal(((byte?)4, (byte?)7, (ushort?)90), (got.Extra, got.Speed, got.Heading));
        Assert.Contains("Speed", ex.Message, StringComparison.Ordinal);
    }

    [Fact]
    public void Ac3_GroupWithAWhenAndASiblingValue_ConditionFalse_WritesOnlyTheSibling()
    {
        // Arrange
        var scheme = InGroupWithSibling();

        // Act
        var raw = BinaryPacker.Pack(scheme, new Row { Mode = 0, Extra = 4, Heading = 90 });
        var got = Typed(scheme, Hex(raw));

        // Assert
        Assert.Equal("01" + "00" + "03" + "04" + "5a00", Hex(raw));
        Assert.Equal(((byte?)4, (byte?)null, (ushort?)90), (got.Extra, got.Speed, got.Heading));
    }

    [Theory]
    [MemberData(nameof(Shapes))]
    public void Ac3_BodyValueOutsideTheFieldRange_FailsPack(string shape)
    {
        // Arrange
        var scheme = Build(shape);
        var row = Dict(1, null, 90);
        row["Speed"] = 300;

        // Act
        var ex = Assert.Throws<ArgumentException>(() => BinaryPacker.Pack(scheme, row));

        // Assert
        Assert.Contains("Speed", ex.Message, StringComparison.Ordinal);
    }
}
