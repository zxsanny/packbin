using Packbin;

namespace Packbin.Tests;

public partial class HostileUnpackTests
{
    [Fact]
    public void Ac2_NegativeSizedCount_ReturnsShortPacket()
    {
        var scheme = new Scheme<SignedCountRow>(1,
            Field.I8<SignedCountRow>(0, x => x.N),
            Field.Sized<SignedCountRow>(1, x => x.P, 0));

        var outcome = HostileProbe.Unpack(scheme, "01ff");

        HostileProbe.ExpectShort(outcome, "P");
    }

    [Fact]
    public void Ac2_NegativeBitsCount_ReturnsShortPacket()
    {
        var scheme = new Scheme<SignedCountRow>(1,
            Field.I8<SignedCountRow>(0, x => x.N),
            Field.Bits<SignedCountRow>(1, x => x.Segs, 0));

        var outcome = HostileProbe.Unpack(scheme, "01ff");

        HostileProbe.ExpectShort(outcome, "Segs");
    }

    [Fact]
    public void Ac2_NegativePackedCount_ReturnsShortPacket()
    {
        var scheme = new Scheme<SignedCountRow>(1,
            Field.I8<SignedCountRow>(0, x => x.N),
            Field.Packed<SignedCountRow>(2, 1, x => x.Kinds, 0));

        var outcome = HostileProbe.Unpack(scheme, "01ff");

        HostileProbe.ExpectShort(outcome, "Kinds");
    }

    [Fact]
    public void Ac2_NegativeTimesCount_ReturnsShortPacket()
    {
        var scheme = new Scheme<SignedCountRow>(1,
            Field.I8<SignedCountRow>(0, x => x.N),
            Field.Times(1, 0, Field.U8<SignedCountRow>(1, x => x.X)));

        var outcome = HostileProbe.Unpack(scheme, "01ff");

        HostileProbe.ExpectShort(outcome, "times");
    }

    [Fact]
    public void Ac2_PackedBiasMakesCountNegative_ReturnsShortPacket()
    {
        var scheme = new Scheme<SignedCountRow>(1,
            Field.I8<SignedCountRow>(0, x => x.N),
            Field.Packed<SignedCountRow>(1, 1, x => x.Kinds, 0, -1));

        var outcome = HostileProbe.Unpack(scheme, "0100");

        HostileProbe.ExpectShort(outcome, "Kinds");
    }

    [Fact]
    public void Ac3_U32SizedCountAboveInt32_ReturnsShortPacketWithClampedNeeded()
    {
        var scheme = new Scheme<WideCountRow>(1,
            Field.U32<WideCountRow>(0, x => x.N),
            Field.Sized<WideCountRow>(1, x => x.P, 0));

        var outcome = HostileProbe.Unpack(scheme, "01ffffffff");

        var error = HostileProbe.ExpectShort(outcome, "P");
        Assert.Equal(0, error.Left);
        Assert.Equal(int.MaxValue, error.Needed);
    }

    [Fact]
    public void Ac3_U64SizedCountAboveInt64_ReturnsShortPacket()
    {
        var scheme = new Scheme<HugeCountRow>(1,
            Field.U64<HugeCountRow>(0, x => x.N),
            Field.Sized<HugeCountRow>(1, x => x.P, 0));

        var outcome = HostileProbe.Unpack(scheme, "01ffffffffffffffff61");

        var error = HostileProbe.ExpectShort(outcome, "P");
        Assert.Equal(1, error.Left);
        Assert.Equal(int.MaxValue, error.Needed);
    }

    [Fact]
    public void Ac3_U32SizedCountOneAboveAvailable_ReportsExactNeeded()
    {
        var scheme = new Scheme<WideCountRow>(1,
            Field.U32<WideCountRow>(0, x => x.N),
            Field.Sized<WideCountRow>(1, x => x.P, 0));

        var outcome = HostileProbe.Unpack(scheme, "0103000000" + "6162");

        var error = HostileProbe.ExpectShort(outcome, "P");
        Assert.Equal(3, error.Needed);
        Assert.Equal(2, error.Left);
    }

    [Fact]
    public void Ac3_U32BitsCountAboveInt32_ReturnsShortPacket()
    {
        var scheme = new Scheme<WideCountRow>(1,
            Field.U32<WideCountRow>(0, x => x.N),
            Field.Bits<WideCountRow>(1, x => x.Segs, 0));

        var outcome = HostileProbe.Unpack(scheme, "01ffffffff");

        var error = HostileProbe.ExpectShort(outcome, "Segs");
        Assert.Equal(0, error.Left);
    }

    [Fact]
    public void Ac3_U32PackedCountAboveInt32_ReturnsShortPacket()
    {
        var scheme = new Scheme<WideCountRow>(1,
            Field.U32<WideCountRow>(0, x => x.N),
            Field.Packed<WideCountRow>(2, 1, x => x.Kinds, 0));

        var outcome = HostileProbe.Unpack(scheme, "01ffffffff");

        var error = HostileProbe.ExpectShort(outcome, "Kinds");
        Assert.Equal(0, error.Left);
    }

    [Fact]
    public void Ac3_U32TimesCountAboveInt32_ReturnsShortPacket()
    {
        var scheme = new Scheme<WideCountRow>(1,
            Field.U32<WideCountRow>(0, x => x.N),
            Field.Times(1, 0, Field.U8<WideCountRow>(1, x => x.X)));

        var outcome = HostileProbe.Unpack(scheme, "01ffffffff00");

        var error = HostileProbe.ExpectShort(outcome, "X");
        Assert.Equal(1, error.Needed);
        Assert.Equal(0, error.Left);
    }

    [Fact]
    public void Ac4_SizedCountBehindClearFlag_ReturnsShortPacket()
    {
        var scheme = new Scheme<GatedCountRow>(1,
            Field.Flags(0, Field.U8<GatedCountRow>(0, x => x.N)),
            Field.Sized<GatedCountRow>(1, x => x.P, 0));

        var outcome = HostileProbe.Unpack(scheme, "010009");

        HostileProbe.ExpectShort(outcome, "P");
    }

    [Fact]
    public void Ac4_BitsCountBehindClearFlag_ReturnsShortPacket()
    {
        var scheme = new Scheme<GatedCountRow>(1,
            Field.Flags(0, Field.U8<GatedCountRow>(0, x => x.N)),
            Field.Bits<GatedCountRow>(1, x => x.Segs, 0));

        var outcome = HostileProbe.Unpack(scheme, "0100");

        HostileProbe.ExpectShort(outcome, "Segs");
    }

    [Fact]
    public void Ac4_PackedCountBehindClearFlag_ReturnsShortPacket()
    {
        var scheme = new Scheme<GatedCountRow>(1,
            Field.Flags(0, Field.U8<GatedCountRow>(0, x => x.N)),
            Field.Packed<GatedCountRow>(2, 1, x => x.Kinds, 0));

        var outcome = HostileProbe.Unpack(scheme, "0100");

        HostileProbe.ExpectShort(outcome, "Kinds");
    }

    [Fact]
    public void Ac4_TimesCountBehindClearFlag_ReturnsShortPacket()
    {
        var scheme = new Scheme<GatedCountRow>(1,
            Field.Flags(0, Field.U8<GatedCountRow>(0, x => x.N)),
            Field.Times(1, 0, Field.U8<GatedCountRow>(1, x => x.X)));

        var outcome = HostileProbe.Unpack(scheme, "0100");

        HostileProbe.ExpectShort(outcome, "times");
    }

    [Fact]
    public void Ac4_CountBehindSetFlag_StillUnpacks()
    {
        var scheme = new Scheme<GatedCountRow>(1,
            Field.Flags(0, Field.U8<GatedCountRow>(0, x => x.N)),
            Field.Sized<GatedCountRow>(1, x => x.P, 0));

        var outcome = HostileProbe.Unpack(scheme, "010102" + "0809");

        Assert.Null(outcome.Error);
        Assert.True(outcome.HandlerCalled);
    }

    private static string FloatHex(float value) =>
        Convert.ToHexString(BitConverter.GetBytes(value)).ToLowerInvariant();

    private static string DoubleHex(double value) =>
        Convert.ToHexString(BitConverter.GetBytes(value)).ToLowerInvariant();

    private static Scheme<FloatCountRow> FloatCount() => new(1,
        Field.F32<FloatCountRow>(0, x => x.F),
        Field.Sized<FloatCountRow>(1, x => x.P, 0));

    private static Scheme<DoubleCountRow> DoubleCount() => new(1,
        Field.F64<DoubleCountRow>(0, x => x.D),
        Field.Sized<DoubleCountRow>(1, x => x.P, 0));

    [Fact]
    public void Count_F32NaN_ReturnsShortPacket()
    {
        var outcome = HostileProbe.Unpack(FloatCount(), "01" + FloatHex(float.NaN));

        HostileProbe.ExpectShort(outcome, "P");
    }

    [Fact]
    public void Count_F32PositiveInfinity_ReturnsShortPacketWithClampedNeeded()
    {
        var outcome = HostileProbe.Unpack(FloatCount(), "01" + FloatHex(float.PositiveInfinity));

        var error = HostileProbe.ExpectShort(outcome, "P");
        Assert.Equal(int.MaxValue, error.Needed);
    }

    [Fact]
    public void Count_F32NegativeInfinity_ReturnsShortPacket()
    {
        var outcome = HostileProbe.Unpack(FloatCount(), "01" + FloatHex(float.NegativeInfinity));

        var error = HostileProbe.ExpectShort(outcome, "P");
        Assert.Equal(0, error.Needed);
    }

    [Fact]
    public void Count_F64Huge_ReturnsShortPacketWithClampedNeeded()
    {
        var outcome = HostileProbe.Unpack(DoubleCount(), "01" + DoubleHex(1e300));

        var error = HostileProbe.ExpectShort(outcome, "P");
        Assert.Equal(int.MaxValue, error.Needed);
    }

    [Fact]
    public void Count_F64HugeNegative_ReturnsShortPacket()
    {
        var outcome = HostileProbe.Unpack(DoubleCount(), "01" + DoubleHex(-1e300));

        var error = HostileProbe.ExpectShort(outcome, "P");
        Assert.Equal(0, error.Needed);
    }

    [Fact]
    public void Count_F64NaN_ReturnsShortPacket()
    {
        var outcome = HostileProbe.Unpack(DoubleCount(), "01" + DoubleHex(double.NaN));

        HostileProbe.ExpectShort(outcome, "P");
    }

    [Fact]
    public void Count_I64MaxValue_ReturnsShortPacketWithClampedNeeded()
    {
        var scheme = new Scheme<LongCountRow>(1,
            Field.I64<LongCountRow>(0, x => x.L),
            Field.Sized<LongCountRow>(1, x => x.P, 0));

        var outcome = HostileProbe.Unpack(scheme, "01ffffffffffffff7f61");

        var error = HostileProbe.ExpectShort(outcome, "P");
        Assert.Equal(int.MaxValue, error.Needed);
        Assert.Equal(1, error.Left);
    }

    [Fact]
    public void Count_I64MinValue_ReturnsShortPacket()
    {
        var scheme = new Scheme<LongCountRow>(1,
            Field.I64<LongCountRow>(0, x => x.L),
            Field.Sized<LongCountRow>(1, x => x.P, 0));

        var outcome = HostileProbe.Unpack(scheme, "010000000000000080");

        var error = HostileProbe.ExpectShort(outcome, "P");
        Assert.Equal(0, error.Needed);
    }

    [Theory]
    [InlineData(1L << 31, 8, int.MaxValue, 268435456)]
    [InlineData(int.MaxValue + 1L, 4, int.MaxValue, 536870912)]
    [InlineData(long.MaxValue, 8, int.MaxValue, int.MaxValue)]
    public void FitsItems_CountAboveInt32EvenWhenBytesFit_IsRejected(long wanted, int per, int left, int needed)
    {
        var fits = Walker.FitsItems(wanted, per, left, out var count, out var bytesNeeded);

        Assert.False(fits);
        Assert.Equal(0, count);
        Assert.Equal(needed, bytesNeeded);
    }

    [Theory]
    [InlineData(0L, 8, 0, 0)]
    [InlineData(9L, 8, 2, 2)]
    [InlineData(5L, 4, 2, 2)]
    [InlineData(int.MaxValue, 8, int.MaxValue, 268435456)]
    public void FitsItems_CountThatFits_ReturnsCountAndBytes(long wanted, int per, int left, int needed)
    {
        var fits = Walker.FitsItems(wanted, per, left, out var count, out var bytesNeeded);

        Assert.True(fits);
        Assert.Equal((int)wanted, count);
        Assert.Equal(needed, bytesNeeded);
    }

    [Fact]
    public void FitsItems_MoreBytesNeededThanLeft_IsRejected()
    {
        var fits = Walker.FitsItems(17, 8, 2, out _, out var bytesNeeded);

        Assert.False(fits);
        Assert.Equal(3, bytesNeeded);
    }

    [Fact]
    public void Times_ZeroWidthBodyWithU64MaxCount_ReturnsShortPacketQuickly()
    {
        var scheme = new Scheme<ZeroTimesRow>(1,
            Field.U64<ZeroTimesRow>(0, x => x.N),
            Field.Times(1, 0, Field.Bytes<ZeroTimesRow>(1, x => x.B, 0)));

        var outcome = HostileProbe.Unpack(scheme, "01ffffffffffffffff", 1);

        var error = HostileProbe.ExpectShort(outcome, "times");
        Assert.Equal(0, error.Needed);
        Assert.Equal(0, error.Left);
    }

    [Fact]
    public void Times_ZeroWidthBodyWithI64MaxCount_ReturnsShortPacketQuickly()
    {
        var scheme = new Scheme<SignedTimesRow>(1,
            Field.I64<SignedTimesRow>(0, x => x.N),
            Field.Times(1, 0, Field.Bytes<SignedTimesRow>(1, x => x.B, 0)));

        var outcome = HostileProbe.Unpack(scheme, "01ffffffffffffff7f", 1);

        HostileProbe.ExpectShort(outcome, "times");
    }

    [Fact]
    public void Times_ZeroWidthBodyWithU32MaxCount_ReturnsShortPacketQuickly()
    {
        var scheme = new Scheme<WideTimesRow>(1,
            Field.U32<WideTimesRow>(0, x => x.N),
            Field.Times(1, 0, Field.Bytes<WideTimesRow>(1, x => x.B, 0)));

        var outcome = HostileProbe.Unpack(scheme, "01ffffffff", 1);

        HostileProbe.ExpectShort(outcome, "times");
    }

    [Fact]
    public void Times_NeverTrueWhenBodyWithU32MaxCount_ReturnsShortPacketQuickly()
    {
        var scheme = new Scheme<GuardedTimesRow>(1,
            Field.U32<GuardedTimesRow>(0, x => x.N),
            Field.Times(1, 0,
                Field.Bytes<GuardedTimesRow>(1, x => x.B, 0),
                Field.When(2, Condition.Eq(1, new byte[] { 1 }), Field.U8<GuardedTimesRow>(2, x => x.V))));

        var outcome = HostileProbe.Unpack(scheme, "01ffffffff", 1);

        HostileProbe.ExpectShort(outcome, "times");
    }

    [Fact]
    public void Times_ZeroWidthBodyWithSmallCount_ReturnsShortPacketWithBytesLeft()
    {
        var scheme = new Scheme<SmallTimesRow>(1,
            Field.U8<SmallTimesRow>(0, x => x.N),
            Field.Times(1, 0, Field.Bytes<SmallTimesRow>(1, x => x.B, 0)));

        var outcome = HostileProbe.Unpack(scheme, "010309", 1);

        var error = HostileProbe.ExpectShort(outcome, "times");
        Assert.Equal(1, error.Left);
    }

    [Fact]
    public void Times_ZeroCount_StillUnpacksWithAZeroWidthBody()
    {
        var scheme = new Scheme<SmallTimesRow>(1,
            Field.U8<SmallTimesRow>(0, x => x.N),
            Field.Times(1, 0, Field.Bytes<SmallTimesRow>(1, x => x.B, 0)));

        var outcome = HostileProbe.Unpack(scheme, "0100", 1);

        Assert.Null(outcome.Error);
    }
}
