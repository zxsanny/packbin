namespace Packbin.Tests;

// Seal and open with inputs that lie inside the output buffer give the bytes of the vector rows. E1 has no clear part, so
// E3 (3 clear bytes) is run too: there the four seal layouts are four different overlaps.
public class FrameOverlapTests
{
    public enum Layout
    {
        PlainInPlace,
        PlainAtStart,
        ClearAndPlainInPlace,
        AdInside,
    }

    // Where the AdInside layout puts ad: inside the body for E1 and E3, across the clear part and the ciphertext.
    private const int AdOffset = 3;

    private static FrameVectors.Row Row(string name) => FrameVectors.Load(FrameVectors.FixturePath()).Single(r => r.Case == name);

    [Theory]
    [InlineData("E1.seal", Layout.PlainInPlace)]
    [InlineData("E1.seal", Layout.PlainAtStart)]
    [InlineData("E1.seal", Layout.ClearAndPlainInPlace)]
    [InlineData("E1.seal", Layout.AdInside)]
    [InlineData("E3.seal", Layout.PlainInPlace)]
    [InlineData("E3.seal", Layout.PlainAtStart)]
    [InlineData("E3.seal", Layout.ClearAndPlainInPlace)]
    [InlineData("E3.seal", Layout.AdInside)]
    public void Ac4_SealGivesTheVectorBodyWhateverTheOverlapAndARefusalWritesNothing(string name, Layout layout)
    {
        var row = Row(name);
        using var session = FrameVectors.LoadSession(row)!;
        var ad = row.Bytes("ad");
        var clear = row.Bytes("clear");
        var plain = row.Bytes("plain");
        var body = row.Bytes("body");
        var output = new byte[300];
        Array.Fill(output, FrameVectors.Sentinel);
        var (adAt, clearAt, plainAt) = layout switch
        {
            Layout.PlainInPlace => ((int?)null, (int?)null, (int?)clear.Length),
            Layout.PlainAtStart => (null, null, 0),
            Layout.ClearAndPlainInPlace => (null, 0, clear.Length),
            _ => (AdOffset, null, null),
        };
        ReadOnlySpan<byte> Input(byte[] value, int? at)
        {
            if (at is not int offset)
                return value;
            value.CopyTo(output, offset);
            return output.AsSpan(offset, value.Length);
        }
        var adInput = Input(ad, adAt);
        var clearInput = Input(clear, clearAt);
        var plainInput = Input(plain, plainAt);
        var before = (byte[])output.Clone();
        var direction = (FrameDirection)row.Int("dir");

        var refused = session.Seal(direction, FrameVectors.Context(row), adInput, clearInput, plainInput, output.AsSpan(0, body.Length - 1), out var refusedWritten);
        Assert.Equal(before, output);
        var error = session.Seal(direction, FrameVectors.Context(row), adInput, clearInput, plainInput, output, out var written);

        Assert.IsType<BufferFull>(refused);
        Assert.Equal(0, refusedWritten);
        Assert.Null(error);
        Assert.Equal(body.Length, written);
        Assert.Equal(FrameVectors.Unhex(body), FrameVectors.Unhex(output.AsSpan(0, written)));
        Assert.All(output.Skip(written), b => Assert.Equal(FrameVectors.Sentinel, b));
    }

    [Theory]
    [InlineData("E1.open")]
    [InlineData("E3.open")]
    public void Ac4_OpenGivesTheVectorPlainWhenPlainOverlapsTheBody(string name)
    {
        var row = Row(name);
        using var session = FrameVectors.LoadSession(row)!;
        var clearLength = row.Int("clear_len");
        var expected = FrameVectors.Unhex(row.Bytes("plain"));

        foreach (var at in new[] { 0, clearLength })
        {
            var buffer = new byte[300];
            row.Bytes("body").CopyTo(buffer, 0);
            var body = buffer.AsSpan(0, row.Bytes("body").Length);

            var error = session.Open((FrameDirection)row.Int("dir"), FrameVectors.Context(row), row.Bytes("ad"), body, clearLength, buffer.AsSpan(at), out var opened);

            Assert.Null(error);
            Assert.Equal(expected, FrameVectors.Unhex(buffer.AsSpan(at, opened.PlainLength)));
        }
    }
}
