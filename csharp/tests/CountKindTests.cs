using Packbin;

namespace Packbin.Tests;

// AZ-2181: the count of a Sized, Bits, Packed or Times field names an integer field, or the scheme does not build.
public class CountKindTests
{
    private sealed class Row
    {
        public string S { get; set; } = "";
        public byte[] Raw { get; set; } = [];
        public float F { get; set; }
        public double D { get; set; }
        public bool Flag { get; set; }
        public byte N { get; set; }
        public byte[] Data { get; set; } = [];
        public List<int>? Segs { get; set; }
        public List<int>? Kinds { get; set; }
        public byte[] Out { get; set; } = [];
        public List<int>? OutBits { get; set; }
        public List<int>? OutKinds { get; set; }
        public byte V { get; set; }
    }

    private sealed class WideRow
    {
        public byte U8 { get; set; }
        public ushort U16 { get; set; }
        public uint U32 { get; set; }
        public ulong U64 { get; set; }
        public sbyte I8 { get; set; }
        public short I16 { get; set; }
        public int I32 { get; set; }
        public long I64 { get; set; }
        public int Slot { get; set; }
        public byte[] Out { get; set; } = [];
    }

    private static string Hex(byte[] raw) => Convert.ToHexString(raw).ToLowerInvariant();

    // The fields before the counted one, the id its count names, and the member name the error must show for it.
    private static (Field[] Fields, int Source, string Member) Source(string kind) => kind switch
    {
        "utf8" => ([Field.Utf8<Row>(0, x => x.S)], 0, "S"),
        "bytes" => ([Field.Bytes<Row>(0, x => x.Raw, 2)], 0, "Raw"),
        "f32" => ([Field.F32<Row>(0, x => x.F)], 0, "F"),
        "f64" => ([Field.F64<Row>(0, x => x.D)], 0, "D"),
        "bool" => ([Field.Flags(0, Field.Bool<Row>(0, x => x.Flag))], 0, "Flag"),
        "sized" => ([Field.U8<Row>(0, x => x.N), Field.Sized<Row>(1, x => x.Data, 0)], 1, "Data"),
        "bits" => ([Field.U8<Row>(0, x => x.N), Field.Bits<Row>(1, x => x.Segs, 0)], 1, "Segs"),
        "packed" => ([Field.U8<Row>(0, x => x.N), Field.Packed<Row>(2, 1, x => x.Kinds, 0)], 1, "Kinds"),
        _ => throw new ArgumentException(kind),
    };

    private static (Field Counted, string Label) Counted(string kind, int id, int count) => kind switch
    {
        "sized" => (Field.Sized<Row>(id, x => x.Out, count), "'Out'"),
        "bits" => (Field.Bits<Row>(id, x => x.OutBits, count), "'OutBits'"),
        "packed" => (Field.Packed<Row>(1, id, x => x.OutKinds, count), "'OutKinds'"),
        "times" => (Field.Times(id, count, Field.U8<Row>(id, x => x.V)), $"times {id}"),
        _ => throw new ArgumentException(kind),
    };

    private static Scheme<Row> Build(string counted, string source)
    {
        var (before, id, _) = Source(source);
        var (field, _) = Counted(counted, before.Length == 1 ? 1 : 2, id);
        return new Scheme<Row>(1, [.. before, field]);
    }

    public static TheoryData<string, string> NonIntegerCounts()
    {
        var data = new TheoryData<string, string>();
        foreach (var counted in new[] { "sized", "bits", "packed", "times" })
        {
            foreach (var source in new[] { "utf8", "bytes", "f32", "f64", "bool", "sized", "bits", "packed" })
                data.Add(counted, source);
        }
        return data;
    }

    [Theory]
    [MemberData(nameof(NonIntegerCounts))]
    public void Construct_CountNamesANonIntegerField_ThrowsNamingBothFields(string counted, string source)
    {
        // Arrange
        var (before, id, member) = Source(source);
        var (field, label) = Counted(counted, before.Length == 1 ? 1 : 2, id);

        // Act
        var error = Assert.Throws<ArgumentException>(() => new Scheme<Row>(1, [.. before, field]));

        // Assert
        Assert.Contains(label, error.Message, StringComparison.Ordinal);
        Assert.Contains($"'{member}'", error.Message, StringComparison.Ordinal);
        Assert.Contains("integer", error.Message, StringComparison.Ordinal);
    }

    [Theory]
    [InlineData("utf8")]
    [InlineData("bytes")]
    [InlineData("bool")]
    public void Construct_Utf8BytesAndBoolProbes_FailAtConstructionNotAtPackOrRead(string source)
    {
        // Act
        var refused = Record.Exception(() => Build("sized", source));

        // Assert
        Assert.IsType<ArgumentException>(refused);
    }

    [Theory]
    [InlineData("U8", "01" + "02" + "0909")]
    [InlineData("U16", "01" + "0200" + "0909")]
    [InlineData("U32", "01" + "02000000" + "0909")]
    [InlineData("U64", "01" + "0200000000000000" + "0909")]
    [InlineData("I8", "01" + "02" + "0909")]
    [InlineData("I16", "01" + "0200" + "0909")]
    [InlineData("I32", "01" + "02000000" + "0909")]
    [InlineData("I64", "01" + "0200000000000000" + "0909")]
    [InlineData("Slot", "01" + "02" + "0909")]
    public void Construct_IntegerCount_BuildsPacksAndReadsBack(string source, string expected)
    {
        // Arrange
        Field count = source switch
        {
            "U8" => Field.U8<WideRow>(0, x => x.U8),
            "U16" => Field.U16<WideRow>(0, x => x.U16),
            "U32" => Field.U32<WideRow>(0, x => x.U32),
            "U64" => Field.U64<WideRow>(0, x => x.U64),
            "I8" => Field.I8<WideRow>(0, x => x.I8),
            "I16" => Field.I16<WideRow>(0, x => x.I16),
            "I32" => Field.I32<WideRow>(0, x => x.I32),
            "I64" => Field.I64<WideRow>(0, x => x.I64),
            _ => Field.U2<WideRow>((0, x => x.Slot)),
        };
        var scheme = new Scheme<WideRow>(1, count, Field.Sized<WideRow>(1, x => x.Out, 0));
        var row = new Dictionary<string, object?> { [source] = 2, ["Out"] = new byte[] { 9, 9 } };

        // Act
        var raw = BinaryPacker.Pack(scheme, row);
        var read = BinaryPacker.Read(scheme, raw);

        // Assert
        Assert.Equal(expected, Hex(raw));
        Assert.Null(read.Error);
        Assert.Equal(new byte[] { 9, 9 }, Assert.IsType<byte[]>(read.Values["Out"]));
    }
}
