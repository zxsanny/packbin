using Packbin;

namespace Packbin.Tests;

// The rows of fixtures/ecc/percent-vectors.txt (reference scripts/ecc/eccfmt.py, contract message-ecc 1.1.0).
public class EccPercentVectorTests
{
    private sealed record Vector(string Kind, string Id, string[] Args);

    private static readonly Lazy<List<Vector>> Loaded = new(Load);

    private static List<Vector> Load()
    {
        var rows = new List<Vector>();
        foreach (var line in File.ReadAllLines(TextVectors.RepositoryFile("fixtures", "ecc", "percent-vectors.txt")))
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

    public static IEnumerable<object[]> PctRows() => Ids("pct");
    public static IEnumerable<object[]> EncpRows() => Ids("encp");
    public static IEnumerable<object[]> InvRows() => Ids("inv");
    public static IEnumerable<object[]> LimpRows() => Ids("limp");
    public static IEnumerable<object[]> FixpRows() => Ids("fixp");
    public static IEnumerable<object[]> BadpRows() => Ids("badp");
    public static IEnumerable<object[]> ParpRows() => Ids("parp");
    public static IEnumerable<object[]> LmtpRows() => Ids("lmtp");

    private static Vector Find(string id) => Loaded.Value.Single(r => r.Id == id);

    private static string Empty(string hex) => hex == "-" ? "" : hex;

    [Fact]
    public void Vectors_CoverEveryRowKind()
    {
        // Arrange
        var kinds = new[] { "pct", "encp", "inv", "limp", "fixp", "badp", "parp", "lmtp" };

        // Act
        var counts = kinds.Select(k => Loaded.Value.Count(r => r.Kind == k)).ToArray();

        // Assert
        Assert.All(counts, c => Assert.True(c > 0));
        Assert.Equal(Loaded.Value.Count, counts.Sum());
    }

    [Theory]
    [MemberData(nameof(PctRows))]
    public void Pct_TheCountOfThatLengthIsTheRow(string id)
    {
        // Arrange
        var row = Find(id);

        // Act
        var n = Ecc.ParityCount(int.Parse(row.Args[0]), int.Parse(row.Args[1]));

        // Assert
        Assert.Equal(int.Parse(row.Args[2]), n);
    }

    [Theory]
    [MemberData(nameof(EncpRows))]
    public void Encp_ProtectUnderThePercentageEqualsTheRow(string id)
    {
        // Arrange
        var row = Find(id);

        // Act
        var protectedBytes = Ecc.ProtectPercent(EccFixture.Bytes(row.Args[1]), int.Parse(row.Args[0]));

        // Assert
        Assert.Equal(Empty(row.Args[2]), EccFixture.Hex(protectedBytes));
    }

    [Theory]
    [MemberData(nameof(InvRows))]
    public void Inv_TheClearLengthOfASentLengthIsTheRow(string id)
    {
        // Arrange
        var row = Find(id);
        var expected = row.Args[2] == "none" ? -1 : int.Parse(row.Args[2]);

        // Act
        var length = Ecc.ClearLength(int.Parse(row.Args[0]), int.Parse(row.Args[1]));

        // Assert
        Assert.Equal(expected, length);
    }

    [Theory]
    [MemberData(nameof(LimpRows))]
    public void Limp_ProtectOfZeroBytesIsOkOrRefused(string id)
    {
        // Arrange
        var row = Find(id);
        var p = int.Parse(row.Args[0]);
        var size = int.Parse(row.Args[1]);

        // Act
        var attempt = Record.Exception(() => Ecc.ProtectPercent(new byte[size], p));

        // Assert
        if (row.Args[2] == "ok")
        {
            Assert.Null(attempt);
            return;
        }
        var refused = Assert.IsType<ArgumentException>(attempt);
        Assert.Contains($"{size} bytes", refused.Message, StringComparison.Ordinal);
        Assert.Contains($"{Ecc.LargestClear(p)} bytes", refused.Message, StringComparison.Ordinal);
    }

    [Theory]
    [MemberData(nameof(FixpRows))]
    public void Fixp_RepairUnderThePercentageReturnsTheClearAndTheCount(string id)
    {
        // Arrange
        var row = Find(id);
        var received = EccFixture.Bytes(row.Args[2]);

        // Act
        var error = Ecc.RepairPercent(
            received, int.Parse(row.Args[0]), int.Parse(row.Args[1]), out var word, out var repaired, out var parity);

        // Assert
        Assert.Null(error);
        Assert.Equal(Empty(row.Args[3]), EccFixture.Hex(word[..(word.Length - parity)]));
        Assert.Equal(int.Parse(row.Args[4]), repaired);
    }

    [Theory]
    [MemberData(nameof(BadpRows))]
    public void Badp_RepairUnderThePercentageIsRefusedWithTheKindOfTheRow(string id)
    {
        // Arrange
        var row = Find(id);
        var received = EccFixture.Bytes(row.Args[2]);

        // Act
        var error = Ecc.RepairPercent(
            received, int.Parse(row.Args[0]), int.Parse(row.Args[1]), out _, out var repaired, out _);

        // Assert
        Assert.Equal(0, repaired);
        switch (row.Args[3])
        {
            case "uncorrectable":
                Assert.IsType<Uncorrectable>(error);
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
    [MemberData(nameof(ParpRows))]
    public void Parp_APercentageOutsideTheRangeIsNotBuiltAndACountIsReplaced(string id)
    {
        // Arrange
        var row = Find(id);
        var p = int.Parse(row.Args[0]);
        var n = int.Parse(row.Args[1]);
        var counted = EccFixture.Position.WithParity(n);

        // Act
        var attempt = Record.Exception(() => counted.WithParityPercent(p));

        // Assert
        if (p is < 0 or > 100)
        {
            var refused = Assert.IsType<ArgumentOutOfRangeException>(attempt);
            Assert.Contains($"p = {p}", refused.Message, StringComparison.Ordinal);
            Assert.Contains("100", refused.Message, StringComparison.Ordinal);
            return;
        }
        // The public setters cannot declare both in one constructor: the later one replaces the earlier.
        Assert.Null(attempt);
        var replaced = counted.WithParityPercent(p);
        Assert.Equal(0, replaced.Parity);
        Assert.Equal(p, replaced.ParityPercent);
    }

    [Theory]
    [MemberData(nameof(LmtpRows))]
    public void Lmtp_ALimitOutsideZeroToSixteenIsRefusedBeforeAnyByteIsRead(string id)
    {
        // Arrange
        var t = int.Parse(Find(id).Args[0]);
        var scheme = EccFixture.Position.WithParityPercent(25);
        var called = false;

        // Act
        var refused = Assert.Throws<ArgumentOutOfRangeException>(
            () => BinaryPacker.Unpack(new byte[17], t, out _, scheme.On(_ => called = true)));

        // Assert
        Assert.False(called);
        Assert.Contains($"{t}", refused.Message, StringComparison.Ordinal);
        Assert.Contains("0..16", refused.Message, StringComparison.Ordinal);
    }
}
