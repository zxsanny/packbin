using Packbin;

namespace Packbin.Tests;

// AZ-2115, C# part: the split-form reference scheme, as TypeScript and Java pin it. `u8 sid`, a flag byte, a `when` on
// the sid between the byte and its bit, then the bit of a u16 heading.
public class SplitFormReferenceTests
{
    private sealed class Row
    {
        public byte Sid { get; set; }
        public byte? Shape { get; set; }
        public ushort? Heading { get; set; }
    }

    private static Scheme<Row> Reference()
    {
        var m = Field.FlagByte();
        return new Scheme<Row>(1,
            Field.U8<Row>(0, x => x.Sid),
            m,
            Field.When(1, Condition.Eq(0, 9), Field.U8<Row>(1, x => x.Shape)),
            m.Bit(Field.U16<Row>(2, x => x.Heading)));
    }

    private static string Hex(byte[] raw) => Convert.ToHexString(raw).ToLowerInvariant();

    private static Row Unpack(Scheme<Row> scheme, string hex)
    {
        Row? got = null;
        var error = BinaryPacker.Unpack(Convert.FromHexString(hex), scheme.On(v => got = v));
        Assert.Null(error);
        return got!;
    }

    [Fact]
    public void Pack_ReferenceRow_Is010901045a00AndUnpacksToTheSameRow()
    {
        // Arrange
        var scheme = Reference();

        // Act
        var raw = BinaryPacker.Pack(scheme, new Row { Sid = 9, Shape = 4, Heading = 90 });
        var got = Unpack(scheme, Hex(raw));

        // Assert
        Assert.Equal("010901045a00", Hex(raw));
        Assert.Equal((9, (byte?)4, (ushort?)90), (got.Sid, got.Shape, got.Heading));
    }

    [Fact]
    public void Pack_ShortRow_Is010100AndUnpacksToTheSameRow()
    {
        // Arrange
        var scheme = Reference();

        // Act
        var raw = BinaryPacker.Pack(scheme, new Row { Sid = 1 });
        var got = Unpack(scheme, Hex(raw));

        // Assert
        Assert.Equal("010100", Hex(raw));
        Assert.Equal((1, (byte?)null, (ushort?)null), (got.Sid, got.Shape, got.Heading));
    }

    [Fact]
    public void PackAndRead_DictionaryRows_GiveTheSameBytesAndValues()
    {
        // Arrange
        var scheme = Reference();
        var full = new Dictionary<string, object?> { ["Sid"] = 9, ["Shape"] = 4, ["Heading"] = 90 };
        var shortRow = new Dictionary<string, object?> { ["Sid"] = 1 };

        // Act
        var fullRaw = BinaryPacker.Pack(scheme, full);
        var shortRaw = BinaryPacker.Pack(scheme, shortRow);
        var fullRead = BinaryPacker.Read(scheme, fullRaw);
        var shortRead = BinaryPacker.Read(scheme, shortRaw);

        // Assert
        Assert.Equal("010901045a00", Hex(fullRaw));
        Assert.Equal("010100", Hex(shortRaw));
        Assert.Equal(
            [9.0, 4.0, 90.0],
            new[] { fullRead.Values["Sid"], fullRead.Values["Shape"], fullRead.Values["Heading"] }.Select(Convert.ToDouble));
        Assert.Equal(1.0, Convert.ToDouble(shortRead.Values["Sid"]));
        Assert.Equal(["Sid"], shortRead.Values.Keys);
    }
}
