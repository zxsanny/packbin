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
}
