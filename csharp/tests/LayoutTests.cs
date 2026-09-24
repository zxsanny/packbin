using System.Globalization;
using Packbin;

namespace Packbin.Tests;

public class LayoutTests
{
    private sealed class Bag { }

    [Fact]
    public void WhenGroupWidth()
    {
        var scheme = new Scheme<Bag>(1,
            Field.U8("profile"),
            Field.When(Condition.Eq("profile", (byte)0), Field.U8("shape")));

        var miss = Pack.Run(scheme, new Dictionary<string, object?> { ["profile"] = (byte)1 });
        Assert.Equal(2, miss.Length);
        Assert.Equal(0x01, miss[0]);

        var hit = Pack.Run(scheme, new Dictionary<string, object?>
        {
            ["profile"] = (byte)0,
            ["shape"] = (byte)9,
        });
        Assert.Equal(3, hit.Length);
        Assert.Equal(1, hit.Length - miss.Length);
    }

    [Fact]
    public void RepeatBoundary()
    {
        var scheme = new Scheme<Bag>(1, Field.Repeat(Field.U8("a"), Field.U8("b")));

        var ok = Unpack.Read(scheme, new byte[] { 1, 1, 2 });
        Assert.Null(ok.Error);
        var groups = Assert.IsType<List<object?>>(ok.Values["a"]);
        Assert.Single(groups);

        var bad = Unpack.Read(scheme, new byte[] { 1, 1, 2, 3 });
        Assert.Empty(bad.Values);
        Assert.IsType<ShortPacket>(bad.Error);
    }

    [Fact]
    public void TrailingBytesAreError()
    {
        var scheme = new Scheme<Bag>(1, Field.U8("type"));
        var got = Unpack.Read(scheme, new byte[] { 0x01, 0x40, 0x99 });
        Assert.Empty(got.Values);
        var trailing = Assert.IsType<TrailingBytes>(got.Error);
        Assert.Equal(1, trailing.Left);
    }

    [Fact]
    public void FlagGroup_EmptyMark()
    {
        var scheme = new Scheme<Bag>(1, Field.Flags("f", Field.Group("mark")));
        var setBit = Pack.Run(scheme, new Dictionary<string, object?> { ["mark"] = true });
        Assert.Equal(new byte[] { 0x01, 0x01 }, setBit);
        var clear = Pack.Run(scheme, new Dictionary<string, object?>());
        Assert.Equal(new byte[] { 0x01, 0x00 }, clear);
    }

    [Fact]
    public void FlagGroup_FiveU8ThenU16()
    {
        var scheme = new Scheme<Bag>(1, Field.Flags("f",
            Field.U8("a"), Field.U8("b"), Field.U8("c"), Field.U8("d"), Field.U8("e"), Field.U16("b5")));
        Assert.Equal(3, Pack.Run(scheme, new Dictionary<string, object?> { ["a"] = (byte)1 }).Length);
        var empty = Pack.Run(scheme, new Dictionary<string, object?>());
        var wide = Pack.Run(scheme, new Dictionary<string, object?> { ["b5"] = (ushort)1 });
        Assert.Equal(0x01, wide[0]);
        Assert.Equal(0x20, wide[1]);
        Assert.Equal(2, wide.Length - empty.Length);
    }

    [Fact]
    public void FlagGroup_Session()
    {
        var scheme = new Scheme<Bag>(1, Field.Flags("f",
            Field.Group("session", Field.U16("login"), Field.U32("ts"))));
        var raw = Pack.Run(scheme, new Dictionary<string, object?>
        {
            ["login"] = (ushort)7,
            ["ts"] = 1000u,
        });
        Assert.Equal("0700e8030000", Convert.ToHexString(raw.AsSpan(2)).ToLowerInvariant());
        Assert.Equal(6, raw.Length - 2);
        var absent = Pack.Run(scheme, new Dictionary<string, object?>());
        Assert.Equal(new byte[] { 0x01, 0x00 }, absent);
        var got = Unpack.Read(scheme, absent);
        Assert.Null(got.Error);
        Assert.False(got.Values.ContainsKey("login"));
        Assert.False(got.Values.ContainsKey("ts"));
    }

    [Fact]
    public void FlagGroup_ZeroU8()
    {
        var scheme = new Scheme<Bag>(1, Field.Flags("f", Field.Group("g", Field.U8("b"))));
        var stored = Pack.Run(scheme, new Dictionary<string, object?> { ["b"] = (byte)0 });
        Assert.Equal(new byte[] { 0x01, 0x01, 0x00 }, stored);
    }

    [Fact]
    public void FlagGroup_SessionShort()
    {
        var scheme = new Scheme<Bag>(1, Field.Flags("f",
            Field.Group("session", Field.U16("login"), Field.U32("ts"))));
        var got = Unpack.Read(scheme, new byte[] { 0x01, 0x01, 0x07 });
        Assert.Empty(got.Values);
        var missing = Assert.IsType<ShortPacket>(got.Error);
        Assert.Equal("login", missing.Field);
        Assert.Equal(2, missing.Needed);
        Assert.Equal(1, missing.Left);
    }

    [Fact]
    public void SizedPayload()
    {
        var scheme = new Scheme<Bag>(1, Field.U16("n"), Field.Sized("payload", "n"));
        var raw = Pack.Run(scheme, new Dictionary<string, object?>
        {
            ["n"] = (ushort)3,
            ["payload"] = PackbinTests.ParseHex("756176"),
        });
        Assert.Equal("010300756176", Convert.ToHexString(raw).ToLowerInvariant());
        var empty = Pack.Run(scheme, new Dictionary<string, object?>
        {
            ["n"] = (ushort)0,
            ["payload"] = Array.Empty<byte>(),
        });
        Assert.Equal("010000", Convert.ToHexString(empty).ToLowerInvariant());
        var emptyGot = Unpack.Read(scheme, empty);
        Assert.Null(emptyGot.Error);
        Assert.Empty((byte[])emptyGot.Values["payload"]!);
        var shortGot = Unpack.Read(scheme, PackbinTests.ParseHex("01030075"));
        Assert.Empty(shortGot.Values);
        var missing = Assert.IsType<ShortPacket>(shortGot.Error);
        Assert.Equal("payload", missing.Field);
        Assert.Equal(3, missing.Needed);
        Assert.Equal(1, missing.Left);
    }

    [Fact]
    public void Utf8String()
    {
        var scheme = new Scheme<Bag>(1, Field.Utf8("name"));
        var raw = Pack.Run(scheme, new Dictionary<string, object?> { ["name"] = "zxsanny" });
        Assert.Equal("0107007a7873616e6e79", Convert.ToHexString(raw).ToLowerInvariant());
        Assert.Equal(10, raw.Length);
        var got = Unpack.Read(scheme, raw);
        Assert.Null(got.Error);
        Assert.Equal("zxsanny", got.Values["name"]);

        var empty = Pack.Run(scheme, new Dictionary<string, object?> { ["name"] = "" });
        Assert.Equal("010000", Convert.ToHexString(empty).ToLowerInvariant());
        var emptyGot = Unpack.Read(scheme, empty);
        Assert.Null(emptyGot.Error);
        Assert.Equal("", emptyGot.Values["name"]);

        Assert.Throws<ArgumentException>(() =>
            Pack.Run(scheme, new Dictionary<string, object?> { ["name"] = new string('a', 65536) }));

        var shortGot = Unpack.Read(scheme, new byte[] { 0x01, 0x07, 0x00, 0x7a, 0x78 });
        Assert.Empty(shortGot.Values);
        var missing = Assert.IsType<ShortPacket>(shortGot.Error);
        Assert.Equal("name", missing.Field);
        Assert.Equal(7, missing.Needed);
        Assert.Equal(2, missing.Left);
    }

    [Fact]
    public void CountedList()
    {
        var two = new Scheme<Bag>(1, Field.List("xs", Field.U16("n")));
        var raw = Pack.Run(two, new Dictionary<string, object?> { ["xs"] = new ushort[] { 1, 2 } });
        Assert.Equal("01020001000200", Convert.ToHexString(raw).ToLowerInvariant());
        var got = Unpack.Read(two, raw);
        Assert.Null(got.Error);
        var xs = Assert.IsAssignableFrom<System.Collections.IList>(got.Values["xs"]);
        Assert.Equal(2, xs.Count);
        Assert.Equal(1, Convert.ToInt32(xs[0], CultureInfo.InvariantCulture));
        Assert.Equal(2, Convert.ToInt32(xs[1], CultureInfo.InvariantCulture));

        var beOne = new Scheme<Bag>(1, Field.List("xs", Field.U16("n").Be()));
        var beRaw = Pack.Run(beOne, new Dictionary<string, object?> { ["xs"] = new ushort[] { 1 } });
        Assert.Equal("0101000001", Convert.ToHexString(beRaw).ToLowerInvariant());

        var followed = new Scheme<Bag>(1, Field.List("xs", Field.U8("n")), Field.U8("y"));
        var both = Pack.Run(followed, new Dictionary<string, object?>
        {
            ["xs"] = new byte[] { 1 },
            ["y"] = (byte)2,
        });
        Assert.Equal("0101000102", Convert.ToHexString(both).ToLowerInvariant());
        var back = Unpack.Read(followed, both);
        Assert.Null(back.Error);
        var one = Assert.IsAssignableFrom<System.Collections.IList>(back.Values["xs"]);
        Assert.Equal(1, Convert.ToInt32(one[0], CultureInfo.InvariantCulture));
        Assert.Equal(2, Convert.ToInt32(back.Values["y"], CultureInfo.InvariantCulture));

        var empty = Pack.Run(two, new Dictionary<string, object?> { ["xs"] = Array.Empty<ushort>() });
        Assert.Equal("010000", Convert.ToHexString(empty).ToLowerInvariant());
        Assert.Throws<ArgumentException>(() =>
            Pack.Run(two, new Dictionary<string, object?> { ["xs"] = new ushort[65536] }));
    }

    [Fact]
    public void CountedDict()
    {
        var scheme = new Scheme<Bag>(1,
            Field.Utf8("username"),
            Field.List("roles", Field.Utf8("role")),
            Field.Dict("access", Field.List("actions", Field.Utf8("action"))));
        const string userHex =
            "0107007a7873616e6e7902000400757365720a0064697370617463686572030007006368616e6e656c010004007265616403006d6170040004007265616407006770735f6669780300736574040065646974050073746f7265020004007265616405007772697465";
        var user = new Dictionary<string, object?>
        {
            ["username"] = "zxsanny",
            ["roles"] = new List<object?> { "user", "dispatcher" },
            ["access"] = new Dictionary<string, object?>
            {
                ["channel"] = new List<object?> { "read" },
                ["map"] = new List<object?> { "read", "gps_fix", "set", "edit" },
                ["store"] = new List<object?> { "read", "write" },
            },
        };
        var raw = Pack.Run(scheme, user);
        Assert.Equal(userHex, Convert.ToHexString(raw).ToLowerInvariant());
        var got = Unpack.Read(scheme, raw);
        Assert.Null(got.Error);
        Assert.Equal("zxsanny", got.Values["username"]);
        var roles = Assert.IsAssignableFrom<System.Collections.IList>(got.Values["roles"]);
        Assert.Equal(2, roles.Count);
        Assert.Equal("user", roles[0]);
        Assert.Equal("dispatcher", roles[1]);
        var access = Assert.IsAssignableFrom<System.Collections.IDictionary>(got.Values["access"]);
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
            ["username"] = "zxsanny",
            ["roles"] = new List<object?> { "user", "dispatcher" },
            ["access"] = new Dictionary<string, object?>
            {
                ["store"] = new List<object?> { "read", "write" },
                ["channel"] = new List<object?> { "read" },
                ["map"] = new List<object?> { "read", "gps_fix", "set", "edit" },
            },
        };
        var reorderedRaw = Pack.Run(scheme, reordered);
        Assert.Equal(0, PackbinTests.MismatchedBytes(raw, reorderedRaw));

        var empties = new Scheme<Bag>(1,
            Field.Utf8("a"),
            Field.List("b", Field.Utf8("x")),
            Field.Dict("c", Field.Utf8("v")));
        var emptyRaw = Pack.Run(empties, new Dictionary<string, object?>
        {
            ["a"] = "",
            ["b"] = new List<object?>(),
            ["c"] = new Dictionary<string, object?>(),
        });
        Assert.Equal("01000000000000", Convert.ToHexString(emptyRaw).ToLowerInvariant());

        var onlyDict = new Scheme<Bag>(1, Field.Dict("access", Field.Utf8("v")));
        var dup = Unpack.Read(onlyDict, PackbinTests.ParseHex("010200010061010078010061010079"));
        Assert.NotNull(dup.Error);
        Assert.Empty(dup.Values);

        var again = Pack.Run(scheme, user);
        Assert.Equal(0, PackbinTests.MismatchedBytes(raw, again));
        byte[]? left = null;
        byte[]? right = null;
        var first = new Thread(() => left = Pack.Run(scheme, user));
        var second = new Thread(() => right = Pack.Run(scheme, user));
        first.Start();
        second.Start();
        first.Join();
        second.Join();
        Assert.Equal(0, PackbinTests.MismatchedBytes(left!, right!));

        var over = new Dictionary<string, object?>();
        for (var i = 0; i < 65536; i++)
            over[i.ToString(CultureInfo.InvariantCulture)] = "x";
        Assert.Throws<ArgumentException>(() =>
            Pack.Run(onlyDict, new Dictionary<string, object?> { ["access"] = over }));
    }

    [Fact]
    public void U2AndBits()
    {
        var kinds = new Scheme<Bag>(1, Field.U2("a", "b", "c", "d"));
        var raw = Pack.Run(kinds, new Dictionary<string, object?>
        {
            ["a"] = 0, ["b"] = 1, ["c"] = 2, ["d"] = 3,
        });
        Assert.Equal("01e4", Convert.ToHexString(raw).ToLowerInvariant());
        var got = Unpack.Read(kinds, raw);
        Assert.Null(got.Error);
        Assert.Equal(0, Convert.ToInt32(got.Values["a"]!, CultureInfo.InvariantCulture));
        Assert.Equal(1, Convert.ToInt32(got.Values["b"]!, CultureInfo.InvariantCulture));
        Assert.Equal(2, Convert.ToInt32(got.Values["c"]!, CultureInfo.InvariantCulture));
        Assert.Equal(3, Convert.ToInt32(got.Values["d"]!, CultureInfo.InvariantCulture));
        var one = Pack.Run(new Scheme<Bag>(1, Field.U2("a")), new Dictionary<string, object?> { ["a"] = 1 });
        Assert.Equal("0101", Convert.ToHexString(one).ToLowerInvariant());

        var layout = new Scheme<Bag>(1, Field.U8("n"), Field.Bits("segs", "n"));
        var eight = Pack.Run(layout, new Dictionary<string, object?>
        {
            ["n"] = (byte)8,
            ["segs"] = new List<int> { 1, 1, 1, 1, 1, 1, 1, 1 },
        });
        Assert.Equal("ff", Convert.ToHexString(eight.AsSpan(2)).ToLowerInvariant());
        Assert.Equal(1, eight.Length - 2);
        var nine = Pack.Run(layout, new Dictionary<string, object?>
        {
            ["n"] = (byte)9,
            ["segs"] = new List<int> { 1, 1, 1, 1, 1, 1, 1, 1, 1 },
        });
        Assert.Equal(2, nine.Length - 2);
        Assert.Equal(0xFF, nine[2]);
        Assert.Equal(0, nine[3] & 0xFE);
        var shortGot = Unpack.Read(layout, new byte[] { 1, 9, 1 });
        Assert.Empty(shortGot.Values);
        var missing = Assert.IsType<ShortPacket>(shortGot.Error);
        Assert.Equal("segs", missing.Field);
        Assert.Equal(2, missing.Needed);
        Assert.Equal(1, missing.Left);
    }
}
