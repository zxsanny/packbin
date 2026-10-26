using Packbin;

namespace Packbin.Tests;

// AZ-2682: message ECC around a compact-text field (EC-11). The EC-10 session tests went with the stream session (ADR-009).
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
