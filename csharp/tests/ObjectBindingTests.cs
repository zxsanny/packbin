using Packbin;

namespace Packbin.Tests;

public class ObjectBindingTests
{
    private sealed class WideRow
    {
        public byte? A { get; set; }
        public byte? B { get; set; }
        public byte? C { get; set; }
        public byte? D { get; set; }
        public byte? E { get; set; }
        public ushort? B5 { get; set; }
    }

    private sealed class Session
    {
        public ushort Login { get; set; }
        public uint Ts { get; set; }
    }

    private sealed class SessionRow
    {
        public Session? Session { get; set; }
    }

    [Fact]
    public void Object_zero_is_present_and_null_is_absent()
    {
        var scheme = new Scheme<WideRow>(1, Field.Flags(
            Field.U8<WideRow>(0, x => x.A), Field.U8<WideRow>(1, x => x.B), Field.U8<WideRow>(2, x => x.C),
            Field.U8<WideRow>(3, x => x.D), Field.U8<WideRow>(4, x => x.E), Field.U16<WideRow>(5, x => x.B5)));
        var absent = BinaryPacker.Pack(scheme, new WideRow());
        Assert.Equal(new byte[] { 0x01, 0x00 }, absent);
        var present = BinaryPacker.Pack(scheme, new WideRow { B5 = 0 });
        Assert.Equal(new byte[] { 0x01, 0x20, 0x00, 0x00 }, present);
    }

    [Fact]
    public void Object_nested_group_and_short_packet()
    {
        var scheme = new Scheme<SessionRow>(1, Field.Flags(
            Field.Group((SessionRow x) => x.Session, Field.U16<Session>(0, s => s.Login), Field.U32<Session>(1, s => s.Ts))));
        var clear = BinaryPacker.Pack(scheme, new SessionRow());
        Assert.Equal(new byte[] { 0x01, 0x00 }, clear);
        var set = BinaryPacker.Pack(scheme, new SessionRow { Session = new Session { Login = 7, Ts = 1000 } });
        Assert.Equal("01010700e8030000", Convert.ToHexString(set).ToLowerInvariant());
        var got = BinaryPacker.Unpack(scheme, set);
        Assert.True(got.Ok);
        Assert.NotNull(got.Value);
        Assert.NotNull(got.Value.Session);
        Assert.Equal((ushort)7, got.Value.Session.Login);
        Assert.Equal(1000u, got.Value.Session.Ts);
        var shortPacket = BinaryPacker.Unpack(scheme, new byte[] { 0x01, 0x01, 0x07 });
        Assert.False(shortPacket.Ok);
        Assert.Null(shortPacket.Value);
        var err = Assert.IsType<ShortPacket>(shortPacket.Error);
        Assert.Equal("Login", err.Field);
        Assert.Equal(2, err.Needed);
        Assert.Equal(1, err.Left);
    }
}
