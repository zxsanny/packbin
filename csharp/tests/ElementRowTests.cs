using Packbin;

namespace Packbin.Tests;

// AZ-4199: a list or dictionary element that is a row of required members, written with no flag byte per element. The
// expected bytes are what TypeScript writes for the same scheme (a list of nested rows), read from a real TypeScript run.
public class ElementRowTests
{
    private sealed class Comment
    {
        public string Id { get; set; } = "";
        public string Text { get; set; } = "";
        public uint AuthorId { get; set; }
        public string Author { get; set; } = "";
    }

    private sealed class Frame
    {
        public List<Comment> Items { get; set; } = [];
        public Dictionary<string, Comment> Map { get; set; } = [];
    }

    private sealed class Tagged
    {
        public byte Id { get; set; }
        public List<Mark> Items { get; set; } = [];
    }

    private sealed class Mark
    {
        public byte Id { get; set; }
        public byte N { get; set; }
    }

    private sealed class NoConstructor
    {
        public NoConstructor(int _)
        {
        }

        public byte V { get; set; }
    }

    private sealed class Holder
    {
        public List<NoConstructor> Items { get; set; } = [];
    }

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

    private static Scheme<Frame> ListScheme() => new(1, f => [
        f.List(x => x.Items, e => [
            e.Utf8(0, i => i.Id),
            e.Utf8(1, i => i.Text),
            e.U32(2, i => i.AuthorId),
            e.Utf8(3, i => i.Author)])]);

    private static Scheme<Frame> DictScheme() => new(1, f => [
        f.Dict(x => x.Map, e => [
            e.Utf8(0, i => i.Id),
            e.Utf8(1, i => i.Text),
            e.U32(2, i => i.AuthorId),
            e.Utf8(3, i => i.Author)])]);

    private static string Hex(byte[] raw) => Convert.ToHexString(raw).ToLowerInvariant();

    private static void AssertSame(Comment expected, Comment actual)
    {
        Assert.Equal(expected.Id, actual.Id);
        Assert.Equal(expected.Text, actual.Text);
        Assert.Equal(expected.AuthorId, actual.AuthorId);
        Assert.Equal(expected.Author, actual.Author);
    }

    [Theory]
    [InlineData(0, Empty)]
    [InlineData(1, One)]
    [InlineData(3, Three)]
    public void Ac1_Pack_ListOfRows_WritesNoFlagBytePerItemAndRoundTrips(int count, string expected)
    {
        // Arrange
        var items = new[] { C1(), C2(), C3() }.Take(count).ToList();
        var scheme = ListScheme();

        // Act
        var raw = BinaryPacker.Pack(scheme, new Frame { Items = items });
        Frame? got = null;
        var err = BinaryPacker.Unpack(raw, scheme.On(v => got = v));

        // Assert
        Assert.Equal(expected, Hex(raw));
        Assert.Null(err);
        Assert.Equal(count, got!.Items!.Count);
        for (var i = 0; i < count; i++)
            AssertSame(items[i], got.Items[i]);
    }

    [Fact]
    public void Ac1_Pack_EmptyList_LeavesTheNextFieldReadable()
    {
        // Arrange
        var scheme = new Scheme<Tagged>(1, f => [
            f.List(x => x.Items, e => [e.U8(0, m => m.Id), e.U8(1, m => m.N)]),
            f.U8(0, x => x.Id)]);

        // Act
        var raw = BinaryPacker.Pack(scheme, new Tagged { Id = 5, Items = [] });
        Tagged? got = null;
        var err = BinaryPacker.Unpack(raw, scheme.On(v => got = v));

        // Assert
        Assert.Equal("01" + "0000" + "05", Hex(raw));
        Assert.Null(err);
        Assert.Equal(5, got!.Id);
        Assert.Empty(got.Items!);
    }

    [Fact]
    public void Ac1b_Pack_DictionaryOfRows_WritesNoFlagByteAndRoundTrips()
    {
        // Arrange
        var scheme = DictScheme();
        var row = new Frame { Map = new() { ["b"] = C2(), ["a"] = C1() } };

        // Act
        var raw = BinaryPacker.Pack(scheme, row);
        Frame? got = null;
        var err = BinaryPacker.Unpack(raw, scheme.On(v => got = v));

        // Assert
        Assert.Equal(Map, Hex(raw));
        Assert.Null(err);
        Assert.Equal(["a", "b"], got!.Map!.Keys.OrderBy(k => k, StringComparer.Ordinal));
        AssertSame(C1(), got.Map["a"]);
        AssertSame(C2(), got.Map["b"]);
    }

    [Fact]
    public void Ac2_Pack_RowWithNullMember_FailsNamingTheMember()
    {
        // Arrange
        var bad = C1();
        bad.Text = null!;

        // Act
        var error = Assert.Throws<ArgumentException>(() =>
            BinaryPacker.Pack(ListScheme(), new Frame { Items = [C1(), bad] }));

        // Assert
        Assert.Contains("Text", error.Message);
    }

    [Fact]
    public void Ac2_Pack_NullItem_FailsNamingTheFirstMember()
    {
        // Arrange
        var row = new Frame { Items = [C1(), null!] };

        // Act
        var error = Assert.Throws<ArgumentException>(() => BinaryPacker.Pack(ListScheme(), row));

        // Assert
        Assert.Contains("Id", error.Message);
    }

    [Fact]
    public void Ac4_Pack_FlagsElementOfTheSameMembers_WritesOneByteMorePerItem()
    {
        // Arrange
        var flags = new Scheme<Frame>(1,
            Field.List((Frame x) => x.Items, Field.Flags(0,
                Field.Utf8<Comment>(0, i => i.Id),
                Field.Utf8<Comment>(1, i => i.Text),
                Field.U32<Comment>(2, i => i.AuthorId),
                Field.Utf8<Comment>(3, i => i.Author))));
        var row = new Frame { Items = [C1(), C2(), C3()] };

        // Act
        var plain = BinaryPacker.Pack(ListScheme(), row);
        var flagged = BinaryPacker.Pack(flags, row);

        // Assert
        Assert.Equal(plain.Length + 3, flagged.Length);
    }

    [Fact]
    public void Ac5_Pack_MapRow_PacksTheSameBytesAndReadGivesRowsByMemberName()
    {
        // Arrange
        var scheme = ListScheme();
        var row = new Dictionary<string, object?>
        {
            ["Items"] = new List<object?>
            {
                new Dictionary<string, object?> { ["Id"] = "c1", ["Text"] = "hi", ["AuthorId"] = 7u, ["Author"] = "ann" },
            },
        };

        // Act
        var raw = BinaryPacker.Pack(scheme, row);
        var read = BinaryPacker.Read(scheme, raw);

        // Assert
        Assert.Equal(One, Hex(raw));
        Assert.Null(read.Error);
        var items = Assert.IsAssignableFrom<System.Collections.IList>(read.Values["Items"]);
        var first = Assert.IsAssignableFrom<IReadOnlyDictionary<string, object?>>(Assert.Single(items.Cast<object?>()));
        Assert.Equal("c1", first["Id"]);
        Assert.Equal(7u, Convert.ToUInt32(first["AuthorId"]));
    }

    [Fact]
    public void Ac5_Build_MemberNamedLikeTheOuterRow_BuildsAndRoundTrips()
    {
        // Arrange
        var scheme = new Scheme<Tagged>(1, f => [
            f.U8(0, x => x.Id),
            f.List(x => x.Items, e => [e.U8(0, m => m.Id), e.U8(1, m => m.N)])]);
        var row = new Tagged { Id = 5, Items = [new Mark { Id = 1, N = 2 }, new Mark { Id = 3, N = 4 }] };

        // Act
        var raw = BinaryPacker.Pack(scheme, row);
        Tagged? got = null;
        var err = BinaryPacker.Unpack(raw, scheme.On(v => got = v));

        // Assert
        Assert.Equal("01" + "05" + "0200" + "0102" + "0304", Hex(raw));
        Assert.Null(err);
        Assert.Equal([(byte)1, (byte)3], got!.Items!.Select(m => m.Id));
        Assert.Equal([(byte)2, (byte)4], got.Items!.Select(m => m.N));
    }

    [Fact]
    public void Ac5_Build_ElementRowWithoutParameterlessConstructor_IsRefusedWithTheExistingMessage()
    {
        // Arrange
        Func<Scheme<Holder>> build = () => new Scheme<Holder>(1, f => [
            f.List(x => x.Items, e => [e.U8(0, m => m.V)])]);

        // Act
        var error = Assert.Throws<ArgumentException>(() => build());

        // Assert
        Assert.Contains("needs a public parameterless constructor", error.Message);
    }

    private sealed class Marked
    {
        public List<Mark> Marks { get; set; } = [];
    }

    [Fact]
    public void Ac6_Pack_ReadmeExample_PacksTheBytesTheReadmeShows()
    {
        // Arrange: the scheme of the README C# List section.
        var scheme = new Scheme<Marked>(1, f => [
            f.List(x => x.Marks, e => [e.U8(0, m => m.Id), e.U8(1, m => m.N)])]);
        var row = new Marked { Marks = [new Mark { Id = 1, N = 2 }, new Mark { Id = 3, N = 4 }] };

        // Act
        var raw = BinaryPacker.Pack(scheme, row);

        // Assert
        Assert.Equal("01" + "0200" + "0102" + "0304", Hex(raw));
    }

    [Fact]
    public void Build_ElementRowWithNoMember_IsRefused()
    {
        // Act
        var error = Assert.Throws<ArgumentException>(() =>
            new Scheme<Tagged>(1, f => [f.List(x => x.Items, e => Array.Empty<Field>())]));

        // Assert
        Assert.Contains("at least one member", error.Message);
    }
}
