using Packbin;

namespace Packbin.Tests;

// AZ-2181 follow-up: a count written to the packet that does not fit an int is refused naming the count, not by a bare
// OverflowException from the conversion.
public class CountOverflowTests
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

    public static TheoryData<string, string, object> TooBig()
    {
        var data = new TheoryData<string, string, object>();
        foreach (var kind in new[] { "sized", "bits", "packed", "times" })
        {
            data.Add(kind, "U", 3000000000u);
            data.Add(kind, "U", 2147483648u);
            data.Add(kind, "L", 4294967296L);
            data.Add(kind, "L", long.MinValue);
            data.Add(kind, "W", ulong.MaxValue);
        }
        return data;
    }

    [Theory]
    [MemberData(nameof(TooBig))]
    public void Pack_CountThatDoesNotFitAnInt_ThrowsArgumentExceptionNamingTheCount(string kind, string source, object value)
    {
        // Arrange
        var scheme = new Scheme<Row>(1, CountField(source), Counted(kind));
        var row = new Dictionary<string, object?> { [source] = value };

        // Act
        var refused = Record.Exception(() => BinaryPacker.Pack(scheme, row));

        // Assert
        var error = Assert.IsType<ArgumentException>(refused);
        Assert.Contains($"count '{source}'", error.Message, StringComparison.Ordinal);
    }

    [Fact]
    public void Pack_CountAtIntMaxValue_StillFailsOnTheValueNotTheCount()
    {
        // Arrange
        var scheme = new Scheme<Row>(1, CountField("U"), Counted("sized"));
        var row = new Dictionary<string, object?> { ["U"] = (uint)int.MaxValue, ["Out"] = new byte[2] };

        // Act
        var error = Assert.Throws<ArgumentException>(() => BinaryPacker.Pack(scheme, row));

        // Assert
        Assert.Contains("expected 2147483647 bytes, got 2", error.Message, StringComparison.Ordinal);
    }
}
