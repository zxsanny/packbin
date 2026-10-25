namespace Packbin.Tests;

public class FrameVectorTests
{
    [Fact]
    public void Ac1_EveryRowOfTheFrameFixtureMatches()
    {
        var rows = FrameVectors.Load(FrameVectors.FixturePath());

        var problems = FrameVectors.Mismatches(rows);

        Assert.Empty(problems);
        Assert.True(rows.Count >= 157, $"only {rows.Count} rows");
        foreach (var op in new[] { "keys", "seal", "open", "mac", "replay" })
            Assert.Contains(rows, r => r.Op == op);
    }

    [Theory]
    [InlineData("E1.seal")]
    [InlineData("E2.seal")]
    [InlineData("E3.seal")]
    [InlineData("E3.seal16")]
    [InlineData("E4.mac")]
    [InlineData("E5.mac")]
    [InlineData("E4.keys")]
    public void Ac1_TheWorkedExamplesAreInTheFileAndMatch(string caseName)
    {
        var row = FrameVectors.Load(FrameVectors.FixturePath()).Single(r => r.Case == caseName);

        var problems = FrameVectors.Mismatches([row]);

        Assert.Empty(problems);
    }

    [Fact]
    public void Ac1_TheLargestEpochWorksAndTheNextOneIsRefused()
    {
        var rows = FrameVectors.Load(FrameVectors.FixturePath());

        var maxEpoch = rows.Where(r => r.Op == "keys" && r["epoch"] == "16777215").ToList();
        var refused = rows.Single(r => r.Case == "refuse.seal.epoch1000000");

        Assert.Equal(3, maxEpoch.Count);
        Assert.Empty(FrameVectors.Mismatches(maxEpoch));
        Assert.Equal("BadValue", refused["result"]);
        Assert.Equal("BadValue", FrameVectors.Run(refused)["result"]);
    }

    [Theory]
    [InlineData("seal", "body")]
    [InlineData("open", "plain")]
    [InlineData("mac", "tag")]
    [InlineData("keys", "k_enc")]
    [InlineData("replay", "states")]
    public void Ac3_AFixtureCopyWithOneExpectedByteChangedFailsAndNamesTheRow(string op, string field)
    {
        var path = CorruptedCopy(FrameVectors.FixturePath(), line => line.StartsWith($"op={op} ", StringComparison.Ordinal) && line.Contains($" {field}="), $" {field}=");
        try
        {
            var name = FrameVectors.Load(path).First(r => r.Op == op && r.Has(field)).Case;

            var problems = FrameVectors.Mismatches(FrameVectors.Load(path));

            Assert.Single(problems);
            Assert.StartsWith(name + " " + field, problems[0]);
        }
        finally
        {
            File.Delete(path);
        }
    }

    // A temp copy where the first hex digit after `marker` on the first matching line is changed.
    internal static string CorruptedCopy(string source, Func<string, bool> pick, string marker)
    {
        var lines = File.ReadAllLines(source);
        var index = Array.FindIndex(lines, l => l.Length > 0 && l[0] != '#' && pick(l));
        Assert.True(index >= 0, "no row to corrupt");
        var at = lines[index].IndexOf(marker, StringComparison.Ordinal) + marker.Length;
        var digit = lines[index][at];
        lines[index] = lines[index].Substring(0, at) + (digit == '0' ? '1' : '0') + lines[index].Substring(at + 1);
        var path = Path.Combine(Path.GetTempPath(), "packbin-" + Guid.NewGuid().ToString("N") + ".txt");
        File.WriteAllLines(path, lines);
        return path;
    }
}
