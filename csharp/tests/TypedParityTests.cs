using Packbin;

namespace Packbin.Tests;

// AZ-2092 Risk 1 and Risk 2: every kind packed and unpacked through a typed row gives the bytes the dictionary path
// gives, so the typed binding can change without moving a wire byte.
public class TypedParityTests
{
    private sealed class ScalarRow
    {
        public byte A { get; set; }
        public sbyte B { get; set; }
        public ushort C { get; set; }
        public short D { get; set; }
        public uint E { get; set; }
        public int F { get; set; }
        public ulong G { get; set; }
        public long H { get; set; }
        public float I { get; set; }
        public double J { get; set; }
        public ushort K { get; set; }
        public byte[] L { get; set; } = [];
    }

    private sealed class VarRow
    {
        public string Name { get; set; } = "";
        public byte N { get; set; }
        public byte[] Payload { get; set; } = [];
        public byte Nb { get; set; }
        public List<int>? Segs { get; set; }
        public byte Np { get; set; }
        public List<int>? Items { get; set; }
        public int P { get; set; }
        public int Q { get; set; }
    }

    private sealed class MotionRow
    {
        public byte Profile { get; set; }
        public byte? Shape { get; set; }
        public ushort? Heading { get; set; }
        public byte? Speed { get; set; }
        public short? Altitude { get; set; }
    }

    private sealed class GroupRow
    {
        public bool? Mark { get; set; }
        public byte? V { get; set; }
        public bool? On { get; set; }
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

    private sealed class U16El
    {
        public ushort N { get; set; }
    }

    private sealed class ListRow
    {
        public ushort[] Xs { get; set; } = [];
        public byte Y { get; set; }
    }

    private sealed class Utf8El
    {
        public string Role { get; set; } = "";
    }

    private sealed class ActionEl
    {
        public string Action { get; set; } = "";
    }

    private sealed class ActionList
    {
        public List<object?>? Actions { get; set; }
    }

    private sealed class UserRow
    {
        public string Username { get; set; } = "";
        public List<object?>? Roles { get; set; }
        public Dictionary<string, object?>? Access { get; set; }
    }

    private sealed class RepeatRow
    {
        public byte A { get; set; }
        public byte B { get; set; }
    }

    private static string Hex(byte[] raw) => Convert.ToHexString(raw).ToLowerInvariant();

    // The dictionary and the typed row pack to `hex`; the typed row unpacks to what `check` expects and packs again to
    // `hex`.
    private static void Same<T>(Scheme<T> scheme, Dictionary<string, object?> dict, T row, string hex, Action<T> check)
        where T : class, new()
    {
        Assert.Equal(hex, Hex(BinaryPacker.Pack(scheme, dict)));
        var raw = BinaryPacker.Pack(scheme, row);
        Assert.Equal(hex, Hex(raw));
        T? got = null;
        var err = BinaryPacker.Unpack(raw, scheme.On(v => got = v));
        Assert.Null(err);
        Assert.NotNull(got);
        check(got);
        Assert.Equal(hex, Hex(BinaryPacker.Pack(scheme, got)));
    }

    [Fact]
    public void Scalars_EveryWidthAndByteOrder()
    {
        var scheme = new Scheme<ScalarRow>(1,
            Field.U8<ScalarRow>(0, x => x.A), Field.I8<ScalarRow>(1, x => x.B),
            Field.U16<ScalarRow>(2, x => x.C), Field.I16<ScalarRow>(3, x => x.D),
            Field.U32<ScalarRow>(4, x => x.E), Field.I32<ScalarRow>(5, x => x.F),
            Field.U64<ScalarRow>(6, x => x.G), Field.I64<ScalarRow>(7, x => x.H),
            Field.F32<ScalarRow>(8, x => x.I), Field.F64<ScalarRow>(9, x => x.J),
            Field.U16<ScalarRow>(10, x => x.K).Be(), Field.Bytes<ScalarRow>(11, x => x.L, 3));
        var dict = new Dictionary<string, object?>
        {
            ["A"] = (byte)200, ["B"] = (sbyte)-5, ["C"] = (ushort)65000, ["D"] = (short)-300,
            ["E"] = 4_000_000_000u, ["F"] = -123_456, ["G"] = ulong.MaxValue, ["H"] = long.MinValue,
            ["I"] = 1.5f, ["J"] = -2.25, ["K"] = (ushort)0x0102, ["L"] = new byte[] { 7, 8, 9 },
        };
        var row = new ScalarRow
        {
            A = 200, B = -5, C = 65000, D = -300, E = 4_000_000_000u, F = -123_456, G = ulong.MaxValue,
            H = long.MinValue, I = 1.5f, J = -2.25, K = 0x0102, L = [7, 8, 9],
        };

        Same(scheme, dict, row,
            "01" + "c8" + "fb" + "e8fd" + "d4fe" + "00286bee" + "c01dfeff" + "ffffffffffffffff" + "0000000000000080"
            + "0000c03f" + "00000000000002c0" + "0102" + "070809",
            got =>
            {
                Assert.Equal(200, got.A);
                Assert.Equal(-5, got.B);
                Assert.Equal(65000, got.C);
                Assert.Equal(-300, got.D);
                Assert.Equal(4_000_000_000u, got.E);
                Assert.Equal(-123_456, got.F);
                Assert.Equal(ulong.MaxValue, got.G);
                Assert.Equal(long.MinValue, got.H);
                Assert.Equal(1.5f, got.I);
                Assert.Equal(-2.25, got.J);
                Assert.Equal(0x0102, got.K);
                Assert.Equal(new byte[] { 7, 8, 9 }, got.L);
            });
    }

    [Fact]
    public void Utf8_Sized_Bits_Packed_U2()
    {
        var scheme = new Scheme<VarRow>(1,
            Field.Utf8<VarRow>(0, x => x.Name),
            Field.U8<VarRow>(1, x => x.N), Field.Sized<VarRow>(2, x => x.Payload, 1),
            Field.U8<VarRow>(3, x => x.Nb), Field.Bits<VarRow>(4, x => x.Segs, 3),
            Field.U8<VarRow>(5, x => x.Np), Field.Packed<VarRow>(2, 6, x => x.Items, 5),
            Field.U2<VarRow>((7, x => x.P), (8, x => x.Q)));
        var dict = new Dictionary<string, object?>
        {
            ["Name"] = "ada", ["N"] = (byte)2, ["Payload"] = new byte[] { 1, 2 }, ["Nb"] = (byte)3,
            ["Segs"] = new List<int> { 1, 0, 1 }, ["Np"] = (byte)3, ["Items"] = new List<int> { 3, 1, 2 },
            ["P"] = 1, ["Q"] = 3,
        };
        var row = new VarRow
        {
            Name = "ada", N = 2, Payload = [1, 2], Nb = 3, Segs = [1, 0, 1], Np = 3, Items = [3, 1, 2], P = 1, Q = 3,
        };

        Same(scheme, dict, row, "010300616461020102030503270d", got =>
        {
            Assert.Equal("ada", got.Name);
            Assert.Equal(new byte[] { 1, 2 }, got.Payload);
            Assert.Equal(new List<int> { 1, 0, 1 }, got.Segs);
            Assert.Equal(new List<int> { 3, 1, 2 }, got.Items);
            Assert.Equal(1, got.P);
            Assert.Equal(3, got.Q);
        });
    }

    [Fact]
    public void SplitFlagBits_AndWhen()
    {
        var motion = Field.FlagByte();
        var scheme = new Scheme<MotionRow>(1,
            Field.U8<MotionRow>(0, x => x.Profile),
            motion,
            Field.When(1, Condition.Eq(0, 0), Field.U8<MotionRow>(1, x => x.Shape)),
            motion.Bit(Field.U16<MotionRow>(2, x => x.Heading)),
            motion.Bit(Field.U8<MotionRow>(3, x => x.Speed)),
            motion.Bit(Field.I16<MotionRow>(4, x => x.Altitude)));
        var dict = new Dictionary<string, object?>
        {
            ["Profile"] = (byte)0, ["Shape"] = (byte)9, ["Heading"] = (ushort)90, ["Altitude"] = (short)-2,
        };
        var row = new MotionRow { Profile = 0, Shape = 9, Heading = 90, Altitude = -2 };

        Same(scheme, dict, row, "01" + "00" + "05" + "09" + "5a00" + "feff", got =>
        {
            Assert.Equal((byte)9, got.Shape);
            Assert.Equal((ushort)90, got.Heading);
            Assert.Null(got.Speed);
            Assert.Equal((short)-2, got.Altitude);
        });
    }

    [Fact]
    public void CombinedFlags_AndGroupWithOwnMember()
    {
        var scheme = new Scheme<GroupRow>(1,
            Field.Flags(0,
                Field.Group(0, (GroupRow x) => x.Mark, Field.U8<GroupRow>(0, x => x.V)),
                Field.Bool<GroupRow>(1, x => x.On)));
        var dict = new Dictionary<string, object?> { ["V"] = (byte)7, ["On"] = true };
        var row = new GroupRow { V = 7, On = true };

        Same(scheme, dict, row, "010307", got =>
        {
            Assert.Equal((byte)7, got.V);
            Assert.True(got.On);
            Assert.Null(got.Mark);
        });
    }

    [Fact]
    public void NestedRowUnderFlags_SetAndNull()
    {
        var scheme = new Scheme<SessionRow>(1, Field.Flags(0,
            Field.Group((SessionRow x) => x.Session, Field.U16<Session>(0, s => s.Login), Field.U32<Session>(1, s => s.Ts))));
        var set = new Dictionary<string, object?> { ["Login"] = (ushort)7, ["Ts"] = 1000u };
        var row = new SessionRow { Session = new Session { Login = 7, Ts = 1000 } };

        Same(scheme, set, row, "01010700e8030000", got =>
        {
            Assert.Equal((ushort)7, got.Session!.Login);
            Assert.Equal(1000u, got.Session.Ts);
        });
        Same(scheme, new(), new SessionRow(), "0100", got => Assert.Null(got.Session));
    }

    [Fact]
    public void PrimitiveElementList_AndTrailingField()
    {
        var scheme = new Scheme<ListRow>(1,
            Field.List((ListRow x) => x.Xs, Field.U16<U16El>(0, n => n.N)),
            Field.U8<ListRow>(0, x => x.Y));
        var dict = new Dictionary<string, object?> { ["Xs"] = new ushort[] { 1, 2 }, ["Y"] = (byte)5 };
        var row = new ListRow { Xs = [1, 2], Y = 5 };

        Same(scheme, dict, row, "01020001000200" + "05", got =>
        {
            Assert.Equal(new ushort[] { 1, 2 }, got.Xs);
            Assert.Equal((byte)5, got.Y);
        });
        Same(scheme, new() { ["Xs"] = Array.Empty<ushort>(), ["Y"] = (byte)0 }, new ListRow(), "01000000",
            got => Assert.Empty(got.Xs));
    }

    [Fact]
    public void BigEndianPrimitiveElementList()
    {
        var scheme = new Scheme<ListRow>(1, Field.List((ListRow x) => x.Xs, Field.U16<U16El>(0, n => n.N).Be()));
        var dict = new Dictionary<string, object?> { ["Xs"] = new ushort[] { 1 } };

        Same(scheme, dict, new ListRow { Xs = [1] }, "0101000001", got => Assert.Equal(new ushort[] { 1 }, got.Xs));
    }

    [Fact]
    public void ListAndDictOfStrings_NestedListInDict()
    {
        var scheme = new Scheme<UserRow>(1,
            Field.Utf8<UserRow>(0, x => x.Username),
            Field.List((UserRow x) => x.Roles, Field.Utf8<Utf8El>(0, r => r.Role)),
            Field.Dict((UserRow x) => x.Access, Field.List((ActionList e) => e.Actions, Field.Utf8<ActionEl>(0, a => a.Action))));
        const string hex =
            "0107007a7873616e6e7902000400757365720a0064697370617463686572030007006368616e6e656c010004007265616403006d6170040004007265616407006770735f6669780300736574040065646974050073746f7265020004007265616405007772697465";
        var dict = new Dictionary<string, object?>
        {
            ["Username"] = "zxsanny",
            ["Roles"] = new List<object?> { "user", "dispatcher" },
            ["Access"] = new Dictionary<string, object?>
            {
                ["channel"] = new List<object?> { "read" },
                ["map"] = new List<object?> { "read", "gps_fix", "set", "edit" },
                ["store"] = new List<object?> { "read", "write" },
            },
        };
        var row = new UserRow
        {
            Username = "zxsanny",
            Roles = ["user", "dispatcher"],
            Access = new Dictionary<string, object?>
            {
                ["store"] = new List<object?> { "read", "write" },
                ["channel"] = new List<object?> { "read" },
                ["map"] = new List<object?> { "read", "gps_fix", "set", "edit" },
            },
        };

        Same(scheme, dict, row, hex, got =>
        {
            Assert.Equal("zxsanny", got.Username);
            Assert.Equal(new[] { "user", "dispatcher" }, got.Roles!.Cast<string>());
            Assert.Equal(new[] { "channel", "map", "store" }, got.Access!.Keys.OrderBy(k => k, StringComparer.Ordinal));
            Assert.Equal(new[] { "read", "write" }, ((List<object?>)got.Access["store"]!).Cast<string>());
        });
    }

    [Fact]
    public void RepeatOfScalarMembers_PacksOneRound()
    {
        var scheme = new Scheme<RepeatRow>(1,
            Field.Repeat(0, Field.U8<RepeatRow>(0, x => x.A), Field.U8<RepeatRow>(1, x => x.B)));
        var dict = new Dictionary<string, object?> { ["A"] = (byte)1, ["B"] = (byte)2 };

        Assert.Equal("010102", Hex(BinaryPacker.Pack(scheme, dict)));
        Assert.Equal("010102", Hex(BinaryPacker.Pack(scheme, new RepeatRow { A = 1, B = 2 })));
    }

    [Fact]
    public void Golden_PositionRow()
    {
        var dict = new Dictionary<string, object?>
        {
            ["Sid"] = (ushort)1, ["Lat"] = 500_000_000, ["Lon"] = 300_000_000, ["Profile"] = (byte)1,
        };
        var row = new PackbinTests.PositionRow { Sid = 1, Lat = 500_000_000, Lon = 300_000_000, Profile = 1 };

        Same(PackbinTests.Target, dict, row, "4001000065cd1d00a3e1110100", got =>
        {
            Assert.Equal(500_000_000, got.Lat);
            Assert.Null(got.Heading);
        });
    }
}
