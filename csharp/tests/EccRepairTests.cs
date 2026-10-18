using System.Diagnostics;
using Packbin;

namespace Packbin.Tests;

// AZ-2682: repair, refusal, hostile bytes and speed of the C# message ECC (EC-5 to EC-8, EC-13).
public class EccRepairTests
{
    [Fact]
    public void Unpack_NTwoOneWrongByteAtAnyPositionWithAnyValue_RecoversTheRow()
    {
        // Arrange
        var scheme = EccFixture.Position.WithParity(2);
        var clean = BinaryPacker.Pack(scheme, EccFixture.Row);
        var recovered = 0;
        var wrongRows = 0;

        // Act
        for (var p = 0; p < clean.Length; p++)
        {
            for (var flip = 1; flip < 256; flip++)
            {
                var message = (byte[])clean.Clone();
                message[p] ^= (byte)flip;
                var (error, row, repaired) = EccFixture.Unpack(message, scheme, 1);
                if (error is null && EccFixture.IsRow(row) && repaired == 1)
                    recovered++;
                else
                    wrongRows++;
            }
        }

        // Assert
        Assert.Equal(15 * 255, recovered);
        Assert.Equal(0, wrongRows);
    }

    [Theory]
    [InlineData(4)]
    [InlineData(8)]
    [InlineData(16)]
    public void Unpack_UpToHalfTheParityWrongBytes_RecoversTheRowInAThousandSeededCases(int n)
    {
        // Arrange
        var scheme = EccFixture.Position.WithParity(n);
        var clean = BinaryPacker.Pack(scheme, EccFixture.Row);
        var random = new Random(n);
        var failures = 0;

        // Act
        for (var i = 0; i < 1000; i++)
        {
            var wrong = random.Next(1, n / 2 + 1);
            var message = (byte[])clean.Clone();
            EccFixture.Corrupt(message, wrong, random);
            var (error, row, repaired) = EccFixture.Unpack(message, scheme, n / 2);
            if (error is not null || !EccFixture.IsRow(row) || repaired != wrong)
                failures++;
        }

        // Assert
        Assert.Equal(0, failures);
    }

    [Theory]
    [InlineData(1)]
    [InlineData(2)]
    [InlineData(4)]
    [InlineData(8)]
    [InlineData(16)]
    [InlineData(32)]
    public void Unpack_AnIntactMessage_ReturnsTheRowAndZeroRepaired(int n)
    {
        // Arrange
        var scheme = EccFixture.Position.WithParity(n);
        var clean = BinaryPacker.Pack(scheme, EccFixture.Row);

        // Act
        var (error, row, repaired) = EccFixture.Unpack(clean, scheme, n / 2);

        // Assert
        Assert.Null(error);
        Assert.True(EccFixture.IsRow(row));
        Assert.Equal(0, repaired);
    }

    [Fact]
    public void Unpack_NFourLimitOneWithTwoOrThreeWrongBytes_IsRefusedInTenThousandSeededCases()
    {
        // Arrange
        var scheme = EccFixture.Position.WithParity(4);
        var clean = BinaryPacker.Pack(scheme, EccFixture.Row);
        var random = new Random(61);
        var wrongRows = 0;
        var refused = 0;

        // Act
        for (var i = 0; i < 10_000; i++)
        {
            var message = (byte[])clean.Clone();
            EccFixture.Corrupt(message, random.Next(2, 4), random);
            var (error, row, _) = EccFixture.Unpack(message, scheme, 1);
            if (error is Uncorrectable && row is null)
                refused++;
            if (row is not null)
                wrongRows++;
        }

        // Assert
        Assert.Equal(10_000, refused);
        Assert.Equal(0, wrongRows);
    }

    [Fact]
    public void Unpack_NFourDetectOnlyWithOneToFourWrongBytes_IsRefusedInTenThousandSeededCases()
    {
        // Arrange
        var scheme = EccFixture.Position.WithParity(4);
        var clean = BinaryPacker.Pack(scheme, EccFixture.Row);
        var random = new Random(62);
        var wrongRows = 0;
        var refused = 0;

        // Act
        for (var i = 0; i < 10_000; i++)
        {
            var message = (byte[])clean.Clone();
            EccFixture.Corrupt(message, random.Next(1, 5), random);
            var (error, row, _) = EccFixture.Unpack(message, scheme, 0);
            if (error is Uncorrectable && row is null)
                refused++;
            if (row is not null)
                wrongRows++;
        }

        // Assert
        Assert.Equal(10_000, refused);
        Assert.Equal(0, wrongRows);
    }

    [Fact]
    public void Unpack_ReportRows8To10_RepairTwoBytesOnlyWhenTheLimitAllowsIt()
    {
        // Arrange
        var scheme = EccFixture.Position.WithParity(4);
        var damaged = EccFixture.Bytes("40015a0065cd1d00a322110100ca856682");

        // Act
        var repairedRow = EccFixture.Unpack(damaged, scheme, 2);
        var limitOne = EccFixture.Unpack(damaged, scheme, 1);
        var detectOnly = EccFixture.Unpack(damaged, scheme, 0);

        // Assert
        Assert.Null(repairedRow.Error);
        Assert.True(EccFixture.IsRow(repairedRow.Row));
        Assert.Equal(2, repairedRow.Repaired);
        Assert.IsType<Uncorrectable>(limitOne.Error);
        Assert.Null(limitOne.Row);
        Assert.IsType<Uncorrectable>(detectOnly.Error);
        Assert.Null(detectOnly.Row);
    }

    [Fact]
    public void Unpack_RandomBuffersOfTheFixtureLengthUnderNTwoDetectOnly_AcceptAtMostTwelveOfTwoHundredThousand()
    {
        // Arrange
        var scheme = EccFixture.Position.WithParity(2);
        var random = new Random(7);
        var buffer = new byte[15];
        var accepted = 0;

        // Act
        for (var i = 0; i < 200_000; i++)
        {
            random.NextBytes(buffer);
            if (BinaryPacker.Unpack(buffer, 0, out _, scheme.On(_ => { })) is not Uncorrectable)
                accepted++;
        }

        // Assert
        Assert.InRange(accepted, 0, 12);
    }

    [Theory]
    [InlineData(1, 0)]
    [InlineData(2, 1)]
    [InlineData(4, 2)]
    [InlineData(16, 8)]
    [InlineData(32, 16)]
    public void Unpack_HostileBuffersOfAnyLength_NeverThrowAndNeverRunAHandlerOnAnUncorrectableError(int n, int limit)
    {
        // Arrange
        var scheme = EccFixture.Position.WithParity(n);
        var random = new Random(n * 100 + limit);
        var handlerRuns = 0;

        // Act
        var attempt = Record.Exception(() =>
        {
            for (var i = 0; i < 3000; i++)
            {
                var buffer = new byte[random.Next(0, 300)];
                random.NextBytes(buffer);
                var before = handlerRuns;
                var error = BinaryPacker.Unpack(buffer, limit, out _, scheme.On(_ => handlerRuns++));
                if (error is not null)
                    Assert.Equal(before, handlerRuns);
            }
        });

        // Assert
        Assert.Null(attempt);
    }

    [Fact]
    public void Unpack_ARepairRoundOnA254ByteMessageWithSixteenParityBytes_FinishesAThousandTimesWithinASecond()
    {
        // Arrange
        var scheme = EccFixture.Blob(238).WithParity(16);
        var row = EccFixture.BlobOf(238);
        new Random(13).NextBytes(row.Data);
        var clean = BinaryPacker.Pack(scheme, row);
        var random = new Random(13);
        var damaged = new byte[1000][];
        for (var i = 0; i < damaged.Length; i++)
        {
            damaged[i] = (byte[])clean.Clone();
            EccFixture.Corrupt(damaged[i], 8, random);
        }
        var wrong = 0;
        EccFixture.BlobRow? got = null;
        var handler = scheme.On(v => got = v);
        BinaryPacker.Unpack(damaged[0], 8, out _, handler);

        // Act
        var clock = Stopwatch.StartNew();
        foreach (var message in damaged)
        {
            var error = BinaryPacker.Unpack(message, 8, out var repaired, handler);
            if (error is not null || repaired != 8)
                wrong++;
        }
        clock.Stop();

        // Assert
        Assert.Equal(254, clean.Length);
        Assert.Equal(0, wrong);
        Assert.Equal(row.Data, got!.Data);
        Assert.True(clock.Elapsed < TimeSpan.FromSeconds(1), $"1000 repairs took {clock.Elapsed.TotalSeconds:F3} s");
    }

    [Fact]
    public void Pack_ThousandBlocksOf254BytesWithSixteenParityBytes_FinishWithinASecond()
    {
        // Arrange
        var scheme = EccFixture.Blob(238).WithParity(16);
        var row = EccFixture.BlobOf(238);
        new Random(14).NextBytes(row.Data);
        BinaryPacker.Pack(scheme, row);
        var length = 0;

        // Act
        var clock = Stopwatch.StartNew();
        for (var i = 0; i < 1000; i++)
            length = BinaryPacker.Pack(scheme, row).Length;
        clock.Stop();

        // Assert
        Assert.Equal(254, length);
        Assert.True(clock.Elapsed < TimeSpan.FromSeconds(1), $"1000 packs took {clock.Elapsed.TotalSeconds:F3} s");
    }
}
