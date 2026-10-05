using Packbin;

namespace Packbin.Tests;

// A list or dict element that reads 0 bytes is an error; the interim bad-value shape is
// ShortPacket(list or dict field, 0, bytes left at the element start), as for a zero-width times round.
public class ZeroWidthElementTests
{
    private sealed class El
    {
        public byte[] B { get; set; } = [];
        public byte V { get; set; }
    }

    private sealed class Mid
    {
        public List<object?>? Inner { get; set; }
    }

    private sealed class ListRow
    {
        public List<object?>? Xs { get; set; }
    }

    private sealed class NestedRow
    {
        public List<object?>? Outer { get; set; }
    }

    private sealed class MapRow
    {
        public Dictionary<string, object?>? M { get; set; }
    }

    private static Scheme<ListRow> ZeroList() => new(1,
        Field.List((ListRow x) => x.Xs, Field.Bytes<El>(0, x => x.B, 0)));

    private static Scheme<NestedRow> NestedZeroList() => new(1,
        Field.List((NestedRow x) => x.Outer,
            Field.List((Mid m) => m.Inner, Field.Bytes<El>(0, x => x.B, 0))));

    private static Scheme<MapRow> ZeroDict() => new(1,
        Field.Dict((MapRow x) => x.M, Field.Bytes<El>(0, x => x.B, 0)));

    [Fact]
    public void ZeroWidthListElement_IsError()
    {
        var outcome = HostileProbe.Unpack(ZeroList(), "010300", 1);

        var error = HostileProbe.ExpectShort(outcome, "Xs");
        Assert.Equal(0, error.Needed);
        Assert.Equal(0, error.Left);
    }

    [Fact]
    public void ZeroWidthListElement_ReportsBytesLeftAtTheElementStart()
    {
        var outcome = HostileProbe.Unpack(ZeroList(), "0101000909", 1);

        var error = HostileProbe.ExpectShort(outcome, "Xs");
        Assert.Equal(2, error.Left);
    }

    [Fact]
    public void ZeroWidthInnerListElement_FiveBytePacketWithMaxCounts_IsError()
    {
        var outcome = HostileProbe.Unpack(NestedZeroList(), "01ffffffff", 1);

        var error = HostileProbe.ExpectShort(outcome, "Inner");
        Assert.Equal(0, error.Needed);
        Assert.Equal(0, error.Left);
    }

    [Fact]
    public void ZeroWidthInnerListElement_SmallPacketThatUnpackedBefore_IsError()
    {
        var outcome = HostileProbe.Unpack(NestedZeroList(), "0101000300", 1);

        HostileProbe.ExpectShort(outcome, "Inner");
    }

    [Fact]
    public void ZeroWidthInnerListElement_131KbPacket_ReturnsQuickly()
    {
        var hex = "01ffff" + string.Concat(Enumerable.Repeat("ffff", 65535));

        var outcome = HostileProbe.Unpack(NestedZeroList(), hex, 1);

        HostileProbe.ExpectShort(outcome, "Inner");
    }

    [Fact]
    public void ZeroWidthDictValue_IsError()
    {
        var outcome = HostileProbe.Unpack(ZeroDict(), "0101000100" + "61", 1);

        var error = HostileProbe.ExpectShort(outcome, "M");
        Assert.Equal(0, error.Needed);
        Assert.Equal(0, error.Left);
    }

    [Fact]
    public void ZeroWidthDictValue_CountFFFFWithOneKey_IsError()
    {
        var outcome = HostileProbe.Unpack(ZeroDict(), "01ffff0100" + "61", 1);

        var error = HostileProbe.ExpectShort(outcome, "M");
        Assert.Equal(0, error.Needed);
        Assert.Equal(0, error.Left);
    }

    [Fact]
    public void NeverMatchingWhenListElement_IsError()
    {
        var scheme = new Scheme<ListRow>(1,
            Field.List((ListRow x) => x.Xs, Field.When(0, Condition.Eq(0, 1), Field.U8<El>(0, x => x.V))));

        var outcome = HostileProbe.Unpack(scheme, "010300", 1);

        HostileProbe.ExpectShort(outcome, "Xs");
    }

    [Fact]
    public void NeverMatchingWhenDictValue_IsError()
    {
        var scheme = new Scheme<MapRow>(1,
            Field.Dict((MapRow x) => x.M, Field.When(0, Condition.Eq(0, 1), Field.U8<El>(0, x => x.V))));

        var outcome = HostileProbe.Unpack(scheme, "0101000100" + "61", 1);

        HostileProbe.ExpectShort(outcome, "M");
    }

    [Fact]
    public void EmptyListOfZeroWidth_StillUnpacks()
    {
        var got = BinaryPacker.Read(ZeroList(), Convert.FromHexString("010000"));

        Assert.Null(got.Error);
        Assert.Empty((List<object?>)got.Values["Xs"]!);
    }

    [Fact]
    public void EmptyDictOfZeroWidth_StillUnpacks()
    {
        var got = BinaryPacker.Read(ZeroDict(), Convert.FromHexString("010000"));

        Assert.Null(got.Error);
        Assert.Empty((Dictionary<string, object?>)got.Values["M"]!);
    }

    [Fact]
    public void ListWithProgress_StillUnpacks()
    {
        var scheme = new Scheme<ListRow>(1,
            Field.List((ListRow x) => x.Xs, Field.U8<El>(0, x => x.V)));

        var got = BinaryPacker.Read(scheme, Convert.FromHexString("010200" + "0708"));

        Assert.Null(got.Error);
        Assert.Equal(2, ((List<object?>)got.Values["Xs"]!).Count);
    }
}
