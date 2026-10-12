using System.Diagnostics;
using Packbin;

namespace Packbin.Tests;

// AZ-2390 (F33): a repeat or times whose body holds no member is refused when the scheme is built (rows 15 to 26 of
// _docs/03_implementation/reference_loop21_slots.md). A member is any field that is not a container, looking through
// `when` and groups; a zero-width byte run, a flag byte and a member-less `flags` are members and still build.
public class EmptyRoundBodyTests
{
    public sealed class Item
    {
        public uint N { get; set; }
        public bool? Mark { get; set; }
    }

    public sealed class BodyRow
    {
        public byte N { get; set; }
        public byte? K { get; set; }
        public bool? G { get; set; }
        public byte[]? V { get; set; }
        public List<Item>? Items { get; set; }
        public List<BodyLeg>? Legs { get; set; }
    }

    public sealed class BodyLeg
    {
        public byte A { get; set; }
    }

    private static string Hex(byte[] raw) => Convert.ToHexString(raw).ToLowerInvariant();

    private static ArgumentException Build(Func<object> build) =>
        Assert.IsType<ArgumentException>(Record.Exception(build));

    private static string Empty(string kind, int anchor) =>
        $"{kind} {anchor}: the body holds no member; a round of it would charge no slot and write nothing";

    // The F33 request shape: a list of groups, each holding `times(n) {}`.
    private static Scheme<BodyRow> F33() =>
        new(1, Field.List((BodyRow x) => x.Items,
            Field.Group(0, (Item e) => e.Mark, Field.U32<Item>(0, e => e.N), Field.Times(1, 0))));

    [Fact]
    public void Ac1_Repeat_EmptyBody_IsRefusedNamingTheKindAndTheAnchor()
    {
        // Act
        var error = Build(() => new Scheme<BodyRow>(1, Field.Repeat(0)));

        // Assert (row 15)
        Assert.Equal(Empty("repeat", 0), error.Message);
    }

    [Fact]
    public void Ac1_Times_EmptyBody_IsRefusedNamingTheKindAndTheAnchor()
    {
        // Act
        var error = Build(() => new Scheme<BodyRow>(1, Field.U8<BodyRow>(0, x => x.N), Field.Times(1, 0)));

        // Assert (row 16)
        Assert.Equal(Empty("times", 1), error.Message);
    }

    [Fact]
    public void Ac1_TypedRepeatAndTimes_EmptyBody_AreRefused()
    {
        // Act
        var repeat = Build(() => new Scheme<BodyRow>(1, Field.Repeat(0, (BodyRow x) => x.Legs)));
        var times = Build(() => new Scheme<BodyRow>(1, Field.U8<BodyRow>(0, x => x.N), Field.Times(1, 0, (BodyRow x) => x.Legs)));

        // Assert
        Assert.Equal(Empty("repeat", 0), repeat.Message);
        Assert.Equal(Empty("times", 1), times.Message);
    }

    [Fact]
    public void Ac1_Group_EmptyGroupBody_IsRefusedByTheEmptyGroupRuleFirst()
    {
        // Act
        var error = Build(() => new Scheme<BodyRow>(1, Field.Repeat(0, Field.Group(0, (BodyRow x) => x.G))));

        // Assert (row 19)
        Assert.Contains("put it directly in Flags", error.Message, StringComparison.Ordinal);
    }

    [Fact]
    public void Ac1_Validate_BodyOfEmptyWhensAndGroups_HoldsNoMember()
    {
        // Arrange (a `when` whose source is outside the round cannot be built in a scheme, so the check is called on the fields)
        Field[] emptyWhen = [Field.Repeat(0, Field.When(0, Condition.Eq(0, 1)))];
        Field[] nestedWhen = [Field.Repeat(0, Field.When(0, Condition.Eq(0, 1), Field.When(0, Condition.Eq(0, 2))))];
        Field[] emptyGroup = [Field.Repeat(0, Field.Group(0, (BodyRow x) => x.G))];

        // Act
        var errors = new[] { emptyWhen, nestedWhen, emptyGroup }
            .Select(fields => Build(() => { RoundScopes.Validate(fields); return fields; }).Message);

        // Assert (rows 17, 18 and 19 without the earlier rules)
        Assert.All(errors, message => Assert.Equal(Empty("repeat", 0), message));
    }

    [Fact]
    public void Ac2_F33RequestShape_FailsAtBuildInUnderOneSecond()
    {
        // Arrange
        var clock = Stopwatch.StartNew();

        // Act
        var error = Build(() => F33());
        clock.Stop();

        // Assert (row 20)
        Assert.Equal(Empty("times", 1), error.Message);
        Assert.True(clock.ElapsedMilliseconds < 1000, $"build took {clock.ElapsedMilliseconds} ms");
    }

    public static TheoryData<string, Func<Scheme<BodyRow>>, string> EmptyWhereverItStands() => new()
    {
        { "under flags", () => new Scheme<BodyRow>(1, Field.Flags(0, Field.Repeat(0))), Empty("repeat", 0) },
        {
            "in a flag bit", () =>
            {
                var m = Field.FlagByte();
                return new Scheme<BodyRow>(1, m, m.Bit(Field.Repeat(0)));
            },
            Empty("repeat", 0)
        },
        {
            "in a when", () => new Scheme<BodyRow>(1,
                Field.U8<BodyRow>(0, x => x.N), Field.When(1, Condition.Eq(0, 1), Field.Repeat(1))),
            Empty("repeat", 1)
        },
        { "in a group", () => new Scheme<BodyRow>(1, Field.Group(0, (BodyRow x) => x.G, Field.Repeat(0))), Empty("repeat", 0) },
        { "in a list element", F33, Empty("times", 1) },
    };

    [Theory]
    [MemberData(nameof(EmptyWhereverItStands))]
    public void Ac1_EmptyBody_WhereverTheRoundStands_IsRefusedWithTheSameText(
        string where, Func<Scheme<BodyRow>> build, string expected)
    {
        // Act
        var error = Build(() => build());

        // Assert (row 25)
        Assert.True(error.Message == expected, $"{where}: {error.Message}");
    }

    [Fact]
    public void Ac3_Times_ZeroWidthBytesBody_Builds_AndPackIsBoundedBySlots()
    {
        // Arrange (row 21)
        var scheme = new Scheme<BodyRow>(1,
            Field.U8<BodyRow>(0, x => x.N), Field.Times(1, 0, Field.Bytes<BodyRow>(1, x => x.V!, 0))).WithLimits(maxSlots: 5);
        var values = new Dictionary<string, object?> { ["N"] = (byte)10, ["V"] = Enumerable.Range(0, 10).Select(_ => (object?)Array.Empty<byte>()).ToArray() };

        // Act
        var error = Budget.Refused(scheme, values);

        // Assert
        Assert.Equal("'V': the rounds would hold 6 slots, above the limit of 5 slots", error.Message);
    }

    [Fact]
    public void Ac3_Repeat_FlagByteBody_BuildsAndPacksTheTypeByte()
    {
        // Arrange (row 22)
        var scheme = new Scheme<BodyRow>(1, Field.Repeat(0, Field.FlagByte()));

        // Act
        var raw = BinaryPacker.Pack(scheme, new Dictionary<string, object?>());

        // Assert
        Assert.Equal("01", Hex(raw));
    }

    [Fact]
    public void Ac3_Repeat_MemberLessFlagsBody_BuildsAndPacksTheTypeByte()
    {
        // Arrange (row 23)
        var scheme = new Scheme<BodyRow>(1, Field.Repeat(0, Field.Flags(0)));

        // Act
        var raw = BinaryPacker.Pack(scheme, new Dictionary<string, object?>());

        // Assert
        Assert.Equal("01", Hex(raw));
    }

    [Fact]
    public void Ac3_Repeat_FlagsHoldingAnEmptyGroup_BuildsAndWritesAFlagBytePerRound()
    {
        // Arrange (row 26)
        var scheme = new Scheme<BodyRow>(1, Field.Repeat(0, Field.Flags(0, Field.Group(0, (BodyRow x) => x.G))));
        var values = new Dictionary<string, object?> { ["G"] = new object?[] { true, null } };

        // Act
        var raw = BinaryPacker.Pack(scheme, values);

        // Assert
        Assert.Equal("010100", Hex(raw));
    }

    [Fact]
    public void Ac3_Repeat_OneMemberBody_PacksAsBefore()
    {
        // Arrange (row 24)
        var repeat = new Scheme<BodyRow>(1, Field.Repeat(0, Field.U8<BodyRow>(0, x => x.K)));
        var times = new Scheme<BodyRow>(1, Field.U8<BodyRow>(0, x => x.N), Field.Times(1, 0, Field.U8<BodyRow>(1, x => x.K)));

        // Act
        var first = BinaryPacker.Pack(repeat, new Dictionary<string, object?> { ["K"] = new object?[] { (byte)7, (byte)8 } });
        var second = BinaryPacker.Pack(times, new Dictionary<string, object?> { ["N"] = (byte)2, ["K"] = new object?[] { (byte)7, (byte)8 } });

        // Assert
        Assert.Equal(("010708", "01020708"), (Hex(first), Hex(second)));
    }
}
