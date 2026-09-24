using Packbin;

var scheme = new Scheme<PositionRow>(0x40,
    Field.U16<PositionRow>(0, x => x.sid),
    Field.I32<PositionRow>(1, x => x.lat),
    Field.I32<PositionRow>(2, x => x.lon),
    Field.U8<PositionRow>(3, x => x.profile),
    Field.Flags(
        Field.U16<PositionRow>(4, x => x.heading),
        Field.U8<PositionRow>(5, x => x.speed),
        Field.I16<PositionRow>(6, x => x.altitude)));

var values = new Dictionary<string, object?>
{
    ["sid"] = (ushort)1,
    ["lat"] = 500_000_000,
    ["lon"] = 300_000_000,
    ["profile"] = (byte)1,
};

Console.WriteLine(Convert.ToHexString(Pack.Run(scheme, values)).ToLowerInvariant());

sealed class PositionRow
{
    public ushort sid { get; set; }
    public int lat { get; set; }
    public int lon { get; set; }
    public byte profile { get; set; }
    public ushort? heading { get; set; }
    public byte? speed { get; set; }
    public short? altitude { get; set; }
}
