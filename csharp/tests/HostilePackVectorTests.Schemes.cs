using Packbin;

namespace Packbin.Tests;

// The row classes and the hand-written schemes of the pack stage of fixtures/hostile/cases.txt; the case table and the
// loader are in HostilePackVectorTests.cs.
public partial class HostilePackVectorTests
{
    private sealed class PackRow
    {
        public byte A { get; set; }
        public byte B { get; set; }
        public byte X { get; set; }
        public bool? On { get; set; }
        public byte? N { get; set; }
    }

    private sealed class WideRow
    {
        public uint N { get; set; }
        public byte? X { get; set; }
    }

    private sealed class SplitRow
    {
        public byte Mode { get; set; }
        public byte Sel { get; set; }
        public byte? N { get; set; }
        public byte? Speed { get; set; }
        public byte? Pt { get; set; }
        public ushort? Heading { get; set; }
    }

    private sealed class BufferRow
    {
        public byte N { get; set; }
        public byte[] D { get; set; } = [];
    }

    // Loop 21 (AZ-2394): round slots, short optional list, late `when` in a bit body, count behind a clear `when`.
    private sealed class SlotsRow
    {
        public byte N { get; set; }
        public byte A { get; set; }
        public byte B { get; set; }
    }

    private sealed class FlagRoundRow
    {
        public byte W { get; set; }
        public bool? On { get; set; }
        public byte? V { get; set; }
    }

    private sealed class LateRow
    {
        public byte Mode { get; set; }
        public byte? D { get; set; }
        public byte? A { get; set; }
        public byte? B { get; set; }
        public bool? Mark { get; set; }
    }

    private sealed class SkippedRow
    {
        public byte Mode { get; set; }
        public ushort? A { get; set; }
        public byte? K { get; set; }
        public byte? B { get; set; }
    }

    // u8 mode; when(mode == 1) { u16 a; u8 k }; when(k == value) { u8 b }: k sits in a clear when (AZ-2816).
    private static Scheme<SkippedRow> SkippedSourceScheme(int value) => new(1,
        Field.U8<SkippedRow>(0, x => x.Mode),
        Field.When(1, Condition.Eq(0, 1), Field.U16<SkippedRow>(1, x => x.A), Field.U8<SkippedRow>(2, x => x.K)),
        Field.When(3, Condition.Eq(2, value), Field.U8<SkippedRow>(3, x => x.B)));

    private sealed class BoolSourceRow
    {
        public byte Mode { get; set; }
        public bool? On { get; set; }
        public byte? A { get; set; }
        public byte? B { get; set; }
    }

    // u8 mode; when(mode == 1) { flags { bool on }; u8 a }; when(on == true) { u8 b }: on sits in a clear when (AZ-3133).
    private static Scheme<BoolSourceRow> BoolSourceScheme() => new(1,
        Field.U8<BoolSourceRow>(0, x => x.Mode),
        Field.When(1, Condition.Eq(0, 1), Field.Flags(1, Field.Bool<BoolSourceRow>(1, x => x.On)), Field.U8<BoolSourceRow>(2, x => x.A)),
        Field.When(3, Condition.Eq(1, true), Field.U8<BoolSourceRow>(3, x => x.B)));

    private sealed class StrandedRow
    {
        public byte Mode { get; set; }
        public byte? C { get; set; }
        public byte? Pt { get; set; }
        public ushort? Heading { get; set; }
        public List<int>? V { get; set; }
    }

    private sealed class StrandedSizedRow
    {
        public byte Mode { get; set; }
        public byte? C { get; set; }
        public byte[] V { get; set; } = [];
    }

    // Loop 22 (AZ-2417): repeat lists of unequal length, a short `times` list under flags, a utf8 under a list element.
    private sealed class RepeatWhenRow
    {
        public byte K { get; set; }
        public byte? V { get; set; }
        public byte X { get; set; }
    }

    private sealed class FlagsTimesRow
    {
        public byte C { get; set; }
        public byte? V { get; set; }
    }

    private sealed class Utf8Item
    {
        public uint N { get; set; }
        public string S { get; set; } = "";
        public bool? Mark { get; set; }
    }

    private sealed class Utf8Items
    {
        public List<object?>? Items { get; set; }
    }

    private static object?[] L(params object?[] items) => items;

    // u8 mode; when mode == 1 { u8 c }; flag byte; bit 0 { counted member (id 2, count id 1) }: the split form.
    private static Scheme<StrandedRow> SplitCounted(Func<Field> member)
    {
        var m = Field.FlagByte();
        return new Scheme<StrandedRow>(1,
            Field.U8<StrandedRow>(0, x => x.Mode),
            Field.When(1, Condition.Eq(0, 1), Field.U8<StrandedRow>(1, x => x.C)),
            m,
            m.Bit(member()));
    }

    private static Scheme<StrandedSizedRow> SplitSized()
    {
        var m = Field.FlagByte();
        return new Scheme<StrandedSizedRow>(1,
            Field.U8<StrandedSizedRow>(0, x => x.Mode),
            Field.When(1, Condition.Eq(0, 1), Field.U8<StrandedSizedRow>(1, x => x.C)),
            m,
            m.Bit(Field.Sized<StrandedSizedRow>(2, x => x.V, 1)));
    }

    // u8 n; times(n) { u8 a }; repeat { u8 b }: one slot per round of either container.
    private static Scheme<SlotsRow> SlotsScheme() => new Scheme<SlotsRow>(1,
        Field.U8<SlotsRow>(0, x => x.N),
        Field.Times(1, 0, Field.U8<SlotsRow>(1, x => x.A)),
        Field.Repeat(2, Field.U8<SlotsRow>(2, x => x.B))).WithLimits(maxSlots: 3);

    // repeat { flags { bool on, u8 v } }: a round of width 2.
    private static Scheme<FlagRoundRow> FlagsSlotsScheme() => new Scheme<FlagRoundRow>(1,
        Field.Repeat(0, Field.Flags(0, Field.Bool<FlagRoundRow>(0, x => x.On), Field.U8<FlagRoundRow>(1, x => x.V))))
        .WithLimits(maxSlots: 4);

    // repeat { u8 w; flags { u8 v } }
    private static Scheme<FlagRoundRow> ShortListScheme() => new(1,
        Field.Repeat(0, Field.U8<FlagRoundRow>(0, x => x.W), Field.Flags(1, Field.U8<FlagRoundRow>(1, x => x.V))));

    // flag byte first; u8 mode; bit 0 { group { u8 d; when mode == 1 { u8 a }; when mode == 2 { u8 b } } }
    private static Scheme<LateRow> LateWhenScheme()
    {
        var m = Field.FlagByte();
        return new Scheme<LateRow>(1, m,
            Field.U8<LateRow>(0, x => x.Mode),
            m.Bit(Field.Group(1, (LateRow x) => x.Mark,
                Field.U8<LateRow>(1, x => x.D),
                Field.When(2, Condition.Eq(0, 1), Field.U8<LateRow>(2, x => x.A)),
                Field.When(3, Condition.Eq(0, 2), Field.U8<LateRow>(3, x => x.B)))));
    }

    // u8 mode; when mode == 1 { u8 c }; flag byte; bit 0 { times(c) { u8 pt } }; bit 1 { u16 heading }
    private static Scheme<StrandedRow> CountClearWhenScheme()
    {
        var m = Field.FlagByte();
        return new Scheme<StrandedRow>(1,
            Field.U8<StrandedRow>(0, x => x.Mode),
            Field.When(1, Condition.Eq(0, 1), Field.U8<StrandedRow>(1, x => x.C)),
            m,
            m.Bit(Field.Times(2, 1, Field.U8<StrandedRow>(2, x => x.Pt))),
            m.Bit(Field.U16<StrandedRow>(3, x => x.Heading)));
    }

    // u8 mode; when mode == 1 { u8 c }; counted member (id 2, count id 1)
    private static Scheme<StrandedRow> CountedScheme(Func<Field> member) => new(1,
        Field.U8<StrandedRow>(0, x => x.Mode),
        Field.When(1, Condition.Eq(0, 1), Field.U8<StrandedRow>(1, x => x.C)),
        member());

    private static Dictionary<string, object?> Row(params (string Name, object? Value)[] values) =>
        values.ToDictionary(v => v.Name, v => v.Value);

    private static Scheme<PackRow> TimesScheme() => new(1,
        Field.U8<PackRow>(0, x => x.A),
        Field.Times(1, 0, Field.U8<PackRow>(1, x => x.X)));

    // Split-form flag byte: the byte is written first when the source or count comes after it.
    private static Scheme<SplitRow> SplitScheme(string shape)
    {
        var m = Field.FlagByte();
        return shape switch
        {
            "when_after" => new Scheme<SplitRow>(1, m,
                Field.U8<SplitRow>(0, x => x.Mode),
                m.Bit(Field.When(1, Condition.Eq(0, 1), Field.U8<SplitRow>(1, x => x.Speed)))),
            "times_after" => new Scheme<SplitRow>(1, m,
                Field.U8<SplitRow>(0, x => x.N),
                m.Bit(Field.Times(1, 0, Field.U8<SplitRow>(1, x => x.Pt)))),
            "times_skipped" => new Scheme<SplitRow>(1,
                Field.U8<SplitRow>(0, x => x.Sel),
                m,
                Field.When(1, Condition.Eq(0, 1), Field.U8<SplitRow>(1, x => x.N)),
                m.Bit(Field.Times(2, 1, Field.U8<SplitRow>(2, x => x.Pt)))),
            "times_after_heading" => new Scheme<SplitRow>(1, m,
                Field.U8<SplitRow>(0, x => x.N),
                m.Bit(Field.Times(1, 0, Field.U8<SplitRow>(1, x => x.Pt))),
                m.Bit(Field.U16<SplitRow>(2, x => x.Heading))),
            _ => new Scheme<SplitRow>(1,
                Field.U8<SplitRow>(0, x => x.Mode),
                m,
                m.Bit(Field.When(1, Condition.Eq(0, 1), Field.U8<SplitRow>(1, x => x.Speed))),
                m.Bit(Field.U16<SplitRow>(2, x => x.Heading))),
        };
    }
}
