using Packbin;

namespace Packbin.Tests;

// AZ-2180: a built scheme packs the same bytes for the rest of its life, whatever is done to a FlagByte handle or to the
// arrays passed in afterwards, and one handle or Flags field can be reused in many schemes.
public class FlagGroupCopyTests
{
    private sealed class Row
    {
        public byte? A { get; set; }
        public byte? B { get; set; }
    }

    private static string Hex(byte[] raw) => Convert.ToHexString(raw).ToLowerInvariant();

    private static Row Both() => new() { A = 1, B = 2 };

    [Fact]
    public void Pack_AfterALaterSchemeSharesTheHandle_EarlierSchemeIsUnchanged()
    {
        // Arrange
        var m = Field.FlagByte();
        var first = new Scheme<Row>(1, m, m.Bit(Field.U8<Row>(0, x => x.A)));
        var before = Hex(BinaryPacker.Pack(first, Both()));

        // Act
        _ = new Scheme<Row>(2, m, m.Bit(Field.U8<Row>(0, x => x.B)));

        // Assert
        Assert.Equal("010101", before);
        Assert.Equal(before, Hex(BinaryPacker.Pack(first, Both())));
    }

    [Fact]
    public void Pack_AfterABitCallWithNoSchemeAroundIt_BuiltSchemeIsUnchanged()
    {
        // Arrange
        var m = Field.FlagByte();
        var scheme = new Scheme<Row>(1, m, m.Bit(Field.U8<Row>(0, x => x.B)));
        var before = Hex(BinaryPacker.Pack(scheme, Both()));

        // Act
        _ = m.Bit(Field.U8<Row>(0, x => x.A));
        _ = m.Bit(Field.U8<Row>(1, x => x.B));

        // Assert
        Assert.Equal("010102", before);
        Assert.Equal(before, Hex(BinaryPacker.Pack(scheme, Both())));
    }

    [Fact]
    public void Unpack_AfterALaterBitCall_BuiltSchemeReadsTheSameRow()
    {
        // Arrange
        var m = Field.FlagByte();
        var scheme = new Scheme<Row>(1, m, m.Bit(Field.U8<Row>(0, x => x.A)));
        var bytes = BinaryPacker.Pack(scheme, Both());
        _ = new Scheme<Row>(2, m, m.Bit(Field.U8<Row>(0, x => x.B)));
        Row? got = null;

        // Act
        var err = BinaryPacker.Unpack(bytes, scheme.On(v => got = v));

        // Assert
        Assert.Null(err);
        Assert.Equal((byte)1, got!.A);
        Assert.Null(got.B);
    }

    [Fact]
    public void Pack_AfterTheCallersArrayIsChanged_SchemeIsUnchanged()
    {
        // Arrange
        var m = Field.FlagByte();
        var fields = new[] { m, m.Bit(Field.U8<Row>(0, x => x.A)) };
        var scheme = new Scheme<Row>(1, fields);
        var before = Hex(BinaryPacker.Pack(scheme, Both()));

        // Act
        fields[1] = Field.U8<Row>(0, x => x.B);
        fields[0] = Field.U8<Row>(1, x => x.A);

        // Assert
        Assert.Equal("010101", before);
        Assert.Equal(before, Hex(BinaryPacker.Pack(scheme, Both())));
    }

    [Fact]
    public async Task Pack_WhileOtherThreadsBuildSchemesOnTheSameHandle_EveryPackIsUnchanged()
    {
        // Arrange
        const int rounds = 3000;
        var m = Field.FlagByte();
        var first = new Scheme<Row>(1, m, m.Bit(Field.U8<Row>(0, x => x.A)));
        var start = new Barrier(5);
        var results = new string[4][];

        // Act
        var packers = Enumerable.Range(0, 4).Select(t => Task.Run(() =>
        {
            var seen = new string[rounds];
            start.SignalAndWait();
            for (var i = 0; i < rounds; i++)
                seen[i] = Hex(BinaryPacker.Pack(first, Both()));
            results[t] = seen;
        })).ToArray();
        var builder = Task.Run(() =>
        {
            start.SignalAndWait();
            for (var i = 0; i < rounds; i++)
                _ = new Scheme<Row>(2, m, m.Bit(Field.U8<Row>(0, x => x.B)), m.Bit(Field.U8<Row>(1, x => x.A)));
        });
        await Task.WhenAll([.. packers, builder]);

        // Assert
        Assert.All(results, seen => Assert.All(seen, hex => Assert.Equal("010101", hex)));
    }

    [Fact]
    public void Pack_FlagsFieldReusedInTwoSchemes_BothPackTheSameBytes()
    {
        // Arrange
        var flags = Field.Flags(0, Field.U8<Row>(0, x => x.A), Field.U8<Row>(1, x => x.B));
        var first = new Scheme<Row>(1, flags);
        var second = new Scheme<Row>(1, flags);
        var row = new Row { B = 2 };

        // Act
        var a = Hex(BinaryPacker.Pack(first, row));
        var b = Hex(BinaryPacker.Pack(second, row));

        // Assert
        Assert.Equal("010202", a);
        Assert.Equal(a, b);
    }

    [Fact]
    public void Construct_BitWithNoFlagByteBeforeIt_FailsNamingTheBitAsBefore()
    {
        // Arrange
        var m = Field.FlagByte();

        // Act
        var ex = Assert.Throws<ArgumentException>(() => new Scheme<Row>(1, m.Bit(Field.U8<Row>(0, x => x.A)), m));

        // Assert
        Assert.Equal("flag bit 'A' has no flag byte read before it in its scope", ex.Message);
    }
}
