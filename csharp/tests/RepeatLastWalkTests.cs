using System.Diagnostics;
using Packbin;
using Xunit.Abstractions;

namespace Packbin.Tests;

// AZ-4259 (F79 of the loop 113 audit): while a repeat was open the walk asked for the first writer under a container
// again at every level, so a chain of nested whens cost O(depth squared). It keeps the first writer per field now.
// OldRoundScopes is the walk as it was, kept to compare decisions and texts.
[Collection("Timing")]
public class RepeatLastWalkTests(ITestOutputHelper output)
{
    private sealed class Row
    {
        public byte K { get; set; }
        public byte V { get; set; }
        public byte[] Z { get; set; } = [];
        public bool? G { get; set; }
        public List<Row> Items { get; set; } = [];
        public Dictionary<string, Row> D { get; set; } = [];
    }

    private static void OnBigStack(Action action)
    {
        Exception? failure = null;
        var thread = new Thread(() =>
        {
            try
            {
                action();
            }
            catch (Exception e)
            {
                failure = e;
            }
        }, 256 * 1024 * 1024);
        thread.Start();
        thread.Join();
        if (failure is not null)
            throw new InvalidOperationException("the walk failed on its own thread", failure);
    }

    // u8 k; repeat { u8 v }; then depth nested whens around an empty when: nothing after the repeat can write a byte, so
    // the scheme builds, and every level of the chain asks for its first writer.
    private static Field[] ChainAfterRepeat(int depth)
    {
        var inner = Field.When(2, Condition.Eq(0, 1));
        for (var i = 0; i < depth; i++)
            inner = Field.When(2, Condition.Eq(0, 1), inner);
        return [Field.U8<Row>(0, x => x.K), Field.Repeat(1, Field.U8<Row>(1, x => x.V)), inner];
    }

    private static Field[] SiblingsAfterRepeat(int width)
    {
        var fields = new List<Field> { Field.U8<Row>(0, x => x.K), Field.Repeat(1, Field.U8<Row>(1, x => x.V)) };
        for (var i = 0; i < width; i++)
            fields.Add(Field.When(2, Condition.Eq(0, 1)));
        return [.. fields];
    }

    // The walk of four times the size of the shape in best of five, against a load-aware bound (the old walk took 1.3 s on
    // the 16,000 chain); the scheme of the shape's own size builds.
    [Theory]
    [InlineData("a chain of nested whens", 4_000)]
    [InlineData("sibling whens that write nothing", 16_000)]
    public void Validate_ShapeAfterARepeat_WalksInTimeLinearInItsSize(string shape, int size)
    {
        // Arrange
        Func<int, Field[]> build = shape.StartsWith("a chain", StringComparison.Ordinal) ? ChainAfterRepeat : SiblingsAfterRepeat;
        var large = build(4 * size);
        var limit = Timing.Bound(0.040);
        var best = double.MaxValue;

        // Act
        OnBigStack(() =>
        {
            Assert.NotNull(new Scheme<Row>(1, build(size)));
            for (var run = 0; run < 5; run++)
            {
                var watch = Stopwatch.StartNew();
                RoundScopes.Validate(large);
                best = Math.Min(best, watch.Elapsed.TotalSeconds);
            }
        });

        // Assert
        output.WriteLine($"{shape}, {4 * size}: {best * 1000:F2} ms");
        limit.AssertWithin(best, $"{shape}, {4 * size}");
    }

    // A random tree of the fields the walk looks at, kept to shapes the nesting and body rules let through, so that the
    // repeat-last rule decides: a round holds no other round and starts with a member, an element starts outside a round.
    private sealed class RandomFields(Random rng)
    {
        private int _ids;

        public Field[] Fields(int depth, bool inRound, int minimum = 0)
        {
            var count = Math.Max(minimum, rng.Next(4));
            var fields = new List<Field>();
            if (inRound)
                fields.Add(Field.U8<Row>(NextId(), x => x.V));
            for (var i = 0; i < count; i++)
                fields.Add(One(depth, inRound));
            return [.. fields];
        }

        private int NextId() => ++_ids;

        private Field One(int depth, bool inRound)
        {
            var id = NextId();
            var pick = depth == 0 ? rng.Next(5) : rng.Next(15);
            switch (pick)
            {
                case 0:
                    return Field.Bool<Row>(id, x => x.G);
                case 1:
                    return Field.Bytes<Row>(id, x => x.Z, 0);
                case 2:
                    return Field.Bytes<Row>(id, x => x.Z, 1);
                case 3:
                    return Field.U8<Row>(id, x => x.V);
                case 4:
                    return Field.FlagByte();
                case 5:
                case 6:
                    return Field.When(id, Condition.Eq(0, 1), Fields(depth - 1, inRound));
                case 7:
                    return Field.Group(id, (Row x) => x.G, Fields(depth - 1, inRound, 1));
                case 8:
                    return Field.Flags(id, Fields(depth - 1, inRound));
                case 9:
                    return Field.FlagByte().Bit(One(depth - 1, inRound));
                case 10:
                case 11:
                    return inRound ? Field.U8<Row>(id, x => x.V) : Field.Repeat(id, Fields(depth - 1, true, 1));
                case 12:
                    return inRound ? Field.U8<Row>(id, x => x.V) : Field.Times(id, 0, Fields(depth - 1, true, 1));
                case 13:
                    return Field.List<Row, Row>(x => x.Items, Fields(depth - 1, false, 1));
                default:
                    return Field.Dict<Row, Row>(x => x.D, Fields(depth - 1, false, 1));
            }
        }
    }

    private static string Outcome(Action validate) =>
        Record.Exception(validate) is { } error ? $"{error.GetType().Name}: {error.Message}" : "built";

    [Fact]
    public void Validate_RandomTrees_DecidesAndWordsAsTheOldWalkDid()
    {
        // Arrange
        var generator = new RandomFields(new Random(4259));
        var refusedByRule = 0;
        var built = 0;

        for (var i = 0; i < 3_000; i++)
        {
            Field[] tree = generator.Fields(4, inRound: false);

            // Act
            var old = Outcome(() => OldRoundScopes.Validate(tree));
            var current = Outcome(() => RoundScopes.Validate(tree));

            // Assert
            Assert.True(old == current, $"tree {i}: old walk {old}, new walk {current}");
            if (old == "built")
                built++;
            else if (old.Contains("follows it", StringComparison.Ordinal) || old.Contains("inside a list or dict element", StringComparison.Ordinal))
                refusedByRule++;
        }
        Assert.True(refusedByRule >= 150 && built >= 150, $"the trees must reach both outcomes: {refusedByRule} refused by the rule, {built} built");
    }
}
