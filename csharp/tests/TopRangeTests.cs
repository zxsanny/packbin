using Packbin;

namespace Packbin.Tests;

public class TopRangeTests
{
    private sealed class WideRow
    {
        public ulong? U64v { get; set; }
        public long? I64v { get; set; }
    }

    private sealed class ListRow
    {
        public List<object?>? Xs { get; set; }
    }

    private sealed class MapRow
    {
        public Dictionary<string, object?>? M { get; set; }
    }

    private sealed class ByteEl
    {
        public byte V { get; set; }
    }

    private sealed class SignedCountRow
    {
        public long N { get; set; }
        public List<int>? Kinds { get; set; }
    }

    private static readonly Scheme<WideRow> U64Scheme = new(1, Field.U64<WideRow>(0, x => x.U64v));

    private static readonly Scheme<WideRow> I64Scheme = new(1, Field.I64<WideRow>(0, x => x.I64v));

    private static WideRow Unpack(Scheme<WideRow> scheme, string hex)
    {
        WideRow? row = null;
        var error = BinaryPacker.Unpack(Convert.FromHexString(hex), scheme.On(r => row = r));
        Assert.Null(error);
        return row!;
    }

    [Theory]
    [InlineData("01ffffffffffffffff", ulong.MaxValue)]
    [InlineData("01fffbffffffffffff", 0xFFFFFFFFFFFFFBFFUL)]
    [InlineData("0100fcffffffffffff", 0xFFFFFFFFFFFFFC00UL)]
    [InlineData("010000000000000080", 0x8000000000000000UL)]
    [InlineData("010100000000000080", 0x8000000000000001UL)]
    public void TopRangeU64_DoesNotThrowAndKeepsTheExactValue(string hex, ulong expected)
    {
        var row = Unpack(U64Scheme, hex);

        Assert.Equal(expected, row.U64v);
    }

    [Theory]
    [InlineData("01ffffffffffffff7f", long.MaxValue)]
    [InlineData("01fffdffffffffff7f", 0x7FFFFFFFFFFFFDFFL)]
    [InlineData("0100feffffffffff7f", 0x7FFFFFFFFFFFFE00L)]
    [InlineData("010000000000000080", long.MinValue)]
    [InlineData("010100000000000080", long.MinValue + 1)]
    public void TopRangeI64_DoesNotThrowAndKeepsTheExactValue(string hex, long expected)
    {
        var row = Unpack(I64Scheme, hex);

        Assert.Equal(expected, row.I64v);
    }

    [Fact]
    public void TopRangeU64_RoundTripsThroughPack()
    {
        var raw = BinaryPacker.Pack(U64Scheme, new WideRow { U64v = ulong.MaxValue });

        var row = Unpack(U64Scheme, Convert.ToHexString(raw));

        Assert.Equal(ulong.MaxValue, row.U64v);
    }

    [Fact]
    public void NegativeI64CountWithPackedBias_IsABadValueNotAHugeCount()
    {
        var scheme = new Scheme<SignedCountRow>(1,
            Field.I64<SignedCountRow>(0, x => x.N),
            Field.Packed<SignedCountRow>(1, 1, x => x.Kinds, 0, -1));

        var outcome = HostileProbe.Unpack(scheme, "010000000000000080");

        var error = HostileProbe.ExpectShort(outcome, "Kinds");
        Assert.Equal(0, error.Needed);
    }

    [Fact]
    public void ListCountFFFF_AllocatesLittle()
    {
        var scheme = new Scheme<ListRow>(1, Field.List((ListRow x) => x.Xs, Field.U8<ByteEl>(0, x => x.V)));
        var raw = Convert.FromHexString("01ffff");

        var allocated = Measure(() => BinaryPacker.Read(scheme, raw));

        Assert.True(allocated < 4096, $"allocated {allocated} bytes");
        Assert.IsType<ShortPacket>(BinaryPacker.Read(scheme, raw).Error);
    }

    [Fact]
    public void DictCountFFFF_AllocatesLittle()
    {
        var scheme = new Scheme<MapRow>(1, Field.Dict((MapRow x) => x.M, Field.U8<ByteEl>(0, x => x.V)));
        var raw = Convert.FromHexString("01ffff");

        var allocated = Measure(() => BinaryPacker.Read(scheme, raw));

        Assert.True(allocated < 4096, $"allocated {allocated} bytes");
        Assert.IsType<ShortPacket>(BinaryPacker.Read(scheme, raw).Error);
    }

    private static long Measure(Action action)
    {
        action();
        var before = GC.GetAllocatedBytesForCurrentThread();
        action();
        return GC.GetAllocatedBytesForCurrentThread() - before;
    }
}
