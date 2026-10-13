using System.Linq.Expressions;
using Packbin;

namespace Packbin.Tests;

// AZ-2436 (G3 of assessment 22): the U11 no-value count refusal (AZ-2410, row 56 of
// _docs/03_implementation/reference_loop22.md) pinned below the top level of a scheme. Row 56 is
// `u8 Mode; when(Mode == 1) { u8 C }; <bit> { member counted by C }` with Mode 0, C 3 and no value: refused, member and
// count named. Every position is spelled with a split flag byte bit and with a combined `flags`, for `bits`, `packed`
// (width 1, bias 0) and `sized`, in dictionary rows and typed rows. Same shapes and hex as
// typescript/tests/loop23-novalue-nested.test.ts and python/tests/test_no_value_count_nested.py; C# words the message
// with the member in quotes, as CountBehindClearWhenTests does.
//
// Spelling notes (probed at b8b2809):
// - A C# group is either anchored (it shares the row, like a Python group) or a nested row (its own scope, ids from 0).
//   The whole row 56 shape fits in both. A bit holding a group that holds the member while the count stays outside
//   (TypeScript's `g: { v }`) is spellable only with an anchored group: a nested-row group cannot name a count outside
//   its own scope and is refused at build (pinned below).
// - With U26 A (loop 25) a nested-row group reads its names from the inner dictionary under its name in a dictionary
//   row, matching the typed row's nested object; a flat row with those names at the outer level fails naming the
//   missing nested dictionary.
// - A counted member inside the clear inner `when` itself is the existing silent skip, not U11 (AC-2 as amended).
public class NoValueCountNestedTests
{
    public sealed class Body
    {
        public byte? Mode { get; set; }
        public byte? C { get; set; }
        public List<int>? V { get; set; }
        public byte[]? Bv { get; set; }
    }

    public sealed class Row
    {
        public byte? O { get; set; }
        public byte? N { get; set; }
        public byte? Mode { get; set; }
        public byte? C { get; set; }
        public bool? G { get; set; }
        public List<int>? V { get; set; }
        public byte[]? Bv { get; set; }
        public Body? In { get; set; }
        public List<Body>? Rounds { get; set; }
    }

    private static readonly string[] Kinds = ["bits", "packed", "sized"];
    private static readonly string[] Bits = ["split", "flags"];

    private static string Hex(byte[] raw) => Convert.ToHexString(raw).ToLowerInvariant();

    private static Dictionary<string, object?> D(params (string Name, object? Value)[] items) =>
        items.ToDictionary(item => item.Name, item => item.Value);

    private static object?[] L(params object?[] items) => items;

    private static string Name(string kind) => kind == "sized" ? "Bv" : "V";

    private static object Value(string kind) => kind == "sized" ? new byte[] { 1, 2, 3 } : new List<int> { 1, 0, 1 };

    private static string SetHex(string kind) => kind == "sized" ? "010203" : "05";

    private static string NoValueCount(string kind) =>
        $"'{Name(kind)}': the count C is 3 in the row, but no field wrote it (the when that holds it is clear), "
        + "so the member reads nothing; give the count 0, leave it out, or make the when hold";

    private static Field Member<T>(
        string kind, int id, int countId, Expression<Func<T, List<int>?>> v, Expression<Func<T, byte[]>> bv) =>
        kind switch
        {
            "bits" => Field.Bits(id, v, countId),
            "packed" => Field.Packed(1, id, v, countId),
            _ => Field.Sized(id, bv, countId),
        };

    private static Field Top(string kind, int id, int countId) => Member<Row>(kind, id, countId, x => x.V, x => x.Bv!);

    private static Field Inner(string kind, int id, int countId) => Member<Body>(kind, id, countId, x => x.V, x => x.Bv!);

    // The member (or what holds it) behind a split flag byte bit or as the one member of a combined `flags` at `anchor`.
    private static Field[] Behind(string bit, int anchor, Field inner)
    {
        if (bit == "flags")
            return [Field.Flags(anchor, inner)];
        var fb = Field.FlagByte();
        return [fb, fb.Bit(inner)];
    }

    // Row 56 with ids from `b` (Mode b, C b+1, member b+2) on the top-level row.
    private static Field[] Shape(string kind, string bit, int b) =>
        [Field.U8<Row>(b, x => x.Mode), Field.When(b + 1, Condition.Eq(b, 1), Field.U8<Row>(b + 1, x => x.C)),
            .. Behind(bit, b + 2, Top(kind, b + 2, b + 1))];

    // Row 56 with ids from `b` on a nested row or a round row.
    private static Field[] BodyShape(string kind, string bit, int b) =>
        [Field.U8<Body>(b, x => x.Mode), Field.When(b + 1, Condition.Eq(b, 1), Field.U8<Body>(b + 1, x => x.C)),
            .. Behind(bit, b + 2, Inner(kind, b + 2, b + 1))];

    private static Dictionary<string, object?> With(Dictionary<string, object?> row, string kind, bool round = false)
    {
        row[Name(kind)] = round ? L(Value(kind)) : Value(kind);
        return row;
    }

    // `refused`: rows with count 3 and no value. `unchanged`: rows and their hex at b8b2809, `*` standing for the value.
    private sealed record Position(
        string Ac,
        Func<string, string, Scheme<Row>> Layout,
        Func<string, object[]> Refused,
        Func<string, (object Row, string Wire)[]> Unchanged);

    private static readonly Dictionary<string, Position> Positions = new()
    {
        ["the row 56 shape inside an anchored group"] = new("AC-1",
            (kind, bit) => new Scheme<Row>(1, Field.Group(0, (Row x) => x.G, Shape(kind, bit, 0))),
            _ => [D(("Mode", (byte)0), ("C", (byte)3)), D(("G", true), ("Mode", (byte)0), ("C", (byte)3)), new Row { Mode = 0, C = 3 }],
            kind =>
            [
                (D(("Mode", (byte)0), ("C", (byte)0)), "010000"), (D(("Mode", (byte)0)), "010000"),
                (D(("Mode", (byte)1), ("C", (byte)3)), "01010300"), (With(D(("Mode", (byte)1), ("C", (byte)3)), kind), "01010301*"),
                (new Row { Mode = 0, C = 0 }, "010000"), (new Row { Mode = 0 }, "010000"), (new Row { Mode = 1, C = 3 }, "01010300"),
            ]),
        ["the row 56 shape inside a nested-row group"] = new("AC-1",
            (kind, bit) => new Scheme<Row>(1, Field.Group((Row x) => x.In, BodyShape(kind, bit, 0))),
            _ => [D(("In", D(("Mode", (byte)0), ("C", (byte)3)))), new Row { In = new Body { Mode = 0, C = 3 } }],
            kind =>
            [
                (D(("In", D(("Mode", (byte)0), ("C", (byte)0)))), "010000"), (D(("In", D(("Mode", (byte)0)))), "010000"),
                (D(("In", D(("Mode", (byte)1), ("C", (byte)3)))), "01010300"),
                (D(("In", With(D(("Mode", (byte)1), ("C", (byte)3)), kind))), "01010301*"),
                (new Row { In = new Body { Mode = 0, C = 0 } }, "010000"), (new Row { In = new Body { Mode = 0 } }, "010000"),
                (new Row { In = new Body { Mode = 1, C = 3 } }, "01010300"),
            ]),
        ["a bit that holds an anchored group holding the member"] = new("AC-1",
            (kind, bit) => new Scheme<Row>(1,
            [
                Field.U8<Row>(0, x => x.Mode), Field.When(1, Condition.Eq(0, 1), Field.U8<Row>(1, x => x.C)),
                .. Behind(bit, 2, Field.Group(2, (Row x) => x.G, Top(kind, 2, 1))),
            ]),
            _ => [D(("Mode", (byte)0), ("C", (byte)3)), new Row { Mode = 0, C = 3 }],
            kind =>
            [
                (D(("Mode", (byte)0), ("C", (byte)0)), "010000"), (D(("Mode", (byte)0)), "010000"),
                (D(("Mode", (byte)1), ("C", (byte)3)), "01010300"), (With(D(("Mode", (byte)1), ("C", (byte)3)), kind), "01010301*"),
                (new Row { Mode = 1, C = 3 }, "01010300"),
            ]),
        ["the row 56 shape inside an outer holding when"] = new("AC-2",
            (kind, bit) => new Scheme<Row>(1, Field.U8<Row>(0, x => x.O), Field.When(1, Condition.Eq(0, 1), Shape(kind, bit, 1))),
            _ => [D(("O", (byte)1), ("Mode", (byte)0), ("C", (byte)3)), new Row { O = 1, Mode = 0, C = 3 }],
            kind => WhenRows(kind)),
        ["a bit that holds a holding when around the member"] = new("AC-2",
            (kind, bit) => new Scheme<Row>(1,
            [
                Field.U8<Row>(0, x => x.O), Field.U8<Row>(1, x => x.Mode),
                Field.When(2, Condition.Eq(1, 1), Field.U8<Row>(2, x => x.C)),
                .. Behind(bit, 3, Field.When(3, Condition.Eq(0, 1), Top(kind, 3, 2))),
            ]),
            _ => [D(("O", (byte)1), ("Mode", (byte)0), ("C", (byte)3)), new Row { O = 1, Mode = 0, C = 3 }],
            // The last row: the when around the member is clear, so the rule does not look at the member (as Python).
            kind => [.. WhenRows(kind), (D(("O", (byte)0), ("Mode", (byte)0), ("C", (byte)3)), "01000000")]),
        ["a count behind nested whens, the outer holding and the inner clear"] = new("AC-2",
            (kind, bit) => new Scheme<Row>(1,
            [
                Field.U8<Row>(0, x => x.Mode), Field.U8<Row>(1, x => x.O),
                Field.When(2, Condition.Eq(1, 1), Field.When(2, Condition.Eq(0, 1), Field.U8<Row>(2, x => x.C))),
                .. Behind(bit, 3, Top(kind, 3, 2)),
            ]),
            _ => [D(("O", (byte)1), ("Mode", (byte)0), ("C", (byte)3)), new Row { O = 1, Mode = 0, C = 3 }],
            kind =>
            [
                (D(("O", (byte)1), ("Mode", (byte)0), ("C", (byte)0)), "01000100"), (D(("O", (byte)1), ("Mode", (byte)0)), "01000100"),
                (D(("O", (byte)1), ("Mode", (byte)1), ("C", (byte)3)), "0101010300"),
                (With(D(("O", (byte)1), ("Mode", (byte)1), ("C", (byte)3)), kind), "0101010301*"),
            ]),
        ["a times round body"] = new("AC-3",
            (kind, bit) => new Scheme<Row>(1, [Field.U8<Row>(0, x => x.N), Field.Times(1, 0, Shape(kind, bit, 1))]),
            _ =>
            [
                D(("N", (byte)1), ("Mode", L((byte)0)), ("C", L((byte)3))),
                D(("N", (byte)2), ("Mode", L((byte)1, (byte)0)), ("C", L((byte)0, (byte)3))),
                D(("N", (byte)2), ("Mode", L((byte)0, (byte)1)), ("C", L((byte)3, (byte)3))),
                D(("N", (byte)1), ("Mode", (byte)0), ("C", (byte)3)),
            ],
            kind => RoundRows(kind, ("N", (byte)1), ("N", (byte)2), "0101", "0102")),
        ["a times round body of round rows"] = new("AC-3",
            (kind, bit) => new Scheme<Row>(1, Field.U8<Row>(0, x => x.N), Field.Times(1, 0, (Row x) => x.Rounds, BodyShape(kind, bit, 1))),
            _ =>
            [
                new Row { N = 1, Rounds = [new Body { Mode = 0, C = 3 }] },
                new Row { N = 2, Rounds = [new Body { Mode = 1, C = 0 }, new Body { Mode = 0, C = 3 }] },
            ],
            _ => [(new Row { N = 2, Rounds = [new Body { Mode = 1, C = 0 }, new Body { Mode = 0, C = 0 }] }, "01020100000000")]),
        ["a repeat round body"] = new("AC-3",
            (kind, bit) => new Scheme<Row>(1, Field.Repeat(0, Shape(kind, bit, 0))),
            _ =>
            [
                D(("Mode", L((byte)0)), ("C", L((byte)3))),
                D(("Mode", L((byte)1, (byte)0)), ("C", L((byte)0, (byte)3))),
                D(("Mode", L((byte)0, (byte)1)), ("C", L((byte)3, (byte)3))),
                D(("Mode", (byte)0), ("C", (byte)3)),
            ],
            kind => RoundRows(kind, null, null, "01", "01")),
        ["a repeat round body of round rows"] = new("AC-3",
            (kind, bit) => new Scheme<Row>(1, Field.Repeat(0, (Row x) => x.Rounds, BodyShape(kind, bit, 0))),
            _ =>
            [
                new Row { Rounds = [new Body { Mode = 0, C = 3 }] },
                new Row { Rounds = [new Body { Mode = 1, C = 0 }, new Body { Mode = 0, C = 3 }] },
            ],
            _ => [(new Row { Rounds = [new Body { Mode = 1, C = 0 }, new Body { Mode = 0, C = 0 }] }, "010100000000")]),
    };

    // count 0, left out, holding inner when with no value and with the value, behind `u8 O` (1) and the outer when.
    private static (object Row, string Wire)[] WhenRows(string kind) =>
    [
        (D(("O", (byte)1), ("Mode", (byte)0), ("C", (byte)0)), "01010000"), (D(("O", (byte)1), ("Mode", (byte)0)), "01010000"),
        (D(("O", (byte)1), ("Mode", (byte)1), ("C", (byte)3)), "0101010300"),
        (With(D(("O", (byte)1), ("Mode", (byte)1), ("C", (byte)3)), kind), "0101010301*"),
    ];

    // The round rows of AC-4, with `n1`/`n2` the times count for one and two rounds (null for a repeat) and `one`/`two`
    // the bytes before the rounds (the version, then a times' count; a repeat writes no count).
    private static (object Row, string Wire)[] RoundRows(
        string kind, (string, object?)? n1, (string, object?)? n2, string one, string two)
    {
        Dictionary<string, object?> Rounds((string, object?)? n, params (string Name, object? Value)[] items)
        {
            var row = D(items);
            if (n is { } count)
                row[count.Item1] = count.Item2;
            return row;
        }

        return
        [
            (Rounds(n2, ("Mode", L((byte)1, (byte)0)), ("C", L((byte)0, (byte)0))), two + "0100000000"),
            (Rounds(n1, ("Mode", L((byte)0))), one + "0000"),
            (Rounds(n1, ("Mode", L((byte)1)), ("C", L((byte)3))), one + "010300"),
            (With(Rounds(n1, ("Mode", L((byte)1)), ("C", L((byte)3))), kind, round: true), one + "010301*"),
            (Rounds(n2, ("Mode", L((byte)1, (byte)0)), ("C", L((byte)3, (byte)0))), two + "0103000000"),
            (Rounds(n2, ("Mode", L((byte)1, (byte)0)), ("C", L((byte)3, null))), two + "0103000000"),
        ];
    }

    private static string Outcome(Scheme<Row> scheme, object row)
    {
        try
        {
            return Hex(row is Row typed
                ? BinaryPacker.Pack(scheme, typed)
                : BinaryPacker.Pack(scheme, (IReadOnlyDictionary<string, object?>)row));
        }
        catch (ArgumentException e)
        {
            return e.Message;
        }
    }

    public static TheoryData<string, string, string> Grid()
    {
        var data = new TheoryData<string, string, string>();
        foreach (var position in Positions.Keys)
        {
            foreach (var kind in Kinds)
            {
                foreach (var bit in Bits)
                    data.Add(position, kind, bit);
            }
        }
        return data;
    }

    [Theory]
    [MemberData(nameof(Grid))]
    public void Ac1To3_Pack_CountAboveZeroWithNoValueInANestedPosition_IsRefusedNamingMemberAndCount(
        string position, string kind, string bit)
    {
        // Arrange
        var at = Positions[position];
        var rows = at.Refused(kind);

        // Act
        var outcomes = rows.Select(row => Outcome(at.Layout(kind, bit), row)).ToArray();

        // Assert
        Assert.Equal(Enumerable.Repeat(NoValueCount(kind), rows.Length), outcomes);
    }

    [Theory]
    [MemberData(nameof(Grid))]
    public void Ac4_Pack_CountZeroLeftOutOrAHoldingWhenInANestedPosition_PacksAsAtHead(
        string position, string kind, string bit)
    {
        // Arrange
        var at = Positions[position];
        var rows = at.Unchanged(kind);

        // Act
        var wires = rows.Select(row => Outcome(at.Layout(kind, bit), row.Row)).ToArray();

        // Assert
        Assert.Equal(rows.Select(row => row.Wire.Replace("*", SetHex(kind))), wires);
    }

    public static TheoryData<string, string> KindsAndBits()
    {
        var data = new TheoryData<string, string>();
        foreach (var kind in Kinds)
        {
            foreach (var bit in Bits)
                data.Add(kind, bit);
        }
        return data;
    }

    [Theory]
    [MemberData(nameof(KindsAndBits))]
    public void Ac2_Pack_MemberInsideTheClearInnerWhenItself_IsASilentSkipAsObserved(string kind, string bit)
    {
        // Arrange: `when(O == 1) { u8 Mode; when(Mode == 1) { u8 C; <bit> { member } } }`; the member and its bit sit
        // in the clear when, so nothing of them is written or looked at (not U11; TypeScript and Python agree)
        var scheme = new Scheme<Row>(1,
            Field.U8<Row>(0, x => x.O),
            Field.When(1, Condition.Eq(0, 1),
                Field.U8<Row>(1, x => x.Mode),
                Field.When(2, Condition.Eq(1, 1), [Field.U8<Row>(2, x => x.C), .. Behind(bit, 3, Top(kind, 3, 2))])));

        // Act
        var dict = Outcome(scheme, D(("O", (byte)1), ("Mode", (byte)0), ("C", (byte)3)));
        var typed = Outcome(scheme, new Row { O = 1, Mode = 0, C = 3 });

        // Assert
        Assert.Equal(("010100", "010100"), (dict, typed));
    }

    [Theory]
    [MemberData(nameof(KindsAndBits))]
    public void Ac1_Build_NestedRowGroupNamingACountOutsideItsRow_IsRefusedSoThatPositionIsNotSpellable(string kind, string bit)
    {
        // Act: TypeScript's `<bit> { group g { member counted by c } }` with c outside the group
        var error = Assert.Throws<ArgumentException>(() => new Scheme<Row>(1,
        [
            Field.U8<Row>(0, x => x.Mode), Field.When(1, Condition.Eq(0, 1), Field.U8<Row>(1, x => x.C)),
            .. Behind(bit, 2, Field.Group((Row x) => x.In, Inner(kind, 0, 1))),
        ]));

        // Assert
        Assert.Equal(
            "count of field id 0 names field id 1, which is not an earlier field in the same scope (the top level, a repeat "
            + "or times body, a list or dict element and a nested row are separate scopes)", error.Message);
    }

    [Theory]
    [MemberData(nameof(KindsAndBits))]
    public void Ac3_Pack_CountListShorterThanTheRoundsWhereTheMissingRoundIsClear_PacksAsTypeScript(string kind, string bit)
    {
        // Act (loop 23 parent probe: TypeScript packs these; Python refuses, AZ-2437)
        var times = Outcome(Positions["a times round body"].Layout(kind, bit),
            D(("N", (byte)2), ("Mode", L((byte)1, (byte)0)), ("C", L((byte)3))));
        var repeat = Outcome(Positions["a repeat round body"].Layout(kind, bit),
            D(("Mode", L((byte)1, (byte)0)), ("C", L((byte)3))));

        // Assert
        Assert.Equal(("01020103000000", "010103000000"), (times, repeat));
    }
}
