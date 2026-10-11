using Packbin;

namespace Packbin.Tests;

// AZ-2366 (security F17 and F27): a typed Unpack of a packet whose round is set returns the error result, never an
// InvalidCastException, and the collection member checks also run inside a repeat or times body.
public class TypedRoundUnpackTests
{
    private sealed class ByteRow
    {
        public byte V { get; set; }
        public byte N { get; set; }
        public bool? On { get; set; }
    }

    private sealed class NarrowIds
    {
        public uint U { get; set; }
        public byte Count { get; set; }
        public List<int>? Ids { get; set; }
    }

    private sealed class WideIds
    {
        public uint U { get; set; }
        public byte Count { get; set; }
        public List<long>? Ids { get; set; }
    }

    private static object? Typed<T>(Scheme<T> scheme, params byte[] packet) where T : class, new()
    {
        var handled = false;
        var result = BinaryPacker.Unpack(packet, scheme.On(_ => handled = true));
        return handled ? "handled" : result;
    }

    private static void AssertBadValue(string field, object? result)
    {
        var bad = Assert.IsType<ShortPacket>(result);
        Assert.Equal(field, bad.Field);
    }

    [Fact]
    public void Ac1_Unpack_RepeatRoundIntoAByteMember_ReturnsAnErrorNamingTheField()
    {
        // Arrange
        var scheme = new Scheme<ByteRow>(3, Field.Repeat(0, Field.U8<ByteRow>(0, x => x.V)));

        // Act
        var result = Typed(scheme, 0x03, 0x01, 0x02);

        // Assert
        AssertBadValue("V", result);
    }

    [Fact]
    public void Ac1_Unpack_TimesRoundIntoAByteMember_ReturnsAnErrorNamingTheField()
    {
        // Arrange
        var scheme = new Scheme<ByteRow>(3,
            Field.U8<ByteRow>(0, x => x.N),
            Field.Times(1, 0, Field.U8<ByteRow>(1, x => x.V)));

        // Act
        var result = Typed(scheme, 0x03, 0x02, 0x01, 0x02);

        // Assert
        AssertBadValue("V", result);
    }

    [Fact]
    public void Ac1_Unpack_FlagsMemberRoundIntoAByteMember_ReturnsAnErrorNamingTheField()
    {
        // Arrange
        var scheme = new Scheme<ByteRow>(3,
            Field.Repeat(0, Field.Flags(0, Field.U8<ByteRow>(0, x => x.V))));

        // Act
        var result = Typed(scheme, 0x03, 0x01, 0x02);

        // Assert
        AssertBadValue("V", result);
    }

    [Fact]
    public void Ac1_Unpack_RepeatWithNoRounds_StillBindsTheRow()
    {
        // Arrange
        var scheme = new Scheme<ByteRow>(3, Field.Repeat(0, Field.U8<ByteRow>(0, x => x.V)));

        // Act
        var result = Typed(scheme, 0x03);

        // Assert
        Assert.Equal("handled", result);
    }

    [Fact]
    public void Ac2_Scheme_ListOfNarrowIdsInARepeat_IsRefusedAtConstructionNamingTheMember()
    {
        // Arrange / Act
        var error = Record.Exception(() => new Scheme<NarrowIds>(1,
            Field.Repeat(0, Field.List((NarrowIds x) => x.Ids, Field.U32<NarrowIds>(0, x => x.U)))));

        // Assert
        var refused = Assert.IsType<ArgumentException>(error);
        Assert.Contains("'Ids'", refused.Message);
        Assert.Contains("one list per round", refused.Message);
    }

    [Fact]
    public void Ac2_Scheme_ListOfNarrowIdsInATimes_IsRefusedAtConstructionNamingTheMember()
    {
        // Arrange / Act
        var error = Record.Exception(() => new Scheme<NarrowIds>(1,
            Field.U8<NarrowIds>(0, x => x.Count),
            Field.Times(1, 0, Field.List((NarrowIds x) => x.Ids, Field.U32<NarrowIds>(0, x => x.U)))));

        // Assert
        var refused = Assert.IsType<ArgumentException>(error);
        Assert.Contains("'Ids'", refused.Message);
    }

    [Fact]
    public void Ac2_Scheme_ListOfLongIdsInARepeat_IsRefusedAtConstructionNamingTheMember()
    {
        // Arrange / Act
        var error = Record.Exception(() => new Scheme<WideIds>(1,
            Field.Repeat(0, Field.List((WideIds x) => x.Ids, Field.U32<WideIds>(0, x => x.U)))));

        // Assert
        var refused = Assert.IsType<ArgumentException>(error);
        Assert.Contains("'Ids'", refused.Message);
        Assert.Contains("one list per round", refused.Message);
    }

    [Fact]
    public void Ac2_Scheme_ListOfLongIdsInATimes_IsRefusedAtConstructionNamingTheMember()
    {
        // Arrange / Act
        var error = Record.Exception(() => new Scheme<WideIds>(1,
            Field.U8<WideIds>(0, x => x.Count),
            Field.Times(1, 0, Field.List((WideIds x) => x.Ids, Field.U32<WideIds>(0, x => x.U)))));

        // Assert
        Assert.Contains("'Ids'", Assert.IsType<ArgumentException>(error).Message);
    }
}
