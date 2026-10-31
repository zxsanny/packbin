using Packbin;

namespace Packbin.Tests;

// AZ-3502: the parity percentage in the scheme, pack, unpack, repair limit and dispatch (contract message-ecc 1.1.0).
public class EccPercentTests
{
    // Independent of Ecc.ParityCount: the count by a ceiling division of exact products.
    private static int Count(int p, int length)
    {
        var exact = (long)p * length;
        var n = (int)(exact / 100 + (exact % 100 == 0 ? 0 : 1));
        return n > 32 ? 32 : n;
    }

    private static int Largest(int p)
    {
        var length = 0;
        while (length + 1 + Count(p, length + 1) <= 254)
            length++;
        return length;
    }

    private static byte[] Fill(int length, Random random)
    {
        var bytes = new byte[length];
        random.NextBytes(bytes);
        return bytes;
    }

    [Fact]
    public void Setter_ReportsThePercentageAndTheLastSetterWins()
    {
        // Arrange
        var scheme = EccFixture.Position;

        // Act
        var percent = scheme.WithParityPercent(25);
        var counted = percent.WithParity(4);
        var replaced = counted.WithParityPercent(10);
        var kept = percent.WithLimits(10, 10, 1000);

        // Assert
        Assert.Equal(0, scheme.ParityPercent);
        Assert.Equal((0, 25), (percent.Parity, percent.ParityPercent));
        Assert.Equal((4, 0), (counted.Parity, counted.ParityPercent));
        Assert.Equal((0, 10), (replaced.Parity, replaced.ParityPercent));
        Assert.Equal((0, 25), (kept.Parity, kept.ParityPercent));
        Assert.Equal(25, scheme.WithParityPercent(25).WithLimits().ParityPercent);
        Assert.Equal(4, scheme.WithParity(4).WithLimits().Parity);
    }

    [Theory]
    [InlineData(-1)]
    [InlineData(101)]
    public void Setter_APercentageOutsideZeroToHundredIsRefusedNamingItAndTheLimit(int p)
    {
        // Arrange
        var scheme = EccFixture.Position;

        // Act
        var refused = Assert.Throws<ArgumentOutOfRangeException>(() => scheme.WithParityPercent(p));

        // Assert
        Assert.Contains($"p = {p}", refused.Message, StringComparison.Ordinal);
        Assert.Contains("100", refused.Message, StringComparison.Ordinal);
    }

    [Fact]
    public void Pack_TheCountAndTheBytesAreThoseOfTheFixedCountScheme()
    {
        // Arrange
        var random = new Random(3502);
        var pairs = 0;

        // Act / Assert
        foreach (var p in new[] { 0, 10, 25, 50, 100 })
        {
            foreach (var length in new[] { 1, 3, 10, 40, 100, 222 })
            {
                var row = EccFixture.BlobOf(length);
                random.NextBytes(row.Data);
                var percent = BinaryPacker.Pack(EccFixture.Blob(length).WithParityPercent(p), row);
                var fixedCount = BinaryPacker.Pack(EccFixture.Blob(length).WithParity(Count(p, length)), row);
                Assert.Equal(length + Count(p, length), percent.Length);
                Assert.Equal(fixedCount, percent);
                pairs++;
            }
        }
        Assert.Equal(30, pairs);
    }

    [Fact]
    public void Pack_PercentageZeroSendsTheClearBytesOnlyWithNoLimit()
    {
        // Arrange
        var scheme = EccFixture.Blob(300).WithParityPercent(0);

        // Act
        var sent = BinaryPacker.Pack(scheme, EccFixture.BlobOf(300));

        // Assert
        Assert.Equal(300, sent.Length);
    }

    [Theory]
    [InlineData(1, 251)]
    [InlineData(10, 230)]
    [InlineData(25, 222)]
    [InlineData(50, 222)]
    [InlineData(100, 222)]
    public void Pack_OneByteAboveTheLargestClearLengthIsRefused(int p, int largest)
    {
        // Arrange
        var fits = EccFixture.Blob(largest).WithParityPercent(p);
        var over = EccFixture.Blob(largest + 1).WithParityPercent(p);

        // Act
        var sent = BinaryPacker.Pack(fits, EccFixture.BlobOf(largest));
        var refused = Assert.Throws<ArgumentException>(() => BinaryPacker.Pack(over, EccFixture.BlobOf(largest + 1)));

        // Assert
        Assert.Equal(largest, Largest(p));
        Assert.True(sent.Length <= 254);
        Assert.Contains($"{largest + 1} bytes", refused.Message, StringComparison.Ordinal);
        Assert.Contains($"{largest} bytes", refused.Message, StringComparison.Ordinal);
    }

    [Fact]
    public void Codec_EveryPercentageAndLengthRoundTripsWithRepairedCountZero()
    {
        // Arrange
        var random = new Random(22752);
        var pairs = 0;

        // Act / Assert
        for (var p = 0; p <= 100; p++)
        {
            var largest = p == 0 ? 254 : Largest(p);
            for (var length = 0; length <= largest; length++)
            {
                var clear = Fill(length, random);
                var sent = Ecc.ProtectPercent(clear, p);
                Assert.Equal(length + (p == 0 ? 0 : Count(p, length)), sent.Length);

                var error = Ecc.RepairPercent(sent, p, 0, out var word, out var repaired, out var parity);

                Assert.Null(error);
                Assert.Equal(0, repaired);
                Assert.Equal(sent.Length - length, parity);
                Assert.Equal(clear, word[..length]);
                pairs++;
            }
        }
        Assert.Equal(22_752, pairs);
    }

    [Fact]
    public void Unpack_ALengthNoClearLengthGivesIsUncorrectableAndAbove254IsTooLong()
    {
        // Arrange
        var missing = new Dictionary<int, int> { [1] = 3, [10] = 24, [25] = 32, [50] = 32, [100] = 32 };

        // Act / Assert
        foreach (var (p, expected) in missing)
        {
            var refused = 0;
            for (var size = 0; size <= 254; size++)
            {
                var error = Ecc.RepairPercent(new byte[size], p, 0, out _, out var repaired, out _);
                if (Ecc.ClearLength(p, size) >= 0)
                    continue;
                Assert.IsType<Uncorrectable>(error);
                Assert.Equal(0, repaired);
                refused++;
            }
            Assert.Equal(expected, refused);
            var tooLong = Assert.IsType<TooLong>(Ecc.RepairPercent(new byte[255], p, 0, out _, out _, out _));
            Assert.Equal((255, 254), (tooLong.Length, tooLong.Limit));
        }
        var scheme = EccFixture.Position.WithParityPercent(100);
        Assert.IsType<Uncorrectable>(EccFixture.Unpack(new byte[3], scheme, 0).Error);
    }

    [Theory]
    [InlineData(50, 10)]
    [InlineData(25, 5)]
    public void Unpack_ACorruptionUpToTheLimitIsRepairedWithTheCountOfThatMessage(int p, int wrong)
    {
        // Arrange
        var scheme = EccFixture.Blob(40).WithParityPercent(p);
        var random = new Random(p);
        var row = EccFixture.BlobOf(40);
        random.NextBytes(row.Data);
        var sent = BinaryPacker.Pack(scheme, row);
        EccFixture.Corrupt(sent, wrong, random);
        BlobRowHolder got = new();

        // Act
        var error = BinaryPacker.Unpack(sent, wrong, out var repaired, scheme.On(r => got.Row = r));

        // Assert
        Assert.Null(error);
        Assert.Equal(wrong, repaired);
        Assert.Equal(row.Data, got.Row!.Data);
    }

    [Theory]
    [InlineData(50, 10, 11)]
    [InlineData(50, 0, 20)]
    public void Unpack_ACorruptionAboveTheLimitIsRefusedForTheSeededPattern(int p, int limit, int wrong)
    {
        // Arrange
        var scheme = EccFixture.Blob(40).WithParityPercent(p);
        var refusals = 0;

        // Act
        for (var seed = 0; seed < 50; seed++)
        {
            var random = new Random(seed);
            var sent = BinaryPacker.Pack(scheme, EccFixture.BlobOf(40));
            EccFixture.Corrupt(sent, wrong, random);
            if (BinaryPacker.Unpack(sent, limit, out _, scheme.On(_ => { })) is Uncorrectable)
                refusals++;
        }

        // Assert
        Assert.True(refusals >= 49, $"{refusals} of 50 refused");
    }

    [Fact]
    public void Unpack_ALimitAboveHalfTheCountBehavesAsHalfTheCount()
    {
        // Arrange
        var scheme = EccFixture.Blob(40).WithParityPercent(25);
        var five = new List<object?>();
        var sixteen = new List<object?>();

        // Act
        for (var seed = 0; seed < 200; seed++)
        {
            var sent = BinaryPacker.Pack(scheme, EccFixture.BlobOf(40));
            EccFixture.Corrupt(sent, 3 + seed % 5, new Random(seed));
            five.Add(Describe(BinaryPacker.Unpack(sent, 5, out var a, scheme.On(_ => { })), a));
            sixteen.Add(Describe(BinaryPacker.Unpack(sent, 16, out var b, scheme.On(_ => { })), b));
        }

        // Assert
        Assert.Equal(five, sixteen);
        Assert.Contains(five, d => (string?)d == "Uncorrectable");
        Assert.Contains(five, d => (string?)d == "repaired 5");
    }

    private static string Describe(object? error, int repaired) => error?.GetType().Name ?? $"repaired {repaired}";

    [Fact]
    public void Unpack_AFixedCountSchemeKeepsItsExactLimitRule()
    {
        // Arrange
        var scheme = EccFixture.Position.WithParity(4);

        // Act
        var refused = Assert.Throws<ArgumentOutOfRangeException>(
            () => BinaryPacker.Unpack(new byte[17], 3, out _, scheme.On(_ => { })));

        // Assert
        Assert.Contains("0..2", refused.Message, StringComparison.Ordinal);
    }

    [Fact]
    public void Dispatch_HandlersOfOnePercentageDispatchAfterTheRepair()
    {
        // Arrange
        var first = EccFixture.Positions(0x40).WithParityPercent(25);
        var second = EccFixture.Positions(0x41).WithParityPercent(25);
        EccFixture.PositionRow? got = null;
        var sent = BinaryPacker.Pack(second, EccFixture.Row);
        sent[3] ^= 0x55;

        // Act
        var error = BinaryPacker.Unpack(sent, 2, out var repaired, first.On(_ => { }), second.On(r => got = r));

        // Assert
        Assert.Null(error);
        Assert.Equal(1, repaired);
        Assert.True(EccFixture.IsRow(got));
    }

    [Fact]
    public void Dispatch_AMixOfPercentagesOrOfAPercentageAndACountIsRefusedBeforeAnyByteIsRead()
    {
        // Arrange
        var called = false;
        var p25 = EccFixture.Positions(0x40).WithParityPercent(25).On(_ => called = true);
        var p50 = EccFixture.Positions(0x41).WithParityPercent(50).On(_ => called = true);
        var counted = EccFixture.Positions(0x42).WithParity(4).On(_ => called = true);

        // Act
        var twoPercents = Assert.Throws<ArgumentException>(() => BinaryPacker.Unpack(new byte[20], 0, out _, p25, p50));
        var percentAndCount = Assert.Throws<ArgumentException>(() => BinaryPacker.Unpack(new byte[20], 0, out _, p25, counted));

        // Assert
        Assert.False(called);
        Assert.Contains("25", twoPercents.Message, StringComparison.Ordinal);
        Assert.Contains("50", twoPercents.Message, StringComparison.Ordinal);
        Assert.Contains("25", percentAndCount.Message, StringComparison.Ordinal);
    }

    private sealed class BlobRowHolder
    {
        public EccFixture.BlobRow? Row { get; set; }
    }
}
