using System.Collections;
using System.Diagnostics;
using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using Packbin;
using Xunit.Abstractions;

namespace Packbin.Tests;

// AZ-2650: every string position is written and read with the compact text format (contract compact-text 1.0.0).
// The rows of fixtures/text/vectors.txt are the expected bytes; the reference is scripts/text/textfmt.py.
internal static class TextVectors
{
    internal sealed record Row(string Kind, string Id, string[] Args);

    private static readonly Lazy<List<Row>> Loaded = new(Load);

    internal static IReadOnlyList<Row> All => Loaded.Value;

    internal static IEnumerable<Row> Of(params string[] kinds) => All.Where(r => kinds.Contains(r.Kind));

    internal static Row Find(string id) => All.Single(r => r.Id == id);

    internal static IEnumerable<object[]> Ids(params string[] kinds) => Of(kinds).Select(r => new object[] { r.Id });

    // "-" is the empty text; otherwise the hex of its UTF-8 bytes.
    internal static string TextOf(string hex) => hex == "-" ? "" : Encoding.UTF8.GetString(Convert.FromHexString(hex));

    internal static string RepositoryFile(params string[] parts)
    {
        var dir = new DirectoryInfo(AppContext.BaseDirectory);
        while (dir is not null)
        {
            var path = Path.Combine([dir.FullName, .. parts]);
            if (File.Exists(path))
                return path;
            dir = dir.Parent;
        }
        throw new FileNotFoundException(string.Join('/', parts));
    }

    private static List<Row> Load()
    {
        var rows = new List<Row>();
        foreach (var line in File.ReadAllLines(RepositoryFile("fixtures", "text", "vectors.txt")))
        {
            if (line.Length == 0 || line[0] == '#')
                continue;
            var parts = line.Split(' ');
            rows.Add(new Row(parts[0], parts[1], parts[2..]));
        }
        return rows;
    }
}

public class CompactTextTests(ITestOutputHelper output)
{
    private sealed class NameRow
    {
        public string Name { get; set; } = "";
    }

    private sealed class NameAfterRow
    {
        public string Name { get; set; } = "";
        public byte After { get; set; }
    }

    private static readonly Scheme<NameRow> Single = new(1, Field.Utf8<NameRow>(0, x => x.Name));
    private static readonly Scheme<NameAfterRow> WithAfter =
        new(1, Field.Utf8<NameAfterRow>(0, x => x.Name), Field.U8<NameAfterRow>(1, x => x.After));

    private static string Hex(byte[] raw) => Convert.ToHexString(raw).ToLowerInvariant();

    private static byte[] Packet(string fieldHex) => Convert.FromHexString("01" + fieldHex);

    private static byte[] PackName(string text) =>
        BinaryPacker.Pack(Single, new Dictionary<string, object?> { ["Name"] = text });

    // The count header of a field and the offset of its payload.
    private static (int Count, int Payload) Header(byte[] field)
    {
        var count = 0;
        var at = 0;
        for (var k = 0; ; k++)
        {
            count |= (field[at] & 0x7f) << (7 * k);
            if ((field[at++] & 0x80) == 0)
                return (count, at);
        }
    }

    public static IEnumerable<object[]> EncRows() => TextVectors.Ids("enc");
    public static IEnumerable<object[]> UnpackRows() => TextVectors.Ids("enc", "alt");
    public static IEnumerable<object[]> BadRows() => TextVectors.Ids("bad");
    public static IEnumerable<object[]> FlipRows() => TextVectors.Ids("flip");
    public static IEnumerable<object[]> RefRows() => TextVectors.Ids("ref");

    // ---- the tables are the frozen ones

    [Fact]
    public void Tables_AreTheFrozenFile()
    {
        // Arrange
        var path = TextVectors.RepositoryFile("fixtures", "text", "tables.json");
        var bytes = File.ReadAllBytes(path);
        using var json = JsonDocument.Parse(bytes);
        var root = json.RootElement;
        int[] Points(string text) => [.. text.EnumerateRunes().Select(r => r.Value)];
        int[] Upper(string mode) =>
            [.. root.GetProperty("upper").GetProperty(mode).EnumerateArray().Select(e => e.GetString()!.Length == 0 ? 0 : Points(e.GetString()!)[0])];
        int[] Lengths(string mode) =>
            [.. root.GetProperty("modes").GetProperty(mode).GetProperty("lengths").EnumerateArray().Select(e => e.GetInt32())];

        // Act
        var sha = Convert.ToHexString(SHA256.HashData(bytes)).ToLowerInvariant();

        // Assert
        Assert.Equal(TextTables.Sha256, sha);
        Assert.Equal(Points(root.GetProperty("alphabets").GetProperty("ua").GetString()!), TextTables.Ua);
        Assert.Equal(Points(root.GetProperty("alphabets").GetProperty("ru").GetString()!), TextTables.Ru);
        Assert.Equal(Points(root.GetProperty("alphabets").GetProperty("en").GetString()!), TextTables.En);
        Assert.Equal(Upper("ua"), TextTables.UaUpper);
        Assert.Equal(Upper("ru"), TextTables.RuUpper);
        Assert.Equal(Upper("en"), TextTables.EnUpper);
        Assert.Equal(Points(root.GetProperty("shared").GetString()!), TextTables.Shared);
        Assert.Equal(Points(root.GetProperty("numset").GetString()!), TextTables.Numset);
        Assert.Equal(Lengths("ua"), TextTables.LengthsUa);
        Assert.Equal(Lengths("ru"), TextTables.LengthsRu);
        Assert.Equal(Lengths("en"), TextTables.LengthsEn);
        Assert.Equal(Lengths("num"), TextTables.LengthsNum);
    }

    // ---- AC-1, AC-2

    [Theory]
    [MemberData(nameof(EncRows))]
    public void Ac1_Pack_EveryEncRow_GivesTheRowBytes(string id)
    {
        // Arrange
        var row = TextVectors.Find(id);

        // Act
        var raw = PackName(TextVectors.TextOf(row.Args[0]));

        // Assert
        Assert.Equal("01" + row.Args[1], Hex(raw));
    }

    [Theory]
    [MemberData(nameof(UnpackRows))]
    public void Ac2_Unpack_EveryEncAndAltRow_GivesTheTextAndUsesEveryByte(string id)
    {
        // Arrange
        var row = TextVectors.Find(id);

        // Act
        var got = BinaryPacker.Read(Single, Packet(row.Args[1]));

        // Assert
        Assert.Null(got.Error);
        Assert.Equal(TextVectors.TextOf(row.Args[0]), got.Values["Name"]);
    }

    // ---- AC-4: bad rows and bit flips

    [Theory]
    [MemberData(nameof(BadRows))]
    public void Ac4_Unpack_EveryBadRow_IsRefusedNamingTheField(string id)
    {
        // Arrange
        var row = TextVectors.Find(id);
        var bytes = Packet(row.Args[1]);

        // Act
        var got = BinaryPacker.Read(Single, bytes);

        // Assert
        var error = Assert.IsType<ShortPacket>(got.Error);
        Assert.Equal("Name", error.Field);
        Assert.Empty(got.Values);
    }

    [Theory]
    [MemberData(nameof(FlipRows))]
    public void Ac4_Unpack_EveryBitOfThePayloadFlipped_IsAStringOrAnErrorAndTheNextFieldIsIntact(string id)
    {
        // Arrange
        var field = Convert.FromHexString(TextVectors.Find(TextVectors.Find(id).Args[0]).Args[1]);
        var (count, payload) = Header(field);
        var flipped = 0;
        var strings = 0;

        // Act and Assert
        for (var bit = 0; bit < 8 * count; bit++)
        {
            var mutated = (byte[])field.Clone();
            mutated[payload + (bit >> 3)] ^= (byte)(0x80 >> (bit & 7));
            var bytes = new byte[] { 1 }.Concat(mutated).Append((byte)0x5a).ToArray();
            var got = BinaryPacker.Read(WithAfter, bytes);
            flipped++;
            if (got.Error is not null)
            {
                Assert.Equal("Name", Assert.IsType<ShortPacket>(got.Error).Field);
                continue;
            }
            strings++;
            Assert.IsType<string>(got.Values["Name"]);
            Assert.Equal((byte)0x5a, got.Values["After"]);
        }
        Assert.Equal(8 * count, flipped);
        output.WriteLine($"{id}: {flipped} flips, {strings} strings, {flipped - strings} errors");
    }

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

    // ---- AC-5: limits and headers

    [Fact]
    public void Ac5_Pack_65535Bytes_IsAcceptedAnd65536Refused()
    {
        // Arrange
        var fits = new string('中', 21_845);
        var over = fits + "a";

        // Act
        var raw = PackName(fits);
        var error = Assert.Throws<ArgumentException>(() => PackName(over));
        var read = BinaryPacker.Read(Single, raw);

        // Assert
        Assert.Equal(1 + 3 + 65_536, raw.Length);
        Assert.StartsWith("01" + "808004" + "10", Hex(raw));
        Assert.Contains("Name", error.Message);
        Assert.Null(read.Error);
        Assert.Equal(fits, read.Values["Name"]);
    }

    [Fact]
    public void Ac5_Pack_CompactTextOf65535Bytes_RoundTrips()
    {
        // Arrange
        var text = new string('a', 65_535);

        // Act
        var raw = PackName(text);
        var read = BinaryPacker.Read(Single, raw);

        // Assert
        Assert.True(raw.Length < 40_000);
        Assert.Null(read.Error);
        Assert.Equal(text, read.Values["Name"]);
    }

    [Theory]
    [InlineData(42, "", 1, "7f10")]
    [InlineData(42, "a", 2, "800110")]
    public void Ac5_Pack_PayloadOf127And128Bytes_HasAOneAndATwoByteHeader(int cjk, string tail, int head, string prefix)
    {
        // Arrange (a character no table codes: the raw payload is 1 + the UTF-8 bytes, 127 or 128 here)
        var text = new string('中', cjk) + tail;

        // Act
        var raw = PackName(text);

        // Assert
        Assert.Equal(1 + head + (head == 1 ? 127 : 128), raw.Length);
        Assert.StartsWith("01" + prefix, Hex(raw));
    }

    [Fact]
    public void Ac5_Pack_MaxBytes_StillBoundsThePacket()
    {
        // Arrange
        var text = new string('中', 20) + "a";
        var fits = new Scheme<NameRow>(1, Field.Utf8<NameRow>(0, x => x.Name)).WithLimits(maxBytes: 64);
        var tight = new Scheme<NameRow>(1, Field.Utf8<NameRow>(0, x => x.Name)).WithLimits(maxBytes: 63);

        // Act
        var raw = BinaryPacker.Pack(fits, new Dictionary<string, object?> { ["Name"] = text });
        var error = Assert.Throws<ArgumentException>(() =>
            BinaryPacker.Pack(tight, new Dictionary<string, object?> { ["Name"] = text }));

        // Assert
        Assert.Equal(64, raw.Length);
        Assert.Contains("'Name': the packet would be 64 bytes, above the limit of 63 bytes", error.Message);
    }

    // ---- AC-6: invalid UTF-8 refused

    public static IEnumerable<object[]> Utf8BadRows() =>
        TextVectors.Of("bad").Where(r => r.Args[0] == "utf8").Select(r => new object[] { r.Id });

    [Theory]
    [MemberData(nameof(Utf8BadRows))]
    public void Ac6_Unpack_InvalidUtf8_IsRefusedNamingTheField(string id)
    {
        // Arrange
        var row = TextVectors.Find(id);

        // Act
        var got = BinaryPacker.Read(Single, Packet(row.Args[1]));

        // Assert
        Assert.Equal("Name", Assert.IsType<ShortPacket>(got.Error).Field);
    }

    // ---- AC-7: dictionary keys

    private sealed class MapRow
    {
        public Dictionary<string, object?>? M { get; set; }
    }

    private sealed class MapEl
    {
        public byte V { get; set; }
    }

    private static readonly Scheme<MapRow> MapScheme = new(1, Field.Dict((MapRow x) => x.M, Field.U8<MapEl>(0, e => e.V)));

    [Fact]
    public void Ac7_Pack_KeysInTwoOrders_GiveIdenticalBytesSortedByUtf8()
    {
        // Arrange
        var first = new Dictionary<string, object?>();
        foreach (var key in new[] { "яблуко", "b", "Карта", "a", "канал" })
            first[key] = (byte)key.Length;
        var second = new Dictionary<string, object?>();
        foreach (var key in new[] { "a", "канал", "яблуко", "Карта", "b" })
            second[key] = (byte)key.Length;

        // Act
        var one = BinaryPacker.Pack(MapScheme, new Dictionary<string, object?> { ["M"] = first });
        var two = BinaryPacker.Pack(MapScheme, new Dictionary<string, object?> { ["M"] = second });
        var read = BinaryPacker.Read(MapScheme, one);

        // Assert (the pairs are in the order of the key's UTF-8 bytes, each key a compact field)
        var sorted = first.Keys.OrderBy(k => Encoding.UTF8.GetBytes(k), Comparer<byte[]>.Create(Compare)).ToList();
        var expected = "01" + "0500" + string.Concat(sorted.Select(k => Hex(PackName(k)[1..]) + ((byte)k.Length).ToString("x2")));
        Assert.Equal(expected, Hex(one));
        Assert.Equal(Hex(one), Hex(two));
        Assert.Null(read.Error);
        Assert.Equal(5, ((Dictionary<string, object?>)read.Values["M"]!).Count);
    }

    private static int Compare(byte[] a, byte[] b) => a.AsSpan().SequenceCompareTo(b);

    [Fact]
    public void Ac7_Unpack_ARepeatedDecodedKey_IsRefused()
    {
        // Arrange (the key "a" twice, once as the compact field and once as the same text; both decode to "a")
        var a = Hex(PackName("a")[1..]);
        var packet = Convert.FromHexString("01" + "0200" + a + "00" + a + "00");

        // Act
        var read = BinaryPacker.Read(MapScheme, packet);

        // Assert
        var error = Assert.IsType<ShortPacket>(read.Error);
        Assert.Equal("M", error.Field);
    }

    // ---- AC-8: speed

    [Collection("Timing")]
    public sealed class Speed(ITestOutputHelper output)
    {
        [Fact]
        public void Ac8_TwentyCharacterUkrainianString_100000RoundTripsWithinOneSecond()
        {
            // Arrange
            var scheme = new Scheme<NameRow>(1, Field.Utf8<NameRow>(0, x => x.Name));
            var row = new NameRow { Name = "Доброго ранку, друже" };
            RoundTrip(scheme, row);

            // Act
            var watch = Stopwatch.StartNew();
            for (var i = 0; i < 100_000; i++)
                RoundTrip(scheme, row);
            watch.Stop();

            // Assert
            output.WriteLine($"AZ-2650 AC-8: {watch.Elapsed.TotalMilliseconds:F0} ms for 100000 round trips of 20 characters");
            Assert.True(watch.Elapsed.TotalMilliseconds <= 1000.0, $"took {watch.Elapsed.TotalMilliseconds:F0} ms");
        }

        private static void RoundTrip(Scheme<NameRow> scheme, NameRow row)
        {
            NameRow? got = null;
            var bytes = BinaryPacker.Pack(scheme, row);
            var error = BinaryPacker.Unpack(bytes, scheme.On(r => got = r));
            Assert.Null(error);
            Assert.Equal(row.Name, got!.Name);
        }
    }
}
