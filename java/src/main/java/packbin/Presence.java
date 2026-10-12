package packbin;

import java.util.List;
import java.util.Map;

/** Which members of a row hold a value, and whether a {@code when} condition holds: what a flag bit is decided on. */
final class Presence {
    private Presence() {}

    static boolean isPresent(Object value) {
        return value != null;
    }

    static boolean boolOn(Object value) {
        return Boolean.TRUE.equals(value);
    }

    /**
     * Whether a flag bit is set. {@code take} is the repeat or times round's item lookup, null outside rounds.
     * {@code seen} holds the values written so far in the scope, which decide a {@code when} member (its condition)
     * and a {@code times} member (its count). A {@code when} is on when its condition holds and its body holds a
     * value; a {@code times} when its count is above 0; a {@code repeat} when a round holds a value.
     */
    static boolean childOn(Object row, Field child, Walker.Take take, Map<Object, Object> seen) {
        return childOn(row, child, take, seen, false);
    }

    /**
     * {@code valuesOnly} asks whether a value would be dropped: a {@code times} then counts only when a round holds
     * a value, since a count with no value behind it leaves nothing to drop.
     */
    private static boolean childOn(
            Object row, Field child, Walker.Take take, Map<Object, Object> seen, boolean valuesOnly) {
        return switch (child.kind) {
            case GROUP -> groupOn(row, child, take, seen, valuesOnly);
            case FLAGS -> anyOn(row, child.children, take, seen, valuesOnly);
            case U2 -> anySlotPresent(row, child.children, take);
            case BOOL -> boolOn(takeValue(child, row, take));
            case FLAG_BIT -> childOn(row, child.inner, take, seen, valuesOnly);
            case WHEN -> conditionHolds(child.condition, seen) && anyOn(row, child.children, take, seen, valuesOnly);
            case TIMES -> VarFields.timesOn(child, row, take, seen) && (!valuesOnly || Rounds.repeatOn(child, row, take));
            case REPEAT -> Rounds.repeatOn(child, row, take);
            case U8, U16, U32, U64, I8, I16, I32, I64, F32, F64, BYTES, UTF8, SIZED, BITS, PACKED, LIST, DICT ->
                    isPresent(takeValue(child, row, take));
            default -> false;
        };
    }

    private static boolean groupOn(
            Object row, Field group, Walker.Take take, Map<Object, Object> seen, boolean valuesOnly) {
        if (group.nestedRow) {
            // The fields of a nested row belong to its member, not to this row: the member alone decides.
            return isPresent(takeValue(group, row, take));
        }
        return anyOn(row, group.children, take, seen, valuesOnly);
    }

    private static boolean anyOn(
            Object row, List<Field> children, Walker.Take take, Map<Object, Object> seen, boolean valuesOnly) {
        for (Field child : children) {
            if (childOn(row, child, take, seen, valuesOnly)) {
                return true;
            }
        }
        return false;
    }

    private static boolean anySlotPresent(Object row, List<Field> slots, Walker.Take take) {
        for (Field slot : slots) {
            if (isPresent(takeValue(slot, row, take))) {
                return true;
            }
        }
        return false;
    }


    /**
     * A split flag bit was decided where its byte stands. When the byte left it clear but the member holds values
     * by now (its condition or count was written between the byte and the bit, or its count was never written),
     * those values cannot be packed, and dropping them would give a packet that unpacks without them: refuse.
     * A condition that is false on values written before the byte drops its body without error, as outside flags.
     */
    static void requireNothingDropped(Field member, Object row, Walker.Take take, Map<Object, Object> seen) {
        if (childOn(row, member, take, seen, true)) {
            throw new IllegalArgumentException(Rounds.firstValueName(member)
                    + ": its flag bit was decided before the value its condition or count reads was written");
        }
        if (valuesWithoutCount(member, row, take, seen)) {
            throw new IllegalArgumentException(
                    Rounds.firstValueName(member) + ": values given, but the count of its times was never written");
        }
        requireCountWritten(member, row, take, seen);
    }

    /**
     * A combined flags decides each bit as its member is reached. A member whose times count was skipped writes no
     * round, so values given for it would be dropped: refuse, naming the first of them.
     */
    static void requireNoSkippedCount(Field member, Object row, Walker.Take take, Map<Object, Object> seen) {
        if (valuesWithoutCount(member, row, take, seen)) {
            throw new IllegalArgumentException(Rounds.firstValueName(member)
                    + ": a value is given, but the count of its times is not written, so its bit is clear;"
                    + " write the count before the times");
        }
        requireCountWritten(member, row, take, seen);
    }

    /**
     * A times whose count no field wrote (the when that holds the count is clear) reads no round, whatever count the
     * row holds, so the row would unpack with a smaller count than it packs: refused where its bit is found clear.
     * A count of 0, or none in the row, agrees with the packet and packs.
     */
    private static void requireCountWritten(Field member, Object row, Walker.Take take, Map<Object, Object> seen) {
        switch (member.kind) {
            case TIMES -> {
                Object count = seen.get(member.countId);
                if (member.countSource == null || count instanceof Number && !(count instanceof Float || count instanceof Double)) {
                    return;
                }
                String given = positive(takeValue(member.countSource, row, take));
                if (given != null) {
                    throw new IllegalArgumentException(Rounds.firstValueName(member) + ": the count "
                            + Rounds.firstValueName(member.countSource) + " is " + given
                            + " in the row, but no field wrote it (the when that holds it is clear), so its times"
                            + " reads no round; give the count 0, leave it out, or make the when hold");
                }
            }
            case FLAG_BIT -> requireCountWritten(member.inner, row, take, seen);
            case GROUP, WHEN, FLAGS -> {
                if (member.nestedRow || member.kind == Field.Kind.WHEN && !conditionHolds(member.condition, seen)) {
                    return;
                }
                for (Field child : member.children) {
                    requireCountWritten(child, row, take, seen);
                }
            }
            default -> { }
        }
    }

    /** The whole number above 0 that {@code value} holds, as text; null for anything else. */
    private static String positive(Object value) {
        if (value instanceof java.math.BigInteger big) {
            return big.signum() > 0 ? big.toString() : null;
        }
        if (value instanceof Number number && !(value instanceof Float || value instanceof Double)) {
            return number.longValue() > 0 ? Long.toString(number.longValue()) : null;
        }
        return null;
    }

    private static boolean valuesWithoutCount(Field member, Object row, Walker.Take take, Map<Object, Object> seen) {
        switch (member.kind) {
            case TIMES -> {
                Object count = seen.get(member.countId);
                boolean written = count instanceof Number && !(count instanceof Float || count instanceof Double);
                return !written && Rounds.repeatOn(member, row, take);
            }
            case FLAG_BIT -> {
                return valuesWithoutCount(member.inner, row, take, seen);
            }
            case GROUP, WHEN, FLAGS -> {
                if (member.kind == Field.Kind.WHEN && !conditionHolds(member.condition, seen)) {
                    return false;
                }
                if (member.nestedRow) {
                    return false;
                }
                for (Field child : member.children) {
                    if (valuesWithoutCount(child, row, take, seen)) {
                        return true;
                    }
                }
                return false;
            }
            default -> {
                return false;
            }
        }
    }

    static Object takeValue(Field field, Object row, Walker.Take take) {
        if (take != null) {
            return take.apply(field);
        }
        return field.get.get(row);
    }

    static boolean conditionHolds(Packbin.Eq condition, Map<Object, Object> seen) {
        Object actual = seen.get(condition.fieldId);
        if (actual == null) {
            return false;
        }
        return valuesEqual(actual, condition.value);
    }

    private static boolean valuesEqual(Object a, Object b) {
        if (a instanceof byte[] aa && b instanceof byte[] bb) {
            return java.util.Arrays.equals(aa, bb);
        }
        if (a instanceof Number na && b instanceof Number nb) {
            if (a instanceof Double || a instanceof Float || b instanceof Double || b instanceof Float) {
                return Double.compare(na.doubleValue(), nb.doubleValue()) == 0;
            }
            return na.longValue() == nb.longValue();
        }
        return a.equals(b);
    }
}
