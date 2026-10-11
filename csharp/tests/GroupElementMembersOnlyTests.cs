using Packbin;

namespace Packbin.Tests;

// AZ-2337: a group element of a list or dictionary packs from its own members only. The row around it no longer lends
// a value, so a missing member is reported by name, as in the other packages.
public class GroupElementMembersOnlyTests
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

    private static Field Element(bool anchored) => anchored
        ? Field.Group(0, (Holder h) => h.Q, Field.U8<Holder>(0, i => i.A), Field.U8<Holder>(1, i => i.B))
        : Field.Group((Holder h) => h.Item, Field.U8<Item>(0, i => i.A), Field.U8<Item>(1, i => i.B));

    private static Scheme<Row> Listed(bool anchored) => new(1, Field.List((Row x) => x.Items, Element(anchored)));

    private static Scheme<Row> Keyed(bool anchored) => new(1, Field.Dict((Row x) => x.Map, Element(anchored)));

    private static Dictionary<string, object?> Members(params (string Name, object? Value)[] items) =>
        items.ToDictionary(item => item.Name, item => item.Value);

    private static string Hex(byte[] raw) => Convert.ToHexString(raw).ToLowerInvariant();

    [Theory]
    [InlineData(false)]
    [InlineData(true)]
    public void Ac1_Pack_ListElementMissingAMemberTheRowHolds_NamesTheMember(bool anchored)
    {
        // Arrange
        var scheme = Listed(anchored);
        var row = new Dictionary<string, object?>
        {
            ["A"] = (byte)9,
            ["Items"] = new List<object?> { Members(("B", (byte)2)) },
        };

        // Act
        var thrown = Record.Exception(() => BinaryPacker.Pack(scheme, row));

        // Assert
        Assert.Contains("'A'", Assert.IsType<ArgumentException>(thrown).Message);
    }

    [Theory]
    [InlineData(false)]
    [InlineData(true)]
    public void Ac1_Pack_DictionaryValueMissingAMemberTheRowHolds_NamesTheMember(bool anchored)
    {
        // Arrange
        var scheme = Keyed(anchored);
        var row = new Dictionary<string, object?>
        {
            ["A"] = (byte)9,
            ["B"] = (byte)8,
            ["Map"] = new Dictionary<string, object?> { ["x"] = Members(("B", (byte)2)) },
        };

        // Act
        var thrown = Record.Exception(() => BinaryPacker.Pack(scheme, row));

        // Assert
        Assert.Contains("'A'", Assert.IsType<ArgumentException>(thrown).Message);
    }

    [Fact]
    public void Ac1_Pack_ElementMemberOutOfRange_StillNamesTheMember()
    {
        // Arrange
        var scheme = Listed(anchored: true);
        var row = new Dictionary<string, object?>
        {
            ["Items"] = new List<object?> { Members(("A", 300), ("B", (byte)2)) },
        };

        // Act
        var thrown = Record.Exception(() => BinaryPacker.Pack(scheme, row));

        // Assert
        Assert.Contains("A", Assert.IsType<ArgumentException>(thrown).Message);
    }

    [Fact]
    public void Ac1_Pack_TypedElementMissingAMember_NamesTheMember()
    {
        // Arrange
        var scheme = Listed(anchored: true);
        var row = new Row { Items = [new Holder { A = null, B = 2 }] };

        // Act
        var thrown = Record.Exception(() => BinaryPacker.Pack(scheme, row));

        // Assert
        Assert.Contains("'A'", Assert.IsType<ArgumentException>(thrown).Message);
    }

    [Theory]
    [InlineData(false)]
    [InlineData(true)]
    public void Ac2_Pack_CompleteElementsInDictionaryRows_BytesAreUnchanged(bool anchored)
    {
        // Arrange
        var scheme = Listed(anchored);
        var row = new Dictionary<string, object?>
        {
            ["A"] = (byte)9,
            ["Items"] = new List<object?>
            {
                Members(("A", (byte)1), ("B", (byte)2)),
                Members(("A", (byte)3), ("B", (byte)4)),
            },
        };

        // Act
        var raw = BinaryPacker.Pack(scheme, row);

        // Assert
        Assert.Equal(ListBytes, Hex(raw));
    }

    [Fact]
    public void Ac2_Pack_CompleteTypedElements_BytesAreUnchanged()
    {
        // Arrange
        var scheme = Listed(anchored: true);
        var row = new Row { Items = [new Holder { A = 1, B = 2 }, new Holder { A = 3, B = 4 }] };

        // Act
        var raw = BinaryPacker.Pack(scheme, row);

        // Assert
        Assert.Equal(ListBytes, Hex(raw));
    }
}
