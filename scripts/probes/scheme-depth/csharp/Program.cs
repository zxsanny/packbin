// Probe of AZ-4291: how deep may a scheme be nested. Usage: Probe <when|group> <depth>.
// Prints one tab-separated line: package, shape-with-depth, build, pack, unpack. It asserts nothing.
//
// Form used for the group shape: the nested-row group (Fields.Group(x => x.M, ...), a group without an
// anchor) over ONE recursive row class, Node { Node? M; byte B }. A chain of D classes would be impractical,
// and the dictionary form cannot be read back by the public Unpack, but one class that holds itself can be
// nested to any depth: group k binds the member M of the Node that group k-1 reads. The scheme and the values
// are built in loops, innermost first, so the probe never recurses; its comparison of the result is a loop too.
//
// No bigger stack and no setting: the default behaviour is the finding. A .NET stack overflow kills the
// process (the run.sh line then says `crashed`). A package error (ArgumentException, InvalidOperationException,
// or an error value returned by Unpack) is "refused"; any other exception is "threw".
using System.Text.RegularExpressions;
using Packbin;

namespace DepthProbe;

public sealed class WhenRow
{
    public byte A { get; set; }
    public byte B { get; set; }
}

public sealed class Node
{
    public Node? M { get; set; }
    public byte B { get; set; }
}

public static class Program
{
    private static string OneLine(string text) => Regex.Replace(text, @"\s+", " ").Trim();

    private static string Cut(string text) => text.Length > 120 ? text[..120] : text;

    private static string Failure(Exception e) =>
        e is ArgumentException or InvalidOperationException
            ? "refused: " + Cut(OneLine($"{e.GetType().Name}: {e.Message}"))
            : "threw: " + e.GetType().Name;

    private static string Hex(byte[] bytes)
    {
        var all = Convert.ToHexString(bytes).ToLowerInvariant();
        return all.Length > 80 ? all[..40] + "...(" + bytes.Length + " bytes)" : all;
    }

    private static Field WhenChain(int depth)
    {
        var inner = Field.U8<WhenRow>(1, x => x.B);
        for (var i = 0; i < depth; i++)
            inner = Field.When(1, Condition.Eq(0, 1), inner);
        return inner;
    }

    private static Field GroupChain(int depth)
    {
        var inner = Field.U8<Node>(0, x => x.B);
        for (var i = 0; i < depth; i++)
            inner = Field.Group((Node x) => x.M, inner);
        return inner;
    }

    private static Node GroupValues(int depth)
    {
        var inner = new Node { B = 7 };
        for (var i = 0; i < depth; i++)
            inner = new Node { M = inner };
        return inner;
    }

    private static string? CompareGroups(Node? got, Node given, int depth)
    {
        var a = got;
        var b = given;
        for (var i = 0; i < depth; i++)
        {
            if (a?.M is null)
                return "level " + i + " has no member M";
            a = a.M;
            b = b.M!;
        }
        return a!.B == b.B && a.M is null ? null : "innermost B=" + a.B;
    }

    private static void Run<T>(string start, Func<Scheme<T>> build, T values, Func<T, string?> compare)
        where T : class, new()
    {
        Scheme<T> scheme;
        try
        {
            scheme = build();
        }
        catch (Exception e)
        {
            Console.WriteLine(start + Failure(e) + "\t-\t-");
            return;
        }
        start += "built\t";

        byte[] packed;
        try
        {
            packed = BinaryPacker.Pack(scheme, values);
        }
        catch (Exception e)
        {
            Console.WriteLine(start + Failure(e) + "\t-");
            return;
        }
        start += Hex(packed) + "\t";

        T? got = null;
        object? result;
        try
        {
            result = BinaryPacker.Unpack(packed, scheme.On(row => got = row));
        }
        catch (Exception e)
        {
            Console.WriteLine(start + Failure(e));
            return;
        }
        if (result is not null || got is null)
        {
            Console.WriteLine(start + "refused: " + (result?.GetType().Name ?? "no row"));
            return;
        }
        string? diff;
        try
        {
            diff = compare(got);
        }
        catch (Exception e)
        {
            Console.WriteLine(start + "threw: probe " + e.GetType().Name);
            return;
        }
        Console.WriteLine(start + (diff is null ? "same" : "differs: " + Cut(OneLine(diff))));
    }

    public static void Main(string[] args)
    {
        var shape = args[0];
        var depth = int.Parse(args[1]);
        var start = "csharp\t" + shape + "-" + depth + "\t";
        if (shape == "when")
        {
            Run(start,
                () => new Scheme<WhenRow>(1, Field.U8<WhenRow>(0, x => x.A), WhenChain(depth)),
                new WhenRow { A = 1, B = 7 },
                got => got.A == 1 && got.B == 7 ? null : $"A={got.A} B={got.B}");
        }
        else
        {
            var values = GroupValues(depth);
            Run(start, () => new Scheme<Node>(1, GroupChain(depth)), values, got => CompareGroups(got, values, depth));
        }
    }
}
