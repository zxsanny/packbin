using System.Collections;
using Packbin;

namespace Packbin.Tests;

// Loop 20 review A1, A2: in a repeat or times round a list or dict member holds one value per round, and the scheme
// builds if and only if typed Unpack can bind that member. Every member type is built and unpacked here with a U8 and a U32
// list in a repeat and in a times, so the two sides cannot drift apart again.
public class RoundCollectionMemberTests
{
    public sealed class RoundRow<M>
    {
        public byte B { get; set; }
        public uint U { get; set; }
        public byte Count { get; set; }
        public byte K { get; set; }
        public M? Ids { get; set; }
    }

    private static string Show(object? value) => value switch
    {
        null => "null",
        IDictionary map => "{" + string.Join(",", map.Keys.Cast<object>().Select(k => $"{k}:{Show(map[k])}")) + "}",
        IEnumerable items => "[" + string.Join(",", items.Cast<object?>().Select(Show)) + "]",
        _ => value.ToString()!,
    };

    private static Field Elem<M>(bool wide) =>
        wide ? Field.U32<RoundRow<M>>(0, x => x.U) : Field.U8<RoundRow<M>>(0, x => x.B);

    private static Field Collection<M>(bool dict, bool wide) =>
        dict ? Field.Dict((RoundRow<M> x) => x.Ids, Elem<M>(wide)) : Field.List((RoundRow<M> x) => x.Ids, Elem<M>(wide));

    private static Scheme<RoundRow<M>> Build<M>(bool dict, bool wide, bool times) =>
        times
            ? new(1, Field.U8<RoundRow<M>>(0, x => x.Count), Field.Times(1, 0, Collection<M>(dict, wide)))
            : new(1, Field.Repeat(0, Collection<M>(dict, wide)));

    // Two rounds holding 10 and 11 (a dict holds them under the key "a").
    private static byte[] Packet(bool dict, bool wide, bool times)
    {
        var packet = new List<byte> { 1 };
        if (times)
            packet.Add(2);
        foreach (byte value in new byte[] { 0x0a, 0x0b })
        {
            packet.AddRange(new byte[] { 1, 0 });
            if (dict)
                packet.AddRange(new byte[] { 2, 0x10, 0x61 });
            packet.Add(value);
            if (wide)
                packet.AddRange(new byte[3]);
        }
        return [.. packet];
    }

    // Builds? and the outcome of unpacking two rounds: the member as text, "short:<field>" or the exception type (the
    // refusal's message when it does not build).
    private static (bool Built, string Outcome) Probe<M>(bool dict, bool wide, bool times)
    {
        Scheme<RoundRow<M>> scheme;
        try
        {
            scheme = Build<M>(dict, wide, times);
        }
        catch (ArgumentException refused)
        {
            return (false, refused.Message);
        }
        try
        {
            RoundRow<M>? bound = null;
            var result = BinaryPacker.Unpack(Packet(dict, wide, times), scheme.On(row => bound = row));
            return (true, bound is not null ? Show(bound.Ids) : result is ShortPacket short1 ? "short:" + short1.Field : "other");
        }
        catch (Exception thrown)
        {
            return (true, "threw " + thrown.GetType().Name);
        }
    }

    private static (bool Built, string Outcome) Run(string member, bool dict, bool wide, bool times) => member switch
    {
        "List<int>" => Probe<List<int>>(dict, wide, times),
        "List<long>" => Probe<List<long>>(dict, wide, times),
        "List<List<object?>>" => Probe<List<List<object?>>>(dict, wide, times),
        "List<object?>" => Probe<List<object?>>(dict, wide, times),
        "IList" => Probe<IList>(dict, wide, times),
        "IList<object?>" => Probe<IList<object?>>(dict, wide, times),
        "object[]" => Probe<object[]>(dict, wide, times),
        "object" => Probe<object>(dict, wide, times),
        "int[]" => Probe<int[]>(dict, wide, times),
        "Dictionary<string,object?>" => Probe<Dictionary<string, object?>>(dict, wide, times),
        "List<Dictionary<string,object?>>" => Probe<List<Dictionary<string, object?>>>(dict, wide, times),
        "ICollection<object?>" => Probe<ICollection<object?>>(dict, wide, times),
        "IEnumerable" => Probe<IEnumerable>(dict, wide, times),
        "IReadOnlyList<object?>" => Probe<IReadOnlyList<object?>>(dict, wide, times),
        "List<IList>" => Probe<List<IList>>(dict, wide, times),
        "List<object>" => Probe<List<object>>(dict, wide, times),
        "IList[]" => Probe<IList[]>(dict, wide, times),
        "List<List<int>>" => Probe<List<List<int>>>(dict, wide, times),
        "int[][]" => Probe<int[][]>(dict, wide, times),
        "object[,]" => Probe<object[,]>(dict, wide, times),
        "string" => Probe<string>(dict, wide, times),
        "byte" => Probe<byte>(dict, wide, times),
        "IList<int>" => Probe<IList<int>>(dict, wide, times),
        _ => throw new ArgumentException(member),
    };

    public static IEnumerable<object[]> Members()
    {
        foreach (var member in new[]
                 {
                     "List<int>", "List<long>", "List<List<object?>>", "List<object?>", "IList", "IList<object?>", "object[]",
                     "object", "int[]", "Dictionary<string,object?>", "List<Dictionary<string,object?>>", "ICollection<object?>",
                     "IEnumerable", "IReadOnlyList<object?>", "List<IList>", "List<object>", "IList[]", "List<List<int>>",
                     "int[][]", "object[,]", "string", "byte", "IList<int>",
                 })
            foreach (var wide in new[] { false, true })
                foreach (var times in new[] { false, true })
                    yield return [member, wide, times];
    }

    // Every member a list holds one list per round in.
    private static readonly string[] Binding =
    [
        "List<List<object?>>", "List<object?>", "IList", "IList<object?>", "object[]", "object", "ICollection<object?>",
        "IEnumerable", "IReadOnlyList<object?>", "List<IList>", "List<object>", "IList[]",
    ];

    [Theory]
    [MemberData(nameof(Members))]
    public void ListInARound_BuildsIfAndOnlyIfTypedUnpackBindsIt(string member, bool wide, bool times)
    {
        // Arrange
        var binds = Array.IndexOf(Binding, member) >= 0;

        // Act
        var (built, outcome) = Run(member, dict: false, wide, times);

        // Assert
        Assert.Equal(binds, built);
        if (built)
            Assert.Equal("[[10],[11]]", outcome);
    }

    [Theory]
    [InlineData("List<int>")]
    [InlineData("List<long>")]
    [InlineData("int[]")]
    [InlineData("List<List<int>>")]
    public void ListOfScalarsInARound_IsRefusedNamingTheMember(string member)
    {
        // Act
        var scheme = Record.Exception(() => Run(member, dict: false, wide: false, times: false));

        // Assert (Run reports the refusal as Built == false and never throws)
        Assert.Null(scheme);
        Assert.False(Run(member, dict: false, wide: false, times: false).Built);
    }

    [Fact]
    public void ObjectArrayInARound_BindsAsBefore()
    {
        // Act
        var (built, outcome) = Run("object[]", dict: false, wide: false, times: false);

        // Assert
        Assert.True(built);
        Assert.Equal("[[10],[11]]", outcome);
    }

    // Every member a dict holds one dictionary per round in (AZ-2389).
    private static readonly string[] DictBinding =
    [
        "List<Dictionary<string,object?>>", "List<object?>", "IList", "IList<object?>", "object[]", "object",
        "ICollection<object?>", "IEnumerable", "IReadOnlyList<object?>", "List<object>",
    ];

    [Theory]
    [MemberData(nameof(Members))]
    public void DictInARound_BuildsIfAndOnlyIfTypedUnpackBindsIt(string member, bool wide, bool times)
    {
        // Arrange
        var binds = Array.IndexOf(DictBinding, member) >= 0;

        // Act
        var (built, outcome) = Run(member, dict: true, wide, times);

        // Assert (the same predicate decides the build and the binding: no member builds and then fails to bind)
        Assert.Equal(binds, built);
        if (built)
            Assert.Equal("[{a:10},{a:11}]", outcome);
    }

    [Theory]
    [InlineData("Dictionary<string,object?>")]
    [InlineData("string")]
    [InlineData("List<int>")]
    [InlineData("int[]")]
    public void DictInARound_ThatCannotHoldTheRounds_IsRefusedAtConstructionNamingTheMember(string member)
    {
        // Act
        var (built, message) = Run(member, dict: true, wide: false, times: false);

        // Assert
        Assert.False(built);
        Assert.Contains("'Ids'", message);
        Assert.Contains("one dictionary per round", message);
    }

    [Fact]
    public void ListInARound_OneRound_BindsAListOfOneList()
    {
        // Arrange
        var scheme = Build<List<List<object?>>>(dict: false, wide: false, times: false);
        RoundRow<List<List<object?>>>? bound = null;

        // Act
        BinaryPacker.Unpack(new byte[] { 1, 1, 0, 0x0a }, scheme.On(row => bound = row));

        // Assert
        Assert.Equal("[[10]]", Show(bound!.Ids));
    }
}
