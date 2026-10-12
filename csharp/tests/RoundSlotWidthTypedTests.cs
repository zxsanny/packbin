using Packbin;

namespace Packbin.Tests;

// AZ-2382 (U2) for a round bound to a collection of rows (AZ-2388): the same rows of the reference table
// (_docs/03_implementation/reference_loop21_slots.md rows 1 to 8) charge the same slots and write the same hex as the
// dictionary form of RoundSlotWidthTests, and row 7 (an unanchored group, a nested row in C#) is expressed here.
public class RoundSlotWidthTypedTests
{
    internal sealed class Leg
    {
        public byte A { get; set; }
        public byte B { get; set; }
        public byte C { get; set; }
        public byte M { get; set; }
        public byte? K { get; set; }
        public byte? V { get; set; }
        public bool? G { get; set; }
        public bool? H { get; set; }
        public bool? On { get; set; }
        public int P { get; set; }
        public int Q { get; set; }
        public int R { get; set; }
        public Nest? Inner { get; set; }
    }

    internal sealed class Nest
    {
        public byte B { get; set; }
    }

    internal sealed class Trip
    {
        public List<Leg>? Legs { get; set; }
    }

    internal sealed record Case(
        string Name, int Width, Func<long, Scheme<Trip>> Scheme, Func<int, Trip> Row, string Hex2, string Hex3, int Left);

    private static Scheme<Trip> Repeat(long maxSlots, params Field[] body) =>
        new Scheme<Trip>(1, Field.Repeat(0, (Trip t) => t.Legs, body)).WithLimits(maxSlots: maxSlots);

    private static Trip Legs(int rounds, params Leg[] legs) => new() { Legs = [.. legs.Take(rounds)] };

    private static string Hex(byte[] raw) => Convert.ToHexString(raw).ToLowerInvariant();

    private static readonly Case[] Rows =
    [
        new("1 empty group, flag byte", 2,
            n => Repeat(n, Field.U8<Leg>(0, x => x.A), Field.Flags(1, Field.Group(1, (Leg x) => x.G))),
            r => Legs(r, new Leg { A = 1, G = true }, new Leg { A = 2 }, new Leg { A = 3, G = true }),
            "0101010200", "01010102000301", 2),
        new("2 duplicate leaf names", 2,
            n => Repeat(n, Field.U8<Leg>(0, x => x.M),
                Field.When(1, Condition.Eq(0, 1), Field.U8<Leg>(1, x => x.K)),
                Field.When(2, Condition.Eq(0, 2), Field.U8<Leg>(2, x => x.K))),
            r => Legs(r, new Leg { M = 1, K = 7 }, new Leg { M = 2, K = 8 }, new Leg { M = 1, K = 9 }),
            "0101070208", "01010702080109", 2),
        new("3 combined flags", 2,
            n => Repeat(n, Field.Flags(0, Field.Bool<Leg>(0, x => x.On), Field.U8<Leg>(1, x => x.V))),
            r => Legs(r, new Leg { On = true, V = 5 }, new Leg { On = true, V = 6 }, new Leg { On = true, V = 7 }),
            "0103050306", "01030503060307", 2),
        new("4 split bits and flag byte", 2,
            n =>
            {
                var m = Field.FlagByte();
                return Repeat(n, m, m.Bit(Field.U8<Leg>(0, x => x.A)), m.Bit(Field.U8<Leg>(1, x => x.B)));
            },
            r => Legs(r, new Leg { A = 1, B = 4 }, new Leg { A = 2, B = 5 }, new Leg { A = 3, B = 6 }),
            "01030104030205", "01030104030205030306", 3),
        new("5 when clear in every round", 2,
            n => Repeat(n, Field.U8<Leg>(0, x => x.M), Field.When(1, Condition.Eq(0, 1), Field.U8<Leg>(1, x => x.K))),
            r => Legs(r, new Leg(), new Leg(), new Leg()),
            "010000", "01000000", 1),
        new("6 nested anchored groups", 3,
            n => Repeat(n, Field.U8<Leg>(0, x => x.A),
                Field.Group(1, (Leg x) => x.G, Field.U8<Leg>(1, x => x.B),
                    Field.Group(2, (Leg x) => x.H, Field.U8<Leg>(2, x => x.C)))),
            r => Legs(r, new Leg { A = 1, B = 4, C = 7 }, new Leg { A = 2, B = 5, C = 8 }, new Leg { A = 3, B = 6, C = 9 }),
            "01010407020508", "01010407020508030609", 3),
        new("7 unanchored group as a nested row", 2,
            n => Repeat(n, Field.U8<Leg>(0, x => x.A), Field.Group((Leg x) => x.Inner, Field.U8<Nest>(0, g => g.B))),
            r => Legs(r, new Leg { A = 1, Inner = new Nest { B = 4 } }, new Leg { A = 2, Inner = new Nest { B = 5 } },
                new Leg { A = 3, Inner = new Nest { B = 6 } }),
            "0101040205", "01010402050306", 2),
        new("8 u2 slots", 4,
            n => Repeat(n, Field.U8<Leg>(0, x => x.A), Field.U2<Leg>((1, x => x.P), (2, x => x.Q), (3, x => x.R))),
            r => Legs(r, new Leg { A = 1, P = 1, Q = 2, R = 3 }, new Leg { A = 2, P = 1, Q = 2, R = 3 },
                new Leg { A = 3, P = 1, Q = 2, R = 3 }),
            "0101390239", "01013902390339", 2),
    ];

    public static TheoryData<string> Names() => [.. Rows.Select(r => r.Name)];

    private static Case Of(string name) => Rows.Single(r => r.Name == name);

    [Theory]
    [MemberData(nameof(Names))]
    public void Ac1_Pack_TwoRoundsAtMaxSlotsOfTwiceTheWidth_WritesTheReferenceBytes(string name)
    {
        // Arrange
        var row = Of(name);

        // Act
        var raw = BinaryPacker.Pack(row.Scheme(2L * row.Width), row.Row(2));

        // Assert
        Assert.Equal(row.Hex2, Hex(raw));
    }

    [Theory]
    [MemberData(nameof(Names))]
    public void Ac1_Pack_ThirdRoundAtTwiceTheWidth_IsRefusedNamingTheCollection(string name)
    {
        // Arrange
        var row = Of(name);

        // Act
        var error = Budget.Refused(row.Scheme(2L * row.Width), row.Row(3));

        // Assert
        Assert.Equal($"'Legs': the rounds would hold {3 * row.Width} slots, above the limit of {2 * row.Width} slots", error.Message);
    }

    [Theory]
    [MemberData(nameof(Names))]
    public void Ac1_Pack_ThreeRoundsAtThreeTimesTheWidth_WritesTheReferenceBytes(string name)
    {
        // Arrange
        var row = Of(name);

        // Act
        var raw = BinaryPacker.Pack(row.Scheme(3L * row.Width), row.Row(3));

        // Assert
        Assert.Equal(row.Hex3, Hex(raw));
    }

    [Theory]
    [MemberData(nameof(Names))]
    public void Ac1_Unpack_ThreeRoundPacketAtTwiceTheWidth_RefusesTheThirdRound(string name)
    {
        // Arrange
        var row = Of(name);
        var scheme = row.Scheme(2L * row.Width);

        // Act
        var error = BinaryPacker.Unpack(Convert.FromHexString(row.Hex3), scheme.On(_ => { }));

        // Assert
        var refused = Assert.IsType<ShortPacket>(error);
        Assert.Equal("Legs", refused.Field);
        Assert.Equal(0, refused.Needed);
        Assert.Equal(row.Left, refused.Left);
    }

    [Theory]
    [MemberData(nameof(Names))]
    public void Ac2_Unpack_PacketPackWroteAtTheLimit_UnpacksAndRepacksToTheSameBytes(string name)
    {
        // Arrange
        var row = Of(name);
        var scheme = row.Scheme(2L * row.Width);
        Trip? got = null;

        // Act
        var error = BinaryPacker.Unpack(Convert.FromHexString(row.Hex2), scheme.On(trip => got = trip));
        var again = BinaryPacker.Pack(scheme, got);

        // Assert
        Assert.Null(error);
        Assert.Equal(row.Hex2, Hex(again));
    }
}
