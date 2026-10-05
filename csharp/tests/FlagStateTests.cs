using System.Globalization;
using System.Reflection;
using Packbin;

namespace Packbin.Tests;

public class FlagStateTests
{
    private const int Rounds = 200_000;

    private sealed class RaceRow
    {
        public byte? A { get; set; }
        public byte? B { get; set; }
    }

    private sealed class MotionRow
    {
        public byte Profile { get; set; }
        public byte? Shape { get; set; }
        public ushort? Heading { get; set; }
        public byte? Speed { get; set; }
        public short? Altitude { get; set; }
    }

    private static readonly Scheme<RaceRow> Combined = new(1,
        Field.Flags(0, Field.U8<RaceRow>(0, x => x.A), Field.U8<RaceRow>(1, x => x.B)));

    private static readonly Scheme<RaceRow> Split = BuildSplit();

    private static readonly Scheme<MotionRow> Motion = BuildMotion();

    private static Scheme<RaceRow> BuildSplit()
    {
        var m = Field.FlagByte();
        return new Scheme<RaceRow>(1, m, m.Bit(Field.U8<RaceRow>(0, x => x.A)), m.Bit(Field.U8<RaceRow>(1, x => x.B)));
    }

    // The schema "split form": flag byte, a when group, then the bits it controls.
    private static Scheme<MotionRow> BuildMotion()
    {
        var motion = Field.FlagByte();
        return new Scheme<MotionRow>(1,
            Field.U8<MotionRow>(0, x => x.Profile),
            motion,
            Field.When(1, Condition.Eq(0, 0), Field.U8<MotionRow>(1, x => x.Shape)),
            motion.Bit(Field.U16<MotionRow>(2, x => x.Heading)),
            motion.Bit(Field.U8<MotionRow>(3, x => x.Speed)),
            motion.Bit(Field.I16<MotionRow>(4, x => x.Altitude)));
    }

    private static int CountWrong(Scheme<RaceRow> scheme, byte[] packet, string present, int expected, string absent)
    {
        var wrong = 0;
        for (var i = 0; i < Rounds; i++)
        {
            var got = BinaryPacker.Read(scheme, packet);
            var ok = got.Error is null
                && got.Values.TryGetValue(present, out var value)
                && Convert.ToInt32(value, CultureInfo.InvariantCulture) == expected
                && !got.Values.ContainsKey(absent);
            if (!ok)
                wrong++;
        }
        return wrong;
    }

    private static int RunRace(Scheme<RaceRow> scheme)
    {
        var onlyA = BinaryPacker.Pack(scheme, new RaceRow { A = 7 });
        var onlyB = BinaryPacker.Pack(scheme, new RaceRow { B = 8 });
        Assert.Equal("010107", Convert.ToHexString(onlyA).ToLowerInvariant());
        Assert.Equal("010208", Convert.ToHexString(onlyB).ToLowerInvariant());
        var start = new Barrier(2);
        var wrongA = 0;
        var wrongB = 0;
        var first = new Thread(() =>
        {
            start.SignalAndWait();
            wrongA = CountWrong(scheme, onlyA, "A", 7, "B");
        });
        var second = new Thread(() =>
        {
            start.SignalAndWait();
            wrongB = CountWrong(scheme, onlyB, "B", 8, "A");
        });
        first.Start();
        second.Start();
        first.Join();
        second.Join();
        return wrongA + wrongB;
    }

    [Fact]
    public void Ac1_TwoThreadsSharingAFlagsScheme_AlwaysGetTheirOwnRow()
    {
        Assert.Equal(0, RunRace(Combined));
    }

    [Fact]
    public void Ac2_TwoThreadsSharingASplitFormScheme_AlwaysGetTheirOwnRow()
    {
        Assert.Equal(0, RunRace(Split));
    }

    [Fact]
    public void Ac3_FlagGroupsHoldNoRuntimeState()
    {
        // Arrange
        var groups = Combined.Fields.Concat(Split.Fields).Concat(Motion.Fields)
            .Select(f => f.FlagOwner)
            .Where(g => g is not null)
            .Distinct()
            .ToList();
        var before = groups.Select(Snapshot).ToList();

        // Act
        for (var i = 0; i < 1000; i++)
        {
            BinaryPacker.Read(Combined, [1, 1, 7]);
            BinaryPacker.Read(Split, [1, 2, 8]);
            BinaryPacker.Read(Motion, [1, 1, 1, 0x5a, 0]);
        }

        // Assert
        Assert.NotEmpty(groups);
        Assert.Equal(before, groups.Select(Snapshot).ToList());
        foreach (var group in groups)
        {
            var settable = group!.GetType()
                .GetFields(BindingFlags.Instance | BindingFlags.Public | BindingFlags.NonPublic)
                .Where(f => !f.IsInitOnly)
                .Select(f => f.Name)
                .ToList();
            Assert.Empty(settable);
        }
    }

    private static string Snapshot(object? group) =>
        string.Join(";", group!.GetType()
            .GetFields(BindingFlags.Instance | BindingFlags.Public | BindingFlags.NonPublic)
            .Select(f => f.Name + "=" + Describe(f.GetValue(group))));

    private static string Describe(object? value) =>
        value is System.Collections.ICollection c ? "count " + c.Count : Convert.ToString(value, CultureInfo.InvariantCulture) ?? "";

    [Fact]
    public void Ac5_SplitForm_HeadingOnly_WritesFlagByteAtItsPosition()
    {
        // Arrange
        var row = new MotionRow { Profile = 1, Heading = 90 };

        // Act
        var raw = BinaryPacker.Pack(Motion, row);
        MotionRow? back = null;
        var err = BinaryPacker.Unpack(raw, Motion.On(v => back = v));

        // Assert: type, profile, flag byte 01, heading 5a 00
        Assert.Equal("0101015a00", Convert.ToHexString(raw).ToLowerInvariant());
        Assert.Null(err);
        Assert.NotNull(back);
        Assert.Equal((byte)1, back.Profile);
        Assert.Equal((ushort)90, back.Heading);
        Assert.Null(back.Speed);
        Assert.Null(back.Altitude);
        Assert.Null(back.Shape);
    }

    [Fact]
    public void Ac5_SplitForm_WithWhenGroupBetween_RoundTrips()
    {
        // Arrange
        var row = new MotionRow { Profile = 0, Shape = 7, Speed = 3, Altitude = -2 };

        // Act
        var raw = BinaryPacker.Pack(Motion, row);
        MotionRow? back = null;
        var err = BinaryPacker.Unpack(raw, Motion.On(v => back = v));

        // Assert: flag byte 06 = speed and altitude, the when group's shape sits between flag byte and bits
        Assert.Equal("01000607" + "03" + "feff", Convert.ToHexString(raw).ToLowerInvariant());
        Assert.Null(err);
        Assert.NotNull(back);
        Assert.Equal((byte?)7, back.Shape);
        Assert.Null(back.Heading);
        Assert.Equal((byte?)3, back.Speed);
        Assert.Equal((short?)-2, back.Altitude);
    }

    [Fact]
    public void Ac5_SplitForm_ClearByteWithLeftoverBytes_IsTrailingBytes()
    {
        // Arrange
        var raw = Convert.FromHexString("010100ff");
        MotionRow? row = null;

        // Act
        var error = BinaryPacker.Unpack(raw, Motion.On(v => row = v));

        // Assert: the row is never built, so no field is set
        var trailing = Assert.IsType<TrailingBytes>(error);
        Assert.Equal(1, trailing.Left);
        Assert.Null(row);
    }
}
