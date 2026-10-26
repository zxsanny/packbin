using Packbin;

namespace Packbin.Tests;

// AZ-2694: a duplicate type number is refused before any byte is read.
public class EccDispatchOrderTests
{
    [Theory]
    [InlineData(0)]
    [InlineData(4)]
    public void Unpack_ADuplicateTypeNumber_IsRefusedBeforeAnyByteIsRead(int parity)
    {
        // Arrange
        var scheme = EccFixture.Position.WithParity(parity);
        var rows = new List<EccFixture.PositionRow>();
        var handler = scheme.On(rows.Add);

        // Act
        var refuse = () => BinaryPacker.Unpack([], 0, out _, handler, handler);

        // Assert
        Assert.Throws<ArgumentException>(refuse);
        Assert.Empty(rows);
    }

    [Fact]
    public void Unpack_NoHandler_IsRefused()
    {
        // Act
        var refuse = () => BinaryPacker.Unpack(new byte[] { 1 });

        // Assert
        Assert.Throws<ArgumentException>(refuse);
    }

    // AZ-2704: the checks run in one order in every package: no handler, duplicate type, parity mix, limit.
    [Theory]
    [InlineData(0)]
    [InlineData(4)]
    public void Unpack_ADuplicateTypeWithAParityMixOrABadLimit_IsTheDuplicateRefusal(int parity)
    {
        // Arrange
        var handler = EccFixture.Position.WithParity(parity).On(_ => { });
        var mixed = EccFixture.Position.WithParity(parity == 0 ? 4 : 0).On(_ => { });

        // Act
        var withMix = () => BinaryPacker.Unpack(new byte[4], 0, out _, handler, mixed, handler);
        var withLimit = () => BinaryPacker.Unpack(new byte[4], 9, out _, handler, handler);

        // Assert
        Assert.Contains("duplicate type number", Assert.Throws<ArgumentException>(withMix).Message);
        Assert.Contains("duplicate type number", Assert.Throws<ArgumentException>(withLimit).Message);
    }
}
