using Packbin;

namespace Packbin.Tests;

// AZ-3512: a parity percentage over a message whose length varies by an optional field (AC-17, S12b), over a string
// field read after the repair (AC-18, S12c), and the refusal of a dispatch mix naming the percentage (AC-19, D4).
public class EccPercentFieldsTests
{
    private sealed class OptionalRow
    {
        public uint A { get; set; }
        public uint B { get; set; }
        public ushort? H { get; set; }
        public byte? S { get; set; }
    }

    private sealed class NoteRow
    {
        public string Text { get; set; } = "";
        public byte N { get; set; }
    }

    private static readonly Scheme<OptionalRow> Optional = new Scheme<OptionalRow>(1,
        Field.U32<OptionalRow>(0, x => x.A),
        Field.U32<OptionalRow>(1, x => x.B),
        Field.Flags(2,
            Field.U16<OptionalRow>(2, x => x.H),
            Field.U8<OptionalRow>(3, x => x.S))).WithParityPercent(25);

    private static readonly Scheme<NoteRow> Note = new Scheme<NoteRow>(1,
        Field.Utf8<NoteRow>(0, x => x.Text),
        Field.U8<NoteRow>(1, x => x.N)).WithParityPercent(25);

    [Theory]
    [InlineData(true, 13, 4)]
    [InlineData(false, 10, 3)]
    public void Pack_AMessageWithAndOneWithoutTheOptionalField_CarryTheirOwnCountAndRoundTrip(bool withField, int clear, int parity)
    {
        // Arrange
        var row = new OptionalRow { A = 1, B = 2, H = withField ? (ushort)3 : null, S = withField ? (byte)4 : null };
        var sent = BinaryPacker.Pack(Optional, row);
        var damaged = (byte[])sent.Clone();
        EccFixture.Corrupt(damaged, parity / 2, new Random(9));
        OptionalRow? intactRow = null;
        OptionalRow? repairedRow = null;

        // Act
        var intactError = BinaryPacker.Unpack(sent, 0, out var intactCount, Optional.On(v => intactRow = v));
        var repairedError = BinaryPacker.Unpack(damaged, parity / 2, out var repairedCount, Optional.On(v => repairedRow = v));

        // Assert
        Assert.Equal(clear + parity, sent.Length);
        Assert.Null(intactError);
        Assert.Null(repairedError);
        Assert.Equal((0, parity / 2), (intactCount, repairedCount));
        foreach (var got in new[] { intactRow, repairedRow })
            Assert.Equal((1u, 2u, row.H, row.S), (got!.A, got.B, got.H, got.S));
    }

    [Theory]
    [InlineData("pack bin ecc 0123456789")]
    [InlineData("Олександр, диспетчер")]
    [InlineData("gps_fix 48.46")]
    public void Unpack_OneWrongByteAnywhereInAMessageWithAString_ReturnsTheOriginalString(string text)
    {
        // Arrange
        var sent = BinaryPacker.Pack(Note, new NoteRow { Text = text, N = 200 });
        var wrong = 0;

        // Act
        for (var place = 0; place < sent.Length; place++)
        {
            var message = (byte[])sent.Clone();
            message[place] ^= 0x5A;
            NoteRow? got = null;
            var error = BinaryPacker.Unpack(message, 1, out var repaired, Note.On(v => got = v));
            if (error is not null || repaired != 1 || got is null || got.Text != text || got.N != 200)
                wrong++;
        }

        // Assert
        Assert.Equal(0, wrong);
    }

    [Fact]
    public void Dispatch_AHandlerOf25PercentWithAHandlerOfCount25_IsRefusedTellingThePercentage()
    {
        // Arrange
        var called = false;
        var percent = EccFixture.Positions(0x40).WithParityPercent(25).On(_ => called = true);
        var counted = EccFixture.Positions(0x41).WithParity(25).On(_ => called = true);

        // Act
        var percentFirst = Assert.Throws<ArgumentException>(() => BinaryPacker.Unpack(new byte[20], 0, out _, percent, counted));
        var countFirst = Assert.Throws<ArgumentException>(() => BinaryPacker.Unpack(new byte[20], 0, out _, counted, percent));

        // Assert
        Assert.False(called);
        Assert.Contains("25 percent and 25 parity bytes", percentFirst.Message, StringComparison.Ordinal);
        Assert.Contains("25 parity bytes and 25 percent", countFirst.Message, StringComparison.Ordinal);
    }
}
