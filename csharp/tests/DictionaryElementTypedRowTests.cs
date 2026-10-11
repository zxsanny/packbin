using Packbin;

namespace Packbin.Tests;

// AZ-2307 (review fix): a typed row whose list or dict member holds dictionaries (List<object?>, Dictionary<string,
// object?>) repacks what it unpacked. The flags element used to be looked up under the empty name, so every bit was
// written clear with no error.
public class DictionaryElementTypedRowTests
{
    private sealed class Point
    {
        public byte? A { get; set; }
        public ushort? B { get; set; }
    }

    private sealed class Holder
    {
        public Item? Item { get; set; }
        public byte Q { get; set; }
        public byte? A { get; set; }
        public byte? B { get; set; }
    }

    private sealed class Item
    {
        public byte? A { get; set; }
        public byte? B { get; set; }
    }

    private sealed class ListRow
    {
        public List<object?>? Pts { get; set; }
    }

    private sealed class MapRow
    {
        public Dictionary<string, object?>? M { get; set; }
    }

    private const string FlagsList = "01" + "0200" + "01" + "01" + "02" + "0200";
    private const string FlagsMap = "01" + "0200" + "0100" + "78" + "01" + "01" + "0100" + "79" + "02" + "0200";
    private const string AnchoredList = "01" + "0200" + "0102" + "0304";

    private static string Hex(byte[] raw) => Convert.ToHexString(raw).ToLowerInvariant();

    private static Field FlagsOfPoint() =>
        Field.Flags(0, Field.U8<Point>(0, p => p.A), Field.U16<Point>(1, p => p.B));

    private static T Unpacked<T>(Scheme<T> scheme, string hex) where T : class, new()
    {
        T? got = null;
        var err = BinaryPacker.Unpack(Convert.FromHexString(hex), scheme.On(v => got = v));
        Assert.Null(err);
        return got!;
    }

    [Fact]
    public void Ac1_Repack_TypedListObjectOfFlagsElements_WritesTheBytesItRead()
    {
        // Arrange
        var scheme = new Scheme<ListRow>(1, Field.List((ListRow x) => x.Pts, FlagsOfPoint()));
        var row = Unpacked(scheme, FlagsList);

        // Act
        var raw = BinaryPacker.Pack(scheme, row);

        // Assert
        Assert.Equal(FlagsList, Hex(raw));
    }

    [Fact]
    public void Ac1_Repack_TypedDictObjectOfFlagsElements_WritesTheBytesItRead()
    {
        // Arrange
        var scheme = new Scheme<MapRow>(1, Field.Dict((MapRow x) => x.M, FlagsOfPoint()));
        var row = Unpacked(scheme, FlagsMap);

        // Act
        var raw = BinaryPacker.Pack(scheme, row);

        // Assert
        Assert.Equal(FlagsMap, Hex(raw));
    }

    [Fact]
    public void Ac1_Pack_TypedListObjectOfFlagsElementThatIsNotARow_ThrowsNamingTheElementKind()
    {
        // Arrange
        var scheme = new Scheme<ListRow>(1, Field.List((ListRow x) => x.Pts, FlagsOfPoint()));
        var row = new ListRow { Pts = ["text"] };

        // Act
        var error = Assert.Throws<ArgumentException>(() => BinaryPacker.Pack(scheme, row));

        // Assert
        Assert.Contains("flags element", error.Message, StringComparison.Ordinal);
    }

    [Fact]
    public void Ac1_Pack_TypedListObjectOfFlagsElementOutsideItsRange_Throws()
    {
        // Arrange
        var scheme = new Scheme<ListRow>(1, Field.List((ListRow x) => x.Pts, FlagsOfPoint()));
        var row = new ListRow { Pts = [new Dictionary<string, object?> { ["B"] = 70000 }] };

        // Act
        var error = Record.Exception(() => BinaryPacker.Pack(scheme, row));

        // Assert
        Assert.IsAssignableFrom<ArgumentException>(error);
    }

    [Fact]
    public void Ac1_Repack_TypedListObjectOfAnchoredGroupElements_ThrowsInsteadOfWritingWrongBytes()
    {
        // Arrange
        var scheme = new Scheme<ListRow>(1, Field.List((ListRow x) => x.Pts,
            Field.Group(0, (Holder h) => h.Q, Field.U8<Holder>(0, i => i.A), Field.U8<Holder>(1, i => i.B))));
        var row = Unpacked(scheme, AnchoredList);

        // Act
        var error = Record.Exception(() => BinaryPacker.Pack(scheme, row));

        // Assert
        Assert.NotNull(error);
    }

    [Fact]
    public void Ac1_Repack_TypedListObjectOfNestedGroupElements_ThrowsInsteadOfWritingWrongBytes()
    {
        // Arrange
        var scheme = new Scheme<ListRow>(1, Field.List((ListRow x) => x.Pts,
            Field.Group((Holder h) => h.Item, Field.U8<Item>(0, i => i.A), Field.U8<Item>(1, i => i.B))));
        var row = Unpacked(scheme, AnchoredList);

        // Act
        var error = Record.Exception(() => BinaryPacker.Pack(scheme, row));

        // Assert
        Assert.NotNull(error);
    }
}
