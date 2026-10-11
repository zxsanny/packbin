using System.Globalization;

namespace Packbin;

internal static partial class Walker
{
    private static bool ConditionHolds(Condition condition, IReadOnlyDictionary<string, object?> values)
    {
        if (!values.TryGetValue(condition.FieldName, out var actual) || actual is null)
            return false;
        return ValuesEqual(actual, condition.Value);
    }

    private static bool ValuesEqual(object a, object b)
    {
        if (a is byte[] aa && b is byte[] bb)
            return aa.AsSpan().SequenceEqual(bb);
        if (!IsNumber(a) || !IsNumber(b))
            return Equals(a, b);
        if (a is float or double || b is float or double)
            return SameDouble(
                Convert.ToDouble(a, CultureInfo.InvariantCulture),
                Convert.ToDouble(b, CultureInfo.InvariantCulture));
        return Convert.ToDecimal(a, CultureInfo.InvariantCulture)
            == Convert.ToDecimal(b, CultureInfo.InvariantCulture);
    }

    // A float compares as a double by Java's Double.compare: NaN equals NaN and -0.0 differs from 0.0.
    private static bool SameDouble(double a, double b) =>
        double.IsNaN(a) ? double.IsNaN(b) : a == b && (BitConverter.DoubleToInt64Bits(a) < 0) == (BitConverter.DoubleToInt64Bits(b) < 0);

    private static bool IsNumber(object value) =>
        value is byte or sbyte or ushort or short or uint or int or ulong or long or float or double or decimal;
}
