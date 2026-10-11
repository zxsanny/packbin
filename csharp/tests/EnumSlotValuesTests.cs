using Packbin;

namespace Packbin.Tests;

// AZ-2359 (owner decision 7 of loop 20): C# keeps refusing an enum member for every numeric field, whatever its
// underlying type, naming the field. The other packages' rules are pinned in their own suites.
public class EnumSlotValuesTests
{
    private enum Level : byte
    {
        High = 200,
    }

    private enum Wide
    {
        Three = 3,
    }

    private sealed class Row
    {
        public byte A { get; set; }
        public int S { get; set; }
        public double D { get; set; }
    }

    [Fact]
    public void Pack_ByteEnumInAU8Slot_IsRefusedNamingTheField()
    {
        // Arrange
        var scheme = new Scheme<Row>(1, Field.U8<Row>(0, x => x.A));

        // Act
        var error = Assert.Throws<ArgumentException>(() =>
            BinaryPacker.Pack(scheme, new Dictionary<string, object?> { ["A"] = Level.High }));

        // Assert
        Assert.Equal("A: expected a number for u8, got Level", error.Message);
    }

    [Fact]
    public void Pack_IntEnumInAU2Slot_IsRefusedNamingTheField()
    {
        // Arrange
        var scheme = new Scheme<Row>(1, Field.U2<Row>((0, x => x.S)));

        // Act
        var error = Assert.Throws<ArgumentException>(() =>
            BinaryPacker.Pack(scheme, new Dictionary<string, object?> { ["S"] = Wide.Three }));

        // Assert
        Assert.Equal("S: expected 2-bit int", error.Message);
    }

    [Fact]
    public void Pack_EnumInAFloatField_IsRefusedNamingTheField()
    {
        // Arrange
        var scheme = new Scheme<Row>(1, Field.F64<Row>(0, x => x.D));

        // Act
        var error = Assert.Throws<ArgumentException>(() =>
            BinaryPacker.Pack(scheme, new Dictionary<string, object?> { ["D"] = Wide.Three }));

        // Assert
        Assert.Equal("D: expected a number for f64, got Wide", error.Message);
    }

    [Fact]
    public void Pack_TheEnumsNumber_PacksAsAnInteger()
    {
        // Arrange
        var scheme = new Scheme<Row>(1, Field.U8<Row>(0, x => x.A));

        // Act
        var raw = BinaryPacker.Pack(scheme, new Dictionary<string, object?> { ["A"] = (byte)Level.High });

        // Assert
        Assert.Equal("01c8", Convert.ToHexString(raw).ToLowerInvariant());
    }
}
