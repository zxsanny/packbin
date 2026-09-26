using System.Globalization;
using Packbin;

namespace Packbin.Tests;

public class BorrowedCountTests
{
    private sealed class KindRow
    {
        public byte N { get; set; }
        public List<int>? Kinds { get; set; }
    }

    private sealed class TailRow
    {
        public byte N { get; set; }
        public int Lat { get; set; }
        public int Lon { get; set; }
        public byte Tail { get; set; }
    }

    private sealed class RouteRow
    {
        public ushort Sid { get; set; }
        public ushort Name { get; set; }
        public ushort? Unit { get; set; }
        public bool Straight { get; set; }
        public ushort? RouteId { get; set; }
        public byte Count { get; set; }
        public List<int>? Kinds { get; set; }
        public int Lat { get; set; }
        public int Lon { get; set; }
        public List<int>? Mask { get; set; }
    }

    private static readonly Scheme<RouteRow> Route = new(0x34,
        Field.U16<RouteRow>(0, x => x.Sid),
        Field.U16<RouteRow>(1, x => x.Name),
        Field.Flags(
            Field.U16<RouteRow>(2, x => x.Unit),
            Field.Bool<RouteRow>(3, x => x.Straight),
            Field.U16<RouteRow>(4, x => x.RouteId)),
        Field.U8<RouteRow>(5, x => x.Count),
        Field.Packed<RouteRow>(2, 6, x => x.Kinds, 5),
        Field.Times(5,
            Field.I32<RouteRow>(7, x => x.Lat),
            Field.I32<RouteRow>(8, x => x.Lon)),
        Field.When(Condition.Eq(3, true),
            Field.Packed<RouteRow>(1, 9, x => x.Mask, 5, -1)));

    private const string RouteHex = "3410001500062d00020d0065cd1d00a3e111108ccd1d10cae11101";

    [Fact]
    public void Width2_FourValues_AreOneByte()
    {
        var scheme = new Scheme<KindRow>(1,
            Field.U8<KindRow>(0, x => x.N),
            Field.Packed<KindRow>(2, 1, x => x.Kinds, 0));
        var raw = BinaryPacker.Pack(scheme, new Dictionary<string, object?>
        {
            ["N"] = (byte)4,
            ["Kinds"] = new List<int> { 0, 1, 2, 3 },
        });
        Assert.Equal("e4", Convert.ToHexString(raw.AsSpan(2)).ToLowerInvariant());
        var got = BinaryPacker.Read(scheme, raw);
        Assert.Null(got.Error);
        Assert.Equal(new[] { 0, 1, 2, 3 }, ((List<int>)got.Values["Kinds"]!).ToArray());
    }

    [Fact]
    public void Width1_BiasMinusOne_WritesEightBitsOrNone()
    {
        var scheme = new Scheme<KindRow>(1,
            Field.U8<KindRow>(0, x => x.N),
            Field.Packed<KindRow>(1, 1, x => x.Kinds, 0, -1));
        var eight = BinaryPacker.Pack(scheme, new Dictionary<string, object?>
        {
            ["N"] = (byte)9,
            ["Kinds"] = new List<int> { 1, 1, 1, 1, 1, 1, 1, 1 },
        });
        Assert.Equal("ff", Convert.ToHexString(eight.AsSpan(2)).ToLowerInvariant());
        var none = BinaryPacker.Pack(scheme, new Dictionary<string, object?>
        {
            ["N"] = (byte)1,
            ["Kinds"] = new List<int>(),
        });
        Assert.Equal(0, none.Length - 2);
        var got = BinaryPacker.Read(scheme, none);
        Assert.Null(got.Error);
        Assert.Empty((List<int>)got.Values["Kinds"]!);
    }

    [Fact]
    public void LengthMismatch_NamesTheField()
    {
        var scheme = new Scheme<KindRow>(1,
            Field.U8<KindRow>(0, x => x.N),
            Field.Packed<KindRow>(2, 1, x => x.Kinds, 0));
        var ex = Assert.Throws<ArgumentException>(() =>
            BinaryPacker.Pack(scheme, new Dictionary<string, object?>
            {
                ["N"] = (byte)2,
                ["Kinds"] = new List<int> { 1 },
            }));
        Assert.Contains("Kinds", ex.Message, StringComparison.Ordinal);
    }

    [Fact]
    public void Times_StopsSoTheNextFieldIsRead()
    {
        var scheme = new Scheme<TailRow>(1,
            Field.U8<TailRow>(0, x => x.N),
            Field.Times(0, Field.I32<TailRow>(1, x => x.Lat), Field.I32<TailRow>(2, x => x.Lon)),
            Field.U8<TailRow>(3, x => x.Tail));
        var raw = BinaryPacker.Pack(scheme, new Dictionary<string, object?>
        {
            ["N"] = (byte)2,
            ["Lat"] = new List<int> { 10, 30 },
            ["Lon"] = new List<int> { 20, 40 },
            ["Tail"] = (byte)7,
        });
        Assert.Equal("020a000000140000001e0000002800000007", Convert.ToHexString(raw.AsSpan(1)).ToLowerInvariant());
        var got = BinaryPacker.Read(scheme, raw);
        Assert.Null(got.Error);
        Assert.Equal(7, Convert.ToInt32(got.Values["Tail"], CultureInfo.InvariantCulture));
        Assert.Equal(2, ((System.Collections.IList)got.Values["Lat"]!).Count);
    }

    [Fact]
    public void Route_MatchesFixtureAndRejectsAShortTail()
    {
        var raw = Convert.FromHexString(RouteHex);
        var got = BinaryPacker.Read(Route, raw);
        Assert.Null(got.Error);
        Assert.Equal(16, Convert.ToInt32(got.Values["Sid"], CultureInfo.InvariantCulture));
        Assert.Equal(new[] { 1, 3 }, ((List<int>)got.Values["Kinds"]!).ToArray());
        Assert.Equal(2, ((System.Collections.IList)got.Values["Lat"]!).Count);
        Assert.Equal(new[] { 1 }, ((List<int>)got.Values["Mask"]!).ToArray());

        var packed = BinaryPacker.Pack(Route, got.Values);
        Assert.Equal(RouteHex, Convert.ToHexString(packed).ToLowerInvariant());

        var shortTail = BinaryPacker.Read(Route, raw[..24]);
        var err = Assert.IsType<ShortPacket>(shortTail.Error);
        Assert.Equal("Lon", err.Field);
        Assert.Equal(4, err.Needed);
        Assert.Equal(2, err.Left);
        Assert.Empty(shortTail.Values);
    }
}
