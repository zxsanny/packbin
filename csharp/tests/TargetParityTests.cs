using System.Runtime.Versioning;
using Packbin;

namespace Packbin.Tests;

// The suite runs twice: against the net10.0 build and, with -p:PackbinTarget=netstandard2.0, against the
// netstandard2.0 build. These pin the parts where the two builds use different code (Compat.cs).
public class TargetParityTests
{
    private sealed class NameRow
    {
        public string Name { get; set; } = "";
    }

    private static readonly Scheme<NameRow> Names = new(1, Field.Utf8<NameRow>(0, x => x.Name));

    [Fact]
    public void LoadedPackbinIsTheBuildUnderTest()
    {
        // Arrange
#if PACKBIN_NETSTANDARD2_0
        const string expected = ".NETStandard,Version=v2.0";
#else
        const string expected = ".NETCoreApp,Version=v10.0";
#endif

        // Act
        var built = typeof(BinaryPacker).Assembly.GetCustomAttributes(typeof(TargetFrameworkAttribute), false)
            .Cast<TargetFrameworkAttribute>().Single().FrameworkName;

        // Assert
        Assert.Equal(expected, built);
    }

    [Fact]
    public void HkdfMatchesRfc5869Case1()
    {
        // Arrange
        var ikm = Convert.FromHexString("0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b");
        var salt = Convert.FromHexString("000102030405060708090a0b0c");
        var info = Convert.FromHexString("f0f1f2f3f4f5f6f7f8f9");
        var okm = new byte[42];

        // Act
        Compat.HkdfSha256(ikm, okm, salt, info);

        // Assert
        Assert.Equal(
            "3cb25f25faacd57a90434f64d0362f2a2d2d0a90cf1a5a4c5db02d56ecc4c5bf34007208d5b887185865",
            Convert.ToHexString(okm).ToLowerInvariant());
    }

    [Theory]
    [InlineData("010200c0af")]
    [InlineData("010200c080")]
    [InlineData("010300e080af")]
    [InlineData("010300eda080")]
    [InlineData("010400f4908080")]
    [InlineData("010200e282")]
    [InlineData("01010080")]
    [InlineData("010100f5")]
    public void InvalidUtf8_IsRefused(string hex)
    {
        // Act
        var outcome = HostileProbe.Unpack(Names, hex);

        // Assert
        HostileProbe.ExpectShort(outcome, "Name");
    }

    [Theory]
    [InlineData("010300e282ac", "€")]
    [InlineData("010400f09f9880", "\U0001F600")]
    [InlineData("010300efbbbf", "﻿")]
    public void ValidUtf8_IsRead(string hex, string expected)
    {
        // Act
        var got = BinaryPacker.Read(Names, Convert.FromHexString(hex));

        // Assert
        Assert.Null(got.Error);
        Assert.Equal(expected, got.Values["Name"]);
    }
}
