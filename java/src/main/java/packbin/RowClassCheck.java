package packbin;

import java.util.List;
import java.util.Locale;
import java.util.function.Supplier;

/**
 * A nested row with a child factory (a nested row, or the element row of a list or dict) refuses at construction a
 * member declared for another row class (AZ-4253, owner decisions D10 and D13), as C#, Go and Swift do. Java
 * accessors are erased lambdas, so the class they take cannot be read: the factory makes one child and each member's
 * getter and setter are called once on it. A lambda declared for another class casts its argument before its body
 * runs and throws {@code ClassCastException}: refused, naming the member and the child's class. The members seen are
 * those that read this row: through flags, flag bits, when, anchored groups, u2 slots and repeat or times rounds, and
 * the accessors of a nested row, list or dict member (not their insides, which have a factory of their own).
 */
final class RowClassCheck {
    private RowClassCheck() {}

    // A factory that returns null builds as before: unpack refuses it when it calls the factory (Walker).
    static void requireRowClass(Supplier<?> create, List<Field> fields) {
        Object child = create.get();
        if (child == null) {
            return;
        }
        for (Field field : fields) {
            check(field, child);
        }
    }

    private static void check(Field field, Object child) {
        switch (field.kind) {
            case FLAGS, WHEN, REPEAT, TIMES, U2 -> {
                for (Field member : field.children) {
                    check(member, child);
                }
            }
            case FLAG_BIT -> check(field.inner, child);
            case FLAG_BYTE -> {}
            case GROUP -> {
                if (field.nestedRow) {
                    call(field, child);
                } else {
                    for (Field member : field.children) {
                        check(member, child);
                    }
                }
            }
            default -> call(field, child);
        }
    }

    // The documented outcome of each exception: a ClassCastException is the member's lambda casting the row to the
    // class it was declared for, so it is refused here. Any other exception (a NullPointerException from a field
    // that is null in a fresh child, an "expected map" from a Map accessor) is not a class mismatch: the scheme
    // builds as before and pack or unpack reports that failure where it happens.
    private static void call(Field field, Object child) {
        try {
            if (field.get != null) {
                field.get.get(child);
            }
            if (field.set != null) {
                field.set.set(child, null);
            }
        } catch (ClassCastException mismatch) {
            throw new IllegalArgumentException(name(field) + ": declared for another row class; this row is "
                    + child.getClass().getSimpleName(), mismatch);
        } catch (RuntimeException notAMismatch) {
            return;
        }
    }

    private static String name(Field field) {
        String kind = field.kind.name().toLowerCase(Locale.ROOT);
        return field.id >= 0 ? kind + " " + field.id : kind;
    }
}
