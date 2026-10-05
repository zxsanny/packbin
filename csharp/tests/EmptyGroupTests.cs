using Packbin;

namespace Packbin.Tests;

// An empty group is a presence bit, so only one bound to a bool or bool? member can ever set it. Any other empty group
// fails construction wherever it stands.
public class EmptyGroupTests
{
    public sealed class In
    {
        public byte? V { get; set; }
    }

    public sealed class Q
    {
        public In? Nested { get; set; }
        public byte? Count { get; set; }
        public bool Flag { get; set; }
    }

    private static string Hex(byte[] raw) => Convert.ToHexString(raw).ToLowerInvariant();

    public static TheoryData<string, Func<Scheme<Q>>> EmptyNestedRow() => new()
    {
        { "top level", () => new Scheme<Q>(1, Field.Group((Q x) => x.Nested)) },
        { "under Flags", () => new Scheme<Q>(1, Field.Flags(0, Field.Group((Q x) => x.Nested))) },
        {
            "under a FlagByte bit", () =>
            {
                var m = Field.FlagByte();
                return new Scheme<Q>(1, m, m.Bit(Field.Group((Q x) => x.Nested)));
            }
        },
    };

    [Theory]
    [MemberData(nameof(EmptyNestedRow))]
    public void Ac1_EmptyNestedRowGroup_FailsWithItsOwnMessage(string where, Func<Scheme<Q>> build)
    {
        // Act
        var ex = Assert.Throws<ArgumentException>(() => build());

        // Assert
        Assert.True(ex.Message.Contains("'Nested'", StringComparison.Ordinal), $"{where}: {ex.Message}");
        Assert.True(ex.Message.Contains("bool or bool? member", StringComparison.Ordinal), $"{where}: {ex.Message}");
        Assert.False(ex.Message.Contains("put it directly in Flags", StringComparison.Ordinal), $"{where}: {ex.Message}");
    }

    [Fact]
    public void Ac1_EmptyGroupOnANonBoolMember_FailsUnderFlags()
    {
        // Act
        var ex = Assert.Throws<ArgumentException>(() => new Scheme<Q>(1, Field.Flags(0, Field.Group(0, (Q x) => x.Count))));

        // Assert
        Assert.Contains("'Count'", ex.Message, StringComparison.Ordinal);
        Assert.Contains("bool or bool? member", ex.Message, StringComparison.Ordinal);
    }

    [Theory]
    [InlineData(true, "0101")]
    [InlineData(false, "0100")]
    public void Ac2_EmptyGroupOnAPlainBoolMember_StaysAPresenceBit(bool flag, string expected)
    {
        // Arrange
        var scheme = new Scheme<Q>(1, Field.Flags(0, Field.Group(0, (Q x) => x.Flag)));

        // Act
        var raw = BinaryPacker.Pack(scheme, new Q { Flag = flag });
        Q? got = null;
        var err = BinaryPacker.Unpack(raw, scheme.On(v => got = v));

        // Assert
        Assert.Equal(expected, Hex(raw));
        Assert.Null(err);
        Assert.Equal(flag, got!.Flag);
    }
}
