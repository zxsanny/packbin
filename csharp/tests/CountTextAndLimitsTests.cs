using System.Reflection;
using Packbin;

namespace Packbin.Tests;

// AZ-2393: the text of a count above int.MaxValue, a lone byte[] in a repeat (loop 20 review A5, A6), and the loop 19
// WithLimits signature, kept as an overload so code compiled against it still binds (A7).
public class CountTextAndLimitsTests
{
    private sealed class Row
    {
        public uint U { get; set; }
        public long L { get; set; }
        public ulong W { get; set; }
        public byte[] Out { get; set; } = [];
        public List<int>? OutBits { get; set; }
        public List<int>? OutKinds { get; set; }
        public byte V { get; set; }
        public byte K { get; set; }
        public byte[] Raw { get; set; } = [];
    }

    private static Field CountField(string source) => source switch
    {
        "U" => Field.U32<Row>(0, x => x.U),
        "L" => Field.I64<Row>(0, x => x.L),
        _ => Field.U64<Row>(0, x => x.W),
    };

    private static Field Counted(string kind) => kind switch
    {
        "sized" => Field.Sized<Row>(1, x => x.Out, 0),
        "bits" => Field.Bits<Row>(1, x => x.OutBits, 0),
        "packed" => Field.Packed<Row>(2, 1, x => x.OutKinds, 0),
        _ => Field.Times(1, 0, Field.U8<Row>(1, x => x.V)),
    };

    public static TheoryData<string, string, object, string> CountTexts() => new()
    {
        { "sized", "U", 3000000000u, "Out: count 'U' is 3000000000, which does not fit an int" },
        { "bits", "U", 2147483648u, "OutBits: count 'U' is 2147483648, which does not fit an int" },
        { "packed", "L", 4294967296L, "OutKinds: count 'L' is 4294967296, which does not fit an int" },
        { "times", "U", 3000000000u, "times: count 'U' is 3000000000, which does not fit an int" },
        { "times", "L", long.MinValue, "times: count 'L' is -9223372036854775808, which does not fit an int" },
        { "times", "W", ulong.MaxValue, "times: count 'W' is 18446744073709551615, which does not fit an int" },
    };

    [Theory]
    [MemberData(nameof(CountTexts))]
    public void Ac1_Pack_CountAboveIntMaxValue_ThrowsThePinnedText(string kind, string source, object value, string text)
    {
        // Arrange
        var scheme = new Scheme<Row>(1, CountField(source), Counted(kind));
        var row = new Dictionary<string, object?> { [source] = value };

        // Act
        var error = Assert.Throws<ArgumentException>(() => BinaryPacker.Pack(scheme, row));

        // Assert
        Assert.Equal(text, error.Message);
    }

    private static Scheme<Row> RepeatOfBytes() => new(1, Field.Repeat(0, Field.Bytes<Row>(0, x => x.Raw, 1)));

    private const string Wrap = "'Raw': a round's value belongs in a list with one entry per round; wrap this value in a list";

    [Theory]
    [InlineData(1)]
    [InlineData(3)]
    public void Ac2_Pack_LoneByteArrayForABytesNameInARepeat_IsRefusedWithTheWrapText(int length)
    {
        // Arrange
        var values = new Dictionary<string, object?> { ["Raw"] = new byte[length] };

        // Act
        var error = Assert.Throws<ArgumentException>(() => BinaryPacker.Pack(RepeatOfBytes(), values));

        // Assert
        Assert.Equal(Wrap, error.Message);
    }

    [Fact]
    public void Ac2_Pack_LoneByteArrayInATypedRowRepeat_IsRefusedWithTheWrapText()
    {
        // Act
        var error = Assert.Throws<ArgumentException>(() => BinaryPacker.Pack(RepeatOfBytes(), new Row { Raw = [7] }));

        // Assert
        Assert.Equal(Wrap, error.Message);
    }

    [Fact]
    public void Ac2_Pack_LoneByteArrayLongerThanTheRoundLimit_IsRefusedWithTheLimitText()
    {
        // Arrange (the limit is checked first, so the wrap text is not the one given: loop 20 review A6)
        var scheme = RepeatOfBytes().WithLimits(maxRounds: 2);
        var values = new Dictionary<string, object?> { ["Raw"] = new byte[3] };

        // Act
        var error = Assert.Throws<ArgumentException>(() => BinaryPacker.Pack(scheme, values));

        // Assert
        Assert.Equal("'Raw': the repeat count is 3, above the limit of 2 rounds", error.Message);
    }

    [Fact]
    public void Ac2_Pack_ByteArrayForAScalarNameInARepeat_IsOneRoundPerByte()
    {
        // Arrange
        var scheme = new Scheme<Row>(1, Field.Repeat(0, Field.U8<Row>(0, x => x.K)));
        var values = new Dictionary<string, object?> { ["K"] = new byte[] { 5, 6 } };

        // Act
        var raw = BinaryPacker.Pack(scheme, values);

        // Assert
        Assert.Equal("010506", Convert.ToHexString(raw).ToLowerInvariant());
    }

    [Fact]
    public void Ac3_WithLimits_LoopNineteenSignature_ResolvesAndSetsTheTwoLimits()
    {
        // Arrange
        var scheme = new Scheme<Row>(1, Field.U8<Row>(0, x => x.K)).WithLimits(maxBytes: 77);
        var old = typeof(Scheme<Row>).GetMethod(nameof(Scheme<Row>.WithLimits), BindingFlags.Public | BindingFlags.Instance, null, [typeof(int), typeof(long)], null);

        // Act
        var limited = (Scheme<Row>)old!.Invoke(scheme, [5, 9L])!;
        var sourceCall = scheme.WithLimits(6, 10L);

        // Assert
        Assert.Equal((5, 9L, BinaryPacker.DefaultMaxBytes), (limited.MaxRounds, limited.MaxSlots, limited.MaxBytes));
        Assert.Equal((6, 10L, BinaryPacker.DefaultMaxBytes), (sourceCall.MaxRounds, sourceCall.MaxSlots, sourceCall.MaxBytes));
    }

    [Fact]
    public void Ac3_WithLimits_OmittedAndNamedLimits_KeepTheirDefaults()
    {
        // Arrange
        var scheme = new Scheme<Row>(1, Field.U8<Row>(0, x => x.K));

        // Act
        var byBytes = scheme.WithLimits(maxBytes: 5);
        var byRounds = scheme.WithLimits(3);

        // Assert
        Assert.Equal((BinaryPacker.DefaultMaxRounds, BinaryPacker.DefaultMaxSlots, 5L), (byBytes.MaxRounds, byBytes.MaxSlots, byBytes.MaxBytes));
        Assert.Equal((3, BinaryPacker.DefaultMaxSlots, BinaryPacker.DefaultMaxBytes), (byRounds.MaxRounds, byRounds.MaxSlots, byRounds.MaxBytes));
    }
}
