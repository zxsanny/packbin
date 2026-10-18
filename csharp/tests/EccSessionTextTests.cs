using Packbin;

namespace Packbin.Tests;

// AZ-2682: message ECC under an open session (EC-10) and around a compact-text field (EC-11).
public class EccSessionTextTests
{
    private sealed class NoteRow
    {
        public ushort Id { get; set; }
        public string Name { get; set; } = "";
        public byte After { get; set; }
    }

    private static readonly Scheme<NoteRow> Note = new(0x30,
        Field.U16<NoteRow>(0, x => x.Id),
        Field.Utf8<NoteRow>(1, x => x.Name),
        Field.U8<NoteRow>(2, x => x.After));

    private static (PackSession Opener, PackSession Waiter) OpenPair()
    {
        var seed = new byte[32];
        for (var i = 0; i < seed.Length; i++)
            seed[i] = (byte)(i + 1);
        var opener = PackSession.Load(seed)!;
        var waiter = PackSession.Load(seed)!;
        var nonce = new byte[16];
        nonce[0] = 1;
        opener.Start(nonce);
        Assert.True(waiter.Join(nonce));
        return (opener, waiter);
    }

    // ---- EC-10: sessions

    [Fact]
    public void SessionPack_WithParity_IsThePaddedClearBytesPlusTheParity()
    {
        // Arrange
        var (plainOpener, _) = OpenPair();
        var (opener, _) = OpenPair();
        var plainScheme = EccFixture.Position;
        var scheme = plainScheme.WithParity(4);

        // Act
        var padded = plainOpener.Pack(plainScheme, EccFixture.Row)!;
        var payload = opener.Pack(scheme, EccFixture.Row)!;

        // Assert
        Assert.Equal(13, padded.Length);
        Assert.Equal(17, payload.Length);
        Assert.Equal(Ecc.Protect(padded, 4), payload);
    }

    [Fact]
    public void SessionUnpack_TwoWrongBytesUnderNFour_RecoversTheRowInSeededCases()
    {
        // Arrange
        var scheme = EccFixture.Position.WithParity(4);
        var (opener, waiter) = OpenPair();
        var random = new Random(10);
        var failures = 0;

        // Act
        for (var i = 0; i < 300; i++)
        {
            var payload = opener.Pack(scheme, EccFixture.Row)!;
            EccFixture.Corrupt(payload, 2, random);
            EccFixture.PositionRow? got = null;
            var error = waiter.Unpack(payload, 2, out var repaired, scheme.On(v => got = v));
            if (error is not null || !EccFixture.IsRow(got) || repaired != 2)
                failures++;
        }

        // Assert
        Assert.Equal(0, failures);
    }

    [Fact]
    public void SessionUnpack_ThreeWrongBytesUnderLimitTwo_IsRefusedAndTheNextPayloadStillReads()
    {
        // Arrange
        var scheme = EccFixture.Position.WithParity(4);
        var (opener, waiter) = OpenPair();
        var random = new Random(11);
        var damaged = opener.Pack(scheme, EccFixture.Row)!;
        var next = opener.Pack(scheme, EccFixture.Row)!;
        EccFixture.Corrupt(damaged, 3, random);
        EccFixture.PositionRow? got = null;

        // Act
        // Three wrong bytes under t = 2 can in rare cases be repaired to another message, so the seed is fixed.
        var refused = waiter.Unpack(damaged, 2, out _, scheme.On(v => got = v));
        var firstRow = got;
        var error = waiter.Unpack(next, 2, out var repaired, scheme.On(v => got = v));

        // Assert
        Assert.IsType<Uncorrectable>(refused);
        Assert.Null(firstRow);
        Assert.Null(error);
        Assert.Equal(0, repaired);
        Assert.True(EccFixture.IsRow(got));
    }

    [Fact]
    public void SessionUnpack_AShortOrLongPayload_AdvancesTheReceiveIndexLikeAnyPayload()
    {
        // Arrange
        var scheme = EccFixture.Position.WithParity(4);
        var (opener, waiter) = OpenPair();
        var first = opener.Pack(scheme, EccFixture.Row)!;
        var second = opener.Pack(scheme, EccFixture.Row)!;
        EccFixture.PositionRow? got = null;

        // Act
        var shortError = waiter.Unpack(first[..3], 0, out _, scheme.On(v => got = v));
        var error = waiter.Unpack(second, 0, out _, scheme.On(v => got = v));

        // Assert
        Assert.IsType<ShortPacket>(shortError);
        Assert.Null(error);
        Assert.True(EccFixture.IsRow(got));
    }

    [Fact]
    public void SessionPack_WithoutParity_KeepsThePayloadTheSameLengthAsClearPack()
    {
        // Arrange
        var (opener, waiter) = OpenPair();
        EccFixture.PositionRow? got = null;

        // Act
        var payload = opener.Pack(EccFixture.Position, EccFixture.Row)!;
        var error = waiter.Unpack(payload, EccFixture.Position.On(v => got = v));

        // Assert
        Assert.Equal(13, payload.Length);
        Assert.Null(error);
        Assert.True(EccFixture.IsRow(got));
    }

    [Fact]
    public void SessionPack_AClearMessageAboveTheLimit_IsRefusedAndTakesNoCounter()
    {
        // Arrange
        var (opener, waiter) = OpenPair();
        var tooBig = EccFixture.Blob(251).WithParity(4);
        var scheme = EccFixture.Position.WithParity(4);
        EccFixture.PositionRow? got = null;

        // Act
        var refused = Assert.Throws<ArgumentException>(() => opener.Pack(tooBig, EccFixture.BlobOf(251)));
        var payload = opener.Pack(scheme, EccFixture.Row)!;
        var error = waiter.Unpack(payload, 0, out _, scheme.On(v => got = v));

        // Assert
        Assert.Contains("251 bytes", refused.Message, StringComparison.Ordinal);
        Assert.Null(error);
        Assert.True(EccFixture.IsRow(got));
    }

    // ---- EC-11: compact text

    private static NoteRow Sample(string name) => new() { Id = 513, Name = name, After = 77 };

    public static IEnumerable<object[]> Names() =>
    [
        ["Привіт, Україно! 123"],
        ["Hello, packbin."],
        ["Съешь ещё этих мягких булок"],
        ["日本語 mixed text"],
        [""],
    ];

    [Theory]
    [MemberData(nameof(Names))]
    public void Unpack_AStringInAProtectedMessageWithTwoWrongBytesAnywhere_ReturnsTheOriginalString(string name)
    {
        // Arrange
        var scheme = Note.WithParity(4);
        var clean = BinaryPacker.Pack(scheme, Sample(name));
        var random = new Random(name.Length + 11);
        var differing = 0;
        var refused = 0;

        // Act
        for (var i = 0; i < 600; i++)
        {
            var message = (byte[])clean.Clone();
            EccFixture.Corrupt(message, 1 + i % 2, random);
            NoteRow? got = null;
            var error = BinaryPacker.Unpack(message, 2, out _, scheme.On(v => got = v));
            if (error is not null)
                refused++;
            else if (got!.Name != name || got.Id != 513 || got.After != 77)
                differing++;
        }

        // Assert
        Assert.Equal(0, refused);
        Assert.Equal(0, differing);
    }

    [Fact]
    public void Unpack_EveryPairOfFlippedBytesInAShortProtectedString_ReturnsTheOriginalString()
    {
        // Arrange
        var scheme = Note.WithParity(4);
        var clean = BinaryPacker.Pack(scheme, Sample("Привіт"));
        var differing = 0;

        // Act
        for (var a = 0; a < clean.Length; a++)
        {
            for (var b = a + 1; b < clean.Length; b++)
            {
                var message = (byte[])clean.Clone();
                message[a] ^= 0xff;
                message[b] ^= 0x01;
                NoteRow? got = null;
                var error = BinaryPacker.Unpack(message, 2, out var repaired, scheme.On(v => got = v));
                if (error is not null || got!.Name != "Привіт" || repaired != 2)
                    differing++;
            }
        }

        // Assert
        Assert.Equal(0, differing);
    }

    [Fact]
    public void Unpack_AStringInAProtectedMessageDetectOnly_NeverReturnsADifferentString()
    {
        // Arrange
        var scheme = Note.WithParity(4);
        var clean = BinaryPacker.Pack(scheme, Sample("Привіт, Україно! 123"));
        var random = new Random(44);
        var differing = 0;

        // Act
        for (var i = 0; i < 5000; i++)
        {
            var message = (byte[])clean.Clone();
            EccFixture.Corrupt(message, random.Next(1, 5), random);
            NoteRow? got = null;
            var error = BinaryPacker.Unpack(message, 0, out _, scheme.On(v => got = v));
            if (error is null || got is not null)
                differing++;
        }

        // Assert
        Assert.Equal(0, differing);
    }
}
