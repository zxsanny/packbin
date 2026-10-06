using System.Buffers.Binary;
using Packbin;

namespace Packbin.Tests;

// A scheme carries maxRounds and maxSlots. An unpack that would start a round above either is refused with the interim
// bad-value error ShortPacket(round field name, 0, bytes left) when that round would start, before its bytes are read.
public class RoundLimitTests
{
    private sealed class RepeatRow
    {
        public byte? K { get; set; }
    }

    private sealed class TimesRow
    {
        public byte N { get; set; }
        public byte? K { get; set; }
        public byte? V { get; set; }
    }

    private sealed class WideCountRow
    {
        public uint N { get; set; }
        public byte? K { get; set; }
    }

    private sealed class WhenRow
    {
        public byte? K { get; set; }
        public byte? A { get; set; }
        public byte? B { get; set; }
        public byte? C { get; set; }
    }

    private static Scheme<RepeatRow> OneByteRepeat(int typeNumber = 1) =>
        new(typeNumber, Field.Repeat(0, Field.U8<RepeatRow>(0, x => x.K)));

    private static Scheme<TimesRow> ByteTimes() => new(1,
        Field.U8<TimesRow>(0, x => x.N),
        Field.Times(1, 0, Field.U8<TimesRow>(1, x => x.K)));

    private static Scheme<WideCountRow> WideTimes() => new(1,
        Field.U32<WideCountRow>(0, x => x.N),
        Field.Times(1, 0, Field.U8<WideCountRow>(1, x => x.K)));

    private static Scheme<WhenRow> ThreeNames() => new(1,
        Field.Repeat(0,
            Field.U8<WhenRow>(0, x => x.K),
            Field.When(1, Condition.Eq(0, (byte)1), Field.U8<WhenRow>(1, x => x.A), Field.U8<WhenRow>(2, x => x.B))));

    private static Scheme<WhenRow> FourNames() => new(1,
        Field.Repeat(0,
            Field.U8<WhenRow>(0, x => x.K),
            Field.When(1, Condition.Eq(0, (byte)1),
                Field.U8<WhenRow>(1, x => x.A), Field.U8<WhenRow>(2, x => x.B), Field.U8<WhenRow>(3, x => x.C))));

    private static byte[] Packet(string hex) => Convert.FromHexString(hex);

    // Type 01 followed by `rounds` one-byte rounds.
    private static byte[] OneByteRounds(int rounds)
    {
        var bytes = new byte[1 + rounds];
        bytes[0] = 1;
        for (var i = 1; i < bytes.Length; i++)
            bytes[i] = (byte)i;
        return bytes;
    }

    // Type 01, a u32 count, then `rounds` one-byte rounds.
    private static byte[] WideCountPacket(uint count, int rounds)
    {
        var bytes = new byte[5 + rounds];
        bytes[0] = 1;
        BinaryPrimitives.WriteUInt32LittleEndian(bytes.AsSpan(1, 4), count);
        return bytes;
    }

    private static ShortPacket Refused(object? error, string field, int left)
    {
        var refusal = Assert.IsType<ShortPacket>(error);
        Assert.Equal(field, refusal.Field);
        Assert.Equal(0, refusal.Needed);
        Assert.Equal(left, refusal.Left);
        return refusal;
    }

    private static int?[] Cells(UnpackResult result, string name) => RoundValueTests.Cells(result.Values[name]);

    private static List<object?> Entries(UnpackResult result, string name) =>
        (List<object?>)result.Values[name]!;

    [Fact]
    public void Ac1_DefaultsAndConstants()
    {
        // Arrange
        var scheme = OneByteRepeat();

        // Act
        var viaWithLimits = scheme.WithLimits();
        var lowRounds = scheme.WithLimits(maxRounds: 10);

        // Assert
        Assert.Equal(65_535, BinaryPacker.DefaultMaxRounds);
        Assert.Equal(4_194_304L, BinaryPacker.DefaultMaxSlots);
        Assert.Equal(65_535, scheme.MaxRounds);
        Assert.Equal(4_194_304L, scheme.MaxSlots);
        Assert.Equal(65_535, viaWithLimits.MaxRounds);
        Assert.Equal(4_194_304L, viaWithLimits.MaxSlots);
        Assert.Equal(10, lowRounds.MaxRounds);
        Assert.Equal(4_194_304L, lowRounds.MaxSlots);
    }

    [Fact]
    public void Ac1_WithLimits_OmittedArgumentIsTheDefaultNotTheReceiversValue()
    {
        // Arrange
        var strict = OneByteRepeat().WithLimits(maxRounds: 10, maxSlots: 20);

        // Act
        var relaxed = strict.WithLimits(maxSlots: 30);

        // Assert
        Assert.Equal(65_535, relaxed.MaxRounds);
        Assert.Equal(30L, relaxed.MaxSlots);
        Assert.Equal(10, strict.MaxRounds);
        Assert.Equal(20L, strict.MaxSlots);
    }

    [Fact]
    public void Ac2_Repeat_DefaultLimit_AcceptsMaxRoundsAndRefusesOneMore()
    {
        // Arrange
        var scheme = OneByteRepeat();
        var accepted = OneByteRounds(BinaryPacker.DefaultMaxRounds);
        var refused = OneByteRounds(BinaryPacker.DefaultMaxRounds + 1);
        var handlerCalled = false;

        // Act
        var ok = BinaryPacker.Read(scheme, accepted);
        var error = BinaryPacker.Unpack(refused, scheme.On(_ => handlerCalled = true));

        // Assert
        Assert.Null(ok.Error);
        Assert.Equal(BinaryPacker.DefaultMaxRounds, Entries(ok, "K").Count);
        Refused(error, "", 1);
        Assert.False(handlerCalled);
    }

    [Fact]
    public void Ac3_Repeat_RefusedWhenTheNextRoundWouldStart()
    {
        // Arrange
        var scheme = OneByteRepeat().WithLimits(maxRounds: 3);

        // Act
        var ok = BinaryPacker.Read(scheme, Packet("01aabbcc"));
        var refused = BinaryPacker.Read(scheme, Packet("01aabbccdd"));

        // Assert
        Assert.Null(ok.Error);
        Assert.Equal<int?>([0xaa, 0xbb, 0xcc], Cells(ok, "K"));
        Refused(refused.Error, "", 1);
        Assert.False(refused.Values.ContainsKey("K"));
    }

    [Fact]
    public void Ac4_Times_RefusedWhenTheNextRoundWouldStart()
    {
        // Arrange
        var scheme = ByteTimes().WithLimits(maxRounds: 3);

        // Act
        var ok = BinaryPacker.Read(scheme, Packet("0103090909"));
        var overByOne = BinaryPacker.Read(scheme, Packet("010409090909"));
        var overByCountOnly = BinaryPacker.Read(scheme, Packet("0104090909"));
        var hugeCountOneRound = BinaryPacker.Read(scheme, Packet("01ff09"));
        var shortBelowLimit = BinaryPacker.Read(scheme, Packet("01030909"));

        // Assert
        Assert.Null(ok.Error);
        Assert.Equal<int?>([9, 9, 9], Cells(ok, "K"));
        Refused(overByOne.Error, "times", 1);
        Refused(overByCountOnly.Error, "times", 0);
        AssertShortRead(hugeCountOneRound.Error, "K");
        AssertShortRead(shortBelowLimit.Error, "K");
    }

    // A round that is read and runs out of bytes: today's short read, not a refusal.
    private static void AssertShortRead(object? error, string field)
    {
        var shortPacket = Assert.IsType<ShortPacket>(error);
        Assert.Equal(field, shortPacket.Field);
        Assert.Equal(1, shortPacket.Needed);
        Assert.Equal(0, shortPacket.Left);
    }

    [Fact]
    public void Ac5_Times_DefaultLimit_U32Count()
    {
        // Arrange
        var scheme = WideTimes();
        var max = BinaryPacker.DefaultMaxRounds;

        // Act
        var accepted = BinaryPacker.Read(scheme, WideCountPacket((uint)max, max));
        var overByOne = BinaryPacker.Read(scheme, WideCountPacket((uint)max + 1, max + 1));
        var hugeCountEnoughBytes = BinaryPacker.Read(scheme, WideCountPacket(uint.MaxValue, max + 1));
        var hugeCountOneRoundShort = BinaryPacker.Read(scheme, WideCountPacket(uint.MaxValue, max));
        var hugeCountOneRound = BinaryPacker.Read(scheme, Packet("01ffffffff00"));

        // Assert
        Assert.Null(accepted.Error);
        Assert.Equal(max, Entries(accepted, "K").Count);
        Refused(overByOne.Error, "times", 1);
        Refused(hugeCountEnoughBytes.Error, "times", 1);
        Refused(hugeCountOneRoundShort.Error, "times", 0);
        AssertShortRead(hugeCountOneRound.Error, "K");
    }

    [Fact]
    public void Ac6_SlotLimit_CountsEveryNameTheRoundCanHold()
    {
        // Arrange
        var scheme = ThreeNames().WithLimits(maxSlots: 6);

        // Act
        var exactly = BinaryPacker.Read(scheme, Packet("010000"));
        var oneRoundOver = BinaryPacker.Read(scheme, Packet("01000000"));
        var twoRoundsOver = BinaryPacker.Read(scheme, Packet("0100000000"));

        // Assert
        Assert.Null(exactly.Error);
        Assert.Equal(2, Entries(exactly, "K").Count);
        Assert.Equal(2, Entries(exactly, "A").Count);
        Refused(oneRoundOver.Error, "", 1);
        Refused(twoRoundsOver.Error, "", 2);
    }

    [Fact]
    public void Ac7_SlotTotalIsSharedByEveryFieldOfOneCall()
    {
        // Arrange
        var scheme = new Scheme<TimesRow>(1,
            Field.U8<TimesRow>(0, x => x.N),
            Field.Times(1, 0, Field.U8<TimesRow>(1, x => x.K)),
            Field.Times(2, 0, Field.U8<TimesRow>(2, x => x.V)));
        var packet = Packet("0102aabbccdd");

        // Act
        var enough = BinaryPacker.Read(scheme.WithLimits(maxRounds: 3, maxSlots: 4), packet);
        var tooFew = BinaryPacker.Read(scheme.WithLimits(maxRounds: 3, maxSlots: 3), packet);

        // Assert
        Assert.Null(enough.Error);
        Assert.Equal(2, Entries(enough, "V").Count);
        Refused(tooFew.Error, "times", 1);
    }

    [Fact]
    public void Ac7_TwoCallsDoNotShareTheSlotTotal()
    {
        // Arrange
        var scheme = ThreeNames().WithLimits(maxSlots: 6);
        var packet = Packet("010000");

        // Act
        var first = BinaryPacker.Read(scheme, packet);
        var second = BinaryPacker.Read(scheme, packet);

        // Assert
        Assert.Null(first.Error);
        Assert.Null(second.Error);
    }

    [Fact]
    public void Ac8_RefusedOneMiBPacket_AllocationIsBoundedByTheLimits()
    {
        // Arrange
        var scheme = FourNames();
        var packet = new byte[1 + (1 << 20)];
        packet[0] = 1;
        var handlerCalled = false;
        Assert.Null(BinaryPacker.Read(scheme, packet.AsSpan(0, 64)).Error);

        // Act
        var before = GC.GetAllocatedBytesForCurrentThread();
        var error = BinaryPacker.Unpack(packet, scheme.On(_ => handlerCalled = true));
        var allocated = GC.GetAllocatedBytesForCurrentThread() - before;

        // Assert
        Refused(error, "", 983_041);
        Assert.False(handlerCalled);
        Assert.True(allocated < 128L * 1024 * 1024, $"allocated {allocated / (1024 * 1024)} MiB");
    }

    [Fact]
    public void Ac9_LimitsBelongToTheScheme()
    {
        // Arrange
        var scheme = OneByteRepeat();
        var strict = scheme.WithLimits(maxRounds: 3);
        var other = OneByteRepeat(2).WithLimits(maxRounds: 2);
        var calls = 0;

        // Act
        var receiver = BinaryPacker.Read(scheme, Packet("01aabbccdd"));
        var strictError = BinaryPacker.Unpack(Packet("01aabbccdd"), strict.On(_ => calls++));
        var dispatchError = BinaryPacker.Unpack(Packet("02aabbcc"), scheme.On(_ => calls++), other.On(_ => calls++));

        // Assert
        Assert.Null(receiver.Error);
        Assert.Equal(4, Entries(receiver, "K").Count);
        Refused(strictError, "", 1);
        Refused(dispatchError, "", 1);
        Assert.Equal(0, calls);
    }

    [Theory]
    [InlineData(0, 1L, "maxRounds")]
    [InlineData(-1, 1L, "maxRounds")]
    [InlineData(1, 0L, "maxSlots")]
    [InlineData(1, -1L, "maxSlots")]
    public void Ac10_InvalidLimits_AreRefusedAtConstruction(int maxRounds, long maxSlots, string paramName)
    {
        // Arrange
        var scheme = OneByteRepeat();

        // Act
        var thrown = Assert.Throws<ArgumentOutOfRangeException>(() => scheme.WithLimits(maxRounds, maxSlots));

        // Assert
        Assert.Equal(paramName, thrown.ParamName);
    }

    [Fact]
    public void Ac10_LargestLimits_AreValidAndAcceptMoreThanTheDefaultRounds()
    {
        // Arrange
        var scheme = OneByteRepeat().WithLimits(int.MaxValue, long.MaxValue);

        // Act
        var result = BinaryPacker.Read(scheme, OneByteRounds(BinaryPacker.DefaultMaxRounds + 1));

        // Assert
        Assert.Null(result.Error);
        Assert.Equal(BinaryPacker.DefaultMaxRounds + 1, Entries(result, "K").Count);
    }

    [Fact]
    public void Ac11_ExistingCallShapes_CompileAndBehaveUnchanged()
    {
        // Arrange
        var byParams = new Scheme<RepeatRow>(1, Field.Repeat(0, Field.U8<RepeatRow>(0, x => x.K)));
        var byFunc = new Scheme<RepeatRow>(1, f => [Field.Repeat(0, f.U8(0, x => x.K))]);
        var values = new Dictionary<string, object?> { ["K"] = new object?[] { (byte)1, (byte)2 } };

        // Act
        var raw = BinaryPacker.Pack(byParams, values);
        var result = BinaryPacker.Read(byFunc, raw);

        // Assert
        Assert.Equal("010102", Convert.ToHexString(raw).ToLowerInvariant());
        Assert.Null(result.Error);
        Assert.Equal<int?>([1, 2], Cells(result, "K"));
    }
}
