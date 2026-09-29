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
