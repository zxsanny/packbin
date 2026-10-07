using Packbin;

namespace Packbin.Tests;

// AZ-2092: a typed row is walked through the accessor each field was declared with, so a nested row, a list element
// and a dictionary value read and write their own members.
public class TypedBindingTests
{
    private sealed class InnerRow
    {
        public byte Name { get; set; }
        public byte Kind { get; set; }
        public byte? V { get; set; }
    }

    private sealed class OuterRow
    {
        public byte Name { get; set; }
        public byte Kind { get; set; }
        public InnerRow? Inner { get; set; }
    }

    private sealed class Item
    {
        public byte V { get; set; }
    }

    private sealed class Holder
    {
        public Item? Item { get; set; }
    }

    private sealed class ListRow
    {
        public List<Holder> Items { get; set; } = [];
    }

    private sealed class Tag
    {
        public string Label { get; set; } = "";
    }

    private sealed class TagArrayRow
    {
        public Tag[] Tags { get; set; } = [];
        public Dictionary<string, Tag> ByKey { get; set; } = [];
    }

    private sealed class NoCtor
    {
        public NoCtor(int unused) => V = (byte)unused;

        public byte V { get; set; }
    }

    private sealed class NoCtorRow
    {
        public NoCtor? Inner { get; set; }
        public List<NoCtor> Many { get; set; } = [];
    }

    private sealed class User
    {
        public string Username { get; set; } = "";
        public List<Role> Roles { get; set; } = [];
        public Dictionary<string, ActionList> Access { get; set; } = [];
    }

    private sealed class Role
    {
        public string RoleName { get; set; } = "";
    }

    private sealed class ActionName
    {
        public string Action { get; set; } = "";
    }

    private sealed class ActionList
    {
        public List<ActionName> Actions { get; set; } = [];
    }

    private sealed class Ping
    {
        public byte Code { get; set; }
    }

    private sealed class Note
    {
        public ushort Id { get; set; }
        public string Title { get; set; } = "";
    }

    private sealed class MemberKinds
    {
        public byte Field;
        public byte Private { get; private set; }
        public int? Wide { get; set; }

        public MemberKinds With(byte privateValue)
        {
            Private = privateValue;
            return this;
        }
    }

    private const string ReadmeHex =
        "0103006164610200040075736572050061646d696e020003006d61700200040072656164040065646974050073746f7265010005007772697465";

    private static string Hex(byte[] raw) => Convert.ToHexString(raw).ToLowerInvariant();

    private static T Unpack<T>(Scheme<T> scheme, byte[] raw) where T : class, new()
    {
        T? got = null;
        var err = BinaryPacker.Unpack(raw, scheme.On(v => got = v));
        Assert.Null(err);
        Assert.NotNull(got);
        return got;
    }

    [Fact]
    public void NestedRow_MemberNamedLikeAnOuterMember_KeepsBothValues()
    {
        // Arrange
        var scheme = new Scheme<OuterRow>(1,
            Field.U8<OuterRow>(0, x => x.Name),
            Field.Group((OuterRow x) => x.Inner, Field.U8<InnerRow>(0, i => i.Name)));

        // Act
        var raw = BinaryPacker.Pack(scheme, new OuterRow { Name = 1, Inner = new InnerRow { Name = 2 } });
        var got = Unpack(scheme, raw);

        // Assert
        Assert.Equal("010102", Hex(raw));
        Assert.Equal(1, got.Name);
        Assert.Equal(2, got.Inner!.Name);
    }

    [Fact]
    public void NestedRow_WhenReadsTheNestedRowsOwnMember()
    {
        // Arrange
        var scheme = new Scheme<OuterRow>(1,
            Field.U8<OuterRow>(0, x => x.Kind),
            Field.Group((OuterRow x) => x.Inner,
                Field.U8<InnerRow>(0, i => i.Kind),
                Field.When(1, Condition.Eq(0, (byte)1), Field.U8<InnerRow>(1, i => i.V))));

        // Act
        var raw = BinaryPacker.Pack(scheme, new OuterRow { Kind = 0, Inner = new InnerRow { Kind = 1, V = 9 } });
        var got = Unpack(scheme, raw);
        var skipped = BinaryPacker.Pack(scheme, new OuterRow { Kind = 1, Inner = new InnerRow { Kind = 0, V = 9 } });

        // Assert
        Assert.Equal("01000109", Hex(raw));
        Assert.Equal(0, got.Kind);
        Assert.Equal(1, got.Inner!.Kind);
        Assert.Equal((byte)9, got.Inner.V);
        Assert.Equal("010100", Hex(skipped));
    }

    [Fact]
    public void Readme_CSharpExample_Packs()
    {
        // Arrange and Act: the README snippet, verbatim
        var userScheme = new Scheme<User>(1, f => [
            f.Utf8(0, x => x.Username),
            f.List(x => x.Roles, r => r.Utf8(0, role => role.RoleName)),
            f.Dict(x => x.Access, e => e.List(a => a.Actions, n => n.Utf8(0, action => action.Action)))]);

        var raw = BinaryPacker.Pack(userScheme, new User
        {
            Username = "ada",
            Roles = [new Role { RoleName = "user" }, new Role { RoleName = "admin" }],
            Access = new()
            {
                ["map"] = new ActionList { Actions = [new ActionName { Action = "read" }, new ActionName { Action = "edit" }] },
                ["store"] = new ActionList { Actions = [new ActionName { Action = "write" }] },
            },
        });

        // Assert
        Assert.Equal(ReadmeHex, Hex(raw));
    }

    [Fact]
    public void Readme_CSharpExample_Unpacks()
    {
        // Arrange
        var userScheme = new Scheme<User>(1, f => [
            f.Utf8(0, x => x.Username),
            f.List(x => x.Roles, r => r.Utf8(0, role => role.RoleName)),
            f.Dict(x => x.Access, e => e.List(a => a.Actions, n => n.Utf8(0, action => action.Action)))]);
        var ping = new Scheme<Ping>(2, f => [f.U8(0, x => x.Code)]);
        var note = new Scheme<Note>(3, f => [f.U16(0, x => x.Id), f.Utf8(1, x => x.Title)]);
        User? got = null;
        Ping? pinged = null;
        Note? noted = null;

        // Act
        var err = BinaryPacker.Unpack(
            Convert.FromHexString(ReadmeHex),
            userScheme.On(row => got = row),
            ping.On(row => pinged = row),
            note.On(row => noted = row));

        // Assert
        Assert.Null(err);
        Assert.Null(pinged);
        Assert.Null(noted);
        Assert.NotNull(got);
        Assert.Equal("ada", got.Username);
        Assert.Equal(new[] { "user", "admin" }, got.Roles.Select(r => r.RoleName));
        Assert.Equal(new[] { "map", "store" }, got.Access.Keys);
        Assert.Equal(new[] { "read", "edit" }, got.Access["map"].Actions.Select(a => a.Action));
        Assert.Equal(new[] { "write" }, got.Access["store"].Actions.Select(a => a.Action));
    }

    [Fact]
    public void ListOfNestedRows_WritesEveryElement()
    {
        // Arrange
        var scheme = new Scheme<ListRow>(1,
            Field.List((ListRow x) => x.Items, Field.Group((Holder h) => h.Item, Field.U8<Item>(0, i => i.V))));
        var row = new ListRow
        {
            Items = [new Holder { Item = new Item { V = 3 } }, new Holder { Item = new Item { V = 4 } }],
        };

        // Act
        var raw = BinaryPacker.Pack(scheme, row);
        var got = Unpack(scheme, raw);

        // Assert
        Assert.Equal("0102000304", Hex(raw));
        Assert.Equal(new byte[] { 3, 4 }, got.Items.Select(h => h.Item!.V));
    }

    [Fact]
    public void ListOfNestedRows_OneElement_IsNotLost()
    {
        // Arrange
        var scheme = new Scheme<ListRow>(1,
            Field.List((ListRow x) => x.Items, Field.Group((Holder h) => h.Item, Field.U8<Item>(0, i => i.V))));

        // Act
        var raw = BinaryPacker.Pack(scheme, new ListRow { Items = [new Holder { Item = new Item { V = 3 } }] });

        // Assert
        Assert.Equal("01010003", Hex(raw));
    }

    [Fact]
    public void ArrayAndDictionaryOfRows_RoundTrip()
    {
        // Arrange
        var scheme = new Scheme<TagArrayRow>(1,
            Field.List((TagArrayRow x) => x.Tags, Field.Utf8<Tag>(0, t => t.Label)),
            Field.Dict((TagArrayRow x) => x.ByKey, Field.Utf8<Tag>(0, t => t.Label)));
        var row = new TagArrayRow
        {
            Tags = [new Tag { Label = "a" }, new Tag { Label = "bc" }],
            ByKey = new() { ["k"] = new Tag { Label = "v" } },
        };

        // Act
        var raw = BinaryPacker.Pack(scheme, row);
        var got = Unpack(scheme, raw);

        // Assert
        Assert.Equal("01" + "0200" + "010061" + "02006263" + "0100" + "01006b" + "010076", Hex(raw));
        Assert.Equal(new[] { "a", "bc" }, got.Tags.Select(t => t.Label));
        Assert.Equal("v", got.ByKey["k"].Label);
    }

    [Fact]
    public void NestedRow_NullOutsideFlags_FailsNamingTheRow()
    {
        // Arrange
        var scheme = new Scheme<OuterRow>(1,
            Field.U8<OuterRow>(0, x => x.Name),
            Field.Group((OuterRow x) => x.Inner, Field.U8<InnerRow>(0, i => i.Name)));

        // Act
        var ex = Assert.Throws<ArgumentException>(() => BinaryPacker.Pack(scheme, new OuterRow { Name = 1 }));

        // Assert
        Assert.Contains("'Inner'", ex.Message, StringComparison.Ordinal);
    }

    [Fact]
    public void FieldMembersAndPrivateSetters_Bind()
    {
        // Arrange
        var scheme = new Scheme<MemberKinds>(1,
            Field.U8<MemberKinds>(0, x => x.Field),
            Field.U8<MemberKinds>(1, x => x.Private),
            Field.Flags(2, Field.I32<MemberKinds>(2, x => x.Wide)));

        // Act
        var raw = BinaryPacker.Pack(scheme, new MemberKinds { Field = 7, Wide = -2 }.With(8));
        var got = Unpack(scheme, raw);

        // Assert
        Assert.Equal("01" + "07" + "08" + "01" + "feffffff", Hex(raw));
        Assert.Equal((byte)7, got.Field);
        Assert.Equal((byte)8, got.Private);
        Assert.Equal(-2, got.Wide);
    }

    [Fact]
    public void NestedRowWithoutParameterlessConstructor_FailsAtConstruction()
    {
        // Arrange
        var group = Field.Group((NoCtorRow x) => x.Inner, Field.U8<NoCtor>(0, i => i.V));

        // Act
        var ex = Assert.Throws<ArgumentException>(() => new Scheme<NoCtorRow>(1, group));

        // Assert
        Assert.Contains("NoCtor", ex.Message, StringComparison.Ordinal);
        Assert.Contains("parameterless constructor", ex.Message, StringComparison.Ordinal);
    }

    [Fact]
    public void ListElementWithoutParameterlessConstructor_FailsAtConstruction()
    {
        // Arrange
        var list = Field.List((NoCtorRow x) => x.Many, Field.U8<NoCtor>(0, i => i.V));

        // Act
        var ex = Assert.Throws<ArgumentException>(() => new Scheme<NoCtorRow>(1, list));

        // Assert
        Assert.Contains("NoCtor", ex.Message, StringComparison.Ordinal);
        Assert.Contains("parameterless constructor", ex.Message, StringComparison.Ordinal);
    }
}
