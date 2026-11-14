using System.Diagnostics;
using Packbin;

namespace Packbin.Tests;

// AZ-4296 (contract scheme-depth 1.0.1, owner decision D18): a scheme nested deeper than 256 levels is refused when it is
// built, with an ArgumentException that carries the contract's text; 256 levels build, pack and unpack at the default
// stack. Every chain is built by a loop, innermost first, so no test recurses.
public class SchemeDepthTests
{
    internal const int Limit = 256;
    internal const string Refusal = "scheme nested too deep: more than 256 levels; the limit is 256";

    internal sealed class WhenRow
    {
        public byte A { get; set; }
        public byte B { get; set; }
    }

    internal sealed class Node
    {
        public Node? M { get; set; }
        public byte B { get; set; }
    }

    private sealed class ListNode
    {
        public List<ListNode>? Kids { get; set; }
        public byte B { get; set; }
    }

    private sealed class DictNode
    {
        public Dictionary<string, DictNode>? Kids { get; set; }
        public byte B { get; set; }
    }

    private sealed class FlagRow
    {
        public byte? B { get; set; }
    }

    private sealed class RoundRow
    {
        public byte N { get; set; }
        public byte K { get; set; }
        public byte V { get; set; }
    }

    private sealed class MixRow
    {
        public byte A { get; set; }
        public List<object?>? Xs { get; set; }
    }

    private sealed class ByteEl
    {
        public byte V { get; set; }
    }

    private sealed class Sub
    {
        public byte B { get; set; }
    }

    private sealed class Item
    {
        public Sub? S { get; set; }
    }

    private sealed class ItemsRow
    {
        public byte A { get; set; }
        public List<Item>? Items { get; set; }
    }

    private static string Hex(byte[] raw) => Convert.ToHexString(raw).ToLowerInvariant();

    private static string Repeated(string unit, int count) => string.Concat(Enumerable.Repeat(unit, count));

    private static Field WhenChain(int depth)
    {
        var inner = Field.U8<WhenRow>(1, x => x.B);
        for (var i = 0; i < depth; i++)
            inner = Field.When(1, Condition.Eq(0, 1), inner);
        return inner;
    }

    private static Field[] WhenFields(int depth) => [Field.U8<WhenRow>(0, x => x.A), WhenChain(depth)];

    internal static Scheme<WhenRow> WhenScheme(int depth) => new(1, WhenFields(depth));

    private static Field[] GroupFields(int depth)
    {
        var inner = Field.U8<Node>(0, x => x.B);
        for (var i = 0; i < depth; i++)
            inner = Field.Group((Node x) => x.M, inner);
        return [inner];
    }

    internal static Scheme<Node> GroupScheme(int depth) => new(1, GroupFields(depth));

    private static Field[] FlagsFields(int depth)
    {
        var inner = Field.U8<FlagRow>(0, x => x.B);
        for (var i = 0; i < depth; i++)
            inner = Field.Flags(0, inner);
        return [inner];
    }

    private static Scheme<FlagRow> FlagsScheme(int depth) => new(1, FlagsFields(depth));

    private static Field[] ListFields(int depth)
    {
        var inner = Field.U8<ListNode>(0, x => x.B);
        for (var i = 0; i < depth; i++)
            inner = Field.List<ListNode, ListNode>(x => x.Kids!, [inner]);
        return [inner];
    }

    private static Scheme<ListNode> ListScheme(int depth) => new(1, ListFields(depth));

    private static Field[] DictFields(int depth)
    {
        var inner = Field.U8<DictNode>(0, x => x.B);
        for (var i = 0; i < depth; i++)
            inner = Field.Dict<DictNode, DictNode>(x => x.Kids!, [inner]);
        return [inner];
    }

    private static Scheme<DictNode> DictScheme(int depth) => new(1, DictFields(depth));

    // repeat (one level) holding `whens` nested whens: k (id 0), then the chain around v (id 1).
    private static Field[] RepeatFields(int whens)
    {
        var inner = Field.U8<RoundRow>(1, x => x.V);
        for (var i = 0; i < whens; i++)
            inner = Field.When(1, Condition.Eq(0, 1), inner);
        return [Field.Repeat(0, Field.U8<RoundRow>(0, x => x.K), inner)];
    }

    private static Scheme<RoundRow> RepeatScheme(int whens) => new(1, RepeatFields(whens));

    // n (id 0); times (one level) holding k (id 1), then `whens` nested whens around v (id 2).
    private static Scheme<RoundRow> TimesScheme(int whens)
    {
        var inner = Field.U8<RoundRow>(2, x => x.V);
        for (var i = 0; i < whens; i++)
            inner = Field.When(2, Condition.Eq(1, 1), inner);
        return new Scheme<RoundRow>(1,
            Field.U8<RoundRow>(0, x => x.N),
            Field.Times(1, 0, Field.U8<RoundRow>(1, x => x.K), inner));
    }

    // `whens` nested whens around a list of u8 elements: the list is one level, so the depth is whens + 1.
    private static Scheme<MixRow> WhensAroundListScheme(int whens)
    {
        Field inner = Field.List((MixRow x) => x.Xs, Field.U8<ByteEl>(0, e => e.V));
        for (var i = 0; i < whens; i++)
            inner = Field.When(1, Condition.Eq(0, 1), inner);
        return new Scheme<MixRow>(1, Field.U8<MixRow>(0, x => x.A), inner);
    }

    // `whens` nested whens around a list whose element is a nested row: the list and the nested row are two levels.
    private static Scheme<ItemsRow> WhensAroundListOfGroupScheme(int whens)
    {
        Field inner = Field.List((ItemsRow x) => x.Items,
            Field.Group((Item e) => e.S, Field.U8<Sub>(0, s => s.B)));
        for (var i = 0; i < whens; i++)
            inner = Field.When(1, Condition.Eq(0, 1), inner);
        return new Scheme<ItemsRow>(1, Field.U8<ItemsRow>(0, x => x.A), inner);
    }

    public static TheoryData<string> Kinds() => ["when", "group", "flags", "list", "dict", "repeat"];

    // The chain is built here, with the caller's own Field calls; the returned action runs only the scheme constructor.
    // A typed list or dict of rows is two levels (the list and its element row, decision D20), so `depth` levels take
    // (depth + 1) / 2 of them: 256 builds, 257 is refused.
    private static Action Prepare(string kind, int depth)
    {
        switch (kind)
        {
            case "when": { var f = WhenFields(depth); return () => _ = new Scheme<WhenRow>(1, f); }
            case "group": { var f = GroupFields(depth); return () => _ = new Scheme<Node>(1, f); }
            case "flags": { var f = FlagsFields(depth); return () => _ = new Scheme<FlagRow>(1, f); }
            case "list": { var f = ListFields((depth + 1) / 2); return () => _ = new Scheme<ListNode>(1, f); }
            case "dict": { var f = DictFields((depth + 1) / 2); return () => _ = new Scheme<DictNode>(1, f); }
            default: { var f = RepeatFields(depth - 1); return () => _ = new Scheme<RoundRow>(1, f); }
        }
    }

    [Theory]
    [MemberData(nameof(Kinds))]
    public void Ac1_Construct_257Levels_IsRefusedWithTheContractText(string kind)
    {
        // Arrange
        var build = Prepare(kind, Limit + 1);

        // Act
        var refused = Record.Exception(build);

        // Assert
        var error = Assert.IsType<ArgumentException>(refused);
        Assert.Equal(Refusal, error.Message);
    }

    [Theory]
    [MemberData(nameof(Kinds))]
    public void Ac1_Construct_256Levels_Builds(string kind)
    {
        // Arrange
        var build = Prepare(kind, Limit);

        // Act
        var refused = Record.Exception(build);

        // Assert
        Assert.Null(refused);
    }

    [Theory]
    [InlineData("when", 1_000)]
    [InlineData("when", 50_000)]
    [InlineData("group", 1_000)]
    [InlineData("group", 50_000)]
    [InlineData("flags", 50_000)]
    [InlineData("list", 5_000)]
    [InlineData("dict", 5_000)]
    [InlineData("repeat", 50_000)]
    public void Ac1_Construct_HugeChain_IsRefusedQuicklyWithNoStackError(string kind, int depth)
    {
        // Arrange
        var construct = Prepare(kind, depth);
        var clock = Stopwatch.StartNew();

        // Act
        var refused = Record.Exception(construct);

        // Assert
        clock.Stop();
        var error = Assert.IsType<ArgumentException>(refused);
        Assert.Equal(Refusal, error.Message);
        Assert.True(clock.Elapsed < TimeSpan.FromSeconds(5), $"{kind}-{depth} took {clock.Elapsed.TotalSeconds:F1} s");
    }

    [Fact]
    public void Ac1_Construct_ADeepSchemeIsRefusedBeforeOtherRulesLookAtIt()
    {
        // Arrange: a `when` that names a later field breaks another rule, but the depth is measured first.
        var inner = Field.U8<WhenRow>(1, x => x.B);
        for (var i = 0; i < Limit + 1; i++)
            inner = Field.When(1, Condition.Eq(9, 1), inner);

        // Act
        var refused = Record.Exception(() => new Scheme<WhenRow>(1, Field.U8<WhenRow>(0, x => x.A), inner));

        // Assert
        Assert.Equal(Refusal, Assert.IsType<ArgumentException>(refused).Message);
    }

    [Fact]
    public void Ac1_Construct_AListOfUint8CountsOneLevel()
    {
        // Arrange / Act
        var fits = Record.Exception(() => WhensAroundListScheme(Limit - 1));
        var refused = Record.Exception(() => WhensAroundListScheme(Limit));

        // Assert: 255 whens + the list is 256; 256 whens + the list is 257.
        Assert.Null(fits);
        Assert.Equal(Refusal, Assert.IsType<ArgumentException>(refused).Message);
    }

    [Fact]
    public void Ac1_Construct_AListOfNestedRowsCountsTheListAndTheRow()
    {
        // Arrange / Act
        var fits = Record.Exception(() => WhensAroundListOfGroupScheme(Limit - 2));
        var refused = Record.Exception(() => WhensAroundListOfGroupScheme(Limit - 1));

        // Assert: 254 whens + list + nested row is 256; 255 whens is 257.
        Assert.Null(fits);
        Assert.Equal(Refusal, Assert.IsType<ArgumentException>(refused).Message);
    }

    [Fact]
    public void Ac1_Construct_ATypedListOfRowsIsTwoLevels_D20()
    {
        // Arrange / Act: 128 typed list-of-row levels are 256 containers; 129 are 258.
        var fits = Record.Exception(() => ListScheme(Limit / 2));
        var refused = Record.Exception(() => ListScheme(Limit / 2 + 1));
        var dictFits = Record.Exception(() => DictScheme(Limit / 2));
        var dictRefused = Record.Exception(() => DictScheme(Limit / 2 + 1));

        // Assert: as in the map form, where a list around a group is two levels
        Assert.Null(fits);
        Assert.Null(dictFits);
        Assert.Equal(Refusal, Assert.IsType<ArgumentException>(refused).Message);
        Assert.Equal(Refusal, Assert.IsType<ArgumentException>(dictRefused).Message);
    }

    [Fact]
    public void Ac2_FlagBitsAddNoLevel_256FlagsEachHoldingTheNextBuild()
    {
        // Arrange / Act
        var fits = Record.Exception(() => FlagsScheme(Limit));
        var refused = Record.Exception(() => FlagsScheme(Limit + 1));

        // Assert
        Assert.Null(fits);
        Assert.Equal(Refusal, Assert.IsType<ArgumentException>(refused).Message);
    }

    [Fact]
    public void Ac2_When256Levels_PacksAndUnpacksTypedAndFromADictionary()
    {
        // Arrange
        var scheme = WhenScheme(Limit);

        // Act
        var typed = BinaryPacker.Pack(scheme, new WhenRow { A = 1, B = 7 });
        var mapped = BinaryPacker.Pack(scheme, new Dictionary<string, object?> { ["A"] = (byte)1, ["B"] = (byte)7 });
        WhenRow? got = null;
        var error = BinaryPacker.Unpack(typed, scheme.On(row => got = row));
        var read = BinaryPacker.Read(scheme, typed);

        // Assert
        Assert.Equal("010107", Hex(typed));
        Assert.Equal("010107", Hex(mapped));
        Assert.Null(error);
        Assert.Equal((1, 7), (got!.A, got.B));
        Assert.Equal((byte)7, read.Values["B"]);
    }

    [Fact]
    public void Ac2_Group256Levels_PacksAndUnpacksTypedAndFromNestedDictionaries()
    {
        // Arrange
        var scheme = GroupScheme(Limit);
        var typedValue = new Node { B = 7 };
        Dictionary<string, object?> mapped = new() { ["B"] = (byte)7 };
        for (var i = 0; i < Limit; i++)
        {
            typedValue = new Node { M = typedValue };
            mapped = new Dictionary<string, object?> { ["M"] = mapped };
        }

        // Act
        var typed = BinaryPacker.Pack(scheme, typedValue);
        var fromMap = BinaryPacker.Pack(scheme, mapped);
        Node? got = null;
        var error = BinaryPacker.Unpack(typed, scheme.On(row => got = row));

        // Assert
        Assert.Equal("0107", Hex(typed));
        Assert.Equal("0107", Hex(fromMap));
        Assert.Null(error);
        var level = got;
        for (var i = 0; i < Limit; i++)
            level = level!.M;
        Assert.Equal((byte)7, level!.B);
    }

    [Fact]
    public void Ac2_Flags256Levels_PacksAndUnpacks()
    {
        // Arrange
        var scheme = FlagsScheme(Limit);

        // Act
        var typed = BinaryPacker.Pack(scheme, new FlagRow { B = 7 });
        var mapped = BinaryPacker.Pack(scheme, new Dictionary<string, object?> { ["B"] = (byte)7 });
        FlagRow? got = null;
        var error = BinaryPacker.Unpack(typed, scheme.On(row => got = row));

        // Assert
        var expected = "01" + Repeated("01", Limit) + "07";
        Assert.Equal(expected, Hex(typed));
        Assert.Equal(expected, Hex(mapped));
        Assert.Null(error);
        Assert.Equal((byte?)7, got!.B);
    }

    [Fact]
    public void Ac2_List256Levels_PacksAndUnpacksTypedAndFromADictionary()
    {
        // Arrange
        var scheme = ListScheme(Limit / 2);
        var typedValue = new ListNode { B = 7 };
        Dictionary<string, object?> mapped = new() { ["B"] = (byte)7 };
        for (var i = 0; i < Limit / 2; i++)
        {
            typedValue = new ListNode { Kids = [typedValue] };
            mapped = new Dictionary<string, object?> { ["Kids"] = new List<object?> { mapped } };
        }

        // Act
        var typed = BinaryPacker.Pack(scheme, typedValue);
        var fromMap = BinaryPacker.Pack(scheme, mapped);
        ListNode? got = null;
        var error = BinaryPacker.Unpack(typed, scheme.On(row => got = row));

        // Assert
        var expected = "01" + Repeated("0100", Limit / 2) + "07";
        Assert.Equal(expected, Hex(typed));
        Assert.Equal(expected, Hex(fromMap));
        Assert.Null(error);
        var level = got;
        for (var i = 0; i < Limit / 2; i++)
            level = level!.Kids![0];
        Assert.Equal((byte)7, level!.B);
    }

    [Fact]
    public void Ac2_Dict256Levels_PacksAndUnpacksTypedAndFromADictionary()
    {
        // Arrange
        var scheme = DictScheme(Limit / 2);
        var typedValue = new DictNode { B = 7 };
        Dictionary<string, object?> mapped = new() { ["B"] = (byte)7 };
        for (var i = 0; i < Limit / 2; i++)
        {
            typedValue = new DictNode { Kids = new Dictionary<string, DictNode> { ["k"] = typedValue } };
            mapped = new Dictionary<string, object?> { ["Kids"] = new Dictionary<string, object?> { ["k"] = mapped } };
        }

        // Act
        var typed = BinaryPacker.Pack(scheme, typedValue);
        var fromMap = BinaryPacker.Pack(scheme, mapped);
        DictNode? got = null;
        var error = BinaryPacker.Unpack(typed, scheme.On(row => got = row));

        // Assert
        Assert.Equal(Hex(typed), Hex(fromMap));
        Assert.Null(error);
        var level = got;
        for (var i = 0; i < Limit / 2; i++)
            level = level!.Kids!["k"];
        Assert.Equal((byte)7, level!.B);
        Assert.Equal(Hex(typed), Hex(BinaryPacker.Pack(scheme, got)));
    }

    [Fact]
    public void Ac2_RepeatRoundHolding255Whens_PacksAndReadsBack()
    {
        // Arrange: repeat is one level, 255 whens inside it make 256.
        var scheme = RepeatScheme(Limit - 1);
        var row = new Dictionary<string, object?>
        {
            ["K"] = new List<object?> { (byte)1, (byte)1 },
            ["V"] = new List<object?> { (byte)7, (byte)8 },
        };

        // Act
        var packed = BinaryPacker.Pack(scheme, row);
        var read = BinaryPacker.Read(scheme, packed);

        // Assert
        Assert.Equal("010107" + "0108", Hex(packed));
        Assert.Null(read.Error);
        Assert.Equal(new object?[] { (byte)7, (byte)8 }, ((IEnumerable<object?>)read.Values["V"]!).ToArray());
    }

    [Fact]
    public void Ac2_TimesRoundHolding255Whens_PacksAndReadsBack()
    {
        // Arrange
        var scheme = TimesScheme(Limit - 1);
        var row = new Dictionary<string, object?>
        {
            ["N"] = (byte)2,
            ["K"] = new List<object?> { (byte)1, (byte)1 },
            ["V"] = new List<object?> { (byte)7, (byte)8 },
        };

        // Act
        var packed = BinaryPacker.Pack(scheme, row);
        var read = BinaryPacker.Read(scheme, packed);

        // Assert
        Assert.Equal("0102" + "0107" + "0108", Hex(packed));
        Assert.Null(read.Error);
        Assert.Equal(new object?[] { (byte)7, (byte)8 }, ((IEnumerable<object?>)read.Values["V"]!).ToArray());
    }

    [Fact]
    public void Ac2_TimesRoundHolding256Whens_IsRefused()
    {
        // Arrange / Act
        var refused = Record.Exception(() => TimesScheme(Limit));

        // Assert: times is one level, so 256 whens inside it make 257.
        Assert.Equal(Refusal, Assert.IsType<ArgumentException>(refused).Message);
    }
}
