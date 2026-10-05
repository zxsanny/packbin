using Packbin;

namespace Packbin.Tests;

// C# has no bad-value error yet (waits for C15). Interim rule of the hostile-vector task: a bad value is answered
// with ShortPacket(field, 0, left), the same stand-in the duplicate dictionary key already uses.
public partial class HostileUnpackTests
{
    private sealed class ZeroRow
    {
        public byte[] B { get; set; } = [];
        public byte V { get; set; }
    }

    private sealed class SignedCountRow
    {
        public sbyte N { get; set; }
        public byte[] P { get; set; } = [];
        public List<int>? Segs { get; set; }
        public List<int>? Kinds { get; set; }
        public byte X { get; set; }
    }

    private sealed class WideCountRow
    {
        public uint N { get; set; }
        public byte[] P { get; set; } = [];
        public List<int>? Segs { get; set; }
        public List<int>? Kinds { get; set; }
        public byte X { get; set; }
    }

    private sealed class HugeCountRow
    {
        public ulong N { get; set; }
        public byte[] P { get; set; } = [];
    }

    private sealed class GatedCountRow
    {
        public byte? N { get; set; }
        public byte[] P { get; set; } = [];
        public List<int>? Segs { get; set; }
        public List<int>? Kinds { get; set; }
        public byte X { get; set; }
    }

    private sealed class NameRow
    {
        public string Name { get; set; } = "";
    }

    private sealed class MapRow
    {
        public Dictionary<string, object?>? M { get; set; }
    }

    private sealed class ValueEl
    {
        public string V { get; set; } = "";
    }

    private sealed class ZeroTimesRow
    {
        public ulong N { get; set; }
        public byte[] B { get; set; } = [];
        public byte V { get; set; }
    }

    private sealed class SignedTimesRow
    {
        public long N { get; set; }
        public byte[] B { get; set; } = [];
    }

    private sealed class SmallTimesRow
    {
        public byte N { get; set; }
        public byte[] B { get; set; } = [];
    }

    private sealed class WideTimesRow
    {
        public uint N { get; set; }
        public byte[] B { get; set; } = [];
    }

    private sealed class GuardedTimesRow
    {
        public uint N { get; set; }
        public byte[] B { get; set; } = [];
        public byte V { get; set; }
    }

    private sealed class FloatCountRow
    {
        public float F { get; set; }
        public byte[] P { get; set; } = [];
    }

    private sealed class DoubleCountRow
    {
        public double D { get; set; }
        public byte[] P { get; set; } = [];
    }

    private sealed class LongCountRow
    {
        public long L { get; set; }
        public byte[] P { get; set; } = [];
    }

    private sealed class WordsRow
    {
        public List<object?>? Words { get; set; }
    }

    private sealed class FloatRow
    {
        public float F { get; set; }
        public byte? V { get; set; }
    }

    [Fact]
    public void Ac1_ZeroWidthRepeatBody_ReturnsTrailingBytes()
    {
        // Arrange
        var scheme = new Scheme<ZeroRow>(1, Field.Repeat(0, Field.Bytes<ZeroRow>(0, x => x.B, 0)));

        // Act
        var outcome = HostileProbe.Unpack(scheme, "0109");

        // Assert
        Assert.False(outcome.HandlerCalled);
        var error = Assert.IsType<TrailingBytes>(outcome.Error);
        Assert.Equal(1, error.Left);
    }

    [Fact]
    public void Ac1_RepeatBodyWithANeverMatchingWhen_ReturnsTrailingBytes()
    {
        // Arrange
        var scheme = new Scheme<ZeroRow>(1,
            Field.Repeat(0,
                Field.Bytes<ZeroRow>(0, x => x.B, 0),
                Field.When(1, Condition.Eq(0, new byte[] { 1 }), Field.U8<ZeroRow>(1, x => x.V))));

        // Act
        var outcome = HostileProbe.Unpack(scheme, "01ff");

        // Assert
        Assert.False(outcome.HandlerCalled);
        var error = Assert.IsType<TrailingBytes>(outcome.Error);
        Assert.Equal(1, error.Left);
    }

    [Fact]
    public void Ac1_RepeatWithProgress_StillReadsEveryRound()
    {
        // Arrange
        var scheme = new Scheme<ZeroRow>(1, Field.Repeat(0, Field.Bytes<ZeroRow>(0, x => x.B, 1)));

        // Act
        var got = BinaryPacker.Read(scheme, Convert.FromHexString("01010203"));

        // Assert
        Assert.Null(got.Error);
        Assert.Equal(3, ((List<object?>)got.Values["B"]!).Count);
    }

    [Fact]
    public void Ac5_InvalidUtf8Field_ReturnsShortPacketAndSkipsHandler()
    {
        var scheme = new Scheme<NameRow>(1, Field.Utf8<NameRow>(0, x => x.Name));

        var outcome = HostileProbe.Unpack(scheme, "010200fffe");

        HostileProbe.ExpectShort(outcome, "Name");
    }

    [Fact]
    public void Ac5_InvalidUtf8Field_LeavesNoRowValues()
    {
        var scheme = new Scheme<NameRow>(1, Field.Utf8<NameRow>(0, x => x.Name));

        var got = BinaryPacker.Read(scheme, Convert.FromHexString("010200fffe"));

        Assert.NotNull(got.Error);
        Assert.Empty(got.Values);
    }

    [Fact]
    public void Ac5_InvalidUtf8DictKey_ReturnsShortPacket()
    {
        var scheme = new Scheme<MapRow>(1,
            Field.Dict((MapRow x) => x.M, Field.Utf8<ValueEl>(0, x => x.V)));

        var outcome = HostileProbe.Unpack(scheme, "0101000100ff0000");

        HostileProbe.ExpectShort(outcome, "M");
    }

    [Fact]
    public void Ac5_ValidMultiByteUtf8_StillUnpacks()
    {
        var scheme = new Scheme<NameRow>(1, Field.Utf8<NameRow>(0, x => x.Name));
        var raw = BinaryPacker.Pack(scheme, new Dictionary<string, object?> { ["Name"] = "héllo \U0001F600" });

        var got = BinaryPacker.Read(scheme, raw);

        Assert.Null(got.Error);
        Assert.Equal("héllo \U0001F600", got.Values["Name"]);
    }

    [Fact]
    public void Ac5_InvalidUtf8InsideAListElement_ReturnsShortPacket()
    {
        var scheme = new Scheme<WordsRow>(1,
            Field.List((WordsRow x) => x.Words, Field.Utf8<ValueEl>(0, x => x.V)));

        var outcome = HostileProbe.Unpack(scheme, "0101000200fffe");

        HostileProbe.ExpectShort(outcome, "V");
    }

    [Fact]
    public void Reliability_ConditionOnNaNFloat_DoesNotThrow()
    {
        var scheme = new Scheme<FloatRow>(1,
            Field.F32<FloatRow>(0, x => x.F),
            Field.When(1, Condition.Eq(0, 1), Field.U8<FloatRow>(1, x => x.V)));

        var outcome = HostileProbe.Unpack(scheme, "010000c07f");

        Assert.Null(outcome.Error);
        Assert.True(outcome.HandlerCalled);
    }
}
