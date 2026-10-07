using System.Globalization;

namespace Packbin;

// The number a row holds for an integer or float field. A dictionary row holds boxed values of any type, so each is
// checked against the field it is written to: an integer field takes a whole number that fits its width (unpack returns
// the narrow ones as whole-number doubles, and a row from JSON holds doubles or longs), a float field takes any number.
internal static partial class Walker
{
    private static string KindName(Field field) => field.Type.ToString().ToLowerInvariant();

    private static ArgumentException NotANumber(Field field, object value) =>
        new($"{field.Name}: expected a number for {KindName(field)}, got {value.GetType().Name}");

    private static ArgumentException DoesNotFit(Field field, object value) =>
        new($"{field.Name}: {Convert.ToString(value, CultureInfo.InvariantCulture)} does not fit in {KindName(field)}");

    private static decimal WholeNumber(Field field, object value)
    {
        if (!IsNumber(value))
            throw NotANumber(field, value);
        if (TryWhole(value, out var whole))
        {
            var (min, max) = Range(field.Type);
            if (whole >= min && whole <= max)
                return whole;
        }
        throw DoesNotFit(field, value);
    }

    // False for a fraction, NaN, an infinity, or a number beyond long.MinValue..ulong.MaxValue.
    private static bool TryWhole(object value, out decimal whole)
    {
        whole = 0;
        switch (value)
        {
            case ulong big:
                whole = big;
                return true;
            case float or double:
                var d = Convert.ToDouble(value, CultureInfo.InvariantCulture);
                if (!(d >= -9223372036854775808.0 && d < 18446744073709551616.0) || Math.Floor(d) != d)
                    return false;
                whole = d >= 9223372036854775808.0 ? (decimal)(ulong)d : (decimal)(long)d;
                return true;
            case decimal exact:
                whole = exact;
                return decimal.Truncate(exact) == exact;
            default:
                whole = Convert.ToInt64(value, CultureInfo.InvariantCulture);
                return true;
        }
    }

    private static (decimal Min, decimal Max) Range(Field.Kind kind) => kind switch
    {
        Field.Kind.U8 => (byte.MinValue, byte.MaxValue),
        Field.Kind.I8 => (sbyte.MinValue, sbyte.MaxValue),
        Field.Kind.U16 => (ushort.MinValue, ushort.MaxValue),
        Field.Kind.I16 => (short.MinValue, short.MaxValue),
        Field.Kind.U32 => (uint.MinValue, uint.MaxValue),
        Field.Kind.I32 => (int.MinValue, int.MaxValue),
        Field.Kind.U64 => (ulong.MinValue, ulong.MaxValue),
        _ => (long.MinValue, long.MaxValue),
    };

    private static double RealNumber(Field field, object value) =>
        IsNumber(value) ? Convert.ToDouble(value, CultureInfo.InvariantCulture) : throw NotANumber(field, value);

    // An f32 takes infinities and NaN as they are, but a finite number beyond its range would silently become infinity.
    private static float SingleNumber(Field field, object value)
    {
        var wide = RealNumber(field, value);
        var narrow = (float)wide;
        if (float.IsInfinity(narrow) && !double.IsInfinity(wide))
            throw DoesNotFit(field, value);
        return narrow;
    }
}
