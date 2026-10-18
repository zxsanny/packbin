using System.Collections;
using Packbin;

namespace Packbin.Tests;

public partial class CompactTextTests
{
    // ---- AC-3: every string position, the ring packets

    private sealed class RoleEl
    {
        public string Role { get; set; } = "";
    }

    private sealed class ActionEl
    {
        public string Action { get; set; } = "";
    }

    private sealed class ActionList
    {
        public List<object?>? Actions { get; set; }
    }

    private sealed class UserRow
    {
        public string Username { get; set; } = "";
        public List<object?>? Roles { get; set; }
        public Dictionary<string, object?>? Access { get; set; }
    }

    private sealed class ValueEl
    {
        public string Value { get; set; } = "";
    }

    private sealed class FieldDict
    {
        public Dictionary<string, object?>? Fields { get; set; }
    }

    private sealed class FieldList
    {
        public List<object?>? Fields { get; set; }
    }

    private sealed class NestedRow
    {
        public Dictionary<string, object?>? Access { get; set; }
    }

    private static readonly Scheme<UserRow> UserScheme = new(1,
        Field.Utf8<UserRow>(0, x => x.Username),
        Field.List((UserRow x) => x.Roles, Field.Utf8<RoleEl>(0, r => r.Role)),
        Field.Dict((UserRow x) => x.Access, Field.List((ActionList e) => e.Actions, Field.Utf8<ActionEl>(0, a => a.Action))));

    private static readonly Scheme<NestedRow> NestedScheme = new(1,
        Field.Dict((NestedRow x) => x.Access, Field.List((FieldList r) => r.Fields, Field.Dict((FieldDict f) => f.Fields, Field.Utf8<ValueEl>(0, v => v.Value)))));

    private static Dictionary<string, object?> User(string name, string[] roles, Dictionary<string, string[]> access) => new()
    {
        ["Username"] = name,
        ["Roles"] = roles.Cast<object?>().ToList(),
        ["Access"] = access.ToDictionary(p => p.Key, p => (object?)p.Value.Cast<object?>().ToList()),
    };

    private static Dictionary<string, object?> Nested(Dictionary<string, Dictionary<string, object?>[]> access) => new()
    {
        ["Access"] = access.ToDictionary(p => p.Key, p => (object?)p.Value.Cast<object?>().ToList()),
    };

    private static Dictionary<string, object?> Op(params string[] pairs)
    {
        var map = new Dictionary<string, object?>();
        for (var i = 0; i < pairs.Length; i += 2)
            map[pairs[i]] = pairs[i + 1];
        return map;
    }

    private static (Scheme<UserRow>? User, Scheme<NestedRow>? Nested, Dictionary<string, object?> Values) RingValues(string id) => id switch
    {
        "ref.user" => (UserScheme, null, User("zxsanny", ["user", "dispatcher"],
            new() { ["channel"] = ["read"], ["map"] = ["read", "gps_fix", "set", "edit"], ["store"] = ["read", "write"] })),
        "ref.user_ua" => (UserScheme, null, User("Олександр", ["диспетчер", "Оператор"],
            new() { ["карта"] = ["читати", "правити"], ["канал"] = ["читати"] })),
        "ref.nested" => (null, NestedScheme, Nested(new()
        {
            ["map"] = [Op("op", "gps_fix")],
            ["store"] = [Op("op", "read"), Op("op", "write")],
        })),
        "ref.nested_mixed" => (null, NestedScheme, Nested(new()
        {
            ["Карта"] = [Op("op", "gps_fix", "note", "увага 48.46, 35.04")],
            ["store"] = [Op("op", "ЧИТАТИ")],
        })),
        _ => throw new ArgumentException(id),
    };

    [Theory]
    [MemberData(nameof(RefRows))]
    public void Ac3_RingPacket_PacksToTheRefBytesAndRoundTrips(string id)
    {
        // Arrange
        var expected = TextVectors.Find(id).Args[0];
        var (user, nested, values) = RingValues(id);

        // Act
        var raw = user is not null ? BinaryPacker.Pack(user, values) : BinaryPacker.Pack(nested!, values);
        var read = user is not null ? BinaryPacker.Read(user, raw) : BinaryPacker.Read(nested!, raw);
        var again = user is not null ? BinaryPacker.Pack(user, read.Values) : BinaryPacker.Pack(nested!, read.Values);

        // Assert
        Assert.Equal(expected, Hex(raw));
        Assert.Null(read.Error);
        Assert.Equal(expected, Hex(again));
        if (user is not null)
        {
            Assert.Equal(values["Username"], read.Values["Username"]);
            Assert.Equal(((IEnumerable)values["Roles"]!).Cast<object?>(), ((IEnumerable)read.Values["Roles"]!).Cast<object?>());
        }
    }

    [Theory]
    [MemberData(nameof(RefRows))]
    public void Ac3_RingPacket_UnpacksTyped(string id)
    {
        // Arrange
        var bytes = Convert.FromHexString(TextVectors.Find(id).Args[0]);
        var (user, nested, values) = RingValues(id);
        UserRow? gotUser = null;
        NestedRow? gotNested = null;

        // Act
        var error = user is not null
            ? BinaryPacker.Unpack(bytes, user.On(r => gotUser = r))
            : BinaryPacker.Unpack(bytes, nested!.On(r => gotNested = r));

        // Assert
        Assert.Null(error);
        var access = (Dictionary<string, object?>)values["Access"]!;
        if (user is not null)
        {
            Assert.Equal(values["Username"], gotUser!.Username);
            Assert.Equal(access.Count, gotUser.Access!.Count);
        }
        else
        {
            Assert.Equal(access.Count, gotNested!.Access!.Count);
        }
    }

    private sealed class RoundRow
    {
        public byte N { get; set; }
        public string S { get; set; } = "";
    }

    private sealed class OptRow
    {
        public string? S { get; set; }
        public byte After { get; set; }
    }

    [Fact]
    public void Ac3_TimesString_EachRoundIsACompactField()
    {
        // Arrange
        var scheme = new Scheme<RoundRow>(1,
            Field.U8<RoundRow>(0, x => x.N),
            Field.Times(1, 0, Field.Utf8<RoundRow>(1, x => x.S)));
        var values = new Dictionary<string, object?> { ["N"] = (byte)3, ["S"] = new object?[] { "привіт", "", "Привіт, Світе!" } };

        // Act
        var raw = BinaryPacker.Pack(scheme, values);
        var read = BinaryPacker.Read(scheme, raw);

        // Assert
        Assert.Equal("0103" + "05a37aa424e0" + "00" + "0c83e6f54849fd8f96849cffe0", Hex(raw));
        Assert.Null(read.Error);
        Assert.Equal(new object?[] { "привіт", "", "Привіт, Світе!" }, ((IEnumerable)read.Values["S"]!).Cast<object?>());
    }

    [Fact]
    public void Ac3_RepeatString_EachRoundIsACompactField()
    {
        // Arrange
        var scheme = new Scheme<RoundRow>(1,
            Field.Repeat(0, Field.U8<RoundRow>(0, x => x.N), Field.Utf8<RoundRow>(1, x => x.S)));
        var values = new Dictionary<string, object?>
        {
            ["N"] = new object?[] { (byte)1, (byte)2 },
            ["S"] = new object?[] { "привіт", "ok" },
        };

        // Act
        var raw = BinaryPacker.Pack(scheme, values);
        var read = BinaryPacker.Read(scheme, raw);

        // Assert
        Assert.Equal("01" + "01" + "05a37aa424e0" + "02" + "03106f6b", Hex(raw));
        Assert.Null(read.Error);
        Assert.Equal(new object?[] { "привіт", "ok" }, ((IEnumerable)read.Values["S"]!).Cast<object?>());
    }

    [Fact]
    public void Ac3_OptionalStringUnderFlags_AbsentAddsNoBytesAndEmptyAddsOne()
    {
        // Arrange
        var scheme = new Scheme<OptRow>(1,
            Field.Flags(0, Field.Utf8<OptRow>(0, x => x.S!)),
            Field.U8<OptRow>(1, x => x.After));
        var absent = new Dictionary<string, object?> { ["After"] = (byte)9 };
        var empty = new Dictionary<string, object?> { ["S"] = "", ["After"] = (byte)9 };
        var some = new Dictionary<string, object?> { ["S"] = "привіт", ["After"] = (byte)9 };

        // Act
        var withNone = BinaryPacker.Pack(scheme, absent);
        var withEmpty = BinaryPacker.Pack(scheme, empty);
        var withText = BinaryPacker.Pack(scheme, some);
        var read = BinaryPacker.Read(scheme, withText);

        // Assert
        Assert.Equal(withNone.Length + 1, withEmpty.Length);
        Assert.Equal("01" + "00" + "09", Hex(withNone));
        Assert.Equal("01" + "01" + "00" + "09", Hex(withEmpty));
        Assert.Equal("01" + "01" + "05a37aa424e0" + "09", Hex(withText));
        Assert.Null(read.Error);
        Assert.Equal("привіт", read.Values["S"]);
        Assert.Equal((byte)9, read.Values["After"]);
    }
}
