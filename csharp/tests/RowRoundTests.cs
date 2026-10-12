using System.Collections;
using Packbin;

namespace Packbin.Tests;

// AZ-2388: a typed repeat or times binds to a collection of row objects (the Rust direction): the round's fields are
// declared for the element row, pack reads one row per round and unpack builds them. The scheme builds if and only if
// typed Unpack can bind the member (the same RowRounds object answers both).
public class RowRoundTests
{
    private sealed class Point
    {
        public int Lat { get; set; }
        public int Lon { get; set; }
    }

    // Named like members of the row around it: a round never sees those names.
    private sealed class Clash
    {
        public byte N { get; set; }
        public byte Tail { get; set; }
    }

    private sealed class Route
    {
        public byte N { get; set; }
        public List<Point>? Points { get; set; }
        public byte Tail { get; set; }
    }

    private sealed class ClashRoute
    {
        public byte N { get; set; }
        public List<Clash>? Items { get; set; }
        public byte Tail { get; set; }
    }

    private sealed class Wayside
    {
        public byte V { get; set; }
        public byte? Alt { get; set; }
    }

    private sealed class Trip
    {
        public byte N { get; set; }
        public Wayside[]? Stops { get; set; }
        public IList<Wayside>? Seen { get; set; }
    }

    private sealed class Inner
    {
        public byte N { get; set; }
        public List<Point>? Points { get; set; }
    }

    private sealed class Outer
    {
        public byte A { get; set; }
        public Inner? Inner { get; set; }
    }

    private static string Hex(byte[] raw) => Convert.ToHexString(raw).ToLowerInvariant();

    private static T? Unpacked<T>(Scheme<T> scheme, byte[] packet) where T : class, new()
    {
        T? bound = null;
        var result = BinaryPacker.Unpack(packet, scheme.On(row => bound = row));
        Assert.Null(result);
        return bound;
    }

    private static Scheme<Route> RouteTimes() => new(1,
        Field.U8<Route>(0, x => x.N),
        Field.Times(1, 0, (Route x) => x.Points, Field.I32<Point>(1, p => p.Lat), Field.I32<Point>(2, p => p.Lon)),
        Field.U8<Route>(3, x => x.Tail));

    private static Scheme<Route> RouteRepeat() => new(1,
        Field.Repeat(0, (Route x) => x.Points, Field.I32<Point>(0, p => p.Lat), Field.I32<Point>(1, p => p.Lon)));

    private const string RouteHex = "01" + "02" + "0a000000" + "14000000" + "1e000000" + "28000000" + "07";

    private static Route TwoPoints() => new()
    {
        N = 2,
        Points = [new Point { Lat = 10, Lon = 20 }, new Point { Lat = 30, Lon = 40 }],
        Tail = 7,
    };

    [Fact]
    public void Ac1_Pack_TimesOverAListOfRows_PacksTheRoundsOfEachRow()
    {
        // Act
        var raw = BinaryPacker.Pack(RouteTimes(), TwoPoints());

        // Assert
        Assert.Equal(RouteHex, Hex(raw));
    }

    [Fact]
    public void Ac1_Unpack_TimesOverAListOfRows_BuildsOneRowPerRound()
    {
        // Act
        var got = Unpacked(RouteTimes(), Convert.FromHexString(RouteHex))!;

        // Assert
        Assert.Equal(2, got.N);
        Assert.Equal(7, got.Tail);
        Assert.Equal([(10, 20), (30, 40)], got.Points!.Select(p => (p.Lat, p.Lon)).ToArray());
    }

    [Fact]
    public void Ac1_Pack_RepeatOverAListOfRows_RoundTripsWithTheSameBytes()
    {
        // Arrange
        var scheme = RouteRepeat();
        var row = new Route { Points = [new Point { Lat = 1, Lon = 2 }, new Point { Lat = -3, Lon = 4 }] };

        // Act
        var raw = BinaryPacker.Pack(scheme, row);
        var got = Unpacked(scheme, raw)!;

        // Assert
        Assert.Equal("01" + "01000000" + "02000000" + "fdffffff" + "04000000", Hex(raw));
        Assert.Equal([(1, 2), (-3, 4)], got.Points!.Select(p => (p.Lat, p.Lon)).ToArray());
        Assert.Equal(Hex(raw), Hex(BinaryPacker.Pack(scheme, got)));
    }

    [Fact]
    public void Ac1_Scheme_BuiltFromFieldsOfT_PacksTheSameAsTheStaticForm()
    {
        // Arrange
        var scheme = new Scheme<Route>(1, f =>
        [
            f.U8(0, x => x.N),
            f.Times(1, 0, x => x.Points!, p => [p.I32(1, r => r.Lat), p.I32(2, r => r.Lon)]),
            f.U8(3, x => x.Tail),
        ]);

        // Act
        var raw = BinaryPacker.Pack(scheme, TwoPoints());

        // Assert
        Assert.Equal(RouteHex, Hex(raw));
    }

    [Fact]
    public void Ac1_Pack_ArrayAndIListMembers_RoundTrip()
    {
        // Arrange
        var scheme = new Scheme<Trip>(1,
            Field.U8<Trip>(0, x => x.N),
            Field.Times(1, 0, (Trip x) => x.Stops, Field.U8<Wayside>(1, w => w.V)),
            Field.Repeat(2, (Trip x) => x.Seen, Field.U8<Wayside>(2, w => w.V)));
        var trip = new Trip
        {
            N = 2,
            Stops = [new Wayside { V = 5 }, new Wayside { V = 6 }],
            Seen = new List<Wayside> { new() { V = 7 } },
        };

        // Act
        var raw = BinaryPacker.Pack(scheme, trip);
        var got = Unpacked(scheme, raw)!;

        // Assert
        Assert.Equal("01" + "02" + "05" + "06" + "07", Hex(raw));
        Assert.Equal(new byte[] { 5, 6 }, got.Stops!.Select(w => w.V).ToArray());
        Assert.Equal(new byte[] { 7 }, got.Seen!.Select(w => w.V).ToArray());
    }

    [Fact]
    public void Ac1_Pack_ElementMembersNamedLikeTheRowAround_StayInTheirOwnRound()
    {
        // Arrange
        var scheme = new Scheme<ClashRoute>(1,
            Field.U8<ClashRoute>(0, x => x.N),
            Field.Times(1, 0, (ClashRoute x) => x.Items, Field.U8<Clash>(1, c => c.N), Field.U8<Clash>(2, c => c.Tail)),
            Field.U8<ClashRoute>(3, x => x.Tail));
        var row = new ClashRoute
        {
            N = 2,
            Items = [new Clash { N = 10, Tail = 11 }, new Clash { N = 12, Tail = 13 }],
            Tail = 99,
        };

        // Act
        var raw = BinaryPacker.Pack(scheme, row);
        var got = Unpacked(scheme, raw)!;

        // Assert
        Assert.Equal("01" + "02" + "0a0b" + "0c0d" + "63", Hex(raw));
        Assert.Equal((byte)2, got.N);
        Assert.Equal((byte)99, got.Tail);
        Assert.Equal(new byte[] { 10, 12 }, got.Items!.Select(c => c.N).ToArray());
        Assert.Equal(new byte[] { 11, 13 }, got.Items!.Select(c => c.Tail).ToArray());
    }

    [Fact]
    public void Ac1_Pack_OptionalMemberOfTheElementUnderFlags_KeepsItsOwnRound()
    {
        // Arrange
        var scheme = new Scheme<Trip>(1,
            Field.Repeat(0, (Trip x) => x.Stops, Field.U8<Wayside>(0, w => w.V), Field.Flags(1, Field.U8<Wayside>(1, w => w.Alt))));
        var trip = new Trip { Stops = [new Wayside { V = 1, Alt = 9 }, new Wayside { V = 2 }] };

        // Act
        var raw = BinaryPacker.Pack(scheme, trip);
        var got = Unpacked(scheme, raw)!;

        // Assert
        Assert.Equal("01" + "01" + "01" + "09" + "02" + "00", Hex(raw));
        Assert.Equal(new byte?[] { 9, null }, got.Stops!.Select(w => w.Alt).ToArray());
    }

    [Fact]
    public void Ac1_Pack_RoundInsideANestedRow_RoundTrips()
    {
        // Arrange
        var scheme = new Scheme<Outer>(1,
            Field.U8<Outer>(0, x => x.A),
            Field.Group((Outer o) => o.Inner,
                Field.U8<Inner>(0, i => i.N),
                Field.Times(1, 0, (Inner i) => i.Points, Field.I32<Point>(1, p => p.Lat), Field.I32<Point>(2, p => p.Lon))));
        var row = new Outer { A = 5, Inner = new Inner { N = 1, Points = [new Point { Lat = 3, Lon = 4 }] } };

        // Act
        var raw = BinaryPacker.Pack(scheme, row);
        var got = Unpacked(scheme, raw)!;

        // Assert
        Assert.Equal("01" + "05" + "01" + "03000000" + "04000000", Hex(raw));
        Assert.Equal((3, 4), (got.Inner!.Points![0].Lat, got.Inner.Points[0].Lon));
    }

    [Fact]
    public void Ac1_Pack_RoundInsideFlags_SetsTheBitOnlyForRows()
    {
        // Arrange
        var scheme = new Scheme<Route>(1,
            Field.U8<Route>(0, x => x.N),
            Field.Flags(1, Field.Times(1, 0, (Route x) => x.Points, Field.I32<Point>(1, p => p.Lat))));

        // Act
        var none = BinaryPacker.Pack(scheme, new Route { N = 0, Points = [] });
        var some = BinaryPacker.Pack(scheme, new Route { N = 1, Points = [new Point { Lat = 5 }] });
        var back = Unpacked(scheme, some)!;

        // Assert
        Assert.Equal("01" + "00" + "00", Hex(none));
        Assert.Equal("01" + "01" + "01" + "05000000", Hex(some));
        Assert.Equal(5, back.Points![0].Lat);
    }

    [Fact]
    public void Ac1_Unpack_NoRounds_GivesAnEmptyCollection()
    {
        // Act
        var times = Unpacked(RouteTimes(), Convert.FromHexString("01" + "00" + "07"))!;
        var repeat = Unpacked(RouteRepeat(), Convert.FromHexString("01"))!;

        // Assert
        Assert.Empty(times.Points!);
        Assert.Empty(repeat.Points!);
    }

    [Fact]
    public void Ac1_Pack_NullCollection_IsNoRounds()
    {
        // Act
        var raw = BinaryPacker.Pack(RouteRepeat(), new Route());

        // Assert
        Assert.Equal("01", Hex(raw));
    }

    [Fact]
    public void Ac1_Pack_TimesCountDifferentFromTheRows_IsRefusedNamingTheMember()
    {
        // Arrange
        var row = TwoPoints();
        row.N = 3;

        // Act
        var error = Assert.Throws<ArgumentException>(() => BinaryPacker.Pack(RouteTimes(), row));

        // Assert
        Assert.Equal("'Points': the times count is 3, but it holds 2 rounds", error.Message);
    }

    [Fact]
    public void Ac1_Pack_ZeroCountWithRows_IsRefusedNamingTheMember()
    {
        // Arrange
        var row = TwoPoints();
        row.N = 0;

        // Act
        var error = Assert.Throws<ArgumentException>(() => BinaryPacker.Pack(RouteTimes(), row));

        // Assert
        Assert.Equal("'Points': the times count is 0, but it holds 2 rounds", error.Message);
    }

    [Fact]
    public void Ac1_Pack_RoundsAboveTheLimits_AreRefusedBeforeAnyRoundIsWritten()
    {
        // Arrange
        var repeat = RouteRepeat().WithLimits(maxRounds: 1);
        var slots = RouteRepeat().WithLimits(maxSlots: 3);
        var row = TwoPoints();

        // Act
        var rounds = Assert.Throws<ArgumentException>(() => BinaryPacker.Pack(repeat, row));
        var spent = Assert.Throws<ArgumentException>(() => BinaryPacker.Pack(slots, row));

        // Assert
        Assert.Equal("'Points': the repeat count is 2, above the limit of 1 rounds", rounds.Message);
        Assert.Equal("'Points': the rounds would hold 4 slots, above the limit of 3 slots", spent.Message);
    }

    [Fact]
    public void Ac1_Unpack_RoundsAboveTheLimit_ReturnTheErrorResult()
    {
        // Arrange
        var scheme = RouteRepeat().WithLimits(maxRounds: 1);
        var handled = false;

        // Act
        var result = BinaryPacker.Unpack(Convert.FromHexString("01" + "01000000" + "02000000" + "03000000" + "04000000"), scheme.On(_ => handled = true));

        // Assert
        Assert.False(handled);
        Assert.IsType<ShortPacket>(result);
    }

    [Fact]
    public void Ac1_Pack_DictionaryFormOfARowRound_KeepsThePerNameLists()
    {
        // Arrange
        var scheme = RouteTimes();
        var values = new Dictionary<string, object?>
        {
            ["N"] = (byte)2,
            ["Lat"] = new object?[] { 10, 30 },
            ["Lon"] = new object?[] { 20, 40 },
            ["Tail"] = (byte)7,
        };

        // Act
        var raw = BinaryPacker.Pack(scheme, values);
        var read = BinaryPacker.Read(scheme, raw);
        var again = BinaryPacker.Pack(scheme, read.Values);

        // Assert
        Assert.Equal(RouteHex, Hex(raw));
        Assert.Null(read.Error);
        Assert.Equal(new object?[] { 10, 30 }, ((List<object?>)read.Values["Lat"]!).ToArray());
        Assert.Equal(RouteHex, Hex(again));
    }

    [Fact]
    public void Ac2_Scheme_RoundFieldsDeclaredForAnotherRow_AreRefused()
    {
        // Act
        var error = Record.Exception(() => new Scheme<Route>(1,
            Field.Repeat(0, (Route x) => x.Points, Field.U8<Route>(0, r => r.Tail))));

        // Assert
        var refused = Assert.IsType<ArgumentException>(error);
        Assert.Equal("'Tail' is declared for row type Route, but this scheme is for Point", refused.Message);
    }

    [Fact]
    public void Ac3_Scheme_OldBindingOfARoundToListMembers_StillBuildsAndUnpacks()
    {
        // Arrange
        var scheme = new Scheme<OldRow>(1, Field.Repeat(0, Field.List((OldRow x) => x.Ids, Field.U8<OldRow>(0, x => x.B))));
        OldRow? bound = null;

        // Act (two rounds, each a list of one byte)
        var result = BinaryPacker.Unpack(new byte[] { 1, 1, 0, 5, 1, 0, 6 }, scheme.On(row => bound = row));

        // Assert
        Assert.Null(result);
        Assert.Equal(2, bound!.Ids!.Count);
        Assert.Equal(new object?[] { (byte)5 }, bound.Ids[0].ToArray());
        Assert.Equal(new object?[] { (byte)6 }, bound.Ids[1].ToArray());
    }

    private sealed class OldRow
    {
        public byte B { get; set; }
        public List<List<object?>>? Ids { get; set; }
    }
}
