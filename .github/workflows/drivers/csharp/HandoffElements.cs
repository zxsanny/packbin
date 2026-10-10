using Packbin;

// The listgroup, dictgroup and listflags commands of Handoff (AZ-2119, AZ-2307, AZ-2239): a list of group, a dict of
// group and a list of flags, packed from and unpacked into typed rows. An absent value is a clear flag bit, so the
// flags item {b: 2} packs its flag byte as 02. Pack also writes the same row through the dictionary overload and fails
// when the two modes disagree.
static class HandoffElements
{
    sealed class Pair
    {
        public byte? A { get; set; }
        public byte? B { get; set; }
        public bool? Mark { get; set; }
    }

    sealed class FlagsItem
    {
        public byte? A { get; set; }
        public ushort? B { get; set; }
    }

    sealed class PairList
    {
        public List<Pair>? Pts { get; set; }
    }

    sealed class PairDict
    {
        public Dictionary<string, Pair>? M { get; set; }
    }

    sealed class FlagsList
    {
        public List<FlagsItem>? Pts { get; set; }
    }

    static Field PairGroup() =>
        Field.Group(0, (Pair p) => p.Mark, Field.U8<Pair>(0, p => p.A), Field.U8<Pair>(1, p => p.B));

    static readonly Scheme<PairList> ListGroup = new(1, Field.List((PairList r) => r.Pts, PairGroup()));
    static readonly Scheme<PairDict> DictGroup = new(1, Field.Dict((PairDict r) => r.M, PairGroup()));

    static readonly Scheme<FlagsList> ListFlags = new(1, Field.List((FlagsList r) => r.Pts,
        Field.Flags(0, Field.U8<FlagsItem>(0, p => p.A), Field.U16<FlagsItem>(1, p => p.B))));

    static Dictionary<string, object?> Item(byte? a = null, object? b = null)
    {
        var item = new Dictionary<string, object?>();
        if (a is not null)
            item["A"] = a;
        if (b is not null)
            item["B"] = b;
        return item;
    }

    // Packs the typed row and the same row as dictionary values; returns the hex, or null when the two modes differ.
    static string? Pack<T>(string kind, Scheme<T> scheme, T row, Dictionary<string, object?> values) where T : class, new()
    {
        var typed = Convert.ToHexString(BinaryPacker.Pack(scheme, row)).ToLowerInvariant();
        var dictionary = Convert.ToHexString(BinaryPacker.Pack(scheme, values)).ToLowerInvariant();
        if (typed == dictionary)
            return typed;
        Console.Error.WriteLine($"pack-{kind}: typed rows give {typed}, dictionary values give {dictionary}");
        return null;
    }

    // 2 for a command that is not one of these.
    public static int Run(string[] args)
    {
        var command = args[0];
        foreach (var kind in new[] { "listgroup", "dictgroup", "listflags" })
        {
            if (command == $"pack-{kind}")
                return PackKind(kind);
            var isShort = command == $"unpack-{kind}-short";
            if (!isShort && command != $"unpack-{kind}")
                continue;
            if (args.Length < 2 || args[1].Length == 0)
                return 2;
            var bytes = Convert.FromHexString(args[1]);
            return isShort ? ExpectRefusal(command, kind, bytes) : Unpack(command, kind, bytes);
        }
        return 2;
    }

    static int PackKind(string kind)
    {
        var hex = kind switch
        {
            "listgroup" => Pack(kind, ListGroup,
                new PairList { Pts = [new Pair { A = 1, B = 2 }, new Pair { A = 3, B = 4 }] },
                new() { ["Pts"] = new List<object?> { Item(1, (byte)2), Item(3, (byte)4) } }),
            "dictgroup" => Pack(kind, DictGroup,
                new PairDict { M = new() { ["y"] = new Pair { A = 3, B = 4 }, ["x"] = new Pair { A = 1, B = 2 } } },
                new() { ["M"] = new Dictionary<string, object?> { ["y"] = Item(3, (byte)4), ["x"] = Item(1, (byte)2) } }),
            _ => Pack(kind, ListFlags,
                new FlagsList { Pts = [new FlagsItem { A = 1 }, new FlagsItem(), new FlagsItem { B = 2 }] },
                new() { ["Pts"] = new List<object?> { Item(1), Item(), Item(b: (ushort)2) } }),
        };
        if (hex is null)
            return 1;
        Console.WriteLine(hex);
        return 0;
    }

    // A short element is refused and no row reaches the handler.
    static int ExpectRefusal(string command, string kind, byte[] bytes)
    {
        var (error, called) = Dispatch(kind, bytes);
        if (error is not null && !called)
            return 0;
        Console.Error.WriteLine($"{command}: error {error?.GetType().Name ?? "none"}, row delivered {called}; expected a refusal and no row");
        return 1;
    }

    static (object? Error, bool Called) Dispatch(string kind, byte[] bytes)
    {
        var called = false;
        object? error = kind switch
        {
            "listgroup" => BinaryPacker.Unpack(bytes, ListGroup.On(_ => called = true)),
            "dictgroup" => BinaryPacker.Unpack(bytes, DictGroup.On(_ => called = true)),
            _ => BinaryPacker.Unpack(bytes, ListFlags.On(_ => called = true)),
        };
        return (error, called);
    }

    static int Unpack(string command, string kind, byte[] bytes)
    {
        object? error;
        string? mismatch;
        switch (kind)
        {
            case "listgroup":
                PairList? pairs = null;
                error = BinaryPacker.Unpack(bytes, ListGroup.On(r => pairs = r));
                mismatch = pairs?.Pts is { } l && Same(l.Select(Show), "1,2", "3,4") ? null : Describe(pairs?.Pts?.Select(Show));
                break;
            case "dictgroup":
                PairDict? map = null;
                error = BinaryPacker.Unpack(bytes, DictGroup.On(r => map = r));
                mismatch = map?.M is { Count: 2 } m && m.TryGetValue("x", out var x) && m.TryGetValue("y", out var y)
                    && Show(x) == "1,2" && Show(y) == "3,4" ? null : Describe(map?.M?.Select(p => $"{p.Key}={Show(p.Value)}"));
                break;
            default:
                FlagsList? flags = null;
                error = BinaryPacker.Unpack(bytes, ListFlags.On(r => flags = r));
                mismatch = flags?.Pts is { } f && Same(f.Select(Show), "1,-", "-,-", "-,2") ? null : Describe(flags?.Pts?.Select(Show));
                break;
        }
        if (error is null && mismatch is null)
            return 0;
        Console.Error.WriteLine($"{command}: error {error?.GetType().Name ?? "none"}, read {mismatch ?? "the expected rows"}");
        return 1;
    }

    static string Show(Pair p) => $"{p.A?.ToString() ?? "-"},{p.B?.ToString() ?? "-"}";

    static string Show(FlagsItem p) => $"{p.A?.ToString() ?? "-"},{p.B?.ToString() ?? "-"}";

    static bool Same(IEnumerable<string> got, params string[] expected) => got.SequenceEqual(expected);

    static string Describe(IEnumerable<string>? rows) => rows is null ? "no rows" : "[" + string.Join(" ", rows) + "]";
}
