using Packbin;

namespace Packbin.Tests;

public class ObjectBindingTests
{
    private sealed class WideRow
    {
        public ushort? b5 { get; set; }
    }

    private sealed class Session
    {
        public ushort login { get; set; }
        public uint ts { get; set; }
    }

    private sealed class SessionRow
    {
        public Session? session { get; set; }
    }

    [Fact]
    public void Object_zero_is_present_and_null_is_absent()
    {
        var scheme = new Scheme<WideRow>(1, Field.Flags(
            "f", Field.U8("a"), Field.U8("b"), Field.U8("c"), Field.U8("d"), Field.U8("e"), Field.U16("b5")));
        var absent = Pack.Run(scheme, new WideRow());
        Assert.Equal(new byte[] { 0x01, 0x00 }, absent);
        var present = Pack.Run(scheme, new WideRow { b5 = 0 });
        Assert.Equal(new byte[] { 0x01, 0x20, 0x00, 0x00 }, present);
    }

    [Fact]
    public void Object_nested_group_and_short_packet()
    {
        var scheme = new Scheme<SessionRow>(1, Field.Flags("f", Field.Group("session", Field.U16("login"), Field.U32("ts"))));
        var clear = Pack.Run(scheme, new SessionRow());
        Assert.Equal(new byte[] { 0x01, 0x00 }, clear);
        var set = Pack.Run(scheme, new SessionRow { session = new Session { login = 7, ts = 1000 } });
        Assert.Equal("01010700e8030000", Convert.ToHexString(set).ToLowerInvariant());
        var got = Unpack.Run(scheme, set);
        Assert.True(got.Ok);
        Assert.NotNull(got.Value);
        Assert.NotNull(got.Value.session);
        Assert.Equal((ushort)7, got.Value.session.login);
        Assert.Equal(1000u, got.Value.session.ts);
        var shortPacket = Unpack.Run(scheme, new byte[] { 0x01, 0x01, 0x07 });
        Assert.False(shortPacket.Ok);
        Assert.Null(shortPacket.Value);
        var err = Assert.IsType<ShortPacket>(shortPacket.Error);
        Assert.Equal("login", err.Field);
        Assert.Equal(2, err.Needed);
        Assert.Equal(1, err.Left);
    }
}
