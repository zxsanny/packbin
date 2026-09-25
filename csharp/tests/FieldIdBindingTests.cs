using System.Globalization;
using System.Linq.Expressions;
using Packbin;

namespace Packbin.Tests;

public class FieldIdBindingTests
{
    public sealed class MarkerRow
    {
        public ushort Sid { get; set; }
        public int Lat { get; set; }
        public int Lon { get; set; }
        public byte Kind { get; set; }
        public ushort? KindId { get; set; }
        public ushort Title { get; set; }
        public bool? Hidden { get; set; }
        public bool? Delta { get; set; }
    }

    public sealed class PointEl
    {
        public ushort Id { get; set; }
    }

    public sealed class PointsRow
    {
        public ushort Sid { get; set; }
        public ushort[]? Points { get; set; }
    }

    private static readonly Scheme<MarkerRow> MarkerScheme = new(0x20,
        Field.U16<MarkerRow>(0, x => x.Sid),
        Field.I32<MarkerRow>(1, x => x.Lat),
        Field.I32<MarkerRow>(2, x => x.Lon),
        Field.U8<MarkerRow>(3, x => x.Kind),
        Field.When(Condition.Eq(3, (byte)1),
            Field.U16<MarkerRow>(4, x => x.KindId)),
        Field.U16<MarkerRow>(5, x => x.Title),
        Field.Flags(
            Field.Bool<MarkerRow>(6, x => x.Hidden),
            Field.Bool<MarkerRow>(7, x => x.Delta)));

    [Fact]
    public void Ac1_MemberNamesAreNotWireNames()
    {
        var row = new MarkerRow
        {
            Sid = 1,
            Lat = 500_000_000,
            Lon = 300_000_000,
            Kind = 1,
            KindId = 0,
            Title = 0,
        };
        var bytes = BinaryPacker.Pack(MarkerScheme, row);
        var hex = Convert.ToHexString(bytes).ToLowerInvariant();
        Assert.Equal("2001000065cd1d00a3e111010000000000", hex);
        Assert.Equal(0x20, bytes[0]);
        Assert.Equal(500_000_000, BitConverter.ToInt32(bytes.AsSpan(3, 4)));
        MarkerRow? got = null;
        var err = BinaryPacker.Unpack(bytes, MarkerScheme.On(v => got = v));
        Assert.Null(err);
        Assert.NotNull(got);
        Assert.Equal(500_000_000, got.Lat);
        Assert.Equal((ushort)1, got.Sid);
        Assert.Equal(300_000_000, got.Lon);
        Assert.Equal((byte)1, got.Kind);
    }

    [Fact]
    public void Ac2_SiblingReferencesUseOrder()
    {
        var withKind = new MarkerRow
        {
            Sid = 1,
            Lat = 0,
            Lon = 0,
            Kind = 1,
            KindId = 9,
            Title = 0,
        };
        var hit = BinaryPacker.Pack(MarkerScheme, withKind);
        Assert.Equal((ushort)9, BitConverter.ToUInt16(hit.AsSpan(12, 2)));
        MarkerRow? hitRow = null;
        var hitErr = BinaryPacker.Unpack(hit, MarkerScheme.On(v => hitRow = v));
        Assert.Null(hitErr);
        Assert.Equal((ushort)9, hitRow!.KindId);

        var without = new MarkerRow
        {
            Sid = 1,
            Lat = 0,
            Lon = 0,
            Kind = 0,
            Title = 0,
        };
        var miss = BinaryPacker.Pack(MarkerScheme, without);
        Assert.Equal(hit.Length - 2, miss.Length);
        MarkerRow? missRow = null;
        var missErr = BinaryPacker.Unpack(miss, MarkerScheme.On(v => missRow = v));
        Assert.Null(missErr);
        Assert.Null(missRow!.KindId);
    }

    [Fact]
    public void Ac3_FlagsUseChildAccessors()
    {
        var row = new MarkerRow
        {
            Sid = 1,
            Lat = 0,
            Lon = 0,
            Kind = 0,
            Title = 0,
            Hidden = true,
            Delta = null,
        };
        var bytes = BinaryPacker.Pack(MarkerScheme, row);
        Assert.Equal(0x01, bytes[^1]);
        MarkerRow? got = null;
        var err = BinaryPacker.Unpack(bytes, MarkerScheme.On(v => got = v));
        Assert.Null(err);
        Assert.True(got!.Hidden);
        Assert.Null(got.Delta);
    }

    [Fact]
    public void Ac4_NestedRowTypeHasOwnIds()
    {
        var scheme = new Scheme<PointsRow>(0x20,
            Field.U16<MarkerRow>(0, x => x.Sid),
            Field.List((PointsRow x) => x.Points, Field.U16<PointEl>(0, p => p.Id)));
        var bytes = BinaryPacker.Pack(scheme, new PointsRow
        {
            Sid = 1,
            Points = [7, 8],
        });
        Assert.Equal(0x20, bytes[0]);
        Assert.Equal((ushort)1, BitConverter.ToUInt16(bytes.AsSpan(1, 2)));
        Assert.Equal((ushort)2, BitConverter.ToUInt16(bytes.AsSpan(3, 2)));
        Assert.Equal((ushort)7, BitConverter.ToUInt16(bytes.AsSpan(5, 2)));
        Assert.Equal((ushort)8, BitConverter.ToUInt16(bytes.AsSpan(7, 2)));
    }

    [Fact]
    public void Ac5_OrderMustMatchTheNumber()
    {
        Assert.ThrowsAny<ArgumentException>(() =>
            new Scheme<MarkerRow>(0x20, Field.I32<MarkerRow>(2, x => x.Lat)));
        Assert.ThrowsAny<ArgumentException>(() =>
            new Scheme<MarkerRow>(0x20,
                Field.U16<MarkerRow>(0, x => x.Sid),
                Field.I32<MarkerRow>(0, x => x.Lat)));
        Assert.ThrowsAny<ArgumentException>(() =>
            new Scheme<MarkerRow>(0x20,
                Field.U16<MarkerRow>(0, x => x.Sid),
                Field.I32<MarkerRow>(2, x => x.Lat)));
        Expression<Func<MarkerRow, int>> bad = x => x.Lat + 1;
        Assert.ThrowsAny<ArgumentException>(() => Field.I32(0, bad));
    }

    [Fact]
    public void Ac6_Ac1BytesStable()
    {
        var row = new MarkerRow
        {
            Sid = 1,
            Lat = 500_000_000,
            Lon = 300_000_000,
            Kind = 1,
            KindId = 0,
            Title = 0,
        };
        var bytes = BinaryPacker.Pack(MarkerScheme, row);
        Assert.Equal(0, PackbinTests.MismatchedBytes(
            bytes,
            PackbinTests.ParseHex("2001000065cd1d00a3e111010000000000")));
        Assert.Equal(500_000_000, Convert.ToInt32(BinaryPacker.Read(MarkerScheme, bytes).Values["Lat"]!, CultureInfo.InvariantCulture));
    }
}
