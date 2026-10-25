namespace Packbin.Tests;

// The code the README shows for frame mode. The lines between the markers are copied into the README by the docs task;
// this test keeps them compiling and correct.
public class FrameReadmeExample
{
    [Fact]
    public void LoadSealOpenWithAWindowAndTheMacOnlyCall()
    {
        // README-BEGIN
        // A 32-byte key shared by the nodes, an epoch (0 to 0xFFFFFF) and a tag of 4, 8 or 16 bytes.
        byte[] key = new byte[32]; // use a random key from your key store
        using var node = FrameSession.Load(key, 1, new FrameConfig(4, FrameDirections.Up | FrameDirections.Down))!;

        // msg_id: 8 bytes that are unique per (key, epoch, direction) for every message ever sealed.
        var message = new MsgContext(new byte[] { 0, 0x30, 0x10, 0x05, 0xe8, 3, 0, 0 }, kind: 4);
        byte[] header = [0, 1, 0, 0x30, 0x10, 0x05, 0xe8, 3, 0, 0, 4]; // authenticated, not sent

        var body = new byte[255];
        var error = node.Seal(FrameDirection.Up, message, header, [], "hello, relay"u8, body, out var length);
        // error is null, or BadValue, TooLong or BufferFull; length is the body length (12 + 4 here)

        // The receiver keeps one ReplayWindow per sender and passes a counter that comes from authenticated bytes.
        var window = new ReplayWindow();
        var plain = new byte[255];
        var opened = node.Open(FrameDirection.Up, message, header, body.AsSpan(0, length), 0, plain, out var result, window, counter: 7);
        // opened is null, or TagMismatch, Duplicate, TooOld, ShortPacket, TooLong, BufferFull or BadValue
        // plain[..result.PlainLength] is the text and result.Slot says which key opened it
        var again = node.Open(FrameDirection.Up, message, header, body.AsSpan(0, length), 0, plain, out _, window, counter: 7); // Duplicate

        // The MAC-only call: a 4-byte network check over a message given in parts.
        using var network = MacKey.Derive(key, 1, "net"u8)!;
        var tag = new byte[4];
        network.Tag(new ReadOnlyMemory<byte>[] { new byte[] { 1, 2, 3, 4 }, body.AsMemory(0, length) }, tag);
        var valid = network.Verify(new ReadOnlyMemory<byte>[] { new byte[] { 1, 2, 3, 4 }, body.AsMemory(0, length) }, tag);
        // README-END

        Assert.Null(error);
        Assert.Equal(16, length);
        Assert.Null(opened);
        Assert.Equal("hello, relay", System.Text.Encoding.UTF8.GetString(plain, 0, result.PlainLength));
        Assert.Equal(FrameSlot.Current, result.Slot);
        Assert.IsType<Duplicate>(again);
        Assert.True(valid);
    }
}
