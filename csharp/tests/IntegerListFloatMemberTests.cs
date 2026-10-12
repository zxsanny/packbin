using Packbin;

namespace Packbin.Tests;

// AZ-2411 (owner decision U12, option A): a collection of double, float or decimal bound to an integer list or dict is
// refused when the scheme is built, because pack refuses a float, double or decimal for an integer element (AZ-2373). The
// build check is the binding's own predicate (loop 20 lesson): every member type is built, packed and unpacked here with
// every integer kind, and a scheme that builds must pack and unpack; a float member for an integer element must not
// build and could not have packed.
public class IntegerListFloatMemberTests
{
    public sealed class Row<M>
    {
        public M? Ids { get; set; }
        public byte A { get; set; }
        public ushort B { get; set; }
        public uint C { get; set; }
        public ulong D { get; set; }
        public sbyte E { get; set; }
        public short F { get; set; }
        public int G { get; set; }
        public long H { get; set; }
        public float I { get; set; }
        public double J { get; set; }
        public int S { get; set; }
    }

    public static readonly string[] Kinds = ["u8", "u16", "u32", "u64", "i8", "i16", "i32", "i64", "u2", "f32", "f64"];

    private static bool IsInteger(string kind) => kind[0] is 'u' or 'i';

    private static Field Elem<M>(string kind) => kind switch
    {
        "u8" => Field.U8<Row<M>>(0, x => x.A),
        "u16" => Field.U16<Row<M>>(0, x => x.B),
        "u32" => Field.U32<Row<M>>(0, x => x.C),
        "u64" => Field.U64<Row<M>>(0, x => x.D),
        "i8" => Field.I8<Row<M>>(0, x => x.E),
        "i16" => Field.I16<Row<M>>(0, x => x.F),
        "i32" => Field.I32<Row<M>>(0, x => x.G),
        "i64" => Field.I64<Row<M>>(0, x => x.H),
        "u2" => Field.U2<Row<M>>((0, x => x.S)),
        "f32" => Field.F32<Row<M>>(0, x => x.I),
        _ => Field.F64<Row<M>>(0, x => x.J),
    };

    private static Scheme<Row<M>> Build<M>(string kind, bool dict) =>
        new(1, dict ? Field.Dict((Row<M> x) => x.Ids, Elem<M>(kind)) : Field.List((Row<M> x) => x.Ids, Elem<M>(kind)));

    // Built?, did the typed row pack?, did the packed row unpack into a bound row?
    private readonly record struct Outcome(bool Built, bool Packed, bool Unpacked, string Refusal);

    private static Outcome Probe<M>(string kind, bool dict, M value)
    {
        Scheme<Row<M>> scheme;
        try
        {
            scheme = Build<M>(kind, dict);
        }
        catch (ArgumentException refused)
        {
            return new(false, false, false, refused.Message);
        }
        byte[] bytes;
        try
        {
            bytes = BinaryPacker.Pack(scheme, new Row<M> { Ids = value });
        }
        catch (ArgumentException)
        {
            return new(true, false, false, "");
        }
        Row<M>? bound = null;
        BinaryPacker.Unpack(bytes, scheme.On(row => bound = row));
        return new(true, true, bound is not null, "");
    }

    // Whether pack takes this boxed element for the kind: the member-free predicate, a row of object elements.
    private static bool PacksAsObject(string kind, bool dict, object element)
    {
        try
        {
            if (dict)
                BinaryPacker.Pack(Build<Dictionary<string, object?>>(kind, true), new Row<Dictionary<string, object?>> { Ids = new() { ["a"] = element } });
            else
                BinaryPacker.Pack(Build<List<object?>>(kind, false), new Row<List<object?>> { Ids = [element] });
            return true;
        }
        catch (ArgumentException)
        {
            return false;
        }
    }

    // A member type, how it probes, and the boxed element a row of it holds (a 1: a u2 slot takes 0 to 3).
    private sealed record Case(string Name, Func<string, Outcome> Run, object Element, bool Floating, bool Dictionary);

    private static Case List<M>(string name, M value, object element, bool floating) =>
        new(name, kind => Probe(kind, false, value), element, floating, false);

    private static Case Map<M>(string name, M value, object element, bool floating) =>
        new(name, kind => Probe(kind, true, value), element, floating, true);

    private static readonly Case[] Cases =
    [
        List<List<double>>("List<double>", [1.0], 1.0, true),
        List<List<float>>("List<float>", [1f], 1f, true),
        List<List<decimal>>("List<decimal>", [1m], 1m, true),
        List<List<double?>>("List<double?>", [1.0], 1.0, true),
        List<List<float?>>("List<float?>", [1f], 1f, true),
        List<List<decimal?>>("List<decimal?>", [1m], 1m, true),
        List<double[]>("double[]", [1.0], 1.0, true),
        List<float[]>("float[]", [1f], 1f, true),
        List<decimal[]>("decimal[]", [1m], 1m, true),
        List<IList<double>>("IList<double>", new List<double> { 1.0 }, 1.0, true),
        List<IList<float>>("IList<float>", new List<float> { 1f }, 1f, true),
        List<IList<decimal>>("IList<decimal>", new List<decimal> { 1m }, 1m, true),
        List<List<long>>("List<long>", [1L], 1L, false),
        List<List<int>>("List<int>", [1], 1, false),
        List<List<ulong>>("List<ulong>", [1UL], 1UL, false),
        List<List<int?>>("List<int?>", [1], 1, false),
        List<int[]>("int[]", [1], 1, false),
        List<IList<long>>("IList<long>", new List<long> { 1L }, 1L, false),
        List<List<object?>>("List<object?>", [1], 1, false),
        List<object[]>("object[]", [1], 1, false),
        List<System.Collections.IList>("IList", new List<object?> { 1 }, 1, false),
        Map<Dictionary<string, double>>("Dictionary<string,double>", new() { ["a"] = 1.0 }, 1.0, true),
        Map<Dictionary<string, float>>("Dictionary<string,float>", new() { ["a"] = 1f }, 1f, true),
        Map<Dictionary<string, decimal>>("Dictionary<string,decimal>", new() { ["a"] = 1m }, 1m, true),
        Map<IDictionary<string, double>>("IDictionary<string,double>", new Dictionary<string, double> { ["a"] = 1.0 }, 1.0, true),
        Map<Dictionary<string, long>>("Dictionary<string,long>", new() { ["a"] = 1L }, 1L, false),
        Map<Dictionary<string, object?>>("Dictionary<string,object?>", new() { ["a"] = 1 }, 1, false),
    ];

    public static IEnumerable<object[]> Matrix() =>
        from c in Cases from kind in Kinds select new object[] { c.Name, kind };

    private static Case Find(string name) => Cases.Single(c => c.Name == name);

    [Theory]
    [MemberData(nameof(Matrix))]
    public void Member_BuildsIfAndOnlyIfItPacksAndUnpacks(string member, string kind)
    {
        // Arrange
        var c = Find(member);

        // Act
        var outcome = c.Run(kind);

        // Assert
        if (c.Floating && IsInteger(kind))
        {
            Assert.False(outcome.Built);
            Assert.Contains("'Ids'", outcome.Refusal, StringComparison.Ordinal);
            Assert.Contains(c.Element.GetType().Name, outcome.Refusal, StringComparison.Ordinal);
            Assert.False(PacksAsObject(kind, c.Dictionary, c.Element), "refused member would have packed");
            return;
        }
        // Every other member: what builds also packs and unpacks (a member too narrow for the kind may be refused).
        if (outcome.Built)
        {
            Assert.True(outcome.Packed, "built but pack refused it");
            Assert.True(outcome.Unpacked, "built but unpack did not bind it");
        }
    }

    [Theory]
    [InlineData("List<long>", "u32")]
    [InlineData("List<int>", "u8")]
    [InlineData("List<object?>", "u64")]
    [InlineData("List<ulong>", "u64")]
    [InlineData("int[]", "i16")]
    [InlineData("IList<long>", "u16")]
    [InlineData("Dictionary<string,long>", "i32")]
    [InlineData("Dictionary<string,object?>", "u8")]
    public void IntegerList_BoundToAnIntegerMemberThatHoldsTheKind_StillBuildsPacksAndUnpacks(string member, string kind)
    {
        // Act
        var outcome = Find(member).Run(kind);

        // Assert
        Assert.True(outcome.Built, outcome.Refusal);
        Assert.True(outcome.Packed);
        Assert.True(outcome.Unpacked);
    }

    [Theory]
    [InlineData("List<double>")]
    [InlineData("List<float>")]
    [InlineData("List<decimal>")]
    [InlineData("double[]")]
    [InlineData("Dictionary<string,double>")]
    public void IntegerList_BoundToFloatMember_IsRefusedNamingMemberAndType(string member)
    {
        // Act
        var outcome = Find(member).Run("u8");

        // Assert
        Assert.False(outcome.Built);
        Assert.Contains("'Ids'", outcome.Refusal, StringComparison.Ordinal);
        Assert.Contains(Find(member).Element.GetType().Name, outcome.Refusal, StringComparison.Ordinal);
    }

    [Theory]
    [InlineData("List<double>", "f32")]
    [InlineData("List<double>", "f64")]
    [InlineData("List<float>", "f32")]
    [InlineData("double[]", "f64")]
    [InlineData("IList<double>", "f64")]
    [InlineData("Dictionary<string,double>", "f64")]
    public void FloatList_BoundToFloatMember_StillBuildsPacksAndUnpacks(string member, string kind)
    {
        // Act
        var outcome = Find(member).Run(kind);

        // Assert
        Assert.True(outcome.Built, outcome.Refusal);
        Assert.True(outcome.Packed);
        Assert.True(outcome.Unpacked);
    }

    [Theory]
    [InlineData("u8", "0102000102")]
    [InlineData("u32", "010200" + "01000000" + "02000000")]
    [InlineData("i16", "01020001000200")]
    public void IntegerList_BoundToAnIntegerMember_KeepsItsWireBytes(string kind, string expected)
    {
        // Arrange
        var scheme = Build<List<long>>(kind, false);

        // Act
        var bytes = BinaryPacker.Pack(scheme, new Row<List<long>> { Ids = [1, 2] });

        // Assert
        Assert.Equal(expected, Convert.ToHexString(bytes).ToLowerInvariant());
    }
}
