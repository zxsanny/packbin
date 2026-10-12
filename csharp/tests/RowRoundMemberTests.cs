using System.Collections;
using Packbin;

namespace Packbin.Tests;

// AZ-2388: the member a typed repeat or times binds rows to. A member builds if and only if typed Unpack binds it (one
// RowRounds object answers both), tried here for every member type with a repeat and a times.
public class RowRoundMemberTests
{
    // The member types a round is declared with, built and unpacked with two rounds. A member builds if and only if typed
    // Unpack binds it; the outcome is the V of each row it received.
    private sealed class Holder<M>
    {
        public byte N { get; set; }
        public M? Items { get; set; }
    }

    private sealed class Seat
    {
        public byte V { get; set; }
    }

    public sealed class NoDefault
    {
        public NoDefault(int v) => V = (byte)v;

        public byte V { get; set; }
    }

    public abstract class Abstract
    {
        public byte V { get; set; }
    }

    public struct Value
    {
        public byte V { get; set; }
    }

    private static (bool Built, string Outcome) Probe<M>(bool times)
    {
        Scheme<Holder<M>> scheme;
        try
        {
            scheme = times
                ? new Scheme<Holder<M>>(1, Field.U8<Holder<M>>(0, x => x.N), Field.Times(1, 0, (Holder<M> x) => x.Items, Field.U8<Seat>(1, s => s.V)))
                : new Scheme<Holder<M>>(1, Field.Repeat(0, (Holder<M> x) => x.Items, Field.U8<Seat>(0, s => s.V)));
        }
        catch (ArgumentException refused)
        {
            return (false, refused.Message);
        }
        Holder<M>? bound = null;
        var packet = times ? new byte[] { 1, 2, 10, 11 } : [1, 10, 11];
        var result = BinaryPacker.Unpack(packet, scheme.On(row => bound = row));
        if (bound is null)
            return (true, "not bound: " + result);
        var seen = (bound.Items as IEnumerable)?.Cast<object>().Select(o => ((Seat)o).V.ToString());
        return (true, seen is null ? "null" : string.Join(",", seen));
    }

    private static (bool Built, string Outcome) Run(string member, bool times) => member switch
    {
        "List<Seat>" => Probe<List<Seat>>(times),
        "Seat[]" => Probe<Seat[]>(times),
        "IList<Seat>" => Probe<IList<Seat>>(times),
        "List<Seat?>" => Probe<List<Seat?>>(times),
        "ICollection<Seat>" => Probe<ICollection<Seat>>(times),
        "IReadOnlyList<Seat>" => Probe<IReadOnlyList<Seat>>(times),
        "IEnumerable<Seat>" => Probe<IEnumerable<Seat>>(times),
        "HashSet<Seat>" => Probe<HashSet<Seat>>(times),
        "Seat[,]" => Probe<Seat[,]>(times),
        "Seat[][]" => Probe<Seat[][]>(times),
        "IList" => Probe<IList>(times),
        "List<object>" => Probe<List<object>>(times),
        "object" => Probe<object>(times),
        "List<int>" => Probe<List<int>>(times),
        "List<NoDefault>" => Probe<List<NoDefault>>(times),
        "List<Abstract>" => Probe<List<Abstract>>(times),
        "List<Value>" => Probe<List<Value>>(times),
        "Seat" => Probe<Seat>(times),
        "string" => Probe<string>(times),
        "byte" => Probe<byte>(times),
        _ => throw new ArgumentException(member),
    };

    private static readonly string[] Binding = ["List<Seat>", "Seat[]", "IList<Seat>", "List<Seat?>"];

    public static IEnumerable<object[]> MemberTypes()
    {
        foreach (var member in new[]
                 {
                     "List<Seat>", "Seat[]", "IList<Seat>", "List<Seat?>", "ICollection<Seat>", "IReadOnlyList<Seat>",
                     "IEnumerable<Seat>", "HashSet<Seat>", "Seat[,]", "Seat[][]", "IList", "List<object>", "object", "List<int>",
                     "List<NoDefault>", "List<Abstract>", "List<Value>", "Seat", "string", "byte",
                 })
            foreach (var times in new[] { false, true })
                yield return [member, times];
    }

    [Theory]
    [MemberData(nameof(MemberTypes))]
    public void Ac2_Scheme_RoundMember_BuildsIfAndOnlyIfTypedUnpackBindsIt(string member, bool times)
    {
        // Arrange
        var binds = Array.IndexOf(Binding, member) >= 0;

        // Act
        var (built, outcome) = Run(member, times);

        // Assert
        Assert.Equal(binds, built);
        Assert.Equal(binds, outcome == "10,11");
    }

    [Theory]
    [InlineData("HashSet<Seat>")]
    [InlineData("IList")]
    [InlineData("List<int>")]
    [InlineData("List<Value>")]
    [InlineData("Seat")]
    public void Ac2_Scheme_MemberThatIsNotACollectionOfRows_IsRefusedNamingTheMember(string member)
    {
        // Act
        var (built, message) = Run(member, times: true);

        // Assert
        Assert.False(built);
        Assert.StartsWith("'Items': ", message, StringComparison.Ordinal);
        Assert.Contains("E[], List<E> or IList<E>", message, StringComparison.Ordinal);
    }

    [Theory]
    [InlineData("List<NoDefault>", "NoDefault")]
    [InlineData("List<Abstract>", "Abstract")]
    public void Ac2_Scheme_RowTypeUnpackCannotCreate_IsRefusedNamingTheType(string member, string type)
    {
        // Act
        var (built, message) = Run(member, times: false);

        // Assert
        Assert.False(built);
        Assert.Equal($"'Items': row type {type} needs a public parameterless constructor to be unpacked", message);
    }
}
