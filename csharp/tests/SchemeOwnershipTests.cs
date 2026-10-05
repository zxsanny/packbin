using System.Collections;
using Packbin;

namespace Packbin.Tests;

// A scheme owns its layout: it copies its field list, refuses a field declared for another row type, and never
// changes a Field or Condition the caller may reuse in another scheme.
public class SchemeOwnershipTests
{
    private sealed class NullRow
    {
        public ushort? Heading { get; set; }
        public byte Tail { get; set; }
    }

    private sealed class BoolRow
    {
        public ushort? Other { get; set; }
        public byte B { get; set; }
        public int Q { get; set; }
        public byte[]? Raw { get; set; }
        public string? Name { get; set; }
        public bool Flag { get; set; }
        public bool? MaybeFlag { get; set; }
        public List<int>? Bits { get; set; }
        public IList? BitList { get; set; }
        public List<int>? Kinds { get; set; }
        public Dictionary<string, byte>? Map { get; set; }
        public NullRow? Nested { get; set; }
    }

    private sealed class Wrapper<TItem>
    {
        public byte V { get; set; }
    }

    private sealed class SharedRow
    {
        public byte A { get; set; }
        public byte B { get; set; }
        public byte C { get; set; }
        public byte[]? Payload { get; set; }
    }

    private sealed class KindRow
    {
        public byte Kind { get; set; }
        public byte Extra { get; set; }
    }

    private sealed class ModeRow
    {
        public byte Mode { get; set; }
        public byte Extra { get; set; }
    }

    private sealed class El
    {
        public ushort V { get; set; }
    }

    private sealed class ListRow
    {
        public byte A { get; set; }
        public List<int>? Xs { get; set; }
        public Dictionary<string, byte>? M { get; set; }
        public NullRow? Inner { get; set; }
    }

    private static string Hex(byte[] raw) => Convert.ToHexString(raw).ToLowerInvariant();

    [Fact]
    public void Construct_FieldDeclaredForAnotherRowType_ThrowsNamingBothTypes()
    {
        // Act
        var ex = Assert.Throws<ArgumentException>(() => new Scheme<NullRow>(1,
            Field.U16<BoolRow>(0, x => x.Other),
            Field.U8<NullRow>(1, x => x.Tail)));

        // Assert
        Assert.Contains("BoolRow", ex.Message);
        Assert.Contains("NullRow", ex.Message);
    }

    public static TheoryData<string, Func<Field[]>> ForeignFields() => new()
    {
        { "top level", () => [Field.U8<BoolRow>(0, x => x.B)] },
        { "flags", () => [Field.Flags(0, Field.U8<BoolRow>(0, x => x.B))] },
        {
            "when",
            () => [Field.U8<NullRow>(0, x => x.Tail), Field.When(1, Condition.Eq(0, (byte)1), Field.U8<BoolRow>(1, x => x.B))]
        },
        { "repeat", () => [Field.Repeat(0, Field.U8<BoolRow>(0, x => x.B))] },
        { "times", () => [Field.U8<NullRow>(0, x => x.Tail), Field.Times(1, 0, Field.U8<BoolRow>(1, x => x.B))] },
        { "continuing group", () => [Field.Group(0, (NullRow x) => x.Tail, Field.U8<BoolRow>(0, x => x.B))] },
        {
            "group in flags",
            () => [Field.Flags(0, Field.Group(0, (NullRow x) => x.Tail, Field.U8<BoolRow>(0, x => x.B)))]
        },
        { "u2", () => [Field.U2<BoolRow>((0, x => x.Q))] },
        { "list", () => [Field.List((BoolRow x) => x.Other, Field.U16<El>(0, e => e.V))] },
        { "bytes", () => [Field.Bytes<BoolRow>(0, x => x.Raw!, 1)] },
        { "utf8", () => [Field.Utf8<BoolRow>(0, x => x.Name!)] },
        { "bool", () => [Field.Flags(0, Field.Bool<BoolRow>(0, x => x.Flag))] },
        { "bool?", () => [Field.Flags(0, Field.Bool<BoolRow>(0, x => x.MaybeFlag))] },
        { "sized", () => [Field.U8<NullRow>(0, x => x.Tail), Field.Sized<BoolRow>(1, x => x.Raw!, 0)] },
        { "bits", () => [Field.U8<NullRow>(0, x => x.Tail), Field.Bits<BoolRow>(1, x => x.Bits, 0)] },
        { "bits of a list", () => [Field.U8<NullRow>(0, x => x.Tail), Field.Bits<BoolRow>(1, x => x.BitList!, 0)] },
        { "packed", () => [Field.U8<NullRow>(0, x => x.Tail), Field.Packed<BoolRow>(2, 1, x => x.Kinds, 0)] },
        { "dict", () => [Field.Dict((BoolRow x) => x.Map, Field.U8<El2>(0, e => e.V))] },
        { "anchored group", () => [Field.Group(0, (BoolRow x) => x.Q, Field.U8<NullRow>(0, x => x.Tail))] },
        { "nested group", () => [Field.Group((BoolRow x) => x.Nested, Field.U8<NullRow>(0, x => x.Tail))] },
    };

    [Theory]
    [MemberData(nameof(ForeignFields))]
    public void Construct_ForeignFieldAtAnyDepth_Throws(string where, Func<Field[]> build)
    {
        // Arrange
        var fields = build();

        // Act
        var ex = Assert.Throws<ArgumentException>(() => new Scheme<NullRow>(1, fields));

        // Assert
        Assert.True(ex.Message.Contains("BoolRow") && ex.Message.Contains("NullRow"), $"{where}: {ex.Message}");
    }

    [Fact]
    public void Construct_ForeignGenericRowType_NamesBothTypesReadably()
    {
        // Act
        var ex = Assert.Throws<ArgumentException>(() =>
            new Scheme<Wrapper<int>>(1, Field.U8<Wrapper<string>>(0, x => x.V)));

        // Assert
        Assert.Contains("Wrapper<String>", ex.Message);
        Assert.Contains("Wrapper<Int32>", ex.Message);
    }

    [Fact]
    public void Construct_ElementsAndNestedRowsBindTheirOwnRowTypes()
    {
        // Act
        var scheme = new Scheme<ListRow>(1,
            Field.U8<ListRow>(0, x => x.A),
            Field.List((ListRow x) => x.Xs, Field.U16<El>(0, e => e.V)),
            Field.Dict((ListRow x) => x.M, Field.U8<El2>(0, e => e.V)),
            Field.Group((ListRow x) => x.Inner, Field.U8<NullRow>(0, i => i.Tail)));

        // Assert
        Assert.Equal(4, scheme.Fields.Count);
    }

    private sealed class El2
    {
        public byte V { get; set; }
    }

    [Fact]
    public void Construct_ForeignFieldBuildsNoScheme_AndTheFieldsStayReusable()
    {
        // Arrange
        var shared = Field.U8<NullRow>(1, x => x.Tail);
        Assert.Throws<ArgumentException>(() => new Scheme<NullRow>(1, Field.U16<BoolRow>(0, x => x.Other), shared));

        // Act
        var scheme = new Scheme<NullRow>(1, Field.U16<NullRow>(0, x => x.Heading), shared);

        // Assert
        Assert.Equal("01020107", Hex(BinaryPacker.Pack(scheme, new NullRow { Heading = 0x0102, Tail = 7 })));
    }

    [Fact]
    public void Construct_FieldDeclaredForABaseOfTheRowType_IsAccepted()
    {
        // Act
        var scheme = new Scheme<DerivedRow>(1, Field.U8<DerivedBase>(0, x => x.A));

        // Assert
        Assert.Equal("0105", Hex(BinaryPacker.Pack(scheme, new DerivedRow { A = 5 })));
    }

    private class DerivedBase
    {
        public byte A { get; set; }
    }

    private sealed class DerivedRow : DerivedBase
    {
    }

    [Fact]
    public void Scheme_CopiesItsFieldList_SoALaterReplacementChangesNothing()
    {
        // Arrange
        var array = new[] { Field.U8<SharedRow>(0, x => x.A), Field.U8<SharedRow>(1, x => x.B) };
        var scheme = new Scheme<SharedRow>(1, array);
        var row = new SharedRow { A = 1, B = 2 };
        var before = Hex(BinaryPacker.Pack(scheme, row));

        // Act
        array[0] = Field.U8<SharedRow>(0, x => x.B);
        array[1] = Field.U8<SharedRow>(1, x => x.A);

        // Assert
        Assert.Equal("010102", before);
        Assert.Equal(before, Hex(BinaryPacker.Pack(scheme, row)));
        Assert.Equal(2, scheme.Fields.Count);
    }

    [Fact]
    public void Scheme_SharedConditionAcrossTwoSchemes_IsNotReBound()
    {
        // Arrange
        var condition = Condition.Eq(0, (byte)1);
        var kind = new Scheme<KindRow>(1,
            Field.U8<KindRow>(0, x => x.Kind),
            Field.When(1, condition, Field.U8<KindRow>(1, x => x.Extra)));
        var alone = BinaryPacker.Pack(kind, new KindRow { Kind = 1, Extra = 5 });
        var mode = new Scheme<ModeRow>(2,
            Field.U8<ModeRow>(0, x => x.Mode),
            Field.When(1, condition, Field.U8<ModeRow>(1, x => x.Extra)));

        // Act
        var raw = BinaryPacker.Pack(kind, new KindRow { Kind = 1, Extra = 5 });
        var other = BinaryPacker.Pack(mode, new ModeRow { Mode = 1, Extra = 6 });

        // Assert
        Assert.Equal("010105", Hex(alone));
        Assert.Equal(Hex(alone), Hex(raw));
        Assert.Equal("020106", Hex(other));
    }

    [Fact]
    public void Scheme_SharedConditionAcrossTwoSchemes_UnpacksEachWithItsOwnTarget()
    {
        // Arrange
        var condition = Condition.Eq(0, (byte)1);
        var kind = new Scheme<KindRow>(1,
            Field.U8<KindRow>(0, x => x.Kind),
            Field.When(1, condition, Field.U8<KindRow>(1, x => x.Extra)));
        _ = new Scheme<ModeRow>(2,
            Field.U8<ModeRow>(0, x => x.Mode),
            Field.When(1, condition, Field.U8<ModeRow>(1, x => x.Extra)));

        // Act
        var got = BinaryPacker.Read(kind, Convert.FromHexString("010105"));

        // Assert
        Assert.Null(got.Error);
        Assert.Equal(5.0, Convert.ToDouble(got.Values["Extra"]));
    }

    [Fact]
    public void Scheme_SharedCountedFieldAcrossTwoSchemes_KeepsItsOwnCount()
    {
        // Arrange
        var payload = Field.Sized<SharedRow>(2, x => x.Payload!, 0);
        var first = new Scheme<SharedRow>(1, Field.U8<SharedRow>(0, x => x.A), Field.U8<SharedRow>(1, x => x.B), payload);
        _ = new Scheme<SharedRow>(2, Field.U8<SharedRow>(0, x => x.B), Field.U8<SharedRow>(1, x => x.A), payload);
        var row = new SharedRow { A = 2, B = 9, Payload = [7, 8] };

        // Act
        var raw = BinaryPacker.Pack(first, row);
        var got = BinaryPacker.Read(first, raw);

        // Assert
        Assert.Equal("010209" + "0708", Hex(raw));
        Assert.Null(got.Error);
        Assert.Equal([7, 8], (byte[])got.Values["Payload"]!);
    }

    [Fact]
    public void Scheme_SharedTimesFieldAcrossTwoSchemes_KeepsItsOwnCount()
    {
        // Arrange
        var rounds = Field.Times(2, 0, Field.U8<SharedRow>(2, x => x.C));
        var first = new Scheme<SharedRow>(1, Field.U8<SharedRow>(0, x => x.A), Field.U8<SharedRow>(1, x => x.B), rounds);
        _ = new Scheme<SharedRow>(2, Field.U8<SharedRow>(0, x => x.B), Field.U8<SharedRow>(1, x => x.A), rounds);

        // Act
        var got = BinaryPacker.Read(first, Convert.FromHexString("01" + "02" + "09" + "0a0b"));

        // Assert
        Assert.Null(got.Error);
        Assert.Equal(new object?[] { 10.0, 11.0 }, ((List<object?>)got.Values["C"]!).ToArray());
    }

    [Fact]
    public void Schemes_SharingAConditionAndAField_PackAndUnpackTheirOwnBytesFromManyThreads()
    {
        // Arrange
        var condition = Condition.Eq(0, (byte)1);
        var payload = Field.Sized<SharedRow>(2, x => x.Payload!, 0);
        var kind = KindScheme(condition);
        var mode = ModeScheme(condition);
        var first = new Scheme<SharedRow>(3, Field.U8<SharedRow>(0, x => x.A), Field.U8<SharedRow>(1, x => x.B), payload);
        var second = new Scheme<SharedRow>(4, Field.U8<SharedRow>(0, x => x.B), Field.U8<SharedRow>(1, x => x.A), payload);
        var mismatches = 0;

        // Act
        Parallel.For(0, 3000, new ParallelOptions { MaxDegreeOfParallelism = 8 }, i =>
        {
            var extra = (byte)i;
            var fresh = ModeScheme(condition);
            var row = new SharedRow { A = 2, B = 9, Payload = [7, 8] };
            var swapped = new SharedRow { A = 9, B = 2, Payload = [7, 8] };
            var ok = Hex(BinaryPacker.Pack(kind, new KindRow { Kind = 1, Extra = extra })) == "0101" + extra.ToString("x2")
                && Hex(BinaryPacker.Pack(mode, new ModeRow { Mode = 1, Extra = extra })) == "0201" + extra.ToString("x2")
                && Hex(BinaryPacker.Pack(fresh, new ModeRow { Mode = 1, Extra = extra })) == "0201" + extra.ToString("x2")
                && Hex(BinaryPacker.Pack(first, row)) == "0302090708"
                && Hex(BinaryPacker.Pack(second, swapped)) == "0402090708"
                && Convert.ToInt32(BinaryPacker.Read(kind, [1, 1, extra]).Values["Extra"]) == extra;
            if (!ok)
                Interlocked.Increment(ref mismatches);
        });

        // Assert
        Assert.Equal(0, mismatches);
    }

    private static Scheme<KindRow> KindScheme(Condition condition) => new(1,
        Field.U8<KindRow>(0, x => x.Kind),
        Field.When(1, condition, Field.U8<KindRow>(1, x => x.Extra)));

    private static Scheme<ModeRow> ModeScheme(Condition condition) => new(2,
        Field.U8<ModeRow>(0, x => x.Mode),
        Field.When(1, condition, Field.U8<ModeRow>(1, x => x.Extra)));
}
