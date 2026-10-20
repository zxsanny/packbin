using System.Runtime.ExceptionServices;
using System.Text;
using Packbin;

namespace Packbin.Tests;

public partial class CompactTextTests
{
    private static int[] Points(string text) => [.. text.EnumerateRunes().Select(r => r.Value)];

    private static int[] Codes(int from, int to) => [.. Enumerable.Range(from, to - from + 1)];

    // Code points by script, so a random run keeps to one script the way real text does. The heavy pools are listed twice.
    private static readonly int[][] RandomPools =
    [
        Points("абвгґдеєжзиіїйклмнопрстуфхцчшщьюя'"),
        Points("абвгґдеєжзиіїйклмнопрстуфхцчшщьюя'"),
        Points("АБВГҐДЕЄЖЗИІЇЙКЛМНОПРСТУФХЦЧШЩЬЮЯ"),
        Points("абвгдеёжзийклмнопрстуфхцчшщъыьэюя"),
        Points("абвгдеёжзийклмнопрстуфхцчшщъыьэюя"),
        Points("АБВГДЕЁЖЗИЙКЛМНОПРСТУФХЦЧШЩЪЫЬЭЮЯ"),
        Points("abcdefghijklmnopqrstuvwxyz'"),
        Points("abcdefghijklmnopqrstuvwxyz'"),
        Points("ABCDEFGHIJKLMNOPQRSTUVWXYZ"),
        Points("0123456789.,-: "),
        Points("0123456789.,-: "),
        Points(" 0123456789,.-:!?;()\"%/@+=*#&_$\n\t"),
        Points("éèêëàâäîïôöûüùçßżłńąęśćźñãõøåœæþðİıÿ"),
        Points("αβγδεζηθικλμνξοπρστυφχψωΑΒΓΔΩ"),
        Points("שלוםעולםمرحباالعالمनमस्ते世界สวัสดี"),
        Points("中文日本語한국어こんにちは"),
        Codes(0x1F300, 0x1F64F),
        [0x200D, 0xFE0F, 0x1F1E6, 0x1F1FA, 0x1F1E6, 0x2764, 0x1F468, 0x1F469, 0x1F467],
        Codes(0x0300, 0x036F),
        [0x0000, 0x0001, 0x001F, 0x007F, 0x0080, 0x009F, 0x00A0, 0xFEFF, 0xFFFD, 0xFFFE, 0xFFFF, 0xE000, 0x10FFFF, 0xD7FF, 0xE001],
    ];

    // A text of up to `limit` code points made of runs of 1 to 8 characters, each run from one pool.
    private static string RandomText(Random rng, int limit = 60)
    {
        var text = new StringBuilder();
        for (var left = rng.Next(limit); left > 0;)
        {
            var pool = RandomPools[rng.Next(RandomPools.Length)];
            for (var run = 1 + rng.Next(8); run > 0 && left > 0; run--, left--)
                text.Append(char.ConvertFromUtf32(pool[rng.Next(pool.Length)]));
        }
        return text.ToString();
    }

    // A text of exactly `bytes` UTF-8 bytes from one pool (or from every pool when `pool` is null); an ASCII tail pads the last bytes.
    private static string RandomTextOfBytes(Random rng, int bytes, int[]? pool)
    {
        var text = new StringBuilder();
        var used = 0;
        while (used < bytes)
        {
            var from = pool ?? RandomPools[rng.Next(RandomPools.Length)];
            var point = from[rng.Next(from.Length)];
            var size = new Rune(point).Utf8SequenceLength;
            if (used + size > bytes)
            {
                text.Append('a');
                used++;
                continue;
            }
            text.Append(char.ConvertFromUtf32(point));
            used += size;
        }
        return text.ToString();
    }

    // Runs the work on its own thread so a hang fails the test after the guard instead of blocking the suite.
    private static void RunGuarded(Action work, Timing.Limit guard, string what)
    {
        ExceptionDispatchInfo? thrown = null;
        var worker = new Thread(() =>
        {
            try
            {
                work();
            }
            catch (Exception ex)
            {
                thrown = ExceptionDispatchInfo.Capture(ex);
            }
        })
        {
            IsBackground = true,
        };
        worker.Start();
        if (!worker.Join(guard.Span))
            Assert.Fail($"{what} did not finish: {guard.Describe(guard.Seconds, "guard")}");
        thrown?.Throw();
    }

    private const int RandomStringCount = 3_000;

    // AZ-2736 (CS-A5, TW-2): the random-string round trip C# did not have.
    [Fact]
    public void Ac2_RandomUnicodeStrings_3000OfEveryScript_RoundTripThroughPackAndUnpack()
    {
        // Arrange
        var rng = new Random(2736);
        var texts = new List<string> { "" };
        for (var i = 0; i < RandomStringCount; i++)
            texts.Add(RandomText(rng, i % 10 == 0 ? 300 : 60));
        texts.Add(new string('a', 65_535));
        texts.Add(RandomTextOfBytes(rng, 65_535, Points("абвгґдеєжзиіїйклмнопрстуфхцчшщьюя ")));
        texts.Add(RandomTextOfBytes(rng, 65_535, Codes(0x4E00, 0x9FFF)));
        texts.Add(RandomTextOfBytes(rng, 65_535, Codes(0x1F300, 0x1F64F)));
        texts.Add(RandomTextOfBytes(rng, 65_535, null));
        var mismatches = new List<string>();
        var compact = 0;
        var guard = Timing.Bound(20.0);

        // Act
        RunGuarded(() =>
        {
            NameRow? got = null;
            var handler = Single.On(row => got = row);
            foreach (var text in texts)
            {
                var raw = PackName(text);
                got = null;
                var error = BinaryPacker.Unpack(raw, handler);
                var utf8 = Encoding.UTF8.GetByteCount(text);
                var rawField = (text.Length == 0 ? 1 : VarintLength(1 + utf8) + 1 + utf8);
                if (error is not null || got is null || got.Name != text)
                    mismatches.Add($"{Describe(text)}: error {error?.GetType().Name ?? "none"}");
                else if (raw.Length > 1 + rawField)
                    mismatches.Add($"{Describe(text)}: {raw.Length} bytes, more than the raw form of {1 + rawField}");
                else if (raw.Length < 1 + rawField)
                    compact++;
            }
        }, guard, "3000 random strings");

        // Assert
        output.WriteLine($"AZ-2736 AC-2: {texts.Count} strings, {compact} packed shorter than the raw form, {mismatches.Count} mismatches");
        Assert.Empty(mismatches.Take(5));
        Assert.True(texts.Count >= RandomStringCount);
        Assert.True(compact >= 300, $"only {compact} strings used the compact form");
        Assert.Equal(5, texts.Count(t => Encoding.UTF8.GetByteCount(t) == 65_535));
    }

    private static int VarintLength(int n) => n < 0x80 ? 1 : n < 0x4000 ? 2 : 3;

    private static string Describe(string text) =>
        text.Length <= 40 ? $"\"{text}\" ({Convert.ToHexString(Encoding.UTF8.GetBytes(text))})" : $"a text of {text.Length} characters";
}
