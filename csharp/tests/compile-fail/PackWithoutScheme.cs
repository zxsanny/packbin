using Packbin;

public sealed class MarkerRow
{
    public byte Sid { get; set; }
}

public static class Program
{
    public static void Main()
    {
        var row = new MarkerRow { Sid = 23 };
        _ = BinaryPacker.Pack(row);
    }
}
