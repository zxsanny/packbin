namespace Packbin.Tests;

public class CryptoVectorTests
{
    [Fact]
    public void Ac2_EveryPrimitiveRowMatches()
    {
        var rows = CryptoVectors.Load(CryptoVectors.FixturePath());

        var problems = CryptoVectors.Mismatches(rows);

        Assert.Empty(problems);
        Assert.Equal(27, rows.Count); // the file has 39 lines: 27 rows and 12 comment lines
        foreach (var primitive in new[] { "sha256", "hmac256", "hkdf256", "chacha-block", "chacha-xor" })
            Assert.Contains(rows, r => r.Primitive == primitive);
    }

    [Theory]
    [InlineData("sha256", "digest")]
    [InlineData("hmac256", "mac")]
    [InlineData("hkdf256", "okm")]
    [InlineData("chacha-block", "block")]
    [InlineData("chacha-xor", "cipher")]
    public void Ac3_AFixtureCopyWithOneExpectedByteChangedFailsAndNamesTheRow(string primitive, string field)
    {
        var path = FrameVectorTests.CorruptedCopy(CryptoVectors.FixturePath(), l => l.StartsWith(primitive + " ", StringComparison.Ordinal), $" {field}=");
        try
        {
            var rows = CryptoVectors.Load(path);
            var changed = rows.First(r => r.Primitive == primitive);

            var problems = CryptoVectors.Mismatches(rows);

            Assert.Single(problems);
            Assert.StartsWith($"{primitive} {changed.Id} ", problems[0]);
        }
        finally
        {
            File.Delete(path);
        }
    }
}
