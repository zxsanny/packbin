using Packbin;

namespace Packbin.Tests;

// AZ-4205: the review Lows of the AZ-4199 element row. The row form for an array, IList<E> and IDictionary<string, E>
// member; a member declared for another row type refused when the scheme is built (element rows and nested rows); `when`
// and `times` inside an element row, pinned to the bytes TypeScript writes for the same scheme (measured in loop 111).
public class ElementRowLowsTests
{
    private sealed class Comment
    {
        public string Id { get; set; } = "";
        public string Text { get; set; } = "";
        public uint AuthorId { get; set; }
        public string Author { get; set; } = "";
    }

    private sealed class ArrayFrame
    {
        public Comment[] Items { get; set; } = [];
    }

    private sealed class ListFrame
    {
        public IList<Comment> Items { get; set; } = [];
    }

    private sealed class MapFrame
    {
        public IDictionary<string, Comment> Map { get; set; } = new Dictionary<string, Comment>();
    }

    private sealed class Mark
    {
        public byte Id { get; set; }
        public byte N { get; set; }
    }

    private sealed class Other
    {
        public byte Id { get; set; }
        public byte Z { get; set; }
    }

    private sealed class Marked
    {
        public List<Mark> Items { get; set; } = [];
        public Dictionary<string, Mark> Map { get; set; } = [];
    }

    private sealed class Nest
    {
        public Mark? M { get; set; }
    }

    private class Base
    {
        public byte Id { get; set; }
    }

    private sealed class Derived : Base
    {
        public byte N { get; set; }
    }

    private sealed class Derivations
    {
        public List<Derived> Items { get; set; } = [];
        public Derived? One { get; set; }
    }

    private sealed class Round
    {
        public byte V { get; set; }
    }

    private sealed class Rich
    {
        public byte Mode { get; set; }
        public byte Speed { get; set; }
        public byte C { get; set; }
        public List<Round> Rs { get; set; } = [];
    }

    private sealed class Riches
    {
        public List<Rich> Items { get; set; } = [];
    }

    // The bytes of the AZ-4199 fixtures (ElementRowTests): what TypeScript writes for a list or dict of these rows.
    private const string Empty = "01" + "0000";
    private const string One = "01" + "0100" + "03106331" + "022aaa" + "07000000" + "03c91980";

    private const string Three = "01" + "0300"
        + "03106331" + "022aaa" + "07000000" + "03c91980"
        + "03106332" + "03106f6b" + "02010000" + "0310626f"
        + "03106333" + "03cb2200" + "01000000" + "03106379";

    private const string Map = "01" + "0200"
        + "021061" + "03106331" + "022aaa" + "07000000" + "03c91980"
        + "021062" + "03106332" + "03106f6b" + "02010000" + "0310626f";

    private static Comment C1() => new() { Id = "c1", Text = "hi", AuthorId = 7, Author = "ann" };
    private static Comment C2() => new() { Id = "c2", Text = "ok", AuthorId = 258, Author = "bo" };
    private static Comment C3() => new() { Id = "c3", Text = "yes", AuthorId = 1, Author = "cy" };

    private static Comment[] Comments(int count) => new[] { C1(), C2(), C3() }.Take(count).ToArray();

    private static Field[] Members(Fields<Comment> e) => [
        e.Utf8(0, i => i.Id),
        e.Utf8(1, i => i.Text),
        e.U32(2, i => i.AuthorId),
        e.Utf8(3, i => i.Author)];

    private static Field[] StaticMembers() => [
        Field.Utf8<Comment>(0, i => i.Id),
        Field.Utf8<Comment>(1, i => i.Text),
        Field.U32<Comment>(2, i => i.AuthorId),
        Field.Utf8<Comment>(3, i => i.Author)];

    private static string Hex(byte[] raw) => Convert.ToHexString(raw).ToLowerInvariant();

    private static void AssertSame(Comment expected, Comment actual)
    {
        Assert.Equal(expected.Id, actual.Id);
        Assert.Equal(expected.Text, actual.Text);
        Assert.Equal(expected.AuthorId, actual.AuthorId);
        Assert.Equal(expected.Author, actual.Author);
    }

    private static void AssertSameRows(IReadOnlyList<Comment> expected, IEnumerable<Comment> actual)
    {
        var got = actual.ToList();
        Assert.Equal(expected.Count, got.Count);
        for (var i = 0; i < expected.Count; i++)
            AssertSame(expected[i], got[i]);
    }

    public static TheoryData<int, string, bool> Counts => new()
    {
        { 0, Empty, false },
        { 1, One, false },
        { 3, Three, false },
        { 0, Empty, true },
        { 1, One, true },
        { 3, Three, true },
    };

    [Theory]
    [MemberData(nameof(Counts))]
    public void Ac1_Pack_ArrayMemberOfRows_WritesTheListFormBytesAndRoundTrips(int count, string expected, bool statics)
    {
        // Arrange
        var scheme = statics
            ? new Scheme<ArrayFrame>(1, Field.List<ArrayFrame, Comment>(x => x.Items, StaticMembers()))
            : new Scheme<ArrayFrame>(1, f => [f.List(x => x.Items, Members)]);
        var items = Comments(count);

        // Act
        var raw = BinaryPacker.Pack(scheme, new ArrayFrame { Items = items });
        ArrayFrame? got = null;
        var err = BinaryPacker.Unpack(raw, scheme.On(v => got = v));

        // Assert
        Assert.Equal(expected, Hex(raw));
        Assert.Null(err);
        Assert.NotNull(got!.Items);
        AssertSameRows(items, got.Items);
    }

    [Theory]
    [MemberData(nameof(Counts))]
    public void Ac1_Pack_IListMemberOfRows_WritesTheListFormBytesAndRoundTrips(int count, string expected, bool statics)
    {
        // Arrange
        var scheme = statics
            ? new Scheme<ListFrame>(1, Field.List<ListFrame, Comment>(x => x.Items, StaticMembers()))
            : new Scheme<ListFrame>(1, f => [f.List(x => x.Items, Members)]);
        var items = Comments(count);

        // Act
        var raw = BinaryPacker.Pack(scheme, new ListFrame { Items = items.ToList() });
        ListFrame? got = null;
        var err = BinaryPacker.Unpack(raw, scheme.On(v => got = v));

        // Assert
        Assert.Equal(expected, Hex(raw));
        Assert.Null(err);
        Assert.IsType<List<Comment>>(got!.Items);
        AssertSameRows(items, got.Items);
    }

    [Fact]
    public void Ac1_Pack_NullArrayMember_IsRefusedAsTheListFormRefusesIt()
    {
        // Arrange
        var scheme = new Scheme<ArrayFrame>(1, f => [f.List(x => x.Items, Members)]);

        // Act
        var error = Assert.Throws<ArgumentException>(() => BinaryPacker.Pack(scheme, new ArrayFrame { Items = null! }));

        // Assert
        Assert.Equal("'Items' has no value; a field that may be absent belongs in Flags", error.Message);
    }

    [Theory]
    [InlineData(false)]
    [InlineData(true)]
    public void Ac1b_Pack_IDictionaryMemberOfRows_WritesTheDictFormBytesAndRoundTrips(bool statics)
    {
        // Arrange
        var scheme = statics
            ? new Scheme<MapFrame>(1, Field.Dict<MapFrame, Comment>(x => x.Map, StaticMembers()))
            : new Scheme<MapFrame>(1, f => [f.Dict(x => x.Map, Members)]);
        var row = new MapFrame { Map = new Dictionary<string, Comment> { ["b"] = C2(), ["a"] = C1() } };

        // Act
        var raw = BinaryPacker.Pack(scheme, row);
        MapFrame? got = null;
        var err = BinaryPacker.Unpack(raw, scheme.On(v => got = v));

        // Assert
        Assert.Equal(Map, Hex(raw));
        Assert.Null(err);
        Assert.IsType<Dictionary<string, Comment>>(got!.Map);
        Assert.Equal(2, got.Map.Count);
        AssertSame(C1(), got.Map["a"]);
        AssertSame(C2(), got.Map["b"]);
    }

    [Fact]
    public void Ac2_Scheme_ListElementRowMembersOfAnotherRowType_AreRefusedWhenBuilt()
    {
        // Act
        var error = Record.Exception(() => new Scheme<Marked>(1,
            Field.List<Marked, Mark>(x => x.Items, Field.U8<Other>(0, o => o.Id), Field.U8<Other>(1, o => o.Z))));

        // Assert
        var refused = Assert.IsType<ArgumentException>(error);
        Assert.Equal("'Id' is declared for row type Other, but the elements of 'Items' are Mark", refused.Message);
    }

    [Fact]
    public void Ac2_Scheme_DictElementRowMembersOfAnotherRowType_AreRefusedWhenBuilt()
    {
        // Act
        var error = Record.Exception(() => new Scheme<Marked>(1,
            Field.Dict<Marked, Mark>(x => x.Map, Field.U8<Mark>(0, m => m.Id), Field.U8<Other>(1, o => o.Z))));

        // Assert
        var refused = Assert.IsType<ArgumentException>(error);
        Assert.Equal("'Z' is declared for row type Other, but the elements of 'Map' are Mark", refused.Message);
    }

    [Fact]
    public void Ac2_Scheme_ElementRowMemberOfAnotherRowTypeUnderAWhen_IsRefusedWhenBuilt()
    {
        // Act
        var error = Record.Exception(() => new Scheme<Marked>(1,
            Field.List<Marked, Mark>(x => x.Items,
                Field.U8<Mark>(0, m => m.Id),
                Field.When(1, Condition.Eq(0, 1), Field.U8<Other>(1, o => o.Z)))));

        // Assert
        var refused = Assert.IsType<ArgumentException>(error);
        Assert.Equal("'Z' is declared for row type Other, but the elements of 'Items' are Mark", refused.Message);
    }

    [Fact]
    public void Ac2b_Scheme_NestedRowMemberOfAnotherRowType_IsRefusedWhenBuilt()
    {
        // Act
        var error = Record.Exception(() => new Scheme<Nest>(1,
            Field.Group<Nest, Mark?>(x => x.M, Field.U8<Other>(0, o => o.Z))));

        // Assert
        var refused = Assert.IsType<ArgumentException>(error);
        Assert.Equal("'Z' is declared for row type Other, but the nested row 'M' is Mark", refused.Message);
    }

    [Fact]
    public void Ac2b_Pack_MembersDeclaredForABaseRowType_BuildAndRoundTrip()
    {
        // Arrange
        var scheme = new Scheme<Derivations>(1,
            Field.List<Derivations, Derived>(x => x.Items, Field.U8<Base>(0, b => b.Id), Field.U8<Derived>(1, d => d.N)),
            Field.Group<Derivations, Derived?>(x => x.One, Field.U8<Base>(0, b => b.Id), Field.U8<Derived>(1, d => d.N)));
        var row = new Derivations
        {
            Items = [new Derived { Id = 1, N = 2 }, new Derived { Id = 3, N = 4 }],
            One = new Derived { Id = 5, N = 6 },
        };

        // Act
        var raw = BinaryPacker.Pack(scheme, row);
        Derivations? got = null;
        var err = BinaryPacker.Unpack(raw, scheme.On(v => got = v));

        // Assert
        Assert.Equal("01" + "0200" + "0102" + "0304" + "0506", Hex(raw));
        Assert.Null(err);
        Assert.Equal([1, 2, 3, 4], got!.Items.SelectMany(d => new[] { d.Id, d.N }));
        Assert.Equal((5, 6), (got.One!.Id, got.One.N));
    }

    [Fact]
    public void Ac3_Pack_WhenInsideAnElementRow_WritesTheTypeScriptBytesAndRoundTrips()
    {
        // Arrange
        var scheme = new Scheme<Riches>(1, f => [f.List(x => x.Items, e => [
            e.U8(0, r => r.Mode),
            e.When(1, Condition.Eq(0, 1), e.U8(1, r => r.Speed))])]);
        var row = new Riches { Items = [new Rich { Mode = 1, Speed = 7 }, new Rich { Mode = 0, Speed = 9 }] };

        // Act
        var raw = BinaryPacker.Pack(scheme, row);
        Riches? got = null;
        var err = BinaryPacker.Unpack(raw, scheme.On(v => got = v));

        // Assert
        Assert.Equal("010200010700", Hex(raw));
        Assert.Null(err);
        Assert.Equal([(1, 7), (0, 0)], got!.Items.Select(r => ((int)r.Mode, (int)r.Speed)));
    }

    [Fact]
    public void Ac3b_Pack_TimesInsideAnElementRow_WritesTheTypeScriptBytesAndRoundTrips()
    {
        // Arrange
        var scheme = new Scheme<Riches>(1, f => [f.List(x => x.Items, e => [
            e.U8(0, r => r.C),
            e.Times(1, 0, r => r.Rs, q => [q.U8(1, v => v.V)])])]);
        var row = new Riches
        {
            Items = [new Rich { C = 2, Rs = [new Round { V = 5 }, new Round { V = 6 }] }, new Rich { C = 0, Rs = [] }],
        };

        // Act
        var raw = BinaryPacker.Pack(scheme, row);
        Riches? got = null;
        var err = BinaryPacker.Unpack(raw, scheme.On(v => got = v));

        // Assert
        Assert.Equal("01020002050600", Hex(raw));
        Assert.Null(err);
        Assert.Equal(2, got!.Items[0].C);
        Assert.Equal([5, 6], got.Items[0].Rs.Select(r => r.V));
        Assert.Equal(0, got.Items[1].C);
        Assert.Empty(got.Items[1].Rs);
    }
}
