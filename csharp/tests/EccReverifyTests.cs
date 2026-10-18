using Packbin;

namespace Packbin.Tests;

// AZ-2695: the check that repaired bytes are a code word. Each received word is one where the locator and the error
// values are computed and applied, yet the result is not a code word (found by a seeded search); only the re-verify
// refuses it.
public class EccReverifyTests
{
    [Theory]
    [InlineData(4, 1, "80332535593733fca1739e2267")]
    [InlineData(4, 1, "2b8db83aa9aa0591c26c")]
    [InlineData(4, 2, "a442946cbcc2c6ed20a7b2")]
    [InlineData(4, 2, "e63fe2b98f6e7b39")]
    [InlineData(6, 2, "69b32100cbe1bb78fbac03493cfe025039a7")]
    [InlineData(6, 3, "09ddf2505e56add4bfdf")]
    [InlineData(8, 3, "0c2313f4e775b4b5a60e5edbebb7c8cab2db")]
    public void Repair_ReceivedWordWhoseRepairIsNotACodeWord_IsRefusedAsUncorrectable(int parity, int limit, string hex)
    {
        // Arrange
        var received = EccFixture.Bytes(hex);

        // Act
        var error = Ecc.Repair(received, parity, limit, out _, out var repaired);

        // Assert
        Assert.IsType<Uncorrectable>(error);
        Assert.Equal(0, repaired);
    }
}
