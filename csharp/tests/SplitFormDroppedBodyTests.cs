using Packbin;

namespace Packbin.Tests;

// AZ-2331: a split flag byte decides its `when`/`times` bits where the byte is written. A body whose condition or count
// is written after the byte (and holds there) or whose count field was skipped would be dropped silently; pack names
// the member instead. A false condition drops its body by design, as in the combined `flags` form: no body, no error.
// A source written before the byte packs as before.
public class SplitFormDroppedBodyTests
{
    private sealed class Row
    {
        public byte Mode { get; set; }
        public byte C { get; set; }
        public byte? Speed { get; set; }
        public byte? Pt { get; set; }
        public ushort? Heading { get; set; }
        public bool? Mark { get; set; }
    }

    private static string Hex(byte[] raw) => Convert.ToHexString(raw).ToLowerInvariant();

    private static Dictionary<string, object?> Dict(params (string Name, object? Value)[] items) =>
        items.ToDictionary(item => item.Name, item => item.Value);

    // The condition's source is written between the byte and the bit.
    private static Scheme<Row> WhenSourceAfterByte()
    {
        var m = Field.FlagByte();
        return new Scheme<Row>(1,
            m,
            Field.U8<Row>(0, x => x.Mode),
            m.Bit(Field.When(1, Condition.Eq(0, 1), Field.U8<Row>(1, x => x.Speed))),
            m.Bit(Field.U16<Row>(2, x => x.Heading)));
    }

    private static Scheme<Row> WhenSourceBeforeByte()
    {
        var m = Field.FlagByte();
        return new Scheme<Row>(1,
            Field.U8<Row>(0, x => x.Mode),
            m,
            m.Bit(Field.When(1, Condition.Eq(0, 1), Field.U8<Row>(1, x => x.Speed))),
            m.Bit(Field.U16<Row>(2, x => x.Heading)));
    }

    private static Scheme<Row> TimesCountAfterByte()
    {
        var m = Field.FlagByte();
        return new Scheme<Row>(1,
            m,
            Field.U8<Row>(0, x => x.C),
            m.Bit(Field.Times(1, 0, Field.U8<Row>(1, x => x.Pt))),
            m.Bit(Field.U16<Row>(2, x => x.Heading)));
    }

    private static Scheme<Row> TimesCountBeforeByte()
    {
        var m = Field.FlagByte();
        return new Scheme<Row>(1,
            Field.U8<Row>(0, x => x.C),
            m,
            m.Bit(Field.Times(1, 0, Field.U8<Row>(1, x => x.Pt))),
            m.Bit(Field.U16<Row>(2, x => x.Heading)));
    }

    // The count sits behind a `when`, so a row with mode 0 skips the count field.
    private static Scheme<Row> TimesCountSkipped()
    {
        var m = Field.FlagByte();
        return new Scheme<Row>(1,
            Field.U8<Row>(0, x => x.Mode),
            m,
            Field.When(1, Condition.Eq(0, 1), Field.U8<Row>(1, x => x.C)),
            m.Bit(Field.Times(2, 1, Field.U8<Row>(2, x => x.Pt))),
            m.Bit(Field.U16<Row>(3, x => x.Heading)));
    }

    private static Scheme<Row> WhenInGroupBit()
    {
        var m = Field.FlagByte();
        return new Scheme<Row>(1,
            Field.U8<Row>(0, x => x.Mode),
            m,
            m.Bit(Field.Group(1, (Row x) => x.Mark, Field.When(1, Condition.Eq(0, 1), Field.U8<Row>(1, x => x.Speed)))),
            m.Bit(Field.U16<Row>(2, x => x.Heading)));
    }

    [Fact]
    public void Ac1_Pack_WhenSourceWrittenAfterTheByte_NamesTheBody()
    {
        // Arrange
        var scheme = WhenSourceAfterByte();

        // Act
        var typed = Record.Exception(() => BinaryPacker.Pack(scheme, new Row { Mode = 1, Speed = 7, Heading = 90 }));
        var dict = Record.Exception(() =>
            BinaryPacker.Pack(scheme, Dict(("Mode", (byte)1), ("Speed", (byte)7), ("Heading", (ushort)90))));

        // Assert
        Assert.Contains("'Speed'", Assert.IsType<ArgumentException>(typed).Message);
        Assert.Contains("'Speed'", Assert.IsType<ArgumentException>(dict).Message);
    }

    [Fact]
    public void Ac1_Pack_WhenSourceWrittenAfterTheByteAndNoBody_PacksAsBefore()
    {
        // Arrange
        var scheme = WhenSourceAfterByte();

        // Act
        var raw = BinaryPacker.Pack(scheme, new Row { Mode = 1, Heading = 90 });

        // Assert
        Assert.Equal("0102015a00", Hex(raw));
    }

    [Fact]
    public void Ac1_Pack_TimesCountWrittenAfterTheByte_NamesTheBody()
    {
        // Arrange
        var scheme = TimesCountAfterByte();
        var row = Dict(("C", (byte)2), ("Pt", new object[] { (byte)5, (byte)6 }), ("Heading", (ushort)90));

        // Act
        var thrown = Record.Exception(() => BinaryPacker.Pack(scheme, row));

        // Assert
        Assert.Contains("'Pt'", Assert.IsType<ArgumentException>(thrown).Message);
    }

    [Fact]
    public void Ac2_Pack_SkippedCountWithValuesGiven_NamesTheBody()
    {
        // Arrange
        var scheme = TimesCountSkipped();
        var row = Dict(("Mode", (byte)0), ("Pt", new object[] { (byte)5 }), ("Heading", (ushort)90));

        // Act
        var thrown = Record.Exception(() => BinaryPacker.Pack(scheme, row));

        // Assert
        Assert.Contains("'Pt'", Assert.IsType<ArgumentException>(thrown).Message);
    }

    [Fact]
    public void Ac2_Pack_SkippedCountWithNoValues_PacksAsBefore()
    {
        // Arrange
        var scheme = TimesCountSkipped();

        // Act
        var raw = BinaryPacker.Pack(scheme, Dict(("Mode", (byte)0), ("Heading", (ushort)90)));

        // Assert
        Assert.Equal("0100025a00", Hex(raw));
    }

    [Fact]
    public void Ac3_Pack_FalseConditionWithABodyGiven_PacksWithoutTheBody()
    {
        // Arrange
        var scheme = WhenSourceBeforeByte();

        // Act
        var typed = BinaryPacker.Pack(scheme, new Row { Mode = 0, Speed = 7, Heading = 90 });
        var dict = BinaryPacker.Pack(scheme, Dict(("Mode", (byte)0), ("Speed", (byte)7), ("Heading", (ushort)90)));

        // Assert
        Assert.Equal("0100025a00", Hex(typed));
        Assert.Equal(Hex(typed), Hex(dict));
    }

    [Fact]
    public void Ac3_Pack_FalseConditionWrittenAfterTheByteWithABodyGiven_PacksWithoutTheBody()
    {
        // Arrange
        var scheme = WhenSourceAfterByte();

        // Act
        var typed = BinaryPacker.Pack(scheme, new Row { Mode = 0, Speed = 7, Heading = 90 });
        var dict = BinaryPacker.Pack(scheme, Dict(("Mode", (byte)0), ("Speed", (byte)7), ("Heading", (ushort)90)));

        // Assert
        Assert.Equal("0102005a00", Hex(typed));
        Assert.Equal(Hex(typed), Hex(dict));
    }

    [Fact]
    public void Ac3_Pack_FalseConditionInAGroupBitWithABodyGiven_PacksWithoutTheBody()
    {
        // Arrange
        var scheme = WhenInGroupBit();

        // Act
        var raw = BinaryPacker.Pack(scheme, new Row { Mode = 0, Speed = 7, Heading = 90 });

        // Assert
        Assert.Equal("0100025a00", Hex(raw));
    }

    [Fact]
    public void Ac3_Pack_FalseConditionHostileValueOutsideTheRange_StillPacksWithoutTheBody()
    {
        // Arrange: a source above 1 and a body at the edge of its range stay silent behind a false condition
        var scheme = WhenSourceAfterByte();

        // Act
        var raw = BinaryPacker.Pack(scheme, new Row { Mode = 200, Speed = 255, Heading = 90 });

        // Assert
        Assert.Equal("0102c85a00", Hex(raw));
    }

    [Fact]
    public void Ac4_Pack_SourceBeforeTheByte_BytesAreUnchanged()
    {
        // Arrange
        var when = WhenSourceBeforeByte();
        var times = TimesCountBeforeByte();

        // Act
        var whenTrue = BinaryPacker.Pack(when, new Row { Mode = 1, Speed = 7, Heading = 90 });
        var whenFalse = BinaryPacker.Pack(when, new Row { Mode = 0, Heading = 90 });
        var two = BinaryPacker.Pack(times, Dict(("C", (byte)2), ("Pt", new object[] { (byte)5, (byte)6 }), ("Heading", (ushort)90)));
        var zero = BinaryPacker.Pack(times, Dict(("C", (byte)0), ("Heading", (ushort)90)));

        // Assert
        Assert.Equal("010103075a00", Hex(whenTrue));
        Assert.Equal("0100025a00", Hex(whenFalse));
        Assert.Equal("01020305065a00", Hex(two));
        Assert.Equal("0100025a00", Hex(zero));
    }

    // The count is written before the byte and is zero: no round, so a lone value has nothing to be dropped from.
    [Fact]
    public void Ac2_Pack_CountWrittenBeforeTheByteIsZeroWithALoneValue_PacksWithoutTheBody()
    {
        // Arrange
        var scheme = TimesCountBeforeByte();

        // Act
        var typed = BinaryPacker.Pack(scheme, new Row { C = 0, Pt = 5, Heading = 90 });
        var dict = BinaryPacker.Pack(scheme, Dict(("C", (byte)0), ("Pt", (byte)5), ("Heading", (ushort)90)));

        // Assert
        Assert.Equal("0100025a00", Hex(typed));
        Assert.Equal(Hex(typed), Hex(dict));
    }

    [Fact]
    public void Ac2_Pack_CountWrittenBeforeTheByteIsZeroAndTheValueIsHostile_StillPacksWithoutTheBody()
    {
        // Arrange: the body value at the top of its range is not looked at when the count is zero
        var scheme = TimesCountBeforeByte();

        // Act
        var raw = BinaryPacker.Pack(scheme, Dict(("C", (byte)0), ("Pt", (byte)255), ("Heading", (ushort)65535)));

        // Assert
        Assert.Equal("010002ffff", Hex(raw));
    }

    [Fact]
    public void Ac2_Pack_CountWrittenAfterTheByteIsZeroWithALoneValue_PacksWithoutTheBody()
    {
        // Arrange
        var scheme = TimesCountAfterByte();

        // Act
        var raw = BinaryPacker.Pack(scheme, Dict(("C", (byte)0), ("Pt", (byte)5), ("Heading", (ushort)90)));

        // Assert
        Assert.Equal("0102005a00", Hex(raw));
    }

    // A list with items under a zero count is an error everywhere (owner decision 7); a typed row holds no list in a
    // `byte?` member, so these rows are dictionaries.
    [Fact]
    public void Ac2_Pack_CountWrittenAfterTheByteIsZeroWithAList_NamesTheBody()
    {
        // Arrange
        var scheme = TimesCountAfterByte();

        // Act
        var array = Record.Exception(() =>
            BinaryPacker.Pack(scheme, Dict(("C", (byte)0), ("Pt", new object[] { (byte)5 }), ("Heading", (ushort)90))));
        var list = Record.Exception(() =>
            BinaryPacker.Pack(scheme, Dict(("C", (byte)0), ("Pt", new List<object?> { (byte)5 }), ("Heading", (ushort)90))));

        // Assert
        Assert.Contains("'Pt'", Assert.IsType<ArgumentException>(array).Message);
        Assert.Contains("'Pt'", Assert.IsType<ArgumentException>(list).Message);
    }

    [Fact]
    public void Ac2_Pack_CountWrittenAfterTheByteIsZeroWithAnEmptyList_PacksWithoutTheBody()
    {
        // Arrange
        var scheme = TimesCountAfterByte();

        // Act
        var raw = BinaryPacker.Pack(scheme, Dict(("C", (byte)0), ("Pt", new object[0]), ("Heading", (ushort)90)));

        // Assert
        Assert.Equal("0102005a00", Hex(raw));
    }

    [Fact]
    public void Ac2_Pack_CountWrittenBeforeTheByteIsZeroWithAList_NamesTheBody()
    {
        // Arrange
        var scheme = TimesCountBeforeByte();

        // Act
        var thrown = Record.Exception(() =>
            BinaryPacker.Pack(scheme, Dict(("C", (byte)0), ("Pt", new object[] { (byte)5 }), ("Heading", (ushort)90))));

        // Assert
        Assert.Contains("'Pt'", Assert.IsType<ArgumentException>(thrown).Message);
    }

    [Fact]
    public void Ac2_Pack_SkippedCountWithALoneValue_NamesTheBodyAndSaysTheCountWasSkipped()
    {
        // Arrange
        var scheme = TimesCountSkipped();

        // Act
        var thrown = Record.Exception(() =>
            BinaryPacker.Pack(scheme, Dict(("Mode", (byte)0), ("Pt", (byte)5), ("Heading", (ushort)90))));

        // Assert
        var message = Assert.IsType<ArgumentException>(thrown).Message;
        Assert.Contains("'Pt'", message);
        Assert.Contains("was skipped", message);
    }

    // The condition's source is a plain optional field that no row gave: it was never written, so the condition cannot hold.
    [Fact]
    public void Ac3_Pack_WhenSourceNeverWrittenWithABodyGiven_PacksWithoutTheBody()
    {
        // Arrange
        var m = Field.FlagByte();
        var scheme = new Scheme<Row>(1,
            m,
            m.Bit(Field.U8<Row>(0, x => x.Mode)),
            m.Bit(Field.When(1, Condition.Eq(0, 1), Field.U8<Row>(1, x => x.Speed))),
            m.Bit(Field.U16<Row>(2, x => x.Heading)));

        // Act
        var raw = BinaryPacker.Pack(scheme, Dict(("Speed", (byte)7), ("Heading", (ushort)90)));

        // Assert
        Assert.Equal("01045a00", Hex(raw));
    }

    // A combined `flags` inside a split bit is written only when the bit is on, so its body is dropped like a `when`'s.
    private static Scheme<Row> FlagsInSplitBit()
    {
        var m = Field.FlagByte();
        return new Scheme<Row>(1,
            m,
            Field.U8<Row>(0, x => x.Mode),
            m.Bit(Field.Flags(1, Field.When(1, Condition.Eq(0, 1), Field.U8<Row>(1, x => x.Speed)))),
            m.Bit(Field.U16<Row>(2, x => x.Heading)));
    }

    [Fact]
    public void Ac1_Pack_FlagsInASplitBitWhoseConditionHolds_NamesTheBody()
    {
        // Arrange
        var scheme = FlagsInSplitBit();

        // Act
        var typed = Record.Exception(() => BinaryPacker.Pack(scheme, new Row { Mode = 1, Speed = 7, Heading = 90 }));
        var dict = Record.Exception(() =>
            BinaryPacker.Pack(scheme, Dict(("Mode", (byte)1), ("Speed", (byte)7), ("Heading", (ushort)90))));

        // Assert
        Assert.Contains("'Speed'", Assert.IsType<ArgumentException>(typed).Message);
        Assert.Contains("'Speed'", Assert.IsType<ArgumentException>(dict).Message);
    }

    [Fact]
    public void Ac3_Pack_FlagsInASplitBitWhoseConditionIsFalse_PacksWithoutTheBody()
    {
        // Arrange
        var scheme = FlagsInSplitBit();

        // Act
        var typed = BinaryPacker.Pack(scheme, new Row { Mode = 0, Speed = 7, Heading = 90 });
        var hostile = BinaryPacker.Pack(scheme, new Row { Mode = 200, Speed = 255, Heading = 90 });

        // Assert
        Assert.Equal("0102005a00", Hex(typed));
        Assert.Equal("0102c85a00", Hex(hostile));
    }
}
