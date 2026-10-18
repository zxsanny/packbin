using Packbin;

namespace Packbin.Tests;

// The rows of fixtures/ecc/vectors.txt (reference scripts/ecc/eccfmt.py, contract message-ecc 1.0.0), at the codec level.
public class EccVectorTests
{
    private sealed record Vector(string Kind, string Id, string[] Args);

    private static readonly Lazy<List<Vector>> Loaded = new(Load);

    private static List<Vector> Load()
    {
        var rows = new List<Vector>();
        foreach (var line in File.ReadAllLines(TextVectors.RepositoryFile("fixtures", "ecc", "vectors.txt")))
        {
            if (line.Length == 0 || line[0] == '#')
                continue;
            var parts = line.Split(' ');
            rows.Add(new Vector(parts[0], parts[1], parts[2..]));
        }
        return rows;
    }

    public static IEnumerable<object[]> Ids(params string[] kinds) =>
        Loaded.Value.Where(r => kinds.Contains(r.Kind)).Select(r => new object[] { r.Id });

    public static IEnumerable<object[]> EncRows() => Ids("enc");
    public static IEnumerable<object[]> FixRows() => Ids("fix");
    public static IEnumerable<object[]> BadRows() => Ids("bad");
    public static IEnumerable<object[]> LimRows() => Ids("lim");
    public static IEnumerable<object[]> ParRows() => Ids("par");
    public static IEnumerable<object[]> LmtRows() => Ids("lmt");

    private static Vector Find(string id) => Loaded.Value.Single(r => r.Id == id);

    [Fact]
    public void Vectors_CoverEveryRowKind()
    {
        // Arrange
        var kinds = new[] { "enc", "fix", "bad", "lim", "par", "lmt" };

        // Act
        var counts = kinds.Select(k => Loaded.Value.Count(r => r.Kind == k)).ToArray();

        // Assert
        Assert.All(counts, c => Assert.True(c > 0));
        Assert.Equal(Loaded.Value.Count, counts.Sum());
        Assert.True(Loaded.Value.Count >= 100);
    }

    [Theory]
    [MemberData(nameof(EncRows))]
    public void Enc_ProtectEqualsTheRow(string id)
    {
        // Arrange
        var row = Find(id);
        var n = int.Parse(row.Args[0]);
        var clear = EccFixture.Bytes(row.Args[1]);

        // Act
        var protectedBytes = Ecc.Protect(clear, n);

        // Assert
        Assert.Equal(row.Args[2] == "-" ? "" : row.Args[2], EccFixture.Hex(protectedBytes));
    }

    [Theory]
    [MemberData(nameof(FixRows))]
    public void Fix_RepairReturnsTheClearAndTheCount(string id)
    {
        // Arrange
        var row = Find(id);
        var n = int.Parse(row.Args[0]);
        var t = int.Parse(row.Args[1]);
        var received = EccFixture.Bytes(row.Args[2]);

        // Act
        var error = Ecc.Repair(received, n, t, out var word, out var repaired);

        // Assert
        Assert.Null(error);
        Assert.Equal(row.Args[3] == "-" ? "" : row.Args[3], EccFixture.Hex(word[..(word.Length - n)]));
        Assert.Equal(int.Parse(row.Args[4]), repaired);
    }

    [Theory]
    [MemberData(nameof(BadRows))]
    public void Bad_RepairIsRefusedWithTheKindOfTheRow(string id)
    {
        // Arrange
        var row = Find(id);
        var n = int.Parse(row.Args[0]);
        var t = int.Parse(row.Args[1]);
        var received = EccFixture.Bytes(row.Args[2]);

        // Act
        var error = Ecc.Repair(received, n, t, out _, out var repaired);

        // Assert
        Assert.Equal(0, repaired);
        switch (row.Args[3])
        {
            case "uncorrectable":
                Assert.IsType<Uncorrectable>(error);
                break;
            case "short":
                var shortPacket = Assert.IsType<ShortPacket>(error);
                Assert.Equal("parity", shortPacket.Field);
                Assert.Equal(n, shortPacket.Needed);
                Assert.Equal(received.Length, shortPacket.Left);
                break;
            case "too_long":
                var tooLong = Assert.IsType<TooLong>(error);
                Assert.Equal(received.Length, tooLong.Length);
                Assert.Equal(254, tooLong.Limit);
                break;
            default:
                Assert.Fail($"unknown kind {row.Args[3]}");
                break;
        }
    }

    [Theory]
    [MemberData(nameof(LimRows))]
    public void Lim_ProtectOfZeroBytesIsOkOrRefused(string id)
    {
        // Arrange
        var row = Find(id);
        var n = int.Parse(row.Args[0]);
        var size = int.Parse(row.Args[1]);

        // Act
        var attempt = Record.Exception(() => Ecc.Protect(new byte[size], n));

        // Assert
        if (row.Args[2] == "ok")
        {
            Assert.Null(attempt);
            return;
        }
        var refused = Assert.IsType<ArgumentException>(attempt);
        Assert.Contains($"{size} bytes", refused.Message, StringComparison.Ordinal);
        Assert.Contains($"{254 - n} bytes", refused.Message, StringComparison.Ordinal);
    }

    [Theory]
    [MemberData(nameof(ParRows))]
    public void Par_ASchemeWithThatParityIsNotBuilt(string id)
    {
        // Arrange
        var n = int.Parse(Find(id).Args[0]);
        var scheme = EccFixture.Position;

        // Act
        var refused = Assert.Throws<ArgumentOutOfRangeException>(() => scheme.WithParity(n));

        // Assert
        Assert.Contains($"n = {n}", refused.Message, StringComparison.Ordinal);
        Assert.Contains("32", refused.Message, StringComparison.Ordinal);
    }

    [Theory]
    [MemberData(nameof(LmtRows))]
    public void Lmt_ALimitAboveHalfTheParityIsRefusedBeforeAnyByteIsRead(string id)
    {
        // Arrange
        var row = Find(id);
        var n = int.Parse(row.Args[0]);
        var t = int.Parse(row.Args[1]);
        var scheme = EccFixture.Position.WithParity(n);
        var called = false;

        // Act
        var refused = Assert.Throws<ArgumentOutOfRangeException>(
            () => BinaryPacker.Unpack(new byte[n], t, out _, scheme.On(_ => called = true)));

        // Assert
        Assert.False(called);
        Assert.Contains($"{t}", refused.Message, StringComparison.Ordinal);
        Assert.Contains($"0..{n / 2}", refused.Message, StringComparison.Ordinal);
    }
}
