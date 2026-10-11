using Packbin;

namespace Packbin.Tests;

// Loop 20 review A8: a maxBytes above the largest byte array is capped there, so an oversized packet is refused naming
// the member instead of overflowing an int. Nothing here allocates the large packet: the limit is exercised through the
// cap function and a reservation, which writes no bytes.
public class PackOutCapTests
{
    private const long MaxArray = 0x7FFFFFC7;

    [Theory]
    [InlineData(1L, 1L)]
    [InlineData(1_000_000L, 1_000_000L)]
    [InlineData(MaxArray, MaxArray)]
    [InlineData(MaxArray + 1, MaxArray)]
    [InlineData(int.MaxValue, MaxArray)]
    [InlineData(long.MaxValue, MaxArray)]
    public void EffectiveCap_IsTheSmallerOfMaxBytesAndTheArrayLimit(long maxBytes, long expected)
    {
        // Act / Assert
        Assert.Equal(expected, PackOut.EffectiveCap(maxBytes));
    }

    [Theory]
    [InlineData(long.MaxValue)]
    [InlineData(int.MaxValue + 1L)]
    [InlineData(MaxArray + 1)]
    public void Reserve_PastTheArrayLimit_RefusesNamingTheMemberWithTheBudgetMessage(long maxBytes)
    {
        // Arrange
        var buffer = new PackOut(maxBytes);

        // Act
        var error = Assert.Throws<ArgumentException>(() => buffer.Reserve(int.MaxValue, "Blob"));

        // Assert
        Assert.Contains("'Blob'", error.Message, StringComparison.Ordinal);
        Assert.Equal($"'Blob': the packet would be {int.MaxValue} bytes, above the limit of {MaxArray} bytes", error.Message);
    }

    [Fact]
    public void Reserve_AfterBytesWritten_CountsThemInLongArithmetic()
    {
        // Arrange
        var buffer = new PackOut(long.MaxValue);
        buffer.Add(1);

        // Act
        var error = Assert.Throws<ArgumentException>(() => buffer.Reserve(int.MaxValue, "Blob"));

        // Assert
        Assert.Contains($"would be {int.MaxValue + 1L} bytes", error.Message, StringComparison.Ordinal);
    }

    [Fact]
    public void Pack_WithAHugeMaxBytes_StillPacksASmallPacket()
    {
        // Arrange
        var scheme = new Scheme<Row>(1, Field.U8<Row>(0, x => x.A)).WithLimits(maxBytes: long.MaxValue);

        // Act
        var raw = BinaryPacker.Pack(scheme, new Row { A = 7 });

        // Assert
        Assert.Equal(new byte[] { 1, 7 }, raw);
    }

    private sealed class Row
    {
        public byte A { get; set; }
    }
}
