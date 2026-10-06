using Packbin;

namespace Packbin.Tests;

// Runs the cases of fixtures/hostile/cases.txt. The file holds bytes and outcomes only (ADR-001), so each case id maps
// to a hand-written C# scheme below, written from fixtures/hostile/README.md.
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

    private sealed class RoundRow
    {
        public byte N { get; set; }
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

    private sealed class NineRow
    {
        public byte? F0 { get; set; }
        public byte? F1 { get; set; }
        public byte? F2 { get; set; }
        public byte? F3 { get; set; }
        public byte? F4 { get; set; }
        public byte? F5 { get; set; }
        public byte? F6 { get; set; }
        public byte? F7 { get; set; }
        public byte? F8 { get; set; }
    }

    private sealed class PresenceRow
    {
        public byte A { get; set; }
        public bool? On { get; set; }
    }

    private sealed class LaterRow
    {
        public byte A { get; set; }
        public byte? B { get; set; }
        public byte C { get; set; }
    }

    private sealed class CountLaterRow
    {
        public byte[] Payload { get; set; } = [];
        public ushort N { get; set; }
    }

    private static Field[] NineU8() =>
    [
        Field.U8<NineRow>(0, x => x.F0), Field.U8<NineRow>(1, x => x.F1), Field.U8<NineRow>(2, x => x.F2),
        Field.U8<NineRow>(3, x => x.F3), Field.U8<NineRow>(4, x => x.F4), Field.U8<NineRow>(5, x => x.F5),
        Field.U8<NineRow>(6, x => x.F6), Field.U8<NineRow>(7, x => x.F7), Field.U8<NineRow>(8, x => x.F8),
    ];

    private static Scheme<NineRow> NineSplitBits()
    {
        var m = Field.FlagByte();
        return new Scheme<NineRow>(1, [m, .. NineU8().Select(m.Bit)]);
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

    // fixtures/hostile/README.md, stage limit: the scheme carries maxRounds 3 and the default maxSlots.
    private const int LowRounds = 3;

    private static readonly Dictionary<string, Func<string, HostileProbe.Outcome>> LimitSchemes = new()
    {
        ["repeat_rounds_over_limit"] = hex => HostileProbe.Unpack(
            new Scheme<RoundRow>(1, Field.Repeat(0, Field.U8<RoundRow>(0, x => x.V)))
                .WithLimits(maxRounds: LowRounds), hex, 1),
        ["times_rounds_over_limit"] = hex => HostileProbe.Unpack(
            new Scheme<RoundRow>(1,
                Field.U8<RoundRow>(0, x => x.N),
                Field.Times(1, 0, Field.U8<RoundRow>(1, x => x.V)))
                .WithLimits(maxRounds: LowRounds), hex, 1),
    };

    private static readonly Dictionary<string, Action> ConstructSchemes = new()
    {
        ["nine_flag_bits"] = () => _ = new Scheme<NineRow>(1, Field.Flags(0, NineU8())),
        ["nine_flag_bits_split"] = () => _ = NineSplitBits(),
        ["bool_outside_flags"] = () => _ = new Scheme<PresenceRow>(1,
            Field.U8<PresenceRow>(0, x => x.A),
            Field.Bool<PresenceRow>(1, x => x.On)),
        ["empty_group_outside_flags"] = () => _ = new Scheme<PresenceRow>(1,
            Field.U8<PresenceRow>(0, x => x.A),
            Field.Group(1, (PresenceRow x) => x.On)),
        ["when_names_later_field"] = () => _ = new Scheme<LaterRow>(1,
            Field.U8<LaterRow>(0, x => x.A),
            Field.When(1, Condition.Eq(2, (byte)1), Field.U8<LaterRow>(1, x => x.B)),
            Field.U8<LaterRow>(2, x => x.C)),
        ["count_names_later_field"] = () => _ = new Scheme<CountLaterRow>(1,
            Field.Sized<CountLaterRow>(0, x => x.Payload, 1),
            Field.U16<CountLaterRow>(1, x => x.N)),
        ["when_names_outer_field_in_repeat"] = () => _ = new Scheme<ModeRow>(1,
            Field.U8<ModeRow>(0, x => x.Mode),
            Field.Repeat(1, Field.When(1, Condition.Eq(0, 1), Field.U8<ModeRow>(1, x => x.V)))),
    };

    // A message fragment for each case refused at construction, so a refusal by some other rule does not pass.
    private static readonly Dictionary<string, string> RefusalRule = new()
    {
        ["nine_flag_bits"] = "at most 8 bits",
        ["nine_flag_bits_split"] = "at most 8 bits",
        ["bool_outside_flags"] = "put it directly in Flags",
        ["empty_group_outside_flags"] = "put it directly in Flags",
        ["zero_progress_repeat_bool"] = "put it directly in Flags",
        ["zero_progress_repeat_when"] = "not an earlier field in the same scope",
        ["when_names_later_field"] = "not an earlier field in the same scope",
        ["count_names_later_field"] = "not an earlier field in the same scope",
        ["when_names_outer_field_in_repeat"] = "not an earlier field in the same scope",
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

    private static IEnumerable<string[]> Cases(string stage)
    {
        foreach (var line in File.ReadLines(FindCases()))
        {
            var trimmed = line.Trim();
            if (trimmed.Length == 0 || trimmed[0] == '#')
                continue;
            var parts = trimmed.Split((char[]?)null, StringSplitOptions.RemoveEmptyEntries);
            if (parts[1] == stage)
                yield return parts;
        }
    }

    public static IEnumerable<object[]> UnpackCases() =>
        Cases("unpack").Select(parts => new object[] { parts[0], parts[2], parts[3] });

    public static IEnumerable<object[]> ConstructCases() =>
        Cases("construct").Select(parts => new object[] { parts[0], parts[2] });

    public static IEnumerable<object[]> LimitCases() =>
        Cases("limit").Select(parts => new object[] { parts[0], parts[2], parts[3] });

    [Fact]
    public void EveryLimitCase_HasACSharpScheme()
    {
        // Arrange
        var ids = Cases("limit").Select(parts => parts[0]).ToList();

        // Act
        var unclaimed = ids.Where(id => !LimitSchemes.ContainsKey(id)).ToList();

        // Assert
        Assert.NotEmpty(ids);
        Assert.Empty(unclaimed);
    }

    [Theory]
    [MemberData(nameof(LimitCases))]
    public void LimitCase_IsRefusedByTheRoundLimit(string id, string expected, string hex)
    {
        // Arrange
        Assert.True(LimitSchemes.TryGetValue(id, out var run), $"{id}: no C# scheme declared for this case");

        // Act
        var outcome = run!(hex);

        // Assert: the interim bad-value error of the round that would start, not a short read of a field.
        Assert.False(outcome.HandlerCalled, $"{id}: handler called");
        var refusal = Assert.IsType<ShortPacket>(outcome.Error);
        Assert.Equal(0, refusal.Needed);
        Assert.Equal(1, refusal.Left);
        var accepted = expected.Split('|').Where(KindOfTerm.ContainsKey).Select(term => KindOfTerm[term]).ToList();
        Assert.True(accepted.Contains(refusal.GetType()), $"{id} -> {refusal.GetType().Name}, expected one of {expected}");
    }

    [Fact]
    public void EveryConstructCase_HasACSharpScheme()
    {
        // Arrange
        var ids = Cases("construct").Select(parts => parts[0]).ToList();

        // Act
        var unclaimed = ids.Where(id => !ConstructSchemes.ContainsKey(id)).ToList();

        // Assert
        Assert.NotEmpty(ids);
        Assert.Empty(unclaimed);
    }

    [Theory]
    [MemberData(nameof(ConstructCases))]
    public void ConstructCase_FailsSchemeConstruction(string id, string expected)
    {
        // Arrange
        Assert.Equal("scheme_error", expected);
        Assert.True(ConstructSchemes.TryGetValue(id, out var build), $"{id}: no C# scheme declared for this case");

        Assert.True(RefusalRule.TryGetValue(id, out var rule), $"{id}: no refusal rule declared for this case");

        // Act
        var refused = Record.Exception(build!);

        // Assert
        var error = Assert.IsType<ArgumentException>(refused);
        Assert.True(error.Message.Contains(rule!, StringComparison.Ordinal), $"{id}: refused by another rule: {error.Message}");
    }

    [Theory]
    [MemberData(nameof(UnpackCases))]
    public void UnpackCase_ReturnsAnErrorValue(string id, string expected, string hex)
    {
        // Arrange
        Assert.True(Schemes.TryGetValue(id, out var run), $"{id}: no C# scheme declared for this case");

        // Act
        HostileProbe.Outcome outcome;
        try
        {
            outcome = run!(hex);
        }
        catch (ArgumentException refused)
        {
            // The case's scheme fails construction; that is a valid outcome only where the file allows scheme_error,
            // and only by the rule declared for the case.
            Assert.True(expected.Split('|').Contains("scheme_error"), $"{id}: construction failed ({refused.Message}), expected {expected}");
            Assert.True(RefusalRule.TryGetValue(id, out var rule), $"{id}: construction failed ({refused.Message}), no refusal rule declared");
            Assert.True(refused.Message.Contains(rule!, StringComparison.Ordinal), $"{id}: refused by another rule: {refused.Message}");
            return;
        }

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
