using Packbin;

namespace Packbin.Tests;

// AZ-2310: the rows Read returns for a list or dict of group elements pack again to the same bytes, and a value that is
// not a byte[] for a Bytes or Sized name is an ArgumentException naming the member.
public class DictRepackTests
{
    private sealed class Item
    {
        public byte? A { get; set; }
        public byte? B { get; set; }
    }

    private sealed class Holder
    {
        public Item? Item { get; set; }
        public byte Q { get; set; }
        public byte? A { get; set; }
        public byte? B { get; set; }
        public string S { get; set; } = "";
    }

    private sealed class Row
    {
        public List<Holder>? Items { get; set; }
        public Dictionary<string, Holder>? Map { get; set; }
    }

    private sealed class Blob
    {
        public byte N { get; set; }
        public byte[] Raw { get; set; } = [];
        public byte[] Data { get; set; } = [];
    }

    private static string Hex(byte[] raw) => Convert.ToHexString(raw).ToLowerInvariant();

    private static Field[] Members() =>
        [Field.U8<Holder>(0, i => i.A), Field.U8<Holder>(1, i => i.B)];

    private static Field Element(bool anchored) => anchored
        ? Field.Group(0, (Holder h) => h.Q, Members())
        : Field.Group((Holder h) => h.Item, Field.U8<Item>(0, i => i.A), Field.U8<Item>(1, i => i.B));

    private static Scheme<Row> Listed(bool anchored) => new(1, Field.List((Row x) => x.Items, Element(anchored)));

    private static Scheme<Row> Keyed(bool anchored) => new(1, Field.Dict((Row x) => x.Map, Element(anchored)));

    private static Scheme<Row> Mixed() => new(1, Field.List((Row x) => x.Items,
        Field.Group(0, (Holder h) => h.Q, Field.U8<Holder>(0, i => i.A), Field.Utf8<Holder>(1, i => i.S))));

    private static Scheme<Row> Flagged() => new(1, Field.List((Row x) => x.Items,
        Field.Group(0, (Holder h) => h.Q, Field.Flags(0, Field.U8<Holder>(0, i => i.A), Field.U8<Holder>(1, i => i.B)))));

    [Theory]
    [InlineData(false)]
    [InlineData(true)]
    public void Ac1_Pack_ReadOfAListOfGroups_GivesTheOriginalBytes(bool anchored)
    {
        // Arrange
        var scheme = Listed(anchored);
        var packet = Convert.FromHexString("01" + "0200" + "0102" + "0304");

        // Act
        var read = BinaryPacker.Read(scheme, packet);
        var again = BinaryPacker.Pack(scheme, read.Values);

        // Assert
        Assert.Null(read.Error);
        Assert.Equal(Hex(packet), Hex(again));
    }

    [Theory]
    [InlineData(false)]
    [InlineData(true)]
    public void Ac1_Pack_ReadOfADictOfGroups_GivesTheOriginalBytes(bool anchored)
    {
        // Arrange
        var scheme = Keyed(anchored);
        var packet = Convert.FromHexString("01" + "0200" + "021078" + "0102" + "021079" + "0304");

        // Act
        var read = BinaryPacker.Read(scheme, packet);
        var again = BinaryPacker.Pack(scheme, read.Values);

        // Assert
        Assert.Null(read.Error);
        Assert.Equal(Hex(packet), Hex(again));
    }

    [Fact]
    public void Ac1_Pack_ReadOfGroupsHoldingAStringAndFlags_GivesTheOriginalBytes()
    {
        // Arrange
        var strings = Convert.FromHexString("01" + "0100" + "07" + "022aaa");
        var flagged = Convert.FromHexString("01" + "0200" + "030102" + "0107");

        // Act
        var first = BinaryPacker.Pack(Mixed(), BinaryPacker.Read(Mixed(), strings).Values);
        var second = BinaryPacker.Pack(Flagged(), BinaryPacker.Read(Flagged(), flagged).Values);

        // Assert
        Assert.Equal(Hex(strings), Hex(first));
        Assert.Equal(Hex(flagged), Hex(second));
    }

    [Fact]
    public void Ac2_Pack_RepackOfEveryUnpackedRandomPacket_EqualsItOrFailsAsTheUnpackDid()
    {
        // Arrange
        var random = new Random(2310);
        (string Name, Scheme<Row> Scheme)[] schemes =
            [("list", Listed(false)), ("anchored list", Listed(true)), ("dict", Keyed(false)), ("anchored dict", Keyed(true)), ("mixed", Mixed()), ("flagged", Flagged())];
        byte[] alphabet = [0, 0, 0, 1, 1, 2, 2, 3, 7, 0x61, 0x62];
        var unpacked = 0;

        foreach (var (name, scheme) in schemes)
        {
            var perScheme = 0;
            for (var i = 0; i < 60000; i++)
            {
                var packet = new byte[random.Next(1, 24)];
                packet[0] = 1;
                for (var j = 1; j < packet.Length; j++)
                    packet[j] = alphabet[random.Next(alphabet.Length)];

                // Act
                var read = BinaryPacker.Read(scheme, packet);
                if (read.Error is not null)
                    continue;
                perScheme++;
                var again = BinaryPacker.Pack(scheme, read.Values);
                var third = BinaryPacker.Pack(scheme, BinaryPacker.Read(scheme, again).Values);

                // Assert
                Assert.True(Hex(again) == Hex(third), $"{name}: {Hex(packet)} -> {Hex(again)} -> {Hex(third)}");
                if (name is "list" or "anchored list")
                    Assert.True(Hex(packet) == Hex(again), $"{name}: {Hex(packet)} -> {Hex(again)}");
            }

            Assert.True(perScheme > 50, $"{name}: only {perScheme} packets unpacked");
            unpacked += perScheme;
        }
    }

    [Theory]
    [InlineData("bytes", false)]
    [InlineData("sized", false)]
    [InlineData("bytes", true)]
    [InlineData("sized", true)]
    public void Ac3_Pack_IntForBytesOrSized_ThrowsArgumentExceptionNamingTheMember(string kind, bool inRound)
    {
        // Arrange
        var member = kind == "bytes" ? "Raw" : "Data";
        Field[] body = kind == "bytes"
            ? [Field.Bytes<Blob>(0, x => x.Raw, 2)]
            : [Field.U8<Blob>(0, x => x.N), Field.Sized<Blob>(1, x => x.Data, 0)];
        var scheme = new Scheme<Blob>(1, inRound ? [Field.Repeat(0, body)] : body);
        var two = new byte[] { 1, 2 };
        var values = new Dictionary<string, object?>
        {
            ["N"] = inRound ? new object?[] { (byte)2, (byte)2 } : (byte)2,
            [member] = inRound ? new object?[] { two, 7 } : 7,
        };

        // Act
        var error = Assert.Throws<ArgumentException>(() => BinaryPacker.Pack(scheme, values));

        // Assert
        Assert.Contains($"{member}:", error.Message, StringComparison.Ordinal);
        Assert.Contains("Int32", error.Message, StringComparison.Ordinal);
    }

    [Fact]
    public void Ac4_Pack_ByteArraysForBytesAndSized_KeepTheirBytes()
    {
        // Arrange
        var scheme = new Scheme<Blob>(1,
            Field.Bytes<Blob>(0, x => x.Raw, 2),
            Field.U8<Blob>(1, x => x.N),
            Field.Sized<Blob>(2, x => x.Data, 1));

        // Act
        var raw = BinaryPacker.Pack(scheme, new Dictionary<string, object?> { ["Raw"] = new byte[] { 1, 2 }, ["N"] = (byte)1, ["Data"] = new byte[] { 9 } });

        // Assert
        Assert.Equal("010102010 9".Replace(" ", ""), Hex(raw));
    }
}
