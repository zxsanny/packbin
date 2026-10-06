package packbin;

import java.util.HashSet;
import java.util.List;
import java.util.Set;

/**
 * A row holds one value per member name, so a name written twice in one scope loses a value (AZ-2246). Fields carry
 * no names: only a setter made by {@code Access.set(String)} is named, so a typed accessor and a hand-written lambda
 * are not checked. The scope is the top level, one nested row, or one list or dict element; a when body, flags, a
 * flag bit, an anchored group and a repeat or times round belong to the scope around them (a round stores its values
 * in the row around it). A name under a when is not counted, so the branches of a chain may share one;
 * a list or dict element is a row of its own and is checked even when the list sits under a when.
 */
final class MemberNames {
    private MemberNames() {}

    static void validate(List<Field> fields) {
        walk(fields, new HashSet<>(), false);
    }

    private static void walk(List<Field> fields, Set<String> declared, boolean underWhen) {
        for (Field field : fields) {
            walk(field, declared, underWhen);
        }
    }

    private static void walk(Field field, Set<String> declared, boolean underWhen) {
        switch (field.kind) {
            case WHEN -> walk(field.children, declared, true);
            case FLAGS, REPEAT, TIMES -> walk(field.children, declared, underWhen);
            case FLAG_BIT -> walk(field.inner, declared, underWhen);
            case FLAG_BYTE -> {}
            case GROUP -> walk(field.children, field.nestedRow ? new HashSet<>() : declared, underWhen);
            case U2 -> {
                for (Field slot : field.children) {
                    declare(slot, declared, underWhen);
                }
            }
            case LIST, DICT -> {
                declare(field, declared, underWhen);
                walk(field.children, new HashSet<>(), false);
            }
            default -> declare(field, declared, underWhen);
        }
    }

    private static void declare(Field field, Set<String> declared, boolean underWhen) {
        if (!underWhen && field.set instanceof Access.KeySetter named && !declared.add(named.key)) {
            throw new IllegalArgumentException("member " + named.key
                    + ": declared twice in one scope; a row holds one value per name, so one would be lost");
        }
    }
}
