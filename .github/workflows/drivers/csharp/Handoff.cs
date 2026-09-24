using System.Collections;
using Packbin;

static class Handoff
{
    sealed class RoleEl
    {
        public string role { get; set; } = "";
    }

    sealed class ActionEl
    {
        public string action { get; set; } = "";
    }

    sealed class ActionList
    {
        public List<object?>? actions { get; set; }
    }

    sealed class UserRow
    {
        public string username { get; set; } = "";
        public List<object?>? roles { get; set; }
        public Dictionary<string, object?>? access { get; set; }
    }

    sealed class ValueEl
    {
        public string value { get; set; } = "";
    }

    sealed class FieldDict
    {
        public Dictionary<string, object?>? fields { get; set; }
    }

    sealed class NestedRow
    {
        public Dictionary<string, object?>? access { get; set; }
    }

    static readonly Scheme<UserRow> UserScheme = new(1,
        Field.Utf8<UserRow>(0, x => x.username),
        Field.List((UserRow x) => x.roles, Field.Utf8<RoleEl>(0, r => r.role)),
        Field.Dict((UserRow x) => x.access, Field.List((ActionList e) => e.actions, Field.Utf8<ActionEl>(0, a => a.action))));

    static readonly Scheme<NestedRow> NestedScheme = new(1,
        Field.Dict((NestedRow x) => x.access, Field.List((FieldDict r) => r.fields, Field.Dict((FieldDict f) => f.fields, Field.Utf8<ValueEl>(0, v => v.value)))));

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
                Console.WriteLine(Convert.ToHexString(Pack.Run(UserScheme, UserValues)).ToLowerInvariant());
                return 0;
            case "pack-nested":
                Console.WriteLine(Convert.ToHexString(Pack.Run(NestedScheme, NestedValues)).ToLowerInvariant());
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
        var got = Unpack.Run(UserScheme, Convert.FromHexString(hex));
        if (!got.Ok || got.Value is null)
            return false;
        if (!EqualsString(got.Value.username, "zxsanny"))
            return false;
        if (!EqualsStringList(got.Value.roles, "user", "dispatcher"))
            return false;
        if (got.Value.access is not IDictionary access)
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
        var got = Unpack.Run(NestedScheme, Convert.FromHexString(hex));
        if (!got.Ok || got.Value is null)
            return false;
        if (got.Value.access is not IDictionary access)
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
