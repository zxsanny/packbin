using System.Globalization;
using Packbin;

namespace Packbin.Tests;

// Sized, utf8, list, dict, u2 and bits layouts (split from LayoutTests, AZ-2365).
public class LayoutCountedTests
{
    private sealed class SizedRow
    {
        public ushort N { get; set; }
        public byte[] Payload { get; set; } = [];
    }

    private sealed class Utf8Row
    {
        public string Name { get; set; } = "";
    }

    private sealed class U16El
    {
        public ushort N { get; set; }
    }

    private sealed class U8El
    {
        public byte N { get; set; }
    }

    private sealed class ListRow
    {
        public ushort[] Xs { get; set; } = [];
    }

    private sealed class ListFollowRow
    {
        public byte[] Xs { get; set; } = [];
        public byte Y { get; set; }
    }

    private sealed class Utf8El
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

    private sealed class EmptyPartsRow
    {
        public string A { get; set; } = "";
        public List<object?>? B { get; set; }
        public Dictionary<string, object?>? C { get; set; }
    }

    private sealed class DictOnlyRow
    {
        public Dictionary<string, object?>? Access { get; set; }
    }

    private sealed class ValueEl
    {
        public string V { get; set; } = "";
    }

    private sealed class U2Row
    {
        public int A { get; set; }
        public int B { get; set; }
        public int C { get; set; }
        public int D { get; set; }
    }

    private sealed class BitsRow
    {
        public byte N { get; set; }
        public List<int>? Segs { get; set; }
    }

    [Fact]
    public void SizedPayload()
    {
        var scheme = new Scheme<SizedRow>(1, Field.U16<SizedRow>(0, x => x.N), Field.Sized<SizedRow>(1, x => x.Payload, 0));
        var raw = BinaryPacker.Pack(scheme, new Dictionary<string, object?>
        {
            ["N"] = (ushort)3,
            ["Payload"] = PackbinTests.ParseHex("756176"),
        });
        Assert.Equal("010300756176", Convert.ToHexString(raw).ToLowerInvariant());
        var empty = BinaryPacker.Pack(scheme, new Dictionary<string, object?>
        {
            ["N"] = (ushort)0,
            ["Payload"] = Array.Empty<byte>(),
        });
        Assert.Equal("010000", Convert.ToHexString(empty).ToLowerInvariant());
        var emptyGot = BinaryPacker.Read(scheme, empty);
        Assert.Null(emptyGot.Error);
        Assert.Empty((byte[])emptyGot.Values["Payload"]!);
        var shortGot = BinaryPacker.Read(scheme, PackbinTests.ParseHex("01030075"));
        Assert.Empty(shortGot.Values);
        var missing = Assert.IsType<ShortPacket>(shortGot.Error);
        Assert.Equal("Payload", missing.Field);
        Assert.Equal(3, missing.Needed);
        Assert.Equal(1, missing.Left);
    }

    [Fact]
    public void Utf8String()
    {
        var scheme = new Scheme<Utf8Row>(1, Field.Utf8<Utf8Row>(0, x => x.Name));
        var raw = BinaryPacker.Pack(scheme, new Dictionary<string, object?> { ["Name"] = "zxsanny" });
        Assert.Equal("0107007a7873616e6e79", Convert.ToHexString(raw).ToLowerInvariant());
        Assert.Equal(10, raw.Length);
        var got = BinaryPacker.Read(scheme, raw);
        Assert.Null(got.Error);
        Assert.Equal("zxsanny", got.Values["Name"]);

        var empty = BinaryPacker.Pack(scheme, new Dictionary<string, object?> { ["Name"] = "" });
        Assert.Equal("010000", Convert.ToHexString(empty).ToLowerInvariant());
        var emptyGot = BinaryPacker.Read(scheme, empty);
        Assert.Null(emptyGot.Error);
        Assert.Equal("", emptyGot.Values["Name"]);

        Assert.Throws<ArgumentException>(() =>
            BinaryPacker.Pack(scheme, new Dictionary<string, object?> { ["Name"] = new string('a', 65536) }));

        var shortGot = BinaryPacker.Read(scheme, new byte[] { 0x01, 0x07, 0x00, 0x7a, 0x78 });
        Assert.Empty(shortGot.Values);
        var missing = Assert.IsType<ShortPacket>(shortGot.Error);
        Assert.Equal("Name", missing.Field);
        Assert.Equal(7, missing.Needed);
        Assert.Equal(2, missing.Left);
    }

    [Fact]
    public void CountedList()
    {
        var two = new Scheme<ListRow>(1, Field.List((ListRow x) => x.Xs, Field.U16<U16El>(0, n => n.N)));
        var raw = BinaryPacker.Pack(two, new Dictionary<string, object?> { ["Xs"] = new ushort[] { 1, 2 } });
        Assert.Equal("01020001000200", Convert.ToHexString(raw).ToLowerInvariant());
        var got = BinaryPacker.Read(two, raw);
        Assert.Null(got.Error);
        var xs = Assert.IsAssignableFrom<System.Collections.IList>(got.Values["Xs"]);
        Assert.Equal(2, xs.Count);
        Assert.Equal(1, Convert.ToInt32(xs[0], CultureInfo.InvariantCulture));
        Assert.Equal(2, Convert.ToInt32(xs[1], CultureInfo.InvariantCulture));

        var beOne = new Scheme<ListRow>(1, Field.List((ListRow x) => x.Xs, Field.U16<U16El>(0, n => n.N).Be()));
        var beRaw = BinaryPacker.Pack(beOne, new Dictionary<string, object?> { ["Xs"] = new ushort[] { 1 } });
        Assert.Equal("0101000001", Convert.ToHexString(beRaw).ToLowerInvariant());

        var followed = new Scheme<ListFollowRow>(1,
            Field.List((ListFollowRow x) => x.Xs, Field.U8<U8El>(0, n => n.N)),
            Field.U8<ListFollowRow>(0, x => x.Y));
        var both = BinaryPacker.Pack(followed, new Dictionary<string, object?>
        {
            ["Xs"] = new byte[] { 1 },
            ["Y"] = (byte)2,
        });
        Assert.Equal("0101000102", Convert.ToHexString(both).ToLowerInvariant());
        var back = BinaryPacker.Read(followed, both);
        Assert.Null(back.Error);
        var one = Assert.IsAssignableFrom<System.Collections.IList>(back.Values["Xs"]);
        Assert.Equal(1, Convert.ToInt32(one[0], CultureInfo.InvariantCulture));
        Assert.Equal(2, Convert.ToInt32(back.Values["Y"], CultureInfo.InvariantCulture));

        var empty = BinaryPacker.Pack(two, new Dictionary<string, object?> { ["Xs"] = Array.Empty<ushort>() });
        Assert.Equal("010000", Convert.ToHexString(empty).ToLowerInvariant());
        Assert.Throws<ArgumentException>(() =>
            BinaryPacker.Pack(two, new Dictionary<string, object?> { ["Xs"] = new ushort[65536] }));
    }

    [Fact]
    public void CountedDict()
    {
        var scheme = new Scheme<UserRow>(1,
            Field.Utf8<UserRow>(0, x => x.Username),
            Field.List((UserRow x) => x.Roles, Field.Utf8<Utf8El>(0, r => r.Role)),
            Field.Dict((UserRow x) => x.Access, Field.List((ActionList e) => e.Actions, Field.Utf8<ActionEl>(0, a => a.Action))));
        const string userHex =
            "0107007a7873616e6e7902000400757365720a0064697370617463686572030007006368616e6e656c010004007265616403006d6170040004007265616407006770735f6669780300736574040065646974050073746f7265020004007265616405007772697465";
        var user = new Dictionary<string, object?>
        {
            ["Username"] = "zxsanny",
            ["Roles"] = new List<object?> { "user", "dispatcher" },
            ["Access"] = new Dictionary<string, object?>
            {
                ["channel"] = new List<object?> { "read" },
                ["map"] = new List<object?> { "read", "gps_fix", "set", "edit" },
                ["store"] = new List<object?> { "read", "write" },
            },
        };
        var raw = BinaryPacker.Pack(scheme, user);
        Assert.Equal(userHex, Convert.ToHexString(raw).ToLowerInvariant());
        var got = BinaryPacker.Read(scheme, raw);
        Assert.Null(got.Error);
        Assert.Equal("zxsanny", got.Values["Username"]);
        var roles = Assert.IsAssignableFrom<System.Collections.IList>(got.Values["Roles"]);
        Assert.Equal(2, roles.Count);
        Assert.Equal("user", roles[0]);
        Assert.Equal("dispatcher", roles[1]);
        var access = Assert.IsAssignableFrom<System.Collections.IDictionary>(got.Values["Access"]);
        Assert.Equal(3, access.Count);
        var channel = Assert.IsAssignableFrom<System.Collections.IList>(access["channel"]);
        Assert.Equal("read", Assert.Single(channel));
        var map = Assert.IsAssignableFrom<System.Collections.IList>(access["map"]);
        Assert.Equal(4, map.Count);
        Assert.Equal("read", map[0]);
        Assert.Equal("gps_fix", map[1]);
        Assert.Equal("set", map[2]);
        Assert.Equal("edit", map[3]);
        var store = Assert.IsAssignableFrom<System.Collections.IList>(access["store"]);
        Assert.Equal(2, store.Count);
        Assert.Equal("read", store[0]);
        Assert.Equal("write", store[1]);

        var reordered = new Dictionary<string, object?>
        {
            ["Username"] = "zxsanny",
            ["Roles"] = new List<object?> { "user", "dispatcher" },
            ["Access"] = new Dictionary<string, object?>
            {
                ["store"] = new List<object?> { "read", "write" },
                ["channel"] = new List<object?> { "read" },
                ["map"] = new List<object?> { "read", "gps_fix", "set", "edit" },
            },
        };
        var reorderedRaw = BinaryPacker.Pack(scheme, reordered);
        Assert.Equal(0, PackbinTests.MismatchedBytes(raw, reorderedRaw));

        var empties = new Scheme<EmptyPartsRow>(1,
            Field.Utf8<EmptyPartsRow>(0, x => x.A),
            Field.List((EmptyPartsRow x) => x.B, Field.Utf8<ValueEl>(0, x => x.V)),
            Field.Dict((EmptyPartsRow x) => x.C, Field.Utf8<ValueEl>(0, x => x.V)));
        var emptyRaw = BinaryPacker.Pack(empties, new Dictionary<string, object?>
        {
            ["A"] = "",
            ["B"] = new List<object?>(),
            ["C"] = new Dictionary<string, object?>(),
        });
        Assert.Equal("01000000000000", Convert.ToHexString(emptyRaw).ToLowerInvariant());

        var onlyDict = new Scheme<DictOnlyRow>(1, Field.Dict((DictOnlyRow x) => x.Access, Field.Utf8<ValueEl>(0, v => v.V)));
        var dup = BinaryPacker.Read(onlyDict, PackbinTests.ParseHex("010200010061010078010061010079"));
        Assert.NotNull(dup.Error);
        Assert.Empty(dup.Values);

        var again = BinaryPacker.Pack(scheme, user);
        Assert.Equal(0, PackbinTests.MismatchedBytes(raw, again));
        byte[]? left = null;
        byte[]? right = null;
        var first = new Thread(() => left = BinaryPacker.Pack(scheme, user));
        var second = new Thread(() => right = BinaryPacker.Pack(scheme, user));
        first.Start();
        second.Start();
        first.Join();
        second.Join();
        Assert.Equal(0, PackbinTests.MismatchedBytes(left!, right!));

        var over = new Dictionary<string, object?>();
        for (var i = 0; i < 65536; i++)
            over[i.ToString(CultureInfo.InvariantCulture)] = "x";
        Assert.Throws<ArgumentException>(() =>
            BinaryPacker.Pack(onlyDict, new Dictionary<string, object?> { ["Access"] = over }));
    }

    [Fact]
    public void U2AndBits()
    {
        var kinds = new Scheme<U2Row>(1, Field.U2<U2Row>(
            (0, x => x.A), (1, x => x.B), (2, x => x.C), (3, x => x.D)));
        var raw = BinaryPacker.Pack(kinds, new Dictionary<string, object?>
        {
            ["A"] = 0, ["B"] = 1, ["C"] = 2, ["D"] = 3,
        });
        Assert.Equal("01e4", Convert.ToHexString(raw).ToLowerInvariant());
        var got = BinaryPacker.Read(kinds, raw);
        Assert.Null(got.Error);
        Assert.Equal(0, Convert.ToInt32(got.Values["A"]!, CultureInfo.InvariantCulture));
        Assert.Equal(1, Convert.ToInt32(got.Values["B"]!, CultureInfo.InvariantCulture));
        Assert.Equal(2, Convert.ToInt32(got.Values["C"]!, CultureInfo.InvariantCulture));
        Assert.Equal(3, Convert.ToInt32(got.Values["D"]!, CultureInfo.InvariantCulture));
        var one = BinaryPacker.Pack(new Scheme<U2Row>(1, Field.U2<U2Row>((0, x => x.A))), new Dictionary<string, object?> { ["A"] = 1 });
        Assert.Equal("0101", Convert.ToHexString(one).ToLowerInvariant());

        var layout = new Scheme<BitsRow>(1, Field.U8<BitsRow>(0, x => x.N), Field.Bits<BitsRow>(1, x => x.Segs, 0));
        var eight = BinaryPacker.Pack(layout, new Dictionary<string, object?>
        {
            ["N"] = (byte)8,
            ["Segs"] = new List<int> { 1, 1, 1, 1, 1, 1, 1, 1 },
        });
        Assert.Equal("ff", Convert.ToHexString(eight.AsSpan(2)).ToLowerInvariant());
        Assert.Equal(1, eight.Length - 2);
        var nine = BinaryPacker.Pack(layout, new Dictionary<string, object?>
        {
            ["N"] = (byte)9,
            ["Segs"] = new List<int> { 1, 1, 1, 1, 1, 1, 1, 1, 1 },
        });
        Assert.Equal(2, nine.Length - 2);
        Assert.Equal(0xFF, nine[2]);
        Assert.Equal(0, nine[3] & 0xFE);
        var shortGot = BinaryPacker.Read(layout, new byte[] { 1, 9, 1 });
        Assert.Empty(shortGot.Values);
        var missing = Assert.IsType<ShortPacket>(shortGot.Error);
        Assert.Equal("Segs", missing.Field);
        Assert.Equal(2, missing.Needed);
        Assert.Equal(1, missing.Left);
    }
}
