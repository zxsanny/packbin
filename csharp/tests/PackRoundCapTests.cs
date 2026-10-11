using Packbin;

namespace Packbin.Tests;

// AZ-2329: pack refuses a times count above the scheme's maxRounds (default 65 535) before it writes any round, naming
// the member, as unpack refuses a round above it. A lone scalar goes to every round, so without the cap a 2-billion
// count would loop and fill the buffer.
public class PackRoundCapTests
{
    private sealed class Row
    {
        public uint N { get; set; }
        public byte? K { get; set; }
    }

    private sealed class Holder
    {
        public List<object?>? Items { get; set; }
    }

    private sealed class Element
    {
        public uint N { get; set; }
        public byte? K { get; set; }
        public bool? Mark { get; set; }
    }

    private static Scheme<Row> Wide() => new(1,
        Field.U32<Row>(0, x => x.N),
        Field.Times(1, 0, Field.U8<Row>(1, x => x.K)));

    private static Scheme<Row> InFlags() => new(1,
        Field.U32<Row>(0, x => x.N),
        Field.Flags(1, Field.Times(1, 0, Field.U8<Row>(1, x => x.K))));

    private static Scheme<Holder> InElement() => new(1,
        Field.List((Holder x) => x.Items,
            Field.Group(0, (Element e) => e.Mark,
                Field.U32<Element>(0, e => e.N),
                Field.Times(1, 0, Field.U8<Element>(1, e => e.K)))));

    private static Dictionary<string, object?> Lone(uint count) =>
        new() { ["N"] = count, ["K"] = (byte)7 };

    // Runs pack on a background thread so a missing cap fails after the guard instead of looping for minutes.
    private static Exception? Refusal<T>(Scheme<T> scheme, IReadOnlyDictionary<string, object?> values) where T : class, new()
    {
        Exception? thrown = null;
        var done = false;
        var worker = new Thread(() =>
        {
            try
            {
                BinaryPacker.Pack(scheme, values);
            }
            catch (Exception ex)
            {
                thrown = ex;
            }
            done = true;
        })
        {
            IsBackground = true,
        };
        worker.Start();
        Assert.True(worker.Join(TimeSpan.FromSeconds(5)), "pack did not return within 5 s");
        Assert.True(done);
        return thrown;
    }

    [Theory]
    [InlineData(65_536u)]
    [InlineData(70_000u)]
    [InlineData(2_000_000_000u)]
    public void Ac1_Pack_CountAboveTheLimitWithALoneScalar_NamesTheMember(uint count)
    {
        // Arrange
        var scheme = Wide();

        // Act
        var error = Refusal(scheme, Lone(count));

        // Assert
        var refused = Assert.IsType<ArgumentException>(error);
        Assert.Contains("'K'", refused.Message);
        Assert.Contains($"count is {count}", refused.Message);
        Assert.Contains("65535", refused.Message);
    }

    [Fact]
    public void Ac1_Pack_CountAboveTheLimitWithNoValue_StillRefusesTheCountFirst()
    {
        // Arrange
        var scheme = Wide();

        // Act
        var error = Refusal(scheme, new Dictionary<string, object?> { ["N"] = 70_000u });

        // Assert
        var refused = Assert.IsType<ArgumentException>(error);
        Assert.Contains("'K'", refused.Message);
    }

    [Fact]
    public void Ac1_Pack_TypedRowCountAboveTheLimit_NamesTheMember()
    {
        // Arrange
        var scheme = Wide();

        // Act
        var thrown = Record.Exception(() => BinaryPacker.Pack(scheme, new Row { N = 70_000, K = 7 }));

        // Assert
        var refused = Assert.IsType<ArgumentException>(thrown);
        Assert.Contains("'K'", refused.Message);
    }

    [Fact]
    public void Ac1_Pack_CountAboveTheLimitInsideFlags_IsRefused()
    {
        // Arrange
        var scheme = InFlags();

        // Act
        var error = Refusal(scheme, Lone(70_000));

        // Assert
        Assert.Contains("'K'", Assert.IsType<ArgumentException>(error).Message);
    }

    [Fact]
    public void Ac1_Pack_CountAboveTheLimitInAListElement_IsRefused()
    {
        // Arrange
        var scheme = InElement();
        var values = new Dictionary<string, object?>
        {
            ["Items"] = new List<object?> { new Dictionary<string, object?> { ["N"] = 70_000u, ["K"] = (byte)7 } },
        };

        // Act
        var error = Refusal(scheme, values);

        // Assert
        Assert.Contains("'K'", Assert.IsType<ArgumentException>(error).Message);
    }

    [Fact]
    public void Ac2_Pack_CountAtTheLimit_PacksAndRoundTrips()
    {
        // Arrange
        var scheme = Wide();

        // Act
        var raw = BinaryPacker.Pack(scheme, Lone(65_535));
        var got = BinaryPacker.Read(scheme, raw);

        // Assert
        Assert.Equal(1 + 4 + 65_535, raw.Length);
        Assert.Equal("01ffff0000", Convert.ToHexString(raw, 0, 5).ToLowerInvariant());
        Assert.All(raw.AsSpan(5).ToArray(), b => Assert.Equal(7, b));
        Assert.Null(got.Error);
        Assert.Equal(65_535, ((List<object?>)got.Values["K"]!).Count);
    }

    [Fact]
    public void Ac2_Pack_SmallCount_BytesAreUnchanged()
    {
        // Arrange
        var scheme = Wide();

        // Act
        var raw = BinaryPacker.Pack(scheme, Lone(3));

        // Assert
        Assert.Equal("01030000000707" + "07", Convert.ToHexString(raw).ToLowerInvariant());
    }

    [Fact]
    public void Ac3_Pack_SchemeThatRaisedTheLimit_PacksALargerCount()
    {
        // Arrange
        var scheme = Wide().WithLimits(maxRounds: 70_000);

        // Act
        var raw = BinaryPacker.Pack(scheme, Lone(70_000));
        var over = Refusal(scheme, Lone(70_001));

        // Assert
        Assert.Equal(1 + 4 + 70_000, raw.Length);
        Assert.Contains("70000", Assert.IsType<ArgumentException>(over).Message);
    }

    [Fact]
    public void Pack_SchemeThatLoweredTheLimit_RefusesWhatItCouldNotUnpack()
    {
        // Arrange
        var scheme = Wide().WithLimits(maxRounds: 3);

        // Act
        var raw = BinaryPacker.Pack(scheme, Lone(3));
        var refused = Record.Exception(() => BinaryPacker.Pack(scheme, Lone(4)));

        // Assert
        Assert.Equal("01030000000707" + "07", Convert.ToHexString(raw).ToLowerInvariant());
        Assert.IsType<ArgumentException>(refused);
        Assert.Null(BinaryPacker.Read(scheme, raw).Error);
    }
}
