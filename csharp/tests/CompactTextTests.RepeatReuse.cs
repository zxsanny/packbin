using System.Text;
using Packbin;

namespace Packbin.Tests;

public partial class CompactTextTests
{
    // AZ-2815 (AC-C3, AC-C4): a pack call reuses the field of the text it wrote last, and only when the next text is equal.
    public sealed class RepeatedTextReuse
    {
        private const int Rounds = 200;

        private static readonly Scheme<RoundRow> TextRounds = new(1,
            Field.U8<RoundRow>(0, x => x.N),
            Field.Times(1, 0, Field.Utf8<RoundRow>(1, x => x.S)));

        public static TheoryData<string> Plans =>
            ["change-at-100", "alternating", "last-character-only", "compact-then-raw", "text-then-empty-then-text"];

        [Theory]
        [MemberData(nameof(Plans))]
        public void Ac3_RoundsOfChangingTexts_PackToTheOneByOneEncoding(string plan)
        {
            // Arrange
            var texts = TextsOf(plan);

            // Act
            var raw = Pack(texts);

            // Assert
            Assert.Equal(Expected(texts), Hex(raw));
            Assert.Equal(texts, Unpacked(raw));
        }

        [Fact]
        public void Ac4_TwoCallsInARow_DoNotShareTheLastText()
        {
            // Arrange
            var first = Enumerable.Repeat(Compact(1000), Rounds).ToList();
            var second = Enumerable.Repeat(Compact(1000) + "!", Rounds).ToList();

            // Act
            var rawFirst = Pack(first);
            var rawSecond = Pack(second);
            var rawFirstAgain = Pack(first);

            // Assert
            Assert.Equal(Expected(first), Hex(rawFirst));
            Assert.Equal(Expected(second), Hex(rawSecond));
            Assert.Equal(Hex(rawFirst), Hex(rawFirstAgain));
        }

        private static List<string> TextsOf(string plan)
        {
            var a = Compact(2000);
            var b = a[..^1] + "?";
            return plan switch
            {
                "change-at-100" => Enumerable.Range(0, Rounds).Select(i => i < 100 ? a : b).ToList(),
                "alternating" => Enumerable.Range(0, Rounds).Select(i => i % 2 == 0 ? a : b).ToList(),
                "last-character-only" => Enumerable.Range(0, Rounds).Select(i => i / 7 % 2 == 0 ? new string('q', 1000) : new string('q', 999) + "r").ToList(),
                "compact-then-raw" => Enumerable.Range(0, Rounds).Select(i => i < 100 ? a : Raw(700)).ToList(),
                "text-then-empty-then-text" => Enumerable.Range(0, Rounds).Select(i => i % 3 == 1 ? "" : a).ToList(),
                _ => throw new ArgumentOutOfRangeException(nameof(plan), plan, null),
            };
        }

        private static string Compact(int length) =>
            string.Concat(Enumerable.Repeat("hello world ", length / 12 + 1))[..length];

        private static string Raw(int length) =>
            string.Concat(Enumerable.Repeat("Ж漢ÿ", length))[..length];

        private static byte[] Pack(List<string> texts) =>
            BinaryPacker.Pack(TextRounds, new Dictionary<string, object?> { ["N"] = (byte)texts.Count, ["S"] = texts.Cast<object?>().ToArray() });

        private static List<string> Unpacked(byte[] raw)
        {
            var read = BinaryPacker.Read(TextRounds, raw);
            Assert.Null(read.Error);
            return ((System.Collections.IEnumerable)read.Values["S"]!).Cast<string>().ToList();
        }

        // The packet every round's text gives when it is encoded on its own: the header, the count, one field per round.
        private static string Expected(List<string> texts) =>
            "01" + Convert.ToHexString([(byte)texts.Count]).ToLowerInvariant()
                 + string.Concat(texts.Select(t => Convert.ToHexString(TextEncoder.Encode(Encoding.UTF8.GetBytes(t))).ToLowerInvariant()));
    }
}
