using System.Security.Cryptography;
using System.Text.Json;
using Packbin;
using Xunit.Abstractions;

namespace Packbin.Tests;

public partial class CompactTextTests(ITestOutputHelper output)
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
}
