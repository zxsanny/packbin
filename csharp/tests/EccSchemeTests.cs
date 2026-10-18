using Packbin;

namespace Packbin.Tests;

// AZ-2682: the scheme setting, the golden protected bytes, the size limit and the dispatch rule (EC-1 to EC-4, EC-8, EC-14, EC-16).
public class EccSchemeTests
{
    // Rows 2 to 6 of the expected results report, and n = 32 from the shared vectors.
    [Theory]
    [InlineData(1, "4001000065cd1d00a3e1110100ab")]
    [InlineData(2, "4001000065cd1d00a3e111010016bd")]
    [InlineData(4, "4001000065cd1d00a3e1110100ca856682")]
    [InlineData(8, "4001000065cd1d00a3e11101006d4f38479f3f2472")]
    [InlineData(16, "4001000065cd1d00a3e11101004ace66ecd5e4a28ffa28098279f5f19d")]
    [InlineData(32, "4001000065cd1d00a3e11101000fd54d3f71511c0d0741bddfa005c231c4aefde998cdf3769550a371d87e005f")]
    public void Pack_WithParity_EqualsTheGoldenProtectedBytes(int n, string expected)
    {
        // Arrange
        var scheme = EccFixture.Position.WithParity(n);

        // Act
        var packed = BinaryPacker.Pack(scheme, EccFixture.Row);

        // Assert
        Assert.Equal(expected, EccFixture.Hex(packed));
        Assert.Equal(13 + n, packed.Length);
    }

    [Fact]
    public void Pack_WithoutParity_IsTheUnchangedGoldenRow()
    {
        // Arrange
        var off = EccFixture.Position.WithParity(0);

        // Act
        var byDefault = BinaryPacker.Pack(EccFixture.Position, EccFixture.Row);
        var explicitZero = BinaryPacker.Pack(off, EccFixture.Row);

        // Assert
        Assert.Equal(0, EccFixture.Position.Parity);
        Assert.Equal(EccFixture.GoldenHex, EccFixture.Hex(byDefault));
        Assert.Equal(EccFixture.GoldenHex, EccFixture.Hex(explicitZero));
    }

    [Fact]
    public void Unpack_WithoutParity_ReadsTheGoldenRowAndReportsNoRepair()
    {
        // Arrange
        var golden = EccFixture.Bytes(EccFixture.GoldenHex);

        // Act
        var (error, row, repaired) = EccFixture.Unpack(golden, EccFixture.Position, 0);

        // Assert
        Assert.Null(error);
        Assert.True(EccFixture.IsRow(row));
        Assert.Equal(0, repaired);
    }

    [Fact]
    public void Unpack_WithoutParityGivenAProtectedMessage_IsTheTrailingBytesError()
    {
        // Arrange
        var protectedBytes = BinaryPacker.Pack(EccFixture.Position.WithParity(4), EccFixture.Row);

        // Act
        var (error, row, _) = EccFixture.Unpack(protectedBytes, EccFixture.Position, 0);

        // Assert
        Assert.Equal(4, Assert.IsType<TrailingBytes>(error).Left);
        Assert.Null(row);
    }

    [Theory]
    [InlineData(33)]
    [InlineData(255)]
    [InlineData(-1)]
    public void WithParity_AboveThirtyTwoOrBelowZero_IsRefusedNamingNAndTheLimit(int n)
    {
        // Arrange
        var scheme = EccFixture.Position;

        // Act
        var refused = Assert.Throws<ArgumentOutOfRangeException>(() => scheme.WithParity(n));

        // Assert
        Assert.Contains($"n = {n}", refused.Message, StringComparison.Ordinal);
        Assert.Contains("32", refused.Message, StringComparison.Ordinal);
    }

    [Fact]
    public void WithParity_KeepsTheLimitsAndWithLimitsKeepsTheParity()
    {
        // Arrange
        var limited = EccFixture.Position.WithLimits(7, 11, 300);

        // Act
        var both = limited.WithParity(4).WithLimits(8, 12, 301);

        // Assert
        Assert.Equal(4, both.Parity);
        Assert.Equal((8, 12L, 301L), (both.MaxRounds, both.MaxSlots, both.MaxBytes));
        Assert.Equal((7, 11L, 300L), (limited.WithParity(2).MaxRounds, limited.WithParity(2).MaxSlots, limited.WithParity(2).MaxBytes));
    }

    // EC-4: n = 32 packs 222 clear bytes and refuses 223; n = 4 refuses 251 against 250 (report row 13).
    [Theory]
    [InlineData(32, 222, true)]
    [InlineData(32, 223, false)]
    [InlineData(4, 250, true)]
    [InlineData(4, 251, false)]
    [InlineData(1, 253, true)]
    [InlineData(1, 254, false)]
    public void Pack_ClearMessageAboveTheLimit_IsRefusedNamingTheLengthAndTheLimit(int n, int clearLength, bool fits)
    {
        // Arrange
        var scheme = EccFixture.Blob(clearLength).WithParity(n);
        var row = EccFixture.BlobOf(clearLength);

        // Act
        var attempt = Record.Exception(() => BinaryPacker.Pack(scheme, row));

        // Assert
        if (fits)
        {
            Assert.Null(attempt);
            return;
        }
        var refused = Assert.IsType<ArgumentException>(attempt);
        Assert.Contains($"{clearLength} bytes", refused.Message, StringComparison.Ordinal);
        Assert.Contains($"{254 - n} bytes", refused.Message, StringComparison.Ordinal);
    }

    [Fact]
    public void Pack_AtTheLimit_WritesAWholeMessageThatUnpacks()
    {
        // Arrange
        var scheme = EccFixture.Blob(222).WithParity(32);
        var row = EccFixture.BlobOf(222);
        row.Data[100] = 0x5a;
        EccFixture.BlobRow? got = null;

        // Act
        var packed = BinaryPacker.Pack(scheme, row);
        var error = BinaryPacker.Unpack(packed, 16, out var repaired, scheme.On(v => got = v));

        // Assert
        Assert.Equal(254, packed.Length);
        Assert.Null(error);
        Assert.Equal(0, repaired);
        Assert.Equal(row.Data, got!.Data);
    }

    [Fact]
    public void Unpack_ABufferAbove254Bytes_IsTooLongWithNoRow()
    {
        // Arrange
        var scheme = EccFixture.Position.WithParity(4);

        // Act
        var (error, row, repaired) = EccFixture.Unpack(new byte[255], scheme, 2);

        // Assert
        var tooLong = Assert.IsType<TooLong>(error);
        Assert.Equal((255, 254), (tooLong.Length, tooLong.Limit));
        Assert.Null(row);
        Assert.Equal(0, repaired);
    }

    [Fact]
    public void Unpack_ShorterThanTheParity_NamesTheParityTheBytesNeededAndPresent()
    {
        // Arrange
        var scheme = EccFixture.Position.WithParity(4);

        // Act
        var (error, row, _) = EccFixture.Unpack(EccFixture.Bytes("400100"), scheme, 0);

        // Assert
        var shortPacket = Assert.IsType<ShortPacket>(error);
        Assert.Equal(("parity", 4, 3), (shortPacket.Field, shortPacket.Needed, shortPacket.Left));
        Assert.Null(row);
    }

    [Fact]
    public void Unpack_OnlyParityBytes_IsTheUnprotectedShortPacketError()
    {
        // Arrange
        var scheme = EccFixture.Position.WithParity(2);

        // Act
        var (error, row, _) = EccFixture.Unpack(new byte[2], scheme, 1);

        // Assert
        var shortPacket = Assert.IsType<ShortPacket>(error);
        Assert.Equal(("", 1, 0), (shortPacket.Field, shortPacket.Needed, shortPacket.Left));
        Assert.Null(row);
    }

    [Theory]
    [InlineData(2, 2)]
    [InlineData(2, -1)]
    [InlineData(0, 1)]
    [InlineData(1, 1)]
    [InlineData(32, 17)]
    public void Unpack_ALimitOutsideZeroToHalfTheParity_IsRefusedBeforeTheBytesAreRead(int n, int limit)
    {
        // Arrange
        var called = false;
        var scheme = EccFixture.Position.WithParity(n);

        // Act
        var attempt = Record.Exception(() => BinaryPacker.Unpack([], limit, out _, scheme.On(_ => called = true)));

        // Assert
        Assert.IsType<ArgumentOutOfRangeException>(attempt);
        Assert.False(called);
    }

    // EC-14: shifting by one byte, or adding and removing a few, is refused.
    [Fact]
    public void Unpack_AMessageShiftedByTrailingZeroOrLastByteRemoved_IsRefused()
    {
        // Arrange
        var scheme = EccFixture.Position.WithParity(4);
        var withZeroParity = FindRowWithLastParityByte(scheme, 0);
        var plain = BinaryPacker.Pack(scheme, EccFixture.Row);

        // Act
        var cases = new[]
        {
            [.. plain, 0],
            plain[..^1],
            [.. withZeroParity, 0],
            withZeroParity[..^1],
            BinaryPacker.Pack(EccFixture.Position, EccFixture.Row),
        };

        // Assert
        Assert.Equal(0, withZeroParity[^1]);
        foreach (var message in cases)
        {
            var (error, row, _) = EccFixture.Unpack(message, scheme, 0);
            Assert.IsType<Uncorrectable>(error);
            Assert.Null(row);
        }
    }

    [Fact]
    public void Unpack_OneToThreeBytesRemovedOrAdded_IsRefusedInTenThousandSeededCases()
    {
        // Arrange
        var scheme = EccFixture.Position.WithParity(4);
        var protectedBytes = BinaryPacker.Pack(scheme, EccFixture.Row);
        var random = new Random(14);
        var wrongRows = 0;

        // Act
        for (var i = 0; i < 10_000; i++)
        {
            var k = random.Next(1, 4);
            byte[] message;
            if (random.Next(2) == 0)
            {
                message = protectedBytes[..^k];
            }
            else
            {
                var extra = new byte[k];
                random.NextBytes(extra);
                message = [.. protectedBytes, .. extra];
            }
            var (error, row, _) = EccFixture.Unpack(message, scheme, 0);
            if (error is null || row is not null)
                wrongRows++;
        }

        // Assert
        Assert.Equal(0, wrongRows);
    }

    private static byte[] FindRowWithLastParityByte(Scheme<EccFixture.PositionRow> scheme, byte last)
    {
        for (var sid = 0; sid <= ushort.MaxValue; sid++)
        {
            var row = new EccFixture.PositionRow { Sid = (ushort)sid, Lat = 500_000_000, Lon = 300_000_000, Profile = 1 };
            var packed = BinaryPacker.Pack(scheme, row);
            if (packed[^1] == last)
                return packed;
        }
        throw new InvalidOperationException("no row ends with the wanted parity byte");
    }

    // ---- EC-16: dispatch

    [Fact]
    public void Unpack_HandlersWithDifferentParityCounts_AreRefusedNamingBothCounts()
    {
        // Arrange
        var two = EccFixture.Positions(0x40).WithParity(2);
        var four = EccFixture.Positions(0x41).WithParity(4);
        var called = false;

        // Act
        var refused = Assert.Throws<ArgumentException>(
            () => BinaryPacker.Unpack(new byte[20], 0, out _, two.On(_ => called = true), four.On(_ => called = true)));

        // Assert
        Assert.False(called);
        Assert.Contains("2 and 4", refused.Message, StringComparison.Ordinal);
    }

    [Fact]
    public void Unpack_AProtectedHandlerNextToAnUnprotectedOne_IsRefused()
    {
        // Arrange
        var off = EccFixture.Positions(0x40);
        var on = EccFixture.Positions(0x41).WithParity(4);

        // Act
        var refused = Assert.Throws<ArgumentException>(
            () => BinaryPacker.Unpack(new byte[20], 0, out _, off.On(_ => { }), on.On(_ => { })));

        // Assert
        Assert.Contains("0 and 4", refused.Message, StringComparison.Ordinal);
    }

    [Fact]
    public void Unpack_TheTypeByteAmongTheWrongBytes_IsRepairedFirstAndReachesTheRightHandler()
    {
        // Arrange
        var schemes = new[] { 0x40, 0x41, 0x42 }.Select(t => EccFixture.Positions(t).WithParity(4)).ToArray();
        var random = new Random(16);
        var ran = new int[3];
        var wrongHandlers = 0;
        var wrongRows = 0;

        // Act
        for (var i = 0; i < 1000; i++)
        {
            var which = random.Next(3);
            var message = BinaryPacker.Pack(schemes[which], EccFixture.Row);
            var extra = random.Next(2);
            message[0] ^= (byte)random.Next(1, 256);
            if (extra == 1)
            {
                var other = random.Next(1, message.Length);
                message[other] ^= (byte)random.Next(1, 256);
            }
            Array.Clear(ran);
            EccFixture.PositionRow? got = null;
            var handlers = schemes.Select((s, k) => s.On(v => { ran[k]++; got = v; })).ToArray();
            var error = BinaryPacker.Unpack(message, 2, out var repaired, handlers);
            for (var k = 0; k < 3; k++)
            {
                if (k != which && ran[k] != 0)
                    wrongHandlers++;
            }
            if (error is not null || ran[which] != 1 || repaired != 1 + extra || !EccFixture.IsRow(got))
                wrongRows++;
        }

        // Assert
        Assert.Equal(0, wrongHandlers);
        Assert.Equal(0, wrongRows);
    }
}
