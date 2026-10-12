using System.Globalization;

namespace Packbin;

// AZ-2386 (U6): a `times` whose bit is clear because no field wrote its count. When the row still holds a count above
// zero (the `when` that writes it is clear), the row expects rounds that unpack would never read, so it is refused where
// the bit is found clear: at the split bit, and in order in a combined `flags`. A count of zero, or none, packs a clear bit.
// AZ-2410 (U11): the same for a `bits`, `packed` or `sized` with no value, whose count (after the `packed` bias) is above zero.
internal static partial class Walker
{
    private static void RequireNoStrandedCount(Field bit, IReadOnlyDictionary<string, object?> values, Scope seen)
    {
        if (StrandedCount(bit, values, seen) is { } message)
            throw new ArgumentException(message);
    }

    // Looks through the flag bit, `flags`, a group and a `when` whose condition holds, as the bit's body would be written.
    private static string? StrandedCount(Field field, IReadOnlyDictionary<string, object?> values, Scope seen)
    {
        switch (field.Type)
        {
            case Field.Kind.Times:
                if (seen.TryGetValue(field.CountName, out var written) && written is not null)
                    return null;
                if (!values.TryGetValue(field.CountName, out var count) || !IsPositive(count))
                    return null;
                return $"'{RoundMember(field, RoundNames(field, packing: true))}': the count {field.CountName} is "
                    + $"{Convert.ToString(count, CultureInfo.InvariantCulture)} in the row, but no field wrote it "
                    + "(the when that holds it is clear), so its times reads no round; give the count 0, leave it out, "
                    + "or make the when hold";
            case Field.Kind.Bits:
            case Field.Kind.Packed:
            case Field.Kind.Sized:
                if (seen.TryGetValue(field.CountName, out var writtenCount) && writtenCount is not null)
                    return null;
                if (!values.TryGetValue(field.CountName, out var given) || !IsPositive(given, field.Bias))
                    return null;
                return $"'{field.Name}': the count {field.CountName} is "
                    + $"{Convert.ToString(given, CultureInfo.InvariantCulture)} in the row, but no field wrote it "
                    + "(the when that holds it is clear), so the member reads nothing; give the count 0, leave it out, "
                    + "or make the when hold";
            case Field.Kind.FlagBit:
                return StrandedCount(field.Inner!, values, seen);
            case Field.Kind.When when !ConditionHolds(field.Pred!, seen):
                return null;
            case Field.Kind.When:
            case Field.Kind.Flags:
            case Field.Kind.Group when !field.NestedRow:
                return field.Children.Select(child => StrandedCount(child, values, seen)).FirstOrDefault(message => message is not null);
            default:
                return null;
        }
    }

    // A whole-number count that is not negative and, after the `packed` bias, above zero.
    private static bool IsPositive(object? count, int bias = 0) =>
        count switch
        {
            sbyte or short or int or long => Convert.ToInt64(count, CultureInfo.InvariantCulture) is var n && n >= 0 && (decimal)n + bias > 0,
            byte or ushort or uint or ulong => Convert.ToUInt64(count, CultureInfo.InvariantCulture) is var u && (decimal)u + bias > 0,
            _ => false,
        };
}
