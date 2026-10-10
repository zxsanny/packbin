using System.Collections;
using System.Globalization;
using Packbin;

namespace Packbin.Tests;

// AZ-2307: a Flags container as a list element or a dictionary value packs and unpacks, in the dictionary result and in a
// typed row, with the bytes TypeScript writes for the same scheme (read from a real TypeScript run). It used to throw
// KeyNotFoundException in Read. A value that is absent is a clear flag bit, so an element row holds only what was read.
public class FlagsElementTests
{
    private sealed class Point
    {
        public byte? A { get; set; }
        public ushort? B { get; set; }
    }

    private sealed class Row
    {
        public List<Point>? Pts { get; set; }
        public Dictionary<string, Point>? M { get; set; }
    }

    private sealed class BoolPoint
    {
        public bool On { get; set; }
        public byte? V { get; set; }
    }

    private sealed class BoolRow
    {
        public List<BoolPoint>? Pts { get; set; }
    }

    private const string ListBytes = "01" + "0300" + "0101" + "00" + "02" + "0200";
    private const string DictBytes = "01" + "0200" + "0100" + "78" + "0101" + "0100" + "79" + "02" + "0200";

    private static Field FlagsOfPoint() =>
        Field.Flags(0, Field.U8<Point>(0, p => p.A), Field.U16<Point>(1, p => p.B));

    private static Scheme<Row> ListScheme() => new(1, Field.List((Row x) => x.Pts, FlagsOfPoint()));

    private static Scheme<Row> DictScheme() => new(1, Field.Dict((Row x) => x.M, FlagsOfPoint()));

    private static string Hex(byte[] raw) => Convert.ToHexString(raw).ToLowerInvariant();

    private static int Int(object? value) => Convert.ToInt32(value, CultureInfo.InvariantCulture);

    private static Dictionary<string, object?> Item(byte? a = null, ushort? b = null)
    {
        var item = new Dictionary<string, object?>();
        if (a is not null)
            item["A"] = a;
        if (b is not null)
            item["B"] = b;
        return item;
    }

    private static string Shape(object? element)
    {
        var row = Assert.IsAssignableFrom<IReadOnlyDictionary<string, object?>>(element);
        return string.Join(",", row.OrderBy(p => p.Key, StringComparer.Ordinal).Select(p => $"{p.Key}={Int(p.Value)}"));
    }

    [Fact]
    public void Ac1_Read_ListOfFlags_ReturnsOneRowPerElementHoldingOnlyWhatWasRead()
    {
        // Act
        var read = BinaryPacker.Read(ListScheme(), Convert.FromHexString(ListBytes));

        // Assert
        Assert.Null(read.Error);
        var items = Assert.IsAssignableFrom<IList>(read.Values["Pts"]);
        Assert.Equal(["A=1", "", "B=2"], items.Cast<object?>().Select(Shape));
    }

    [Fact]
    public void Ac1_Read_DictOfFlags_ReturnsOneRowPerValue()
    {
        // Act
        var read = BinaryPacker.Read(DictScheme(), Convert.FromHexString(DictBytes));

        // Assert
        Assert.Null(read.Error);
        var map = Assert.IsAssignableFrom<IDictionary>(read.Values["M"]);
        Assert.Equal(2, map.Count);
        Assert.Equal("A=1", Shape(map["x"]));
        Assert.Equal("B=2", Shape(map["y"]));
    }

    [Fact]
    public void Ac1_Pack_ListOfFlagsInDictionaryMode_WritesTheTypeScriptBytes()
    {
        // Arrange
        var values = new Dictionary<string, object?>
        {
            ["Pts"] = new List<object?> { Item(a: 1), Item(), Item(b: 2) },
        };

        // Act
        var raw = BinaryPacker.Pack(ListScheme(), values);

        // Assert
        Assert.Equal(ListBytes, Hex(raw));
    }

    [Fact]
    public void Ac1_Pack_DictOfFlagsInDictionaryMode_WritesTheTypeScriptBytes()
    {
        // Arrange
        var values = new Dictionary<string, object?>
        {
            ["M"] = new Dictionary<string, object?> { ["y"] = Item(b: 2), ["x"] = Item(a: 1) },
        };

        // Act
        var raw = BinaryPacker.Pack(DictScheme(), values);

        // Assert
        Assert.Equal(DictBytes, Hex(raw));
    }

    [Fact]
    public void Ac1_Pack_ListOfFlagsTyped_WritesTheTypeScriptBytes()
    {
        // Arrange
        var row = new Row { Pts = [new Point { A = 1 }, new Point(), new Point { B = 2 }] };

        // Act
        var raw = BinaryPacker.Pack(ListScheme(), row);

        // Assert
        Assert.Equal(ListBytes, Hex(raw));
    }

    [Fact]
    public void Ac1_Pack_DictOfFlagsTyped_WritesTheTypeScriptBytes()
    {
        // Arrange
        var row = new Row { M = new Dictionary<string, Point> { ["y"] = new Point { B = 2 }, ["x"] = new Point { A = 1 } } };

        // Act
        var raw = BinaryPacker.Pack(DictScheme(), row);

        // Assert
        Assert.Equal(DictBytes, Hex(raw));
    }

    [Fact]
    public void Ac1_Unpack_TypedListOfFlags_FillsEveryElementRow()
    {
        // Arrange
        var scheme = ListScheme();
        Row? got = null;

        // Act
        var err = BinaryPacker.Unpack(Convert.FromHexString(ListBytes), scheme.On(v => got = v));

        // Assert
        Assert.Null(err);
        Assert.Equal<(byte?, ushort?)[]>([(1, null), (null, null), (null, 2)], [.. got!.Pts!.Select(p => (p.A, p.B))]);
    }

    [Fact]
    public void Ac1_Unpack_TypedDictOfFlags_FillsEveryValueRow()
    {
        // Arrange
        var scheme = DictScheme();
        Row? got = null;

        // Act
        var err = BinaryPacker.Unpack(Convert.FromHexString(DictBytes), scheme.On(v => got = v));

        // Assert
        Assert.Null(err);
        Assert.Equal<(byte?, ushort?)[]>([(1, null), (null, 2)], [(got!.M!["x"].A, got.M["x"].B), (got.M["y"].A, got.M["y"].B)]);
    }

    [Fact]
    public void Ac1_FlagsElementWithABoolBit_RoundTripsAndKeepsEachElementsOwnBit()
    {
        // Arrange
        var scheme = new Scheme<BoolRow>(1, Field.List((BoolRow x) => x.Pts,
            Field.Flags(0, Field.Bool<BoolPoint>(0, p => p.On), Field.U8<BoolPoint>(1, p => p.V))));
        var row = new BoolRow { Pts = [new BoolPoint { On = true, V = 7 }, new BoolPoint { On = false, V = null }] };
        BoolRow? got = null;

        // Act
        var raw = BinaryPacker.Pack(scheme, row);
        var err = BinaryPacker.Unpack(raw, scheme.On(v => got = v));

        // Assert
        Assert.Equal("01" + "0200" + "0307" + "00", Hex(raw));
        Assert.Null(err);
        Assert.Equal<(bool, byte?)[]>([(true, 7), (false, null)], [.. got!.Pts!.Select(p => (p.On, p.V))]);
    }

    [Fact]
    public void Ac1_Pack_FlagsElementInDictionaryModeWhenTheRowHoldsTheSameNames_IgnoresTheRowsValues()
    {
        // Arrange
        var scheme = ListScheme();
        var values = new Dictionary<string, object?>
        {
            ["A"] = (byte)9,
            ["Pts"] = new List<object?> { Item() },
        };

        // Act
        var raw = BinaryPacker.Pack(scheme, values);

        // Assert
        Assert.Equal("01" + "0100" + "00", Hex(raw));
    }

    [Fact]
    public void Ac1_Read_ShortFlagsElement_ReturnsShortPacket()
    {
        // Arrange
        var scheme = ListScheme();

        // Act
        var read = BinaryPacker.Read(scheme, Convert.FromHexString("01" + "0300" + "0101" + "00" + "0201"));

        // Assert
        var error = Assert.IsType<ShortPacket>(read.Error);
        Assert.Equal(2, error.Needed);
        Assert.Equal(1, error.Left);
    }

    [Fact]
    public void Ac1_Pack_FlagsElementThatIsNotARow_ThrowsNamingTheElementKind()
    {
        // Arrange
        var values = new Dictionary<string, object?> { ["Pts"] = new List<object?> { "text" } };

        // Act
        var error = Assert.Throws<ArgumentException>(() => BinaryPacker.Pack(ListScheme(), values));

        // Assert
        Assert.Contains("flags element", error.Message, StringComparison.Ordinal);
    }

    [Fact]
    public void Ac1_Pack_FlagsElementMemberOutsideItsRange_ThrowsAndWritesNothing()
    {
        // Arrange
        var values = new Dictionary<string, object?> { ["Pts"] = new List<object?> { Item(a: 1), new Dictionary<string, object?> { ["B"] = 70000 } } };

        // Act
        var error = Record.Exception(() => BinaryPacker.Pack(ListScheme(), values));

        // Assert
        Assert.IsAssignableFrom<ArgumentException>(error);
    }
}
