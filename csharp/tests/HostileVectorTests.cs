using Packbin;

namespace Packbin.Tests;

// Runs every `unpack` case of fixtures/hostile/cases.txt. The file holds bytes and outcomes only (ADR-001), so each
// case id maps to a hand-written C# scheme below, written from fixtures/hostile/README.md.
public class HostileVectorTests
{
    private sealed class BoolRow
    {
        public bool On { get; set; }
    }

    private sealed class ModeRow
    {
        public byte Mode { get; set; }
        public byte V { get; set; }
    }

    private sealed class SignedRow
    {
        public sbyte N { get; set; }
        public byte[] Payload { get; set; } = [];
    }

    private sealed class WideRow
    {
        public uint N { get; set; }
        public byte[] Payload { get; set; } = [];
        public byte V { get; set; }
    }

    private sealed class ListRow
    {
        public List<object?>? Xs { get; set; }
    }

    private sealed class MapRow
    {
        public Dictionary<string, object?>? M { get; set; }
    }

    private sealed class NameRow
    {
        public string Name { get; set; } = "";
    }

    private sealed class GatedRow
    {
        public byte? N { get; set; }
        public byte[] Payload { get; set; } = [];
        public List<int>? Segs { get; set; }
    }

    private sealed class ByteEl
    {
        public byte V { get; set; }
    }

    private static readonly Dictionary<string, Func<string, HostileProbe.Outcome>> Schemes = new()
    {
        ["zero_progress_repeat_bool"] = hex => HostileProbe.Unpack(
            new Scheme<BoolRow>(1, Field.Repeat(0, Field.Bool<BoolRow>(0, x => x.On))), hex, 1),
        ["zero_progress_repeat_when"] = hex => HostileProbe.Unpack(
            new Scheme<ModeRow>(1,
                Field.U8<ModeRow>(0, x => x.Mode),
                Field.Repeat(1, Field.When(1, Condition.Eq(0, 1), Field.U8<ModeRow>(1, x => x.V)))), hex, 1),
        ["negative_count"] = hex => HostileProbe.Unpack(
            new Scheme<SignedRow>(1,
                Field.I8<SignedRow>(0, x => x.N),
                Field.Sized<SignedRow>(1, x => x.Payload, 0)), hex, 1),
        ["oversize_count"] = hex => HostileProbe.Unpack(
            new Scheme<WideRow>(1,
                Field.U32<WideRow>(0, x => x.N),
                Field.Sized<WideRow>(1, x => x.Payload, 0)), hex, 1),
        ["oversize_count_times"] = hex => HostileProbe.Unpack(
            new Scheme<WideRow>(1,
                Field.U32<WideRow>(0, x => x.N),
                Field.Times(1, 0, Field.U8<WideRow>(1, x => x.V))), hex, 1),
        ["oversize_list_count"] = hex => HostileProbe.Unpack(
            new Scheme<ListRow>(1, Field.List((ListRow x) => x.Xs, Field.U8<ByteEl>(0, x => x.V))), hex, 1),
        ["invalid_utf8"] = hex => HostileProbe.Unpack(
            new Scheme<NameRow>(1, Field.Utf8<NameRow>(0, x => x.Name)), hex, 1),
        ["invalid_utf8_dict_key"] = hex => HostileProbe.Unpack(
            new Scheme<MapRow>(1, Field.Dict((MapRow x) => x.M, Field.U8<ByteEl>(0, x => x.V))), hex, 1),
        ["count_behind_clear_flag"] = hex => HostileProbe.Unpack(
            new Scheme<GatedRow>(1,
                Field.Flags(0, Field.U8<GatedRow>(0, x => x.N)),
                Field.Sized<GatedRow>(1, x => x.Payload, 0)), hex, 1),
        ["count_behind_clear_flag_bits"] = hex => HostileProbe.Unpack(
            new Scheme<GatedRow>(1,
                Field.Flags(0, Field.U8<GatedRow>(0, x => x.N)),
                Field.Bits<GatedRow>(1, x => x.Segs, 0)), hex, 1),
    };

    // C# has no bad_value or too_many type yet (C15); ShortPacket stands in for both.
    private static readonly Dictionary<string, Type> KindOfTerm = new()
    {
        ["short_packet"] = typeof(ShortPacket),
        ["bad_value"] = typeof(ShortPacket),
        ["too_many"] = typeof(ShortPacket),
        ["trailing_bytes"] = typeof(TrailingBytes),
        ["type_mismatch"] = typeof(TypeMismatch),
    };

    public static IEnumerable<object[]> UnpackCases()
    {
        foreach (var line in File.ReadLines(FindCases()))
        {
            var trimmed = line.Trim();
            if (trimmed.Length == 0 || trimmed[0] == '#')
                continue;
            var parts = trimmed.Split((char[]?)null, StringSplitOptions.RemoveEmptyEntries);
            if (parts[1] == "unpack")
                yield return [parts[0], parts[2], parts[3]];
        }
    }

    [Theory]
    [MemberData(nameof(UnpackCases))]
    public void UnpackCase_ReturnsAnErrorValue(string id, string expected, string hex)
    {
        // Arrange
        Assert.True(Schemes.TryGetValue(id, out var run), $"{id}: no C# scheme declared for this case");

        // Act
        var outcome = run!(hex);

        // Assert
        Assert.False(outcome.HandlerCalled, $"{id}: handler called");
        Assert.NotNull(outcome.Error);
        var returned = outcome.Error!.GetType();
        var accepted = expected.Split('|')
            .Where(KindOfTerm.ContainsKey)
            .Select(term => KindOfTerm[term])
            .ToList();
        Assert.True(accepted.Contains(returned), $"{id} -> {returned.Name}, expected one of {expected}");
    }

    private static string FindCases()
    {
        var dir = new DirectoryInfo(AppContext.BaseDirectory);
        while (dir is not null)
        {
            var path = Path.Combine(dir.FullName, "fixtures", "hostile", "cases.txt");
            if (File.Exists(path))
                return path;
            dir = dir.Parent;
        }
        throw new FileNotFoundException("fixtures/hostile/cases.txt");
    }
}
