using Packbin;

namespace Packbin.Tests;

// AZ-2128 ("any value, any kind"): a u2 that is a direct member of Flags, or the field of a flag bit, sets its bit when
// any of its slots has a value, so a slot left out is refused by name instead of the others being dropped.
public class U2PresenceTests
{
    private sealed class Row
    {
        public int A { get; set; }
        public int B { get; set; }
    }

    private static string Hex(byte[] raw) => Convert.ToHexString(raw).ToLowerInvariant();

    private static Dictionary<string, object?> Values(params (string Name, object Value)[] slots) =>
        slots.ToDictionary(s => s.Name, s => (object?)s.Value);

    private static Scheme<Row> Combined() =>
        new(1, Field.Flags(0, Field.U2<Row>((0, x => x.A), (1, x => x.B))));

    private static Scheme<Row> Split()
    {
        var m = Field.FlagByte();
        return new Scheme<Row>(1, m, m.Bit(Field.U2<Row>((0, x => x.A), (1, x => x.B))));
    }

    public static TheoryData<bool> Forms() => new() { false, true };

    [Theory]
    [MemberData(nameof(Forms))]
    public void Pack_OnlyTheSecondSlot_ThrowsNamingTheFirst(bool split)
    {
        // Arrange
        var scheme = split ? Split() : Combined();

        // Act
        var error = Assert.Throws<ArgumentException>(() => BinaryPacker.Pack(scheme, Values(("B", 2))));

        // Assert
        Assert.Contains("A", error.Message, StringComparison.Ordinal);
    }

    [Theory]
    [MemberData(nameof(Forms))]
    public void Pack_OnlyTheFirstSlot_ThrowsNamingTheSecond(bool split)
    {
        // Arrange
        var scheme = split ? Split() : Combined();

        // Act
        var error = Assert.Throws<ArgumentException>(() => BinaryPacker.Pack(scheme, Values(("A", 1))));

        // Assert
        Assert.Contains("B", error.Message, StringComparison.Ordinal);
    }

    [Theory]
    [MemberData(nameof(Forms))]
    public void Pack_BothSlots_SetsTheBitAndWritesOneByte(bool split)
    {
        // Arrange
        var scheme = split ? Split() : Combined();

        // Act
        var raw = BinaryPacker.Pack(scheme, Values(("A", 1), ("B", 2)));

        // Assert
        Assert.Equal("010109", Hex(raw));
    }

    [Theory]
    [MemberData(nameof(Forms))]
    public void Pack_NoSlot_LeavesTheBitClear(bool split)
    {
        // Arrange
        var scheme = split ? Split() : Combined();

        // Act
        var raw = BinaryPacker.Pack(scheme, Values());

        // Assert
        Assert.Equal("0100", Hex(raw));
    }
}
