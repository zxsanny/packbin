using System.Globalization;

namespace Packbin;

// The number a row holds for an integer or float field. A dictionary row holds boxed values of any type, so each is
// checked against the field it is written to: an integer field takes an integer type that fits its width (unpack returns
// the exact type of each, so an unpacked row packs again as it is), never a float, double or decimal, whole or not; a
// float field takes any number.
internal static partial class Walker
{
    internal static string KindName(Field field) => field.Type.ToString().ToLowerInvariant();

    private static ArgumentException NotANumber(Field field, object value) =>
        new($"{field.Name}: expected a number for {KindName(field)}, got {value.GetType().Name}");

    private static ArgumentException DoesNotFit(Field field, object value) =>
        new($"{field.Name}: {Convert.ToString(value, CultureInfo.InvariantCulture)} does not fit in {KindName(field)}");

    private static decimal WholeNumber(Field field, object value)
    {
        if (!IsNumber(value))
            throw NotANumber(field, value);
        if (value is float or double or decimal)
            throw new ArgumentException(
                $"{field.Name}: {Convert.ToString(value, CultureInfo.InvariantCulture)} is a {value.GetType().Name}; "
                + $"{KindName(field)} takes an integer type, not a float, double or decimal (f32 and f64 take them)");
        var whole = Whole(value);
        var (min, max) = Range(field.Type);
        if (whole >= min && whole <= max)
            return whole;
        throw DoesNotFit(field, value);
    }

    // A u2 slot, bit or packed item: an integer from 0 to `max`. A float, double, decimal (a whole `3.0` too), bool, string,
    // char, enum or object is not.
    private static bool TrySlot(object? value, int max, out int slot)
    {
        slot = 0;
        if (value is null or float or double or decimal || !IsNumber(value))
            return false;
        var whole = Whole(value);
        if (whole < 0 || whole > max)
            return false;
        slot = (int)whole;
        return true;
    }

    // The value of an integer type (byte to ulong), as one decimal.
    private static decimal Whole(object value) =>
        value is ulong big ? big : Convert.ToInt64(value, CultureInfo.InvariantCulture);

    internal static (decimal Min, decimal Max) Range(Field.Kind kind) => kind switch
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
