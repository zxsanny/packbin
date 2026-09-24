using Packbin;

var scheme = new Scheme<PositionRow>(0x40,
    Field.U16<PositionRow>(0, x => x.Sid),
    Field.I32<PositionRow>(1, x => x.Lat),
    Field.I32<PositionRow>(2, x => x.Lon),
    Field.U8<PositionRow>(3, x => x.Profile),
    Field.Flags(
        Field.U16<PositionRow>(4, x => x.Heading),
        Field.U8<PositionRow>(5, x => x.Speed),
        Field.I16<PositionRow>(6, x => x.Altitude)));

var values = new Dictionary<string, object?>
{
    ["Sid"] = (ushort)1,
    ["Lat"] = 500_000_000,
    ["Lon"] = 300_000_000,
    ["Profile"] = (byte)1,
};

Console.WriteLine(Convert.ToHexString(BinaryPacker.Pack(scheme, values)).ToLowerInvariant());

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
