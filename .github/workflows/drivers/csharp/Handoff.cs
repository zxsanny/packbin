using System.Collections;
using Packbin;

static class Handoff
{
    static readonly Packet UserPacket = Packet.Of(
        Field.Utf8("username"),
        Field.List("roles", Field.Utf8("role")),
        Field.Dict("access", Field.List("actions", Field.Utf8("action"))));

    static readonly Packet NestedPacket = Packet.Of(
        Field.Dict("access", Field.List("rows", Field.Dict("fields", Field.Utf8("value")))));

    static readonly Dictionary<string, object?> UserValues = new()
    {
        ["username"] = "zxsanny",
        ["roles"] = new List<object?> { "user", "dispatcher" },
        ["access"] = new Dictionary<string, object?>
        {
            ["channel"] = new List<object?> { "read" },
            ["map"] = new List<object?> { "read", "gps_fix", "set", "edit" },
            ["store"] = new List<object?> { "read", "write" },
        },
    };

    static readonly Dictionary<string, object?> NestedValues = new()
    {
        ["access"] = new Dictionary<string, object?>
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

    static int Main(string[] args)
    {
        if (args.Length == 0)
            return 2;

        switch (args[0])
        {
            case "pack-user":
                Console.WriteLine(Convert.ToHexString(Pack.Run(UserPacket, UserValues)).ToLowerInvariant());
                return 0;
            case "pack-nested":
                Console.WriteLine(Convert.ToHexString(Pack.Run(NestedPacket, NestedValues)).ToLowerInvariant());
                return 0;
            case "unpack-user":
                if (args.Length < 2)
                    return 2;
                return UnpackUser(args[1]) ? 0 : 1;
            case "unpack-nested":
                if (args.Length < 2)
                    return 2;
                return UnpackNested(args[1]) ? 0 : 1;
            default:
                return 2;
        }
    }

    static bool UnpackUser(string hex)
    {
        var got = Unpack.Run(UserPacket, Convert.FromHexString(hex));
        if (got.Error is not null || got.Values.Count != 3)
            return false;
        if (!EqualsString(got.Values.GetValueOrDefault("username"), "zxsanny"))
            return false;
        if (!EqualsStringList(got.Values.GetValueOrDefault("roles"), "user", "dispatcher"))
            return false;
        if (got.Values.GetValueOrDefault("access") is not IDictionary access)
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
        var got = Unpack.Run(NestedPacket, Convert.FromHexString(hex));
        if (got.Error is not null)
            return false;
        if (got.Values.GetValueOrDefault("access") is not IDictionary access)
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
