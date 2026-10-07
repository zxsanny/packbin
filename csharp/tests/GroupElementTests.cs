using System.Globalization;
using Packbin;

namespace Packbin.Tests;

// AZ-2119: a list element or a dictionary value that is a group unpacks to a row of the group's members, in the
// dictionary result and in a typed row, as TypeScript, Python and Java return it. It used to throw KeyNotFoundException.
public class GroupElementTests
{
    private sealed class Item
    {
        public byte? A { get; set; }
        public byte? B { get; set; }
    }

    private sealed class Holder
    {
        public Item? Item { get; set; }
        public byte Q { get; set; }
        public byte? A { get; set; }
        public byte? B { get; set; }
    }

    private sealed class Row
    {
        public List<Holder>? Items { get; set; }
        public Dictionary<string, Holder>? Map { get; set; }
    }

    private const string ListBytes = "01" + "0200" + "0102" + "0304";
    private const string DictBytes = "01" + "0200" + "0100" + "78" + "0102" + "0100" + "79" + "0304";

    private static Field NestedField(bool dictionary) => dictionary
        ? Field.Dict((Row x) => x.Map, Field.Group((Holder h) => h.Item, Field.U8<Item>(0, i => i.A), Field.U8<Item>(1, i => i.B)))
        : Field.List((Row x) => x.Items, Field.Group((Holder h) => h.Item, Field.U8<Item>(0, i => i.A), Field.U8<Item>(1, i => i.B)));

    private static Field AnchoredField(bool dictionary) => dictionary
        ? Field.Dict((Row x) => x.Map, Field.Group(0, (Holder h) => h.Q, Field.U8<Holder>(0, i => i.A), Field.U8<Holder>(1, i => i.B)))
        : Field.List((Row x) => x.Items, Field.Group(0, (Holder h) => h.Q, Field.U8<Holder>(0, i => i.A), Field.U8<Holder>(1, i => i.B)));

    private static Scheme<Row> Scheme(bool anchored, bool dictionary) =>
        new(1, anchored ? AnchoredField(dictionary) : NestedField(dictionary));

    private static string Hex(byte[] raw) => Convert.ToHexString(raw).ToLowerInvariant();

    private static int Int(object? value) => Convert.ToInt32(value, CultureInfo.InvariantCulture);

    private static (int A, int B) Members(object? element)
    {
        var row = Assert.IsAssignableFrom<IReadOnlyDictionary<string, object?>>(element);
        Assert.Equal(2, row.Count);
        return (Int(row["A"]), Int(row["B"]));
    }

    [Theory]
    [InlineData(false)]
    [InlineData(true)]
    public void Read_ListOfGroups_ReturnsOneRowPerElement(bool anchored)
    {
        // Arrange
        var scheme = Scheme(anchored, dictionary: false);

        // Act
        var read = BinaryPacker.Read(scheme, Convert.FromHexString(ListBytes));

        // Assert
        Assert.Null(read.Error);
        var items = Assert.IsAssignableFrom<System.Collections.IList>(read.Values["Items"]);
        Assert.Equal([(1, 2), (3, 4)], items.Cast<object?>().Select(Members));
    }

    [Theory]
    [InlineData(false)]
    [InlineData(true)]
    public void Read_DictOfGroups_ReturnsOneRowPerValue(bool anchored)
    {
        // Arrange
        var scheme = Scheme(anchored, dictionary: true);

        // Act
        var read = BinaryPacker.Read(scheme, Convert.FromHexString(DictBytes));

        // Assert
        Assert.Null(read.Error);
        var map = Assert.IsAssignableFrom<System.Collections.IDictionary>(read.Values["Map"]);
        Assert.Equal(["x", "y"], map.Keys.Cast<string>().OrderBy(k => k, StringComparer.Ordinal));
        Assert.Equal((1, 2), Members(map["x"]));
        Assert.Equal((3, 4), Members(map["y"]));
    }

    [Theory]
    [InlineData(false)]
    [InlineData(true)]
    public void Unpack_TypedListOfGroups_FillsEveryElementRow(bool anchored)
    {
        // Arrange
        var scheme = Scheme(anchored, dictionary: false);
        Row? got = null;

        // Act
        var err = BinaryPacker.Unpack(Convert.FromHexString(ListBytes), scheme.On(v => got = v));

        // Assert
        Assert.Null(err);
        var pairs = got!.Items!.Select(h => anchored ? (h.A, h.B) : (h.Item!.A, h.Item.B));
        Assert.Equal<(byte?, byte?)[]>([(1, 2), (3, 4)], [.. pairs]);
    }

    [Theory]
    [InlineData(false)]
    [InlineData(true)]
    public void Unpack_TypedDictOfGroups_FillsEveryValueRow(bool anchored)
    {
        // Arrange
        var scheme = Scheme(anchored, dictionary: true);
        Row? got = null;

        // Act
        var err = BinaryPacker.Unpack(Convert.FromHexString(DictBytes), scheme.On(v => got = v));

        // Assert
        Assert.Null(err);
        var x = got!.Map!["x"];
        var y = got.Map["y"];
        Assert.Equal<(byte?, byte?)[]>(
            [(1, 2), (3, 4)],
            anchored ? [(x.A, x.B), (y.A, y.B)] : [(x.Item!.A, x.Item.B), (y.Item!.A, y.Item.B)]);
    }

    [Theory]
    [InlineData(false)]
    [InlineData(true)]
    public void PackThenUnpack_TypedListOfGroups_RoundTrips(bool anchored)
    {
        // Arrange
        var scheme = Scheme(anchored, dictionary: false);
        var items = anchored
            ? new List<Holder> { new() { A = 1, B = 2 }, new() { A = 3, B = 4 } }
            : [new Holder { Item = new Item { A = 1, B = 2 } }, new Holder { Item = new Item { A = 3, B = 4 } }];
        Row? got = null;

        // Act
        var raw = BinaryPacker.Pack(scheme, new Row { Items = items });
        var err = BinaryPacker.Unpack(raw, scheme.On(v => got = v));

        // Assert
        Assert.Equal(ListBytes, Hex(raw));
        Assert.Null(err);
        Assert.Equal(2, got!.Items!.Count);
    }
}
