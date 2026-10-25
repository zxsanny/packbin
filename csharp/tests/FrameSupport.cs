namespace Packbin.Tests;

// The worked examples E1 to E3 of the contract as open inputs, read from their rows of fixtures/frame/vectors.txt.
internal sealed class FrameExample
{
    internal required string Name { get; init; }
    internal required byte[] Key { get; init; }
    internal required uint Epoch { get; init; }
    internal required FrameDirection Direction { get; init; }
    internal required int TagLength { get; init; }
    internal required byte[] MsgId { get; init; }
    internal required int Kind { get; init; }
    internal required byte[] Ad { get; init; }
    internal required int ClearLength { get; init; }
    internal required byte[] Body { get; init; }
    internal required byte[] Plain { get; init; }

    internal MsgContext Context => new(MsgId, Kind);

    internal static List<FrameExample> Worked()
    {
        var rows = FrameVectors.Load(FrameVectors.FixturePath());
        return new[] { "E1", "E2", "E3" }.Select(n => From(rows.Single(r => r.Case == n + ".open"), n)).ToList();
    }

    internal static FrameExample From(FrameVectors.Row row, string name) => new()
    {
        Name = name,
        Key = row.Bytes("key"),
        Epoch = uint.Parse(row["epoch"]),
        Direction = (FrameDirection)row.Int("dir"),
        TagLength = row.Int("tag_len"),
        MsgId = row.Bytes("msg_id"),
        Kind = row.Int("kind"),
        Ad = row.Bytes("ad"),
        ClearLength = row.Int("clear_len"),
        Body = row.Bytes("body"),
        Plain = row.Bytes("plain"),
    };

    internal FrameSession Session(byte[]? key = null, uint? epoch = null) =>
        FrameSession.Load(key ?? Key, epoch ?? Epoch, new FrameConfig(TagLength, FrameDirections.All))!;
}
