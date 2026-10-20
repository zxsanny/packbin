using System.Diagnostics;
using Packbin;
using Xunit.Abstractions;

namespace Packbin.Tests;

public partial class CompactTextTests
{
    // AZ-2735 (CS-S3, TW-1): the tables are constants and the codec keeps no shared mutable state.
    [Collection("Timing")]
    public sealed class Concurrency(ITestOutputHelper output)
    {
        private const int Workers = 8;
        private const int RandomTextsPerWorker = 200;
        private const int Rounds = 5;
        private static int _active;

        // A text and the bytes its pack must give: a vector row's reference, or the single-threaded pack of a random text.
        private sealed record Item(string Label, string Text, string Expected);

        private sealed class Outcome
        {
            public int Packed;
            public int Mismatches;
            public int Errors;
            public int Peak;
            public readonly List<string> Problems = [];
        }

        [Fact]
        public void Ac1_EightWorkers_PackAndUnpackDifferentTexts_GetTheReferenceBytesAndTheirOwnText()
        {
            // Arrange
            var vectors = TextVectors.Of("enc")
                .Select(row => new Item(row.Id, TextVectors.TextOf(row.Args[0]), "01" + row.Args[1]))
                .ToList();
            var plans = Enumerable.Range(0, Workers).Select(worker => PlanOf(worker, vectors)).ToList();
            var outcomes = plans.Select(_ => new Outcome()).ToList();
            var start = new Barrier(Workers);
            Interlocked.Exchange(ref _active, 0);
            var limit = Timing.Bound(1.0);
            var threads = Enumerable.Range(0, Workers)
                .Select(worker => new Thread(() => Work(plans[worker], start, outcomes[worker])) { IsBackground = true })
                .ToList();

            // Act
            var watch = Stopwatch.StartNew();
            threads.ForEach(thread => thread.Start());
            var unfinished = threads.Select((thread, worker) => (thread, worker))
                .Where(x => !x.thread.Join(TimeSpan.FromSeconds(Math.Max(0.0, limit.Seconds - watch.Elapsed.TotalSeconds))))
                .Select(x => x.worker)
                .ToList();
            watch.Stop();

            // Assert
            var packed = outcomes.Sum(o => o.Packed);
            var problems = outcomes.SelectMany(o => o.Problems).ToList();
            output.WriteLine($"AZ-2735 AC-1: {Workers} workers, {packed} texts, {watch.Elapsed.TotalMilliseconds:F0} ms, load factor {limit.Factor:F2}, {outcomes.Sum(o => o.Mismatches)} mismatches, {outcomes.Sum(o => o.Errors)} errors, up to {outcomes.Max(o => o.Peak)} workers at once");
            Assert.True(unfinished.Count == 0, $"workers {string.Join(", ", unfinished)} did not finish: {limit.Describe(watch.Elapsed.TotalSeconds, "eight workers")}");
            Assert.Empty(problems.Take(5));
            Assert.Equal(0, outcomes.Sum(o => o.Mismatches));
            Assert.Equal(0, outcomes.Sum(o => o.Errors));
            Assert.All(plans, plan => Assert.True(plan.Select(item => item.Text).Distinct().Count() >= 200));
            Assert.Equal(plans.Sum(plan => plan.Count) * Rounds, packed);
            limit.AssertWithin(watch.Elapsed, "eight workers packing and unpacking different texts");
        }

        // The vector rows from a different place for each worker, a random text between every two rows. The expected bytes of the
        // random texts come from a single-threaded pack here, which also warms the codec before the workers start.
        private static List<Item> PlanOf(int worker, List<Item> vectors)
        {
            var rng = new Random(2735 + worker);
            var plan = new List<Item>();
            var random = Enumerable.Range(0, RandomTextsPerWorker).Select(n =>
            {
                var text = RandomText(rng, 120);
                return new Item($"worker {worker} random {n}", text, Hex(PackName(text)));
            }).ToList();
            var shift = worker * (vectors.Count / Workers);
            for (var i = 0; i < vectors.Count; i++)
            {
                plan.Add(vectors[(i + shift) % vectors.Count]);
                if (i < random.Count)
                    plan.Add(random[i]);
            }
            plan.AddRange(random.Skip(vectors.Count));
            return plan;
        }

        // Starts with the other workers, then packs each text (typed and by dictionary in turn) and unpacks it, in several rounds.
        private static void Work(List<Item> plan, Barrier start, Outcome outcome)
        {
            if (!start.SignalAndWait(TimeSpan.FromSeconds(30)))
            {
                outcome.Errors++;
                outcome.Problems.Add("the workers did not start together");
                return;
            }
            NameRow? got = null;
            var handler = Single.On(row => got = row);
            Interlocked.Increment(ref _active);
            for (var round = 0; round < Rounds; round++)
            {
                for (var i = 0; i < plan.Count; i++)
                {
                    var item = plan[i];
                    outcome.Peak = Math.Max(outcome.Peak, Volatile.Read(ref _active));
                    try
                    {
                        var raw = (i + round) % 2 == 0
                            ? BinaryPacker.Pack(Single, new NameRow { Name = item.Text })
                            : PackName(item.Text);
                        got = null;
                        var error = BinaryPacker.Unpack(raw, handler);
                        outcome.Packed++;
                        if (Hex(raw) != item.Expected || error is not null || got is null || got.Name != item.Text)
                        {
                            outcome.Mismatches++;
                            outcome.Problems.Add($"{item.Label}: packed {Hex(raw)[..Math.Min(40, raw.Length * 2)]}, expected {item.Expected[..Math.Min(40, item.Expected.Length)]}, error {error?.GetType().Name ?? "none"}");
                        }
                    }
                    catch (Exception ex)
                    {
                        outcome.Errors++;
                        outcome.Problems.Add($"{item.Label}: {ex.GetType().Name}: {ex.Message}");
                    }
                }
            }
            Interlocked.Decrement(ref _active);
        }
    }
}
