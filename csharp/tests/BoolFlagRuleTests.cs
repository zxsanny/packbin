using System.Globalization;
using Packbin;

namespace Packbin.Tests;

// A bool or an empty group is a flag bit with no payload: set only for true, allowed only directly under Flags or a
// FlagByte bit. One flags byte holds 8 bits.
public class BoolFlagRuleTests
{
    private sealed class BoolRow
    {
        public bool Straight { get; set; }
    }

    private sealed class MaybeRow
    {
        public bool? Straight { get; set; }
    }

    private sealed class MarkRow
    {
        public bool? Mark { get; set; }
    }

    public sealed class PlacedRow
    {
        public byte A { get; set; }
        public bool? On { get; set; }
        public bool? Mark { get; set; }
        public List<object?>? Xs { get; set; }
        public Dictionary<string, object?>? M { get; set; }
        public Inner? Nested { get; set; }
    }

    public sealed class Inner
    {
        public bool? On { get; set; }
    }

    private sealed class OnEl
    {
        public bool? On { get; set; }
    }

    private sealed class NineRow
    {
        public byte? A0 { get; set; }
        public byte? A1 { get; set; }
        public byte? A2 { get; set; }
        public byte? A3 { get; set; }
        public byte? A4 { get; set; }
        public byte? A5 { get; set; }
        public byte? A6 { get; set; }
        public byte? A7 { get; set; }
        public byte? A8 { get; set; }
    }

    private sealed class KindsRow
    {
        public byte N { get; set; }
        public bool? Mark { get; set; }
        public List<int>? Segs { get; set; }
        public byte[]? Payload { get; set; }
        public List<int>? Kinds { get; set; }
        public int P { get; set; }
        public int Q { get; set; }
        public byte? V { get; set; }
    }

    private static string Hex(byte[] raw) => Convert.ToHexString(raw).ToLowerInvariant();

    private static T UnpackRow<T>(Scheme<T> scheme, byte[] raw) where T : class, new()
    {
        T? got = null;
        var err = BinaryPacker.Unpack(raw, scheme.On(v => got = v));
        Assert.Null(err);
        Assert.NotNull(got);
        return got;
    }

    private static Field[] NineU8() =>
    [
        Field.U8<NineRow>(0, x => x.A0), Field.U8<NineRow>(1, x => x.A1), Field.U8<NineRow>(2, x => x.A2),
        Field.U8<NineRow>(3, x => x.A3), Field.U8<NineRow>(4, x => x.A4), Field.U8<NineRow>(5, x => x.A5),
        Field.U8<NineRow>(6, x => x.A6), Field.U8<NineRow>(7, x => x.A7), Field.U8<NineRow>(8, x => x.A8),
    ];

    [Fact]
    public void Ac1_BoolFalse_ClearsTheBitAndRoundTripsFalse()
    {
        // Arrange
        var scheme = new Scheme<BoolRow>(1, Field.Flags(0, Field.Bool<BoolRow>(0, x => x.Straight)));

        // Act
        var raw = BinaryPacker.Pack(scheme, new BoolRow { Straight = false });
        var got = UnpackRow(scheme, raw);

        // Assert
        Assert.Equal("0100", Hex(raw));
        Assert.False(got.Straight);
    }

    [Fact]
    public void Ac1_SplitFormBoolFalse_ClearsTheBit()
    {
        // Arrange
        var m = Field.FlagByte();
        var scheme = new Scheme<BoolRow>(1, m, m.Bit(Field.Bool<BoolRow>(0, x => x.Straight)));

        // Act
        var off = BinaryPacker.Pack(scheme, new BoolRow { Straight = false });
        var on = BinaryPacker.Pack(scheme, new BoolRow { Straight = true });

        // Assert
        Assert.Equal("0100", Hex(off));
        Assert.False(UnpackRow(scheme, off).Straight);
        Assert.Equal("0101", Hex(on));
        Assert.True(UnpackRow(scheme, on).Straight);
    }

    [Fact]
    public void Ac2_BoolTrue_SetsTheBitAndNullClearsIt()
    {
        // Arrange
        var plain = new Scheme<BoolRow>(1, Field.Flags(0, Field.Bool<BoolRow>(0, x => x.Straight)));
        var nullable = new Scheme<MaybeRow>(1, Field.Flags(0, Field.Bool<MaybeRow>(0, x => x.Straight)));

        // Act
        var on = BinaryPacker.Pack(plain, new BoolRow { Straight = true });
        var none = BinaryPacker.Pack(nullable, new MaybeRow { Straight = null });

        // Assert
        Assert.Equal("0101", Hex(on));
        Assert.True(UnpackRow(plain, on).Straight);
        Assert.Equal("0100", Hex(none));
        Assert.Null(UnpackRow(nullable, none).Straight);
    }

    [Theory]
    [InlineData(false, "0100", null)]
    [InlineData(null, "0100", null)]
    [InlineData(true, "0101", true)]
    public void Ac3_EmptyGroupMark_FollowsTheBoolRule(bool? mark, string expected, bool? unpacked)
    {
        // Arrange
        var scheme = new Scheme<MarkRow>(1, Field.Flags(0, Field.Group(0, (MarkRow x) => x.Mark)));

        // Act
        var raw = BinaryPacker.Pack(scheme, new MarkRow { Mark = mark });

        // Assert
        Assert.Equal(expected, Hex(raw));
        Assert.Equal(unpacked, UnpackRow(scheme, raw).Mark);
    }

    public static TheoryData<object> NotTrueValues() => new() { 1, "true" };

    [Theory]
    [MemberData(nameof(NotTrueValues))]
    public void DictionaryValueOtherThanTrue_ClearsTheBit(object value)
    {
        // Arrange
        var scheme = new Scheme<MaybeRow>(1, Field.Flags(0, Field.Bool<MaybeRow>(0, x => x.Straight)));

        // Act
        var raw = BinaryPacker.Pack(scheme, new Dictionary<string, object?> { ["Straight"] = value });
        var got = BinaryPacker.Read(scheme, raw);

        // Assert
        Assert.Equal("0100", Hex(raw));
        Assert.Null(got.Error);
        Assert.False(got.Values.ContainsKey("Straight"));
    }

    public static TheoryData<string, Func<Scheme<PlacedRow>>> BoolOutsideFlags() => new()
    {
        { "top level", () => new Scheme<PlacedRow>(1, Field.Bool<PlacedRow>(0, x => x.On)) },
        { "repeat", () => new Scheme<PlacedRow>(1, Field.Repeat(0, Field.Bool<PlacedRow>(0, x => x.On))) },
        {
            "when", () => new Scheme<PlacedRow>(1,
                Field.U8<PlacedRow>(0, x => x.A),
                Field.When(1, Condition.Eq(0, 1), Field.Bool<PlacedRow>(1, x => x.On)))
        },
        {
            "when under flags", () => new Scheme<PlacedRow>(1,
                Field.U8<PlacedRow>(0, x => x.A),
                Field.Flags(1, Field.When(1, Condition.Eq(0, 1), Field.Bool<PlacedRow>(1, x => x.On))))
        },
        {
            "times", () => new Scheme<PlacedRow>(1,
                Field.U8<PlacedRow>(0, x => x.A),
                Field.Times(1, 0, Field.Bool<PlacedRow>(1, x => x.On)))
        },
        { "list element", () => new Scheme<PlacedRow>(1, Field.List((PlacedRow x) => x.Xs, Field.Bool<OnEl>(0, e => e.On))) },
        { "dict element", () => new Scheme<PlacedRow>(1, Field.Dict((PlacedRow x) => x.M, Field.Bool<OnEl>(0, e => e.On))) },
        {
            "group under flags", () => new Scheme<PlacedRow>(1,
                Field.Flags(0, Field.Group(0, (PlacedRow x) => x.Mark, Field.Bool<PlacedRow>(0, x => x.On))))
        },
        {
            "group under a flag byte bit", () =>
            {
                var m = Field.FlagByte();
                return new Scheme<PlacedRow>(1,
                    m, m.Bit(Field.Group(0, (PlacedRow x) => x.Mark, Field.Bool<PlacedRow>(0, x => x.On))));
            }
        },
        { "nested row", () => new Scheme<PlacedRow>(1, Field.Group((PlacedRow x) => x.Nested, Field.Bool<Inner>(0, i => i.On))) },
    };

    [Theory]
    [MemberData(nameof(BoolOutsideFlags))]
    public void Ac4_BoolNotDirectlyUnderFlags_FailsConstruction(string where, Func<Scheme<PlacedRow>> build)
    {
        // Act
        var ex = Assert.Throws<ArgumentException>(() => build());

        // Assert
        Assert.True(ex.Message.Contains("On", StringComparison.Ordinal), $"{where}: {ex.Message}");
        Assert.True(ex.Message.Contains("Flags", StringComparison.Ordinal), $"{where}: {ex.Message}");
    }

    public static TheoryData<string, Func<Scheme<PlacedRow>>> EmptyGroupOutsideFlags() => new()
    {
        { "top level", () => new Scheme<PlacedRow>(1, Field.Group(0, (PlacedRow x) => x.Mark)) },
        {
            "after a field", () => new Scheme<PlacedRow>(1,
                Field.U8<PlacedRow>(0, x => x.A),
                Field.Group(1, (PlacedRow x) => x.Mark))
        },
        {
            "when", () => new Scheme<PlacedRow>(1,
                Field.U8<PlacedRow>(0, x => x.A),
                Field.When(1, Condition.Eq(0, 1), Field.Group(1, (PlacedRow x) => x.Mark)))
        },
        { "repeat", () => new Scheme<PlacedRow>(1, Field.Repeat(0, Field.Group(0, (PlacedRow x) => x.Mark))) },
        {
            "group under flags", () => new Scheme<PlacedRow>(1,
                Field.Flags(0, Field.Group(0, (PlacedRow x) => x.On, Field.Group(0, (PlacedRow x) => x.Mark))))
        },
    };

    [Theory]
    [MemberData(nameof(EmptyGroupOutsideFlags))]
    public void Ac5_EmptyGroupNotDirectlyUnderFlags_FailsConstruction(string where, Func<Scheme<PlacedRow>> build)
    {
        // Act
        var ex = Assert.Throws<ArgumentException>(() => build());

        // Assert
        Assert.True(ex.Message.Contains("Mark", StringComparison.Ordinal), $"{where}: {ex.Message}");
        Assert.True(ex.Message.Contains("Flags", StringComparison.Ordinal), $"{where}: {ex.Message}");
    }

    [Fact]
    public void Ac6_NineChildFlags_FailsNamingTheLimit()
    {
        // Arrange
        Scheme<NineRow>? scheme = null;

        // Act
        var ex = Assert.Throws<ArgumentException>(() => scheme = new Scheme<NineRow>(1, Field.Flags(0, NineU8())));

        // Assert
        Assert.Null(scheme);
        Assert.Contains("A8", ex.Message, StringComparison.Ordinal);
        Assert.Contains("8 bits", ex.Message, StringComparison.Ordinal);
    }

    [Fact]
    public void Ac6_NinthBitOnOneFlagByte_FailsOnTheNinthCall()
    {
        // Arrange
        var m = Field.FlagByte();
        var fields = NineU8();
        for (var i = 0; i < 8; i++)
            m.Bit(fields[i]);

        // Act
        var ex = Assert.Throws<ArgumentException>(() => m.Bit(fields[8]));

        // Assert
        Assert.Contains("A8", ex.Message, StringComparison.Ordinal);
        Assert.Contains("8 bits", ex.Message, StringComparison.Ordinal);
    }

    [Fact]
    public void Ac6_EightChildFlags_StillBuildsAndKeepsTheLastBit()
    {
        // Arrange
        var scheme = new Scheme<NineRow>(1, Field.Flags(0, NineU8()[..8]));

        // Act
        var raw = BinaryPacker.Pack(scheme, new NineRow { A7 = 5 });

        // Assert
        Assert.Equal("018005", Hex(raw));
        Assert.Equal((byte)5, UnpackRow(scheme, raw).A7);
    }

    [Fact]
    public void Ac7_GroupWithOnlyABitsChild_SetsTheBitAndWritesTheBits()
    {
        // Arrange
        var scheme = new Scheme<KindsRow>(1,
            Field.U8<KindsRow>(0, x => x.N),
            Field.Flags(1, Field.Group(1, (KindsRow x) => x.Mark, Field.Bits<KindsRow>(1, x => x.Segs, 0))));
        var row = new KindsRow { N = 8, Segs = [1, 1, 1, 1, 1, 1, 1, 1], Mark = null };

        // Act
        var raw = BinaryPacker.Pack(scheme, row);
        var got = UnpackRow(scheme, raw);

        // Assert
        Assert.Equal("010801ff", Hex(raw));
        Assert.Equal(row.Segs, got.Segs);
        Assert.Null(got.Mark);
    }

    [Fact]
    public void Ac7_GroupWithOnlyASizedChild_SetsTheBitAndWritesThePayload()
    {
        // Arrange
        var scheme = new Scheme<KindsRow>(1,
            Field.U8<KindsRow>(0, x => x.N),
            Field.Flags(1, Field.Group(1, (KindsRow x) => x.Mark, Field.Sized<KindsRow>(1, x => x.Payload!, 0))));

        // Act
        var raw = BinaryPacker.Pack(scheme, new KindsRow { N = 3, Payload = [0x61, 0x62, 0x63] });
        var got = UnpackRow(scheme, raw);

        // Assert
        Assert.Equal("010301616263", Hex(raw));
        Assert.Equal(new byte[] { 0x61, 0x62, 0x63 }, got.Payload);
    }

    [Fact]
    public void Ac7_GroupWithOnlyAPackedChild_SetsTheBitAndWritesTheItems()
    {
        // Arrange
        var scheme = new Scheme<KindsRow>(1,
            Field.U8<KindsRow>(0, x => x.N),
            Field.Flags(1, Field.Group(1, (KindsRow x) => x.Mark, Field.Packed<KindsRow>(2, 1, x => x.Kinds, 0))));

        // Act
        var raw = BinaryPacker.Pack(scheme, new KindsRow { N = 4, Kinds = [0, 1, 2, 3] });
        var got = UnpackRow(scheme, raw);

        // Assert
        Assert.Equal("010401e4", Hex(raw));
        Assert.Equal(new List<int> { 0, 1, 2, 3 }, got.Kinds);
    }

    [Fact]
    public void Ac7_GroupWithOnlyAU2Child_SetsTheBitAndWritesTheSlots()
    {
        // Arrange
        var scheme = new Scheme<KindsRow>(1,
            Field.Flags(0, Field.Group(0, (KindsRow x) => x.Mark, Field.U2<KindsRow>((0, x => x.P), (1, x => x.Q)))));

        // Act
        var raw = BinaryPacker.Pack(scheme, new Dictionary<string, object?> { ["P"] = 1, ["Q"] = 2 });
        var got = BinaryPacker.Read(scheme, raw);

        // Assert
        Assert.Equal("010109", Hex(raw));
        Assert.Null(got.Error);
        Assert.Equal(1, Convert.ToInt32(got.Values["P"], CultureInfo.InvariantCulture));
        Assert.Equal(2, Convert.ToInt32(got.Values["Q"], CultureInfo.InvariantCulture));
    }

    [Fact]
    public void Ac7_SplitFormGroupWithMemberNull_WritesItsChildren()
    {
        // Arrange
        var m = Field.FlagByte();
        var scheme = new Scheme<KindsRow>(1,
            m, m.Bit(Field.Group(0, (KindsRow x) => x.Mark, Field.U8<KindsRow>(0, x => x.V))));

        // Act
        var raw = BinaryPacker.Pack(scheme, new KindsRow { V = 5, Mark = null });
        var got = UnpackRow(scheme, raw);

        // Assert
        Assert.Equal("010105", Hex(raw));
        Assert.Equal((byte)5, got.V);
    }
}
