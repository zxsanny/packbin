using Packbin;

namespace Packbin.Tests;

// AZ-2694: a duplicate type number is refused before any byte is read and before the receive index advances.
public class EccDispatchOrderTests
{
    private static (PackSession Opener, PackSession Waiter) OpenPair()
    {
        var seed = new byte[32];
        for (var i = 0; i < seed.Length; i++)
            seed[i] = (byte)(i + 1);
        var opener = PackSession.Load(seed)!;
        var waiter = PackSession.Load(seed)!;
        var nonce = new byte[16];
        nonce[0] = 1;
        opener.Start(nonce);
        Assert.True(waiter.Join(nonce));
        return (opener, waiter);
    }

    [Theory]
    [InlineData(0)]
    [InlineData(4)]
    public void SessionUnpack_ADuplicateTypeNumber_IsRefusedAndTheReceiveIndexStays(int parity)
    {
        // Arrange
        var scheme = EccFixture.Position.WithParity(parity);
        var (opener, waiter) = OpenPair();
        var first = opener.Pack(scheme, EccFixture.Row)!;
        var second = opener.Pack(scheme, EccFixture.Row)!;
        var rows = new List<EccFixture.PositionRow>();
        var handler = scheme.On(rows.Add);

        // Act
        var refuse = () => waiter.Unpack(first, 0, out _, handler, handler);
        var firstError = waiter.Unpack(first, 0, out _, handler);
        var secondError = waiter.Unpack(second, 0, out _, handler);

        // Assert
        var thrown = Assert.Throws<ArgumentException>(refuse);
        Assert.Contains("duplicate type number", thrown.Message);
        Assert.Null(firstError);
        Assert.Null(secondError);
        Assert.Equal(2, rows.Count);
        Assert.All(rows, row => Assert.True(EccFixture.IsRow(row)));
    }

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

    // AZ-2704: the checks run in one order in every package: not open, no handler, duplicate type, parity mix, limit.
    [Theory]
    [InlineData(0)]
    [InlineData(4)]
    public void SessionUnpack_NotOpenWithADuplicateType_ReturnsTheNotOpenShortPacket(int parity)
    {
        // Arrange
        var scheme = EccFixture.Position.WithParity(parity);
        var closed = PackSession.Load(new byte[32])!;
        var handler = scheme.On(_ => { });

        // Act
        var result = closed.Unpack(new byte[4], 0, out _, handler, handler);

        // Assert
        var shortPacket = Assert.IsType<ShortPacket>(result);
        Assert.Equal(("", 1, 0), (shortPacket.Field, shortPacket.Needed, shortPacket.Left));
    }

    [Theory]
    [InlineData(0)]
    [InlineData(4)]
    public void SessionUnpack_NoHandler_IsRefusedAndTheReceiveIndexStays(int parity)
    {
        // Arrange
        var scheme = EccFixture.Position.WithParity(parity);
        var (opener, waiter) = OpenPair();
        var first = opener.Pack(scheme, EccFixture.Row)!;
        var rows = new List<EccFixture.PositionRow>();
        var handler = scheme.On(rows.Add);

        // Act
        var refuse = () => waiter.Unpack(first, 0, out _);
        var error = waiter.Unpack(first, 0, out _, handler);

        // Assert
        var thrown = Assert.Throws<ArgumentException>(refuse);
        Assert.Contains("at least one handler", thrown.Message);
        Assert.Null(error);
        Assert.Single(rows);
    }

    [Fact]
    public void Unpack_NoHandler_IsRefused()
    {
        // Act
        var refuse = () => BinaryPacker.Unpack(new byte[] { 1 });

        // Assert
        Assert.Throws<ArgumentException>(refuse);
    }

    [Theory]
    [InlineData(0)]
    [InlineData(4)]
    public void Unpack_ADuplicateTypeWithAParityMixOrABadLimit_IsTheDuplicateRefusal(int parity)
    {
        // Arrange
        var handler = EccFixture.Position.WithParity(parity).On(_ => { });
        var mixed = EccFixture.Position.WithParity(parity == 0 ? 4 : 0).On(_ => { });
        var (_, waiter) = OpenPair();

        // Act
        var withMix = () => waiter.Unpack(new byte[4], 0, out _, handler, mixed, handler);
        var withLimit = () => BinaryPacker.Unpack(new byte[4], 9, out _, handler, handler);

        // Assert
        Assert.Contains("duplicate type number", Assert.Throws<ArgumentException>(withMix).Message);
        Assert.Contains("duplicate type number", Assert.Throws<ArgumentException>(withLimit).Message);
    }
}
