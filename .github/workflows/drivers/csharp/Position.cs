using Packbin;

var scheme = new Scheme<PositionRow>(0x40,
    Field.U16("sid"),
    Field.I32("lat"),
    Field.I32("lon"),
    Field.U8("profile"),
    Field.Flags("motion", Field.U16("heading"), Field.U8("speed"), Field.I16("altitude")));

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
