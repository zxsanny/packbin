using Packbin;

namespace Packbin.Tests;

// AZ-2305 (review fix): a collection member that is not a row holder must hold what unpack hands over for an element of
// a non-leaf kind (a dictionary for a group, flags or dict element, a list for a list element, a number for a u2).
// List<int> for a list of flags used to build and then throw InvalidCastException from Unpack.
public class CollectionElementKindTests
{
    private sealed class Point
    {
        public byte? A { get; set; }
    }

    private sealed class Holder
    {
        public Item? Item { get; set; }
        public byte Q { get; set; }
        public byte? A { get; set; }
    }

    private sealed class Item
    {
        public byte? A { get; set; }
    }

    private sealed class Inner
    {
        public List<string>? Names { get; set; }
        public Dictionary<string, string>? Map { get; set; }
    }

    private sealed class Slot
    {
        public int V { get; set; }
    }

    private sealed class ListOf<T>
    {
        public List<T>? Ids { get; set; }
    }

    private sealed class MapOf<T>
    {
        public Dictionary<string, T>? Ids { get; set; }
    }

    private sealed class Text
    {
        public string V { get; set; } = "";
    }

    private static Field Flags() => Field.Flags(0, Field.U8<Point>(0, p => p.A));

    private static Field Anchored() => Field.Group(0, (Holder h) => h.Q, Field.U8<Holder>(0, i => i.A));

    private static Field Nested() => Field.Group((Holder h) => h.Item, Field.U8<Item>(0, i => i.A));

    private static Field InnerList() => Field.List((Inner x) => x.Names, Field.Utf8<Text>(0, t => t.V));

    private static Field InnerDict() => Field.Dict((Inner x) => x.Map, Field.Utf8<Text>(0, t => t.V));

    private static Field TwoBits() => Field.U2<Slot>((0, s => s.V));

    private static void BuildList<T>(Field element) => _ = new Scheme<ListOf<T>>(1, Field.List((ListOf<T> x) => x.Ids, element));

    private static void BuildDict<T>(Field element) => _ = new Scheme<MapOf<T>>(1, Field.Dict((MapOf<T> x) => x.Ids, element));

    private static void Accepted(Action build) => Assert.Null(Record.Exception(build));

    private static void Refused(Action build, string element)
    {
        var error = Assert.Throws<ArgumentException>(build);

        Assert.Contains("'Ids'", error.Message, StringComparison.Ordinal);
        Assert.Contains(element, error.Message, StringComparison.Ordinal);
    }

    public static TheoryData<string> RowKinds => new() { "flags", "anchored", "nested", "dict" };

    private static Field RowKind(string kind) => kind switch
    {
        "flags" => Flags(),
        "anchored" => Anchored(),
        "nested" => Nested(),
        _ => InnerDict(),
    };

    [Theory]
    [MemberData(nameof(RowKinds))]
    public void Build_ListOfIntForADictionaryElement_Refused(string kind) =>
        Refused(() => BuildList<int>(RowKind(kind)), "Int32");

    [Theory]
    [MemberData(nameof(RowKinds))]
    public void Build_ListOfStringForADictionaryElement_Refused(string kind) =>
        Refused(() => BuildList<string>(RowKind(kind)), "String");

    [Theory]
    [MemberData(nameof(RowKinds))]
    public void Build_DictOfIntForADictionaryElement_Refused(string kind) =>
        Refused(() => BuildDict<int>(RowKind(kind)), "Int32");

    [Theory]
    [MemberData(nameof(RowKinds))]
    public void Build_ListOfListForADictionaryElement_Refused(string kind) =>
        Refused(() => BuildList<List<object?>>(RowKind(kind)), "List");

    [Theory]
    [MemberData(nameof(RowKinds))]
    public void Build_ListOfObjectOrDictionaryForADictionaryElement_Accepted(string kind)
    {
        Accepted(() => BuildList<object?>(RowKind(kind)));
        Accepted(() => BuildList<Dictionary<string, object?>>(RowKind(kind)));
        Accepted(() => BuildList<IDictionary<string, object?>>(RowKind(kind)));
        Accepted(() => BuildList<IReadOnlyDictionary<string, object?>>(RowKind(kind)));
        Accepted(() => BuildDict<object?>(RowKind(kind)));
        Accepted(() => BuildDict<Dictionary<string, object?>>(RowKind(kind)));
    }

    [Fact]
    public void Build_ListOfIntForAListElement_Refused() =>
        Refused(() => BuildList<int>(InnerList()), "Int32");

    [Fact]
    public void Build_ListOfDictionaryForAListElement_Refused() =>
        Refused(() => BuildList<Dictionary<string, object?>>(InnerList()), "Dictionary");

    [Fact]
    public void Build_ListOfListOrObjectForAListElement_Accepted()
    {
        Accepted(() => BuildList<List<object?>>(InnerList()));
        Accepted(() => BuildList<IList<object?>>(InnerList()));
        Accepted(() => BuildList<System.Collections.IList>(InnerList()));
        Accepted(() => BuildList<object?>(InnerList()));
    }

    [Fact]
    public void Build_ListOfStringForAU2Element_Refused() =>
        Refused(() => BuildList<string>(TwoBits()), "String");

    [Fact]
    public void Build_ListOfDictionaryForAU2Element_Refused() =>
        Refused(() => BuildList<Dictionary<string, object?>>(TwoBits()), "Dictionary");

    [Fact]
    public void Build_ListOfNumberOrObjectForAU2Element_Accepted()
    {
        Accepted(() => BuildList<byte>(TwoBits()));
        Accepted(() => BuildList<int>(TwoBits()));
        Accepted(() => BuildList<double>(TwoBits()));
        Accepted(() => BuildList<object?>(TwoBits()));
    }

    [Fact]
    public void Unpack_ListOfDictionaryForFlagsElements_ReturnsTheRows()
    {
        // Arrange
        var scheme = new Scheme<ListOf<Dictionary<string, object?>>>(
            1, Field.List((ListOf<Dictionary<string, object?>> x) => x.Ids, Flags()));
        ListOf<Dictionary<string, object?>>? got = null;

        // Act
        var err = BinaryPacker.Unpack(Convert.FromHexString("01" + "0200" + "0101" + "00"), scheme.On(v => got = v));

        // Assert
        Assert.Null(err);
        Assert.Equal(2, got!.Ids!.Count);
        Assert.Equal((byte)1, Convert.ToByte(got.Ids[0]["A"], System.Globalization.CultureInfo.InvariantCulture));
        Assert.Empty(got.Ids[1]);
    }

    [Fact]
    public void Unpack_ListOfListForListElements_ReturnsTheLists()
    {
        // Arrange
        var scheme = new Scheme<ListOf<List<object?>>>(1, Field.List((ListOf<List<object?>> x) => x.Ids, InnerList()));
        ListOf<List<object?>>? got = null;

        // Act
        var err = BinaryPacker.Unpack(Convert.FromHexString("01" + "0100" + "0100" + "0100" + "78"), scheme.On(v => got = v));

        // Assert
        Assert.Null(err);
        Assert.Equal(["x"], got!.Ids![0]);
    }
}
