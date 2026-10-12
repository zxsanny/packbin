using Packbin;

namespace Packbin.Tests;

// AZ-2305: a collection member that cannot hold its element field, or that Packbin cannot build, is refused when the
// scheme is built, so no packet can make Unpack throw on it.
public class CollectionMemberTests
{
    private sealed class El
    {
        public uint V { get; set; }
    }

    private sealed class Small
    {
        public ushort V { get; set; }
    }

    private sealed class Text
    {
        public string V { get; set; } = "";
    }

    private sealed class Wide
    {
        public long V { get; set; }
    }

    private sealed class IntsRow
    {
        public List<int>? Ids { get; set; }
    }

    private sealed class IntArrayRow
    {
        public int[]? Ids { get; set; }
    }

    private sealed class IntMapRow
    {
        public Dictionary<string, int>? Ids { get; set; }
    }

    private sealed class LongsRow
    {
        public List<long>? Ids { get; set; }
    }

    private sealed class BytesRow
    {
        public List<byte>? Ids { get; set; }
    }

    private sealed class StackRow
    {
        public Stack<int>? Ids { get; set; }
    }

    private sealed class SetRow
    {
        public HashSet<int>? Ids { get; set; }
    }

    private sealed class EnumerableRow
    {
        public IEnumerable<int>? Ids { get; set; }
    }

    private sealed class IntKeyRow
    {
        public Dictionary<int, long>? Ids { get; set; }
    }

    private sealed class RoleList : List<string>
    {
    }

    private sealed class SubclassRow
    {
        public RoleList? Roles { get; set; }
    }

    private sealed class MixedRow
    {
        public List<string>? Names { get; set; }
        public List<uint>? Wide { get; set; }
        public double[]? Doubles { get; set; }
        public List<object?>? Any { get; set; }
        public IList<ulong>? Big { get; set; }
        public IDictionary<string, long>? Map { get; set; }
    }

    private sealed class Num<T>
    {
        public T? V { get; set; }
    }

    private static void ExpectRefused(Action build, string member, string element)
    {
        var error = Assert.Throws<ArgumentException>(build);

        Assert.Contains($"'{member}'", error.Message, StringComparison.Ordinal);
        Assert.Contains(element, error.Message, StringComparison.Ordinal);
    }

    [Fact]
    public void Build_ListOfIntForU32_RefusedNamingMemberAndElement() =>
        ExpectRefused(() => new Scheme<IntsRow>(1, Field.List((IntsRow x) => x.Ids, Field.U32<El>(0, e => e.V))), "Ids", "Int32");

    [Fact]
    public void Build_ArrayOfIntForU32_RefusedNamingMemberAndElement() =>
        ExpectRefused(() => new Scheme<IntArrayRow>(1, Field.List((IntArrayRow x) => x.Ids, Field.U32<El>(0, e => e.V))), "Ids", "Int32");

    [Fact]
    public void Build_DictOfIntForU32_RefusedNamingMemberAndElement() =>
        ExpectRefused(() => new Scheme<IntMapRow>(1, Field.Dict((IntMapRow x) => x.Ids, Field.U32<El>(0, e => e.V))), "Ids", "Int32");

    [Fact]
    public void Build_ListOfByteForU16_RefusedNamingMemberAndElement() =>
        ExpectRefused(() => new Scheme<BytesRow>(1, Field.List((BytesRow x) => x.Ids, Field.U16<Small>(0, e => e.V))), "Ids", "Byte");

    [Fact]
    public void Build_EveryIntegerPair_AcceptedOnlyWhenTheMemberHoldsTheFieldRange()
    {
        // Arrange
        Func<string, Field> element = kind => kind switch
        {
            "U8" => Field.U8<Num<byte>>(0, e => e.V),
            "I8" => Field.I8<Num<sbyte>>(0, e => e.V),
            "U16" => Field.U16<Num<ushort>>(0, e => e.V),
            "I16" => Field.I16<Num<short>>(0, e => e.V),
            "U32" => Field.U32<Num<uint>>(0, e => e.V),
            "I32" => Field.I32<Num<int>>(0, e => e.V),
            "U64" => Field.U64<Num<ulong>>(0, e => e.V),
            _ => Field.I64<Num<long>>(0, e => e.V),
        };
        string[] kinds = ["U8", "I8", "U16", "I16", "U32", "I32", "U64", "I64"];
        Type[] members = [typeof(byte), typeof(sbyte), typeof(ushort), typeof(short), typeof(uint), typeof(int), typeof(ulong), typeof(long)];
        decimal[][] ranges =
        [
            [0, 255], [-128, 127], [0, 65535], [-32768, 32767], [0, 4294967295], [-2147483648, 2147483647],
            [0, 18446744073709551615m], [-9223372036854775808m, 9223372036854775807m],
        ];

        for (var f = 0; f < kinds.Length; f++)
        {
            for (var m = 0; m < members.Length; m++)
            {
                var holds = ranges[m][0] <= ranges[f][0] && ranges[m][1] >= ranges[f][1];

                // Act
                var built = Record.Exception(() => Build(members[m], element(kinds[f])));

                // Assert
                Assert.True(holds == (built is null), $"{members[m].Name} for {kinds[f]}: {built?.Message}");
                if (!holds)
                    Assert.IsType<ArgumentException>(built);
            }
        }
    }

    private static void Build(Type member, Field element)
    {
        var typed = typeof(CollectionMemberTests)
            .GetMethod(nameof(BuildTyped), System.Reflection.BindingFlags.NonPublic | System.Reflection.BindingFlags.Static)!
            .MakeGenericMethod(member);
        try
        {
            typed.Invoke(null, [element]);
        }
        catch (System.Reflection.TargetInvocationException ex)
        {
            System.Runtime.ExceptionServices.ExceptionDispatchInfo.Capture(ex.InnerException!).Throw();
        }
    }

    public sealed class Holder<T>
    {
        public List<T>? Ids { get; set; }
    }

    private static void BuildTyped<T>(Field element) =>
        _ = new Scheme<Holder<T>>(1, Field.List((Holder<T> x) => x.Ids, element));

    [Fact]
    public void Build_StackForAList_RefusedNamingMember() =>
        ExpectRefused(() => new Scheme<StackRow>(1, Field.List((StackRow x) => x.Ids, Field.U32<El>(0, e => e.V))), "Ids", "Stack");

    [Fact]
    public void Build_HashSetForAList_RefusedNamingMember() =>
        ExpectRefused(() => new Scheme<SetRow>(1, Field.List((SetRow x) => x.Ids, Field.U32<El>(0, e => e.V))), "Ids", "HashSet");

    [Fact]
    public void Build_IEnumerableForAList_RefusedNamingMember() =>
        ExpectRefused(() => new Scheme<EnumerableRow>(1, Field.List((EnumerableRow x) => x.Ids, Field.U32<El>(0, e => e.V))), "Ids", "IEnumerable");

    [Fact]
    public void Build_SubclassOfListForAList_RefusedNamingMember() =>
        ExpectRefused(() => new Scheme<SubclassRow>(1, Field.List((SubclassRow x) => x.Roles, Field.Utf8<Text>(0, e => e.V))), "Roles", "RoleList");

    [Fact]
    public void Build_DictionaryWithIntKeysForADict_RefusedNamingMember() =>
        ExpectRefused(() => new Scheme<IntKeyRow>(1, Field.Dict((IntKeyRow x) => x.Ids, Field.I64<Wide>(0, e => e.V))), "Ids", "Dictionary");

    [Fact]
    public void Unpack_F25Packet_AgainstWideEnoughScheme_ReturnsValueNotException()
    {
        // Arrange
        var scheme = new Scheme<LongsRow>(1, Field.List((LongsRow x) => x.Ids, Field.U32<El>(0, e => e.V)));
        LongsRow? got = null;
        byte[] packet = [0x01, 0x01, 0x00, 0xFF, 0xFF, 0xFF, 0xFF];

        // Act
        var result = BinaryPacker.Unpack(packet, scheme.On(r => got = r));

        // Assert
        Assert.Null(result);
        Assert.Equal([4294967295L], got!.Ids);
    }

    // AZ-2411: pack refuses a double for an integer element, so a double[] for a u32 list does not build (the member
    // stays in MixedRow for this refusal).
    [Fact]
    public void Build_DoubleArrayForAnIntegerList_RefusedNamingMemberAndType() =>
        ExpectRefused(() => new Scheme<MixedRow>(1, Field.List((MixedRow x) => x.Doubles, Field.U32<El>(0, e => e.V))), "Doubles", "Double");

    [Fact]
    public void Build_MatchingAndWiderMembers_Accepted()
    {
        // Arrange
        var element = Field.U32<El>(0, e => e.V);
        var names = Field.Utf8<Text>(0, e => e.V);

        // Act
        var built = Record.Exception(() => new Scheme<MixedRow>(
            1,
            Field.List((MixedRow x) => x.Names, names),
            Field.List((MixedRow x) => x.Wide, element),
            Field.List((MixedRow x) => x.Any, element),
            Field.List((MixedRow x) => x.Big, element),
            Field.Dict((MixedRow x) => x.Map, element)));

        // Assert
        Assert.Null(built);
    }

    private sealed class FloatEl
    {
        public double D { get; set; }
        public float F { get; set; }
    }

    private sealed class FloatsRow
    {
        public List<float>? Singles { get; set; }
        public List<double>? Doubles { get; set; }
        public List<int>? Ints { get; set; }
    }

    [Fact]
    public void Build_SingleForF64_RefusedAndDoubleForF32_Accepted()
    {
        // Act
        var narrow = Assert.Throws<ArgumentException>(() => new Scheme<FloatsRow>(
            1, Field.List((FloatsRow x) => x.Singles, Field.F64<FloatEl>(0, e => e.D))));
        var wide = Record.Exception(() => new Scheme<FloatsRow>(
            1, Field.List((FloatsRow x) => x.Doubles, Field.F32<FloatEl>(0, e => e.F))));

        // Assert
        Assert.Contains("'Singles'", narrow.Message, StringComparison.Ordinal);
        Assert.Null(wide);
    }

    [Fact]
    public void Build_ListOfIntForUtf8_RefusedNamingMember() =>
        ExpectRefused(() => new Scheme<FloatsRow>(1, Field.List((FloatsRow x) => x.Ints, Field.Utf8<Text>(0, e => e.V))), "Ints", "Int32");
}
