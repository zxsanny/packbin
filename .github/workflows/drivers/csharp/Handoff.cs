using System.Collections;
using Packbin;

static class Handoff
{
    sealed class RoleEl
    {
        public string Role { get; set; } = "";
    }

    sealed class ActionEl
    {
        public string Action { get; set; } = "";
    }

    sealed class ActionList
    {
        public List<object?>? Actions { get; set; }
    }

    sealed class UserRow
    {
        public string Username { get; set; } = "";
        public List<object?>? Roles { get; set; }
        public Dictionary<string, object?>? Access { get; set; }
    }

    sealed class ValueEl
    {
        public string Value { get; set; } = "";
    }

    sealed class FieldDict
    {
        public Dictionary<string, object?>? Fields { get; set; }
    }

    sealed class NestedRow
    {
        public Dictionary<string, object?>? Access { get; set; }
    }

    static readonly Scheme<UserRow> UserScheme = new(1,
        Field.Utf8<UserRow>(0, x => x.Username),
        Field.List((UserRow x) => x.Roles, Field.Utf8<RoleEl>(0, r => r.Role)),
        Field.Dict((UserRow x) => x.Access, Field.List((ActionList e) => e.Actions, Field.Utf8<ActionEl>(0, a => a.Action))));

    static readonly Scheme<NestedRow> NestedScheme = new(1,
        Field.Dict((NestedRow x) => x.Access, Field.List((FieldDict r) => r.Fields, Field.Dict((FieldDict f) => f.Fields, Field.Utf8<ValueEl>(0, v => v.Value)))));

    static readonly Dictionary<string, object?> UserValues = new()
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

    static readonly Dictionary<string, object?> NestedValues = new()
    {
        ["Access"] = new Dictionary<string, object?>
        {
            ["map"] = new List<object?>
            {
                new Dictionary<string, object?> { ["op"] = "gps_fix" },
            },
            ["store"] = new List<object?>
            {
                new Dictionary<string, object?> { ["op"] = "read" },
                new Dictionary<string, object?> { ["op"] = "write" },
            },
        },
    };

    sealed class PositionRow
    {
        public ushort Sid { get; set; }
        public int Lat { get; set; }
        public int Lon { get; set; }
        public byte Profile { get; set; }
        public ushort? Heading { get; set; }
        public byte? Speed { get; set; }
        public short? Altitude { get; set; }
    }

    static readonly Scheme<PositionRow> PositionScheme = new(0x40,
        Field.U16<PositionRow>(0, x => x.Sid),
        Field.I32<PositionRow>(1, x => x.Lat),
        Field.I32<PositionRow>(2, x => x.Lon),
        Field.U8<PositionRow>(3, x => x.Profile),
        Field.Flags(4,
            Field.U16<PositionRow>(4, x => x.Heading),
            Field.U8<PositionRow>(5, x => x.Speed),
            Field.I16<PositionRow>(6, x => x.Altitude)));

    static readonly PositionRow PositionRowValue = new()
    {
        Sid = 1,
        Lat = 500_000_000,
        Lon = 300_000_000,
        Profile = 1,
    };

    sealed class BoolFlagRow
    {
        public bool? On { get; set; }
    }

    static readonly Scheme<BoolFlagRow> BoolFlagScheme = new(1, Field.Flags(0, Field.Bool<BoolFlagRow>(0, x => x.On)));

    sealed class BitWhenRow
    {
        public byte K { get; set; }
        public byte? V { get; set; }
    }

    // u8 k; split flag byte m; when (k == 1) { m.bit(u8 v) }. The bit follows the row even when the when is not taken.
    static readonly Scheme<BitWhenRow> BitWhenScheme = BitWhen();

    static Scheme<BitWhenRow> BitWhen()
    {
        var m = Field.FlagByte();
        return new Scheme<BitWhenRow>(1,
            Field.U8<BitWhenRow>(0, x => x.K),
            m,
            Field.When(1, Condition.Eq(0, 1), m.Bit(Field.U8<BitWhenRow>(1, x => x.V))));
    }

    sealed class RoundFlagsRow
    {
        public bool? On { get; set; }
        public byte? N { get; set; }
    }

    sealed class RoundWhenRow
    {
        public byte? K { get; set; }
        public byte? V { get; set; }
    }

    // repeat(flags(bool on, u8 n)): one list entry per round, so the row is a dictionary of lists.
    static readonly Scheme<RoundFlagsRow> RoundFlagsScheme = new(1,
        Field.Repeat(0,
            Field.Flags(0, Field.Bool<RoundFlagsRow>(0, x => x.On), Field.U8<RoundFlagsRow>(1, x => x.N))));

    static readonly Dictionary<string, object?> RoundFlagsValues = new()
    {
        ["On"] = new object?[] { true, false, true },
        ["N"] = new object?[] { (byte)1, (byte)2, (byte)3 },
    };

    // repeat(u8 k, when(k == 1, u8 v)): v has no entry for a round that skips it.
    static readonly Scheme<RoundWhenRow> RoundWhenScheme = new(1,
        Field.Repeat(0,
            Field.U8<RoundWhenRow>(0, x => x.K),
            Field.When(1, Condition.Eq(0, (byte)1), Field.U8<RoundWhenRow>(1, x => x.V))));

    static readonly Dictionary<string, object?> RoundWhenValues = new()
    {
        ["K"] = new object?[] { (byte)1, (byte)2 },
        ["V"] = new object?[] { (byte)9 },
    };

    static readonly byte[] SessionSeed = Enumerable.Range(1, 32).Select(i => (byte)i).ToArray();
    static readonly byte[] SessionNonce = Convert.FromHexString("01000000000000000000000000000000");

    static int Main(string[] args)
    {
        if (args.Length == 0)
            return 2;

        switch (args[0])
        {
            case "pack-user":
                Console.WriteLine(Convert.ToHexString(BinaryPacker.Pack(UserScheme, UserValues)).ToLowerInvariant());
                return 0;
            case "pack-nested":
                Console.WriteLine(Convert.ToHexString(BinaryPacker.Pack(NestedScheme, NestedValues)).ToLowerInvariant());
                return 0;
            case "pack-session":
                return PackSessionOpener();
            case "pack-boolflag":
                Console.WriteLine(Convert.ToHexString(BinaryPacker.Pack(BoolFlagScheme, new BoolFlagRow { On = false })).ToLowerInvariant());
                return 0;
            case "pack-bitwhen":
                Console.WriteLine(Convert.ToHexString(BinaryPacker.Pack(BitWhenScheme, new BitWhenRow { K = 0, V = 5 })).ToLowerInvariant());
                return 0;
            case "pack-booltrue":
                Console.WriteLine(Convert.ToHexString(BinaryPacker.Pack(BoolFlagScheme, new BoolFlagRow { On = true })).ToLowerInvariant());
                return 0;
            case "pack-roundflags":
                Console.WriteLine(Convert.ToHexString(BinaryPacker.Pack(RoundFlagsScheme, RoundFlagsValues)).ToLowerInvariant());
                return 0;
            case "pack-roundwhen":
                Console.WriteLine(Convert.ToHexString(BinaryPacker.Pack(RoundWhenScheme, RoundWhenValues)).ToLowerInvariant());
                return 0;
            case "unpack-user":
                if (args.Length < 2)
                    return 2;
                return UnpackUser(args[1]) ? 0 : 1;
            case "unpack-nested":
                if (args.Length < 2)
                    return 2;
                return UnpackNested(args[1]) ? 0 : 1;
            case "unpack-session":
                if (args.Length < 2)
                    return 2;
                return UnpackSession(args[1]) ? 0 : 1;
            case "unpack-boolflag":
                if (args.Length < 2)
                    return 2;
                return UnpackBoolFlag(args[1], expectOn: false);
            case "unpack-booltrue":
                if (args.Length < 2)
                    return 2;
                return UnpackBoolFlag(args[1], expectOn: true);
            case "unpack-bitwhen":
                if (args.Length < 2)
                    return 2;
                return UnpackBitWhen(args[1]);
            default:
                return 2;
        }
    }

    static int PackSessionOpener()
    {
        var opener = PackSession.Load(SessionSeed);
        if (opener is null || opener.Start(SessionNonce) is null)
            return 1;
        var payload = opener.Pack(PositionScheme, PositionRowValue);
        if (payload is null)
            return 1;
        Console.WriteLine(Convert.ToHexString(payload).ToLowerInvariant());
        return 0;
    }

    static bool UnpackSession(string hex)
    {
        var waiter = PackSession.Load(SessionSeed);
        if (waiter is null || !waiter.Join(SessionNonce))
            return false;
        PositionRow? got = null;
        var err = waiter.Unpack(Convert.FromHexString(hex), PositionScheme.On(v => got = v));
        if (err is not null || got is null)
            return false;
        return got.Sid == 1
            && got.Lat == 500_000_000
            && got.Lon == 300_000_000
            && got.Profile == 1
            && got.Heading is null
            && got.Speed is null
            && got.Altitude is null;
    }

    // expectOn: the row must read on = true; otherwise on must be absent or false.
    static int UnpackBoolFlag(string hex, bool expectOn)
    {
        var command = expectOn ? "unpack-booltrue" : "unpack-boolflag";
        BoolFlagRow? row = null;
        var err = BinaryPacker.Unpack(Convert.FromHexString(hex), BoolFlagScheme.On(v => row = v));
        if (err is not null || row is null)
        {
            Console.Error.WriteLine($"{command}: not ok ({err?.GetType().Name ?? "no row"})");
            return 1;
        }
        if ((row.On is true) != expectOn)
        {
            var wanted = expectOn ? "true" : "absent or false";
            var got = row.On switch { true => "true", false => "false", null => "absent" };
            Console.Error.WriteLine($"{command}: on is {got}, expected {wanted}");
            return 1;
        }
        return 0;
    }

    static int UnpackBitWhen(string hex)
    {
        BitWhenRow? row = null;
        var err = BinaryPacker.Unpack(Convert.FromHexString(hex), BitWhenScheme.On(v => row = v));
        if (err is not null || row is null)
        {
            Console.Error.WriteLine($"unpack-bitwhen: not ok ({err?.GetType().Name ?? "no row"})");
            return 1;
        }
        if (row.K != 0 || row.V is not null)
        {
            Console.Error.WriteLine($"unpack-bitwhen: k = {row.K}, v = {row.V?.ToString() ?? "absent"}; expected k = 0 and no v");
            return 1;
        }
        return 0;
    }

    static bool UnpackUser(string hex)
    {
        UserRow? row = null;
        var err = BinaryPacker.Unpack(Convert.FromHexString(hex), UserScheme.On(v => row = v));
        if (err is not null || row is null)
            return false;
        if (!EqualsString(row.Username, "zxsanny"))
            return false;
        if (!EqualsStringList(row.Roles, "user", "dispatcher"))
            return false;
        if (row.Access is not IDictionary access)
            return false;
        if (!EqualsStringList(access["channel"], "read"))
            return false;
        if (!EqualsStringList(access["map"], "read", "gps_fix", "set", "edit"))
            return false;
        if (!EqualsStringList(access["store"], "read", "write"))
            return false;
        return access.Count == 3;
    }

    static bool UnpackNested(string hex)
    {
        NestedRow? row = null;
        var err = BinaryPacker.Unpack(Convert.FromHexString(hex), NestedScheme.On(v => row = v));
        if (err is not null || row is null)
            return false;
        if (row.Access is not IDictionary access)
            return false;
        if (access.Count != 2)
            return false;
        if (!EqualsOpRows(access["map"], "gps_fix"))
            return false;
        if (!EqualsOpRows(access["store"], "read", "write"))
            return false;
        return true;
    }

    static bool EqualsString(object? value, string expected) =>
        value is string s && s == expected;

    static bool EqualsStringList(object? value, params string[] expected)
    {
        if (value is not IList list || list.Count != expected.Length)
            return false;
        for (var i = 0; i < expected.Length; i++)
        {
            if (list[i] is not string s || s != expected[i])
                return false;
        }
        return true;
    }

    static bool EqualsOpRows(object? value, params string[] ops)
    {
        if (value is not IList list || list.Count != ops.Length)
            return false;
        for (var i = 0; i < ops.Length; i++)
        {
            if (list[i] is not IDictionary row || row.Count != 1)
                return false;
            if (row["op"] is not string s || s != ops[i])
                return false;
        }
        return true;
    }
}
