using System.Collections;
using Packbin;

namespace Packbin.Tests;

// AZ-2473 (U26 A, loop 25): a dictionary row holding a nested-row group reads the group's member names from the inner
// dictionary of that row, not from the outer dictionary. The parity reference is TypeScript's Dict reader (U26) and
// GO-12 ("the map form reads a nested-row group from the nested map").
public class DictNestedRowGroupTests
{
    private sealed class GRow
    {
        public byte? N { get; set; }
    }

    private sealed class TopRow
    {
        public GRow? G { get; set; }
        public byte? X { get; set; }
    }

    // The nested-row group takes no outer id (SchemeOrder numbers its members from 0 in their own scope), so the outer
    // u8 "X" sits at top-level id 0 just as it does in TypeScript's parity scheme.
    private static Scheme<TopRow> Scheme() => new(1,
        Field.Group((TopRow x) => x.G, Field.U8<GRow>(0, g => g.N)),
        Field.U8<TopRow>(0, x => x.X));

    private static string Hex(byte[] raw) => Convert.ToHexString(raw).ToLowerInvariant();

    [Fact]
    public void Ac1_Pack_NestedDictionaryRow_PacksTheGroupMemberFromTheInnerDictionary()
    {
        // Arrange: TypeScript's parity row for a nested-row group in a dictionary row.
        var scheme = Scheme();
        var row = new Dictionary<string, object?>
        {
            ["G"] = new Dictionary<string, object?> { ["N"] = (byte)7 },
            ["X"] = (byte)1,
        };

        // Act
        var raw = BinaryPacker.Pack(scheme, row);

        // Assert: type (01), inner "N" (07), outer "X" (01).
        Assert.Equal("010701", Hex(raw));
    }

    [Fact]
    public void Ac2_Pack_FlatDictionaryRow_FailsNamingTheMissingNestedDictionary()
    {
        // Arrange: the same scheme but "N" sits at the outer level; the nested-row group now reads nothing there.
        var scheme = Scheme();
        var row = new Dictionary<string, object?>
        {
            ["G"] = new Dictionary<string, object?>(),
            ["N"] = (byte)7,
            ["X"] = (byte)1,
        };

        // Act
        var error = Assert.Throws<ArgumentException>(() => BinaryPacker.Pack(scheme, row));

        // Assert: the error names the inner member "N" of the nested-row group "G" (its id in the inner scope is 0),
        // signaling that the outer "N" is not read for the group.
        Assert.Contains("'N'", error.Message, StringComparison.Ordinal);
    }

    [Fact]
    public void Ac2_Pack_RowMissingTheNestedDictionary_FailsNamingTheGroup()
    {
        // Arrange: the group's nested dictionary is omitted entirely.
        var scheme = Scheme();
        var row = new Dictionary<string, object?>
        {
            ["N"] = (byte)7,
            ["X"] = (byte)1,
        };

        // Act
        var error = Assert.Throws<ArgumentException>(() => BinaryPacker.Pack(scheme, row));

        // Assert: the group "G" has no nested dictionary, so pack names it.
        Assert.Contains("'G'", error.Message, StringComparison.Ordinal);
    }

    [Fact]
    public void Ac2_Pack_FlatRow_WritesNoBytes()
    {
        // Arrange: a flat dictionary row with the nested-row group's names at the outer level is refused before any
        // bytes of the body reach the output; writing fails before the pack call returns.
        var scheme = Scheme();
        var row = new Dictionary<string, object?>
        {
            ["N"] = (byte)7,
            ["X"] = (byte)1,
        };

        // Act
        var error = Record.Exception(() => BinaryPacker.Pack(scheme, row));

        // Assert
        Assert.IsType<ArgumentException>(error);
    }

    [Fact]
    public void Ac3_Unpack_RoundTripsThroughTheNestedDictionary()
    {
        // Arrange
        var scheme = Scheme();
        var raw = Convert.FromHexString("010701");

        // Act
        var got = BinaryPacker.Read(scheme, raw);
        var again = BinaryPacker.Pack(scheme, got.Values);

        // Assert: the group "G" is a nested dictionary carrying "N"; "X" sits at the outer level.
        Assert.Null(got.Error);
        var inner = Assert.IsAssignableFrom<IReadOnlyDictionary<string, object?>>(got.Values["G"]);
        Assert.Equal((byte)7, inner["N"]);
        Assert.Equal((byte)1, got.Values["X"]);
        Assert.False(got.Values.ContainsKey("N"));
        Assert.Equal("010701", Hex(again));
    }

    [Fact]
    public void Ac4_Pack_TypedRowAndDictionaryRow_GiveTheSameBytes()
    {
        // Arrange: the parity row pins typed-row and dictionary-row packing to the same bytes, as TypeScript's U26
        // reader does.
        var scheme = Scheme();
        var typed = new TopRow { G = new GRow { N = 7 }, X = 1 };
        var dict = new Dictionary<string, object?>
        {
            ["G"] = new Dictionary<string, object?> { ["N"] = (byte)7 },
            ["X"] = (byte)1,
        };

        // Act
        var fromTyped = BinaryPacker.Pack(scheme, typed);
        var fromDict = BinaryPacker.Pack(scheme, dict);

        // Assert
        Assert.Equal("010701", Hex(fromTyped));
        Assert.Equal("010701", Hex(fromDict));
    }

    [Fact]
    public void Ac4_Unpack_TypedAndDictionaryShapes_HoldTheSameValues()
    {
        // Arrange: unpack the AC-1 bytes into a typed row and into a dictionary row; both carry the same values.
        var scheme = Scheme();
        var raw = Convert.FromHexString("010701");
        TopRow? typed = null;

        // Act
        var typedError = BinaryPacker.Unpack(raw, scheme.On(r => typed = r));
        var dictResult = BinaryPacker.Read(scheme, raw);

        // Assert
        Assert.Null(typedError);
        Assert.Null(dictResult.Error);
        Assert.Equal((byte)7, typed!.G!.N);
        Assert.Equal((byte)1, typed.X);
        var inner = Assert.IsAssignableFrom<IReadOnlyDictionary<string, object?>>(dictResult.Values["G"]);
        Assert.Equal((byte)7, inner["N"]);
        Assert.Equal((byte)1, dictResult.Values["X"]);
    }
}
