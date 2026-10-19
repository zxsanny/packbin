using Packbin;
using Xunit.Abstractions;

namespace Packbin.Tests;

// AZ-2722 (F59): a repair allocates a few arrays of n + 1 bytes once per call, not a locator copy at every step.
public sealed class EccRepairAllocationTests(ITestOutputHelper output)
{
    [Fact]
    public void Repair_WorstCase254Bytes32Parity16Errors_RepairsAndAllocatesLittleBeyondTheWord()
    {
        // Arrange
        const int parity = 32;
        const int limit = 16;
        var scheme = EccFixture.Blob(254 - parity).WithParity(parity);
        var row = EccFixture.BlobOf(254 - parity);
        new Random(59).NextBytes(row.Data);
        var clean = BinaryPacker.Pack(scheme, row);
        var damaged = (byte[])clean.Clone();
        EccFixture.Corrupt(damaged, limit, new Random(59));
        Ecc.Repair(damaged, parity, limit, out _, out _);

        // Act
        var before = GC.GetAllocatedBytesForCurrentThread();
        var error = Ecc.Repair(damaged, parity, limit, out var word, out var repaired);
        var allocated = GC.GetAllocatedBytesForCurrentThread() - before;

        // Assert (the result word itself is 254 bytes plus its header)
        output.WriteLine($"AZ-2722 F59: {allocated} bytes allocated for one worst-case repair of {clean.Length} bytes");
        Assert.Null(error);
        Assert.Equal(limit, repaired);
        Assert.Equal(clean, word);
        Assert.Equal(254, clean.Length);
        Assert.True(allocated - (word.Length + 24) < 1536, $"allocated {allocated} bytes");
    }
}
