using System.Diagnostics;
using Packbin;
using Xunit.Abstractions;

namespace Packbin.Tests;

public partial class CompactTextTests
{
    private sealed class RepeatRow
    {
        public byte N { get; set; }
        public string S { get; set; } = "";
    }

    // u8 n; times(n) { utf8 s }: one string written in every round, as the Python and TypeScript HD-2 tests build it.
    private static readonly Scheme<RepeatRow> RepeatedText =
        new(1, Field.U8<RepeatRow>(0, x => x.N), Field.Times(1, 0, Field.Utf8<RepeatRow>(1, x => x.S)));

    // AZ-2737 (CS-D7, TW-5): HD-2 of the Python and TypeScript suites for the C# pack walker.
    [Collection("Timing")]
    public sealed class RepeatedTextSpeed(ITestOutputHelper output)
    {
        private const int Rounds = 200;
        private const int Characters = 65_535;

        [Theory]
        [InlineData(true)]
        [InlineData(false)]
        public void Ac1_LoneText_65535CharactersIn200Rounds_PacksAndUnpacksWithinOneSecondNominal(bool typed)
        {
            // Arrange
            var text = new string('q', Characters);
            var warm = new RepeatRow { N = 2, S = "warm-up" };
            Unpacked(Pack(warm, typed));
            var row = new RepeatRow { N = Rounds, S = text };
            var limit = Timing.Bound(1.0);

            // Act
            var watch = Stopwatch.StartNew();
            var raw = Pack(row, typed);
            var packed = watch.Elapsed;
            var read = BinaryPacker.Read(RepeatedText, raw);
            watch.Stop();

            // Assert
            output.WriteLine($"AZ-2737 AC-1 ({(typed ? "typed" : "dictionary")}): {watch.Elapsed.TotalMilliseconds:F0} ms ({packed.TotalMilliseconds:F0} ms to pack), {raw.Length} bytes, load factor {limit.Factor:F2}");
            Assert.True(raw.Length > Rounds * Characters);
            Assert.Null(read.Error);
            var rounds = Assert.IsType<List<object?>>(read.Values["S"]);
            Assert.Equal(Rounds, rounds.Count);
            Assert.All(rounds, round => Assert.True(ReferenceEquals(round, rounds[0]) || (string)round! == text));
            limit.AssertWithin(watch.Elapsed, "one 65535-character string under 200 rounds, packed and unpacked");
        }

        private static byte[] Pack(RepeatRow row, bool typed) =>
            typed
                ? BinaryPacker.Pack(RepeatedText, row)
                : BinaryPacker.Pack(RepeatedText, new Dictionary<string, object?> { ["N"] = row.N, ["S"] = row.S });

        private static void Unpacked(byte[] raw)
        {
            var read = BinaryPacker.Read(RepeatedText, raw);
            Assert.Null(read.Error);
        }
    }
}
