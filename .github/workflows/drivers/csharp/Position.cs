using Packbin;

var packet = Packet.Of(
    Field.U8("type"),
    Field.U16("sid"),
    Field.I32("lat"),
    Field.I32("lon"),
    Field.U8("profile"),
    Field.Flags("motion", Field.U16("heading"), Field.U8("speed"), Field.I16("altitude")));

var values = new Dictionary<string, object?>
{
    ["type"] = (byte)0x40,
    ["sid"] = (ushort)1,
    ["lat"] = 500_000_000,
    ["lon"] = 300_000_000,
    ["profile"] = (byte)1,
};

Console.WriteLine(Convert.ToHexString(Pack.Run(packet, values)).ToLowerInvariant());
