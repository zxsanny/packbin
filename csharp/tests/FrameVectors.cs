namespace Packbin.Tests;

// Replays the rows of fixtures/frame/vectors.txt through the public API (contract pack-session 2.0.0, frame mode).
// A row's input fields build the call, every output field of the row is compared with what the call gave.
internal static class FrameVectors
{
    internal const byte Sentinel = 0xA5;

    internal sealed class Row
    {
        internal Row(Dictionary<string, string> fields) => Fields = fields;

        internal Dictionary<string, string> Fields { get; }

        internal string Op => Fields["op"];

        internal string Case => Fields["case"];

        internal string this[string name] => Fields[name];

        internal bool Has(string name) => Fields.ContainsKey(name);

        internal int Int(string name) => int.Parse(Fields[name], System.Globalization.CultureInfo.InvariantCulture);

        internal byte[] Bytes(string name) => Hex(Fields[name]);
    }

    internal static string FixturePath() => TextVectors.RepositoryFile("fixtures", "frame", "vectors.txt");

    internal static List<Row> Load(string path)
    {
        var rows = new List<Row>();
        foreach (var line in File.ReadAllLines(path))
        {
            if (line.Length == 0 || line[0] == '#')
                continue;
            var fields = new Dictionary<string, string>();
            foreach (var token in line.Split(' '))
            {
                var at = token.IndexOf('=');
                fields[token.Substring(0, at)] = token.Substring(at + 1);
            }
            rows.Add(new Row(fields));
        }
        return rows;
    }

    internal static byte[] Hex(string text) => text == "-" ? [] : Convert.FromHexString(text);

    internal static string Unhex(ReadOnlySpan<byte> bytes) => bytes.IsEmpty ? "-" : Convert.ToHexString(bytes).ToLowerInvariant();

    internal static string KindName(object? error) => error switch
    {
        BadValue => "BadValue",
        TooLong => "TooLong",
        BufferFull => "BufferFull",
        ShortPacket => "ShortPacket",
        TagMismatch => "TagMismatch",
        Duplicate => "Duplicate",
        TooOld => "TooOld",
        null => "Ok",
        _ => "other:" + error.GetType().Name,
    };

    internal static string WindowText(ReplayWindow window) => $"{window.Top:x}:{window.Bits:x}";

    internal static FrameDirections Dirs(Row row)
    {
        var set = FrameDirections.None;
        foreach (var c in row.Has("dirs") ? row["dirs"] : "123")
            set |= (FrameDirections)(1 << (c - '1'));
        return set;
    }

    internal static FrameSession? LoadSession(Row row) =>
        FrameSession.Load(row.Bytes("key"), uint.Parse(row["epoch"]), new FrameConfig(row.Has("tag_len") ? row.Int("tag_len") : 4, Dirs(row)));

    internal static MsgContext Context(Row row) => new(row.Bytes("msg_id"), row.Int("kind"));

    // The fields of a row that are outputs (the others are inputs): "body" and "plain" are outputs of seal and open only.
    internal static string[] OutputNames(string op) => op switch
    {
        "keys" => ["k_enc", "k_mac", "k_label"],
        "seal" => ["body", "result"],
        "open" => ["result", "slot", "plain", "window_after"],
        "mac" => ["tag", "valid", "result"],
        _ => ["results", "states"],
    };

    // The output fields the call gave for the row; a row with an error result gives `result` only.
    internal static Dictionary<string, string> Run(Row row)
    {
        switch (row.Op)
        {
            case "keys": return RunKeys(row);
            case "seal": return RunSeal(row);
            case "open": return RunOpen(row);
            case "mac": return RunMac(row);
            case "replay": return RunReplay(row);
            default: throw new InvalidOperationException("unknown op " + row.Op);
        }
    }

    // Every mismatch of every row, as "case field: expected X, got Y".
    internal static List<string> Mismatches(IEnumerable<Row> rows)
    {
        var problems = new List<string>();
        foreach (var row in rows)
        {
            var got = Run(row);
            foreach (var name in OutputNames(row.Op))
            {
                if (!row.Has(name))
                    continue;
                if (!got.TryGetValue(name, out var value))
                    problems.Add($"{row.Case} {name}: the row has it and the call gave none");
                else if (value != row[name])
                    problems.Add($"{row.Case} {name}: expected {row[name]}, got {value}");
            }
        }
        return problems;
    }

    private static Dictionary<string, string> RunKeys(Row row)
    {
        var epoch = uint.Parse(row["epoch"]);
        if (row.Has("label"))
        {
            using var mac = MacKey.Derive(row.Bytes("key"), epoch, row.Bytes("label"));
            return new Dictionary<string, string> { ["k_label"] = mac is null ? "BadValue" : Unhex(mac.KeyArray) };
        }
        var dir = (FrameDirection)row.Int("dir");
        using var session = FrameSession.Load(row.Bytes("key"), epoch, new FrameConfig(4, (FrameDirections)(1 << ((int)dir - 1))));
        return new Dictionary<string, string>
        {
            ["k_enc"] = session is null ? "BadValue" : Unhex(session.CurrentKeys.Enc(dir)),
            ["k_mac"] = session is null ? "BadValue" : Unhex(session.CurrentKeys.Mac(dir)),
        };
    }

    private static Dictionary<string, string> RunSeal(Row row)
    {
        var got = new Dictionary<string, string>();
        using var session = LoadSession(row);
        if (session is null)
        {
            got["result"] = "BadValue";
            return got;
        }
        var buffer = new byte[row.Has("out_len") ? row.Int("out_len") : 300];
        Array.Fill(buffer, Sentinel);
        var error = session.Seal((FrameDirection)row.Int("dir"), Context(row), row.Bytes("ad"), row.Bytes("clear"), row.Bytes("plain"), buffer, out var written);
        if (error is null)
        {
            got["body"] = Unhex(buffer.AsSpan(0, written));
            return got;
        }
        got["result"] = KindName(error);
        if (written != 0 || buffer.Any(b => b != Sentinel))
            got["result"] += " (a refused seal wrote bytes)";
        return got;
    }

    private static Dictionary<string, string> RunOpen(Row row)
    {
        var got = new Dictionary<string, string>();
        ReplayWindow? window = null;
        if (row.Has("window"))
        {
            var parts = row["window"].Split(':');
            window = new ReplayWindow(Convert.ToUInt64(parts[0], 16), Convert.ToUInt64(parts[1], 16));
        }
        var before = window is null ? null : WindowText(window);
        var session = LoadSession(row);
        if (session is not null && row.Has("prev_key") && !session.SetPrevious(row.Bytes("prev_key"), uint.Parse(row["prev_epoch"])))
        {
            session.Dispose();
            session = null;
        }
        if (session is null)
        {
            got["result"] = "BadValue";
        }
        else
        {
            using (session)
            {
                var buffer = new byte[row.Has("out_len") ? row.Int("out_len") : 300];
                Array.Fill(buffer, Sentinel);
                var counter = row.Has("counter") ? ulong.Parse(row["counter"]) : 0UL;
                var error = session.Open((FrameDirection)row.Int("dir"), Context(row), row.Bytes("ad"), row.Bytes("body"), row.Int("clear_len"), buffer,
                    out var opened, window, counter);
                got["result"] = KindName(error);
                if (error is null)
                {
                    got["slot"] = opened.Slot == FrameSlot.Current ? "current" : "previous";
                    got["plain"] = Unhex(buffer.AsSpan(0, opened.PlainLength));
                }
                else
                {
                    if (buffer.Any(b => b != Sentinel))
                        got["result"] += " (a refused open wrote bytes)";
                    if (window is not null && WindowText(window) != before)
                        got["result"] += " (a refused open changed the window)";
                }
            }
        }
        if (window is not null)
            got["window_after"] = WindowText(window);
        return got;
    }

    private static Dictionary<string, string> RunMac(Row row)
    {
        var got = new Dictionary<string, string>();
        using var mac = MacKey.Derive(row.Bytes("key"), uint.Parse(row["epoch"]), row.Bytes("label"));
        if (mac is null)
        {
            got["result"] = "BadValue";
            return got;
        }
        var parts = (row.Has("parts") ? row["parts"].Split('|').Select(Hex) : [Hex(row["message"])]).Select(p => (ReadOnlyMemory<byte>)p).ToArray();
        if (row.Has("verify"))
        {
            got["valid"] = mac.Verify(parts, row.Bytes("verify")) ? "true" : "false";
            return got;
        }
        var tag = new byte[row.Int("n")];
        var error = mac.Tag(parts, tag);
        if (error is null)
            got["tag"] = Unhex(tag);
        else
            got["result"] = KindName(error);
        return got;
    }

    private static Dictionary<string, string> RunReplay(Row row)
    {
        var window = new ReplayWindow();
        var results = new List<string>();
        var states = new List<string>();
        foreach (var step in row["steps"].Split(','))
        {
            var colon = step.IndexOf(':');
            var n = ulong.Parse(step.Substring(colon + 1));
            if (step.StartsWith("check", StringComparison.Ordinal))
                results.Add(window.Check(n).ToString());
            else
            {
                window.Commit(n);
                states.Add(WindowText(window));
            }
        }
        return new Dictionary<string, string> { ["results"] = string.Join(',', results), ["states"] = states.Count == 0 ? "-" : string.Join(',', states) };
    }
}
