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
        SessionRow? row = null;
        var err = BinaryPacker.Unpack(set, scheme.On(v => row = v));
        Assert.Null(err);
        Assert.NotNull(row);
        Assert.NotNull(row.Session);
        Assert.Equal((ushort)7, row.Session.Login);
        Assert.Equal(1000u, row.Session.Ts);
        SessionRow? shortRow = null;
        var shortErr = BinaryPacker.Unpack(new byte[] { 0x01, 0x01, 0x07 }, scheme.On(v => shortRow = v));
        Assert.Null(shortRow);
        var missing = Assert.IsType<ShortPacket>(shortErr);
        Assert.Equal("Login", missing.Field);
        Assert.Equal(2, missing.Needed);
        Assert.Equal(1, missing.Left);
    }
}
