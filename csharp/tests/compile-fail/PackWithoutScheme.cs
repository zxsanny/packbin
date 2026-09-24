using Packbin;

public sealed class MarkerRow
{
    public byte sid { get; set; }
}

public static class Program
{
    public static void Main()
    {
        var row = new MarkerRow { sid = 23 };
        _ = Pack.Run(row);
    }
}
