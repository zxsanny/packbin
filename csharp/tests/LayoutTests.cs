using Packbin;

namespace Packbin.Tests;

public class LayoutTests
{
    private sealed class WhenRow
    {
        public byte Profile { get; set; }
        public byte? Shape { get; set; }
    }

    private sealed class RepeatRow
    {
        public byte A { get; set; }
        public byte B { get; set; }
    }

    private sealed class TrailingRow
    {
        public byte Type { get; set; }
    }

    private sealed class MarkRow
    {
        public bool? Mark { get; set; }
    }

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

    private sealed class SessionFlagRow
    {
        public Session? Session { get; set; }
    }

    private sealed class NestedByte
    {
        public byte B { get; set; }
    }

    private sealed class NestedByteRow
    {
        public NestedByte? G { get; set; }
    }

    [Fact]
    public void WhenGroupWidth()
    {
        var scheme = new Scheme<WhenRow>(1,
            Field.U8<WhenRow>(0, x => x.Profile),
            Field.When(1, Condition.Eq(0, (byte)0), Field.U8<WhenRow>(1, x => x.Shape)));

        var miss = BinaryPacker.Pack(scheme, new Dictionary<string, object?> { ["Profile"] = (byte)1 });
        Assert.Equal(2, miss.Length);
        Assert.Equal(0x01, miss[0]);

        var hit = BinaryPacker.Pack(scheme, new Dictionary<string, object?>
        {
            ["Profile"] = (byte)0,
            ["Shape"] = (byte)9,
        });
        Assert.Equal(3, hit.Length);
        Assert.Equal(1, hit.Length - miss.Length);
    }

    [Fact]
    public void RepeatBoundary()
    {
        var scheme = new Scheme<RepeatRow>(1, Field.Repeat(0, Field.U8<RepeatRow>(0, x => x.A), Field.U8<RepeatRow>(1, x => x.B)));

        var ok = BinaryPacker.Read(scheme, new byte[] { 1, 1, 2 });
        Assert.Null(ok.Error);
        var groups = Assert.IsType<List<object?>>(ok.Values["A"]);
        Assert.Single(groups);

        var bad = BinaryPacker.Read(scheme, new byte[] { 1, 1, 2, 3 });
        Assert.Empty(bad.Values);
        Assert.IsType<ShortPacket>(bad.Error);

        var packed = BinaryPacker.Pack(scheme, new Dictionary<string, object?> { ["A"] = (byte)1, ["B"] = (byte)2 });
        Assert.Equal("010102", Convert.ToHexString(packed).ToLowerInvariant());
    }

    [Fact]
    public void Repeat_MatchingAnchor_SameBytes()
    {
        var scheme = new Scheme<RepeatRow>(1,
            Field.U8<RepeatRow>(0, x => x.A),
            Field.Repeat(1, Field.U8<RepeatRow>(1, x => x.B)));
        var packed = BinaryPacker.Pack(scheme, new Dictionary<string, object?> { ["A"] = (byte)1, ["B"] = (byte)2 });
        Assert.Equal("010102", Convert.ToHexString(packed).ToLowerInvariant());
    }

    [Fact]
    public void Repeat_WrongAnchor_FailsConstruction()
    {
        var bytesWritten = 0;
        var schemes = 0;
        try
        {
            var scheme = new Scheme<RepeatRow>(1,
                Field.Repeat(1, Field.U8<RepeatRow>(0, x => x.A), Field.U8<RepeatRow>(1, x => x.B)));
            schemes++;
            bytesWritten = BinaryPacker.Pack(scheme, new Dictionary<string, object?> { ["A"] = (byte)1, ["B"] = (byte)2 }).Length;
        }
        catch (ArgumentException)
        {
        }
        Assert.Equal(0, schemes);
        Assert.Equal(0, bytesWritten);
    }

    [Fact]
    public void TrailingBytesAreError()
    {
        var scheme = new Scheme<TrailingRow>(1, Field.U8<TrailingRow>(0, x => x.Type));
        var got = BinaryPacker.Read(scheme, new byte[] { 0x01, 0x40, 0x99 });
        Assert.Empty(got.Values);
        var trailing = Assert.IsType<TrailingBytes>(got.Error);
        Assert.Equal(1, trailing.Left);
    }

    [Fact]
    public void FlagGroup_EmptyMark()
    {
        var scheme = new Scheme<MarkRow>(1, Field.Flags(0, Field.Group(0, (MarkRow x) => x.Mark)));
        var setBit = BinaryPacker.Pack(scheme, new Dictionary<string, object?> { ["Mark"] = true });
        Assert.Equal(new byte[] { 0x01, 0x01 }, setBit);
        var clear = BinaryPacker.Pack(scheme, new Dictionary<string, object?>());
        Assert.Equal(new byte[] { 0x01, 0x00 }, clear);
    }

    [Fact]
    public void FlagGroup_FiveU8ThenU16()
    {
        var scheme = new Scheme<WideRow>(1, Field.Flags(0,
            Field.U8<WideRow>(0, x => x.A), Field.U8<WideRow>(1, x => x.B), Field.U8<WideRow>(2, x => x.C),
            Field.U8<WideRow>(3, x => x.D), Field.U8<WideRow>(4, x => x.E), Field.U16<WideRow>(5, x => x.B5)));
        Assert.Equal(3, BinaryPacker.Pack(scheme, new Dictionary<string, object?> { ["A"] = (byte)1 }).Length);
        var empty = BinaryPacker.Pack(scheme, new Dictionary<string, object?>());
        var wide = BinaryPacker.Pack(scheme, new Dictionary<string, object?> { ["B5"] = (ushort)1 });
        Assert.Equal(0x01, wide[0]);
        Assert.Equal(0x20, wide[1]);
        Assert.Equal(2, wide.Length - empty.Length);
    }

    [Fact]
    public void FlagGroup_Session()
    {
        var scheme = new Scheme<SessionFlagRow>(1, Field.Flags(0,
            Field.Group((SessionFlagRow x) => x.Session, Field.U16<Session>(0, s => s.Login), Field.U32<Session>(1, s => s.Ts))));
        var raw = BinaryPacker.Pack(scheme, new Dictionary<string, object?>
        {
            ["Login"] = (ushort)7,
            ["Ts"] = 1000u,
        });
        Assert.Equal("0700e8030000", Convert.ToHexString(raw.AsSpan(2)).ToLowerInvariant());
        Assert.Equal(6, raw.Length - 2);
        var absent = BinaryPacker.Pack(scheme, new Dictionary<string, object?>());
        Assert.Equal(new byte[] { 0x01, 0x00 }, absent);
        var got = BinaryPacker.Read(scheme, absent);
        Assert.Null(got.Error);
        Assert.False(got.Values.ContainsKey("Login"));
        Assert.False(got.Values.ContainsKey("Ts"));
    }

    [Fact]
    public void FlagGroup_ZeroU8()
    {
        var scheme = new Scheme<NestedByteRow>(1, Field.Flags(0, Field.Group((NestedByteRow x) => x.G, Field.U8<NestedByte>(0, g => g.B))));
        var stored = BinaryPacker.Pack(scheme, new Dictionary<string, object?> { ["B"] = (byte)0 });
        Assert.Equal(new byte[] { 0x01, 0x01, 0x00 }, stored);
    }

    [Fact]
    public void FlagGroup_SessionShort()
    {
        var scheme = new Scheme<SessionFlagRow>(1, Field.Flags(0,
            Field.Group((SessionFlagRow x) => x.Session, Field.U16<Session>(0, s => s.Login), Field.U32<Session>(1, s => s.Ts))));
        var got = BinaryPacker.Read(scheme, new byte[] { 0x01, 0x01, 0x07 });
        Assert.Empty(got.Values);
        var missing = Assert.IsType<ShortPacket>(got.Error);
        Assert.Equal("Login", missing.Field);
        Assert.Equal(2, missing.Needed);
        Assert.Equal(1, missing.Left);
    }
}
