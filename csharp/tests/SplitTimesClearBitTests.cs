using Packbin;

namespace Packbin.Tests;

// AZ-2384 (U4): a split-bit `times` whose count (above 0) is written after the flag byte and whose body is absent or
// empty packs a clear bit, as TypeScript does (rows 40 to 43 of _docs/03_implementation/reference_loop21_slots.md). A body
// that is given is refused (row 43); C# words that refusal its own way, see SplitFormDroppedBodyTests.
public class SplitTimesClearBitTests
{
    private sealed class Row
    {
        public byte N { get; set; }
        public byte? Pt { get; set; }
        public ushort? Heading { get; set; }
    }

    private static string Hex(byte[] raw) => Convert.ToHexString(raw).ToLowerInvariant();

    private static Dictionary<string, object?> Dict(params (string Name, object? Value)[] items) =>
        items.ToDictionary(item => item.Name, item => item.Value);

    // flag byte, n, bit 0 = times(n) { u8 pt }, bit 1 = u16 heading
    private static Scheme<Row> TimesAfterTheByte()
    {
        var fb = Field.FlagByte();
        return new Scheme<Row>(1,
            fb,
            Field.U8<Row>(0, x => x.N),
            fb.Bit(Field.Times(1, 0, Field.U8<Row>(1, x => x.Pt))),
            fb.Bit(Field.U16<Row>(2, x => x.Heading)));
    }

    [Fact]
    public void Ac1_Pack_CountAboveZeroAndBodyAbsent_PacksAClearBit()
    {
        // Arrange (row 40)
        var scheme = TimesAfterTheByte();

        // Act
        var dict = BinaryPacker.Pack(scheme, Dict(("N", (byte)2), ("Heading", (ushort)90)));
        var typed = BinaryPacker.Pack(scheme, new Row { N = 2, Heading = 90 });

        // Assert
        Assert.Equal(("0102025a00", "0102025a00"), (Hex(dict), Hex(typed)));
    }

    [Fact]
    public void Ac1_Pack_CountAboveZeroAndEmptyBody_PacksAClearBit()
    {
        // Arrange (row 41)
        var scheme = TimesAfterTheByte();

        // Act
        var raw = BinaryPacker.Pack(scheme, Dict(("N", (byte)2), ("Pt", new object[] { }), ("Heading", (ushort)90)));

        // Assert
        Assert.Equal("0102025a00", Hex(raw));
    }

    [Fact]
    public void Ac1_Pack_CountZeroAndBodyAbsent_PacksAClearBit()
    {
        // Arrange (row 42)
        var scheme = TimesAfterTheByte();

        // Act
        var raw = BinaryPacker.Pack(scheme, Dict(("N", (byte)0), ("Heading", (ushort)90)));

        // Assert
        Assert.Equal("0102005a00", Hex(raw));
    }

    [Fact]
    public void Ac2_Pack_BodyGiven_IsRefusedNamingTheBody()
    {
        // Arrange (row 43)
        var scheme = TimesAfterTheByte();

        // Act
        var error = Budget.Refused(scheme, Dict(("N", (byte)2), ("Pt", new object[] { (byte)5, (byte)6 }), ("Heading", (ushort)90)));

        // Assert
        Assert.Equal(
            "'Pt' has a value, but its flag bit is clear: the count that decides the bit is written after the flag byte",
            error.Message);
    }
}
