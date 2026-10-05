package packbin;

import java.util.HashSet;
import java.util.List;
import java.util.Locale;
import java.util.Set;

final class SchemeOrder {
    private SchemeOrder() {}

    private static final String NOT_EARLIER = ", which is not an earlier integer or bool field in its scope";
    private static final String ONLY_A_BIT = " is allowed only as a bit of flags or a flagByte";
    private static final String NEVER_SET = " has no fields and no accessor, so its bit can never be set";
    private static final String NESTED_ROUND =
            " is inside a repeat or times round; a round cannot hold another repeat or times";

    static void validate(List<Field> fields) {
        walkScope(fields, new int[] {0}, false);
        requireFlagBytes(fields, new HashSet<>());
    }

    /**
     * A split flag bit reads the byte its own flagByte read earlier in the same container (top level,
     * repeat or times round, list or dict element). A byte inside a when or flags child is visible only there.
     */
    private static void requireFlagBytes(List<Field> fields, Set<FlagGroup> visible) {
        for (Field field : fields) {
            switch (field.kind) {
                case FLAG_BYTE -> visible.add(field.group);
                case FLAG_BIT -> {
                    if (!visible.contains(field.group)) {
                        throw new IllegalArgumentException(
                                "flag bit " + bitName(field.inner) + " has no flagByte before it in the same scope");
                    }
                    requireFlagBytes(List.of(field.inner), new HashSet<>(visible));
                }
                case FLAGS -> {
                    for (Field bit : field.children) {
                        requireFlagBytes(List.of(bit.inner), new HashSet<>(visible));
                    }
                }
                case WHEN -> requireFlagBytes(field.children, new HashSet<>(visible));
                case GROUP -> requireFlagBytes(field.children, visible);
                case REPEAT, TIMES, LIST, DICT -> requireFlagBytes(field.children, new HashSet<>());
                default -> {}
            }
        }
    }

    /** Fields carry no names, so a bit is named by its kind and, when it has one, its id (ids restart per scope). */
    private static String bitName(Field inner) {
        return inner.id >= 0 ? inner.kind + " " + inner.id : inner.kind.toString();
    }

    /**
     * One reference scope: the top level, a repeat or times round, a list or dict element, or a nested row.
     * A when condition or a borrowed count may name only an integer or bool field read earlier in the same scope
     * (C++ {@code find_ref}, {@code is_count_source}). Order ids continue through repeat and times rounds;
     * {@code next} carries them. {@code inRound} is true inside a repeat or times round, including a nested row
     * there: a round packs item i of each list, so an inner repeat or times would read every inner round from the
     * same item. A list or dict element is a row of its own and starts outside any round.
     */
    private static void walkScope(List<Field> fields, int[] next, boolean inRound) {
        Set<Integer> earlier = new HashSet<>();
        for (Field field : fields) {
            walk(field, earlier, next, false, inRound);
        }
    }

    /**
     * {@code earlier} holds the ids of the integer and bool fields read before this field in its scope. {@code isBit} is true only for
     * the direct payload of a flags bit or a flagByte bit: a bool or an empty group is a presence bit and
     * nothing else (C++ {@code check_shape}). An empty anchored group has no accessor, so its bit could never be
     * set: it is refused wherever it stands. An empty nested row sets its bit when its member is present.
     */
    private static void walk(Field field, Set<Integer> earlier, int[] next, boolean isBit, boolean inRound) {
        switch (field.kind) {
            case FLAGS -> {
                requireAnchor(field, next);
                for (Field bit : field.children) {
                    walk(bit.inner, earlier, next, true, inRound);
                }
            }
            case FLAG_BIT -> walk(field.inner, earlier, next, true, inRound);
            case FLAG_BYTE -> {}
            case WHEN -> {
                requireAnchor(field, next);
                requireEarlier(field.condition.fieldId, earlier, "when " + field.id + " tests field ");
                for (Field child : field.children) {
                    walk(child, earlier, next, false, inRound);
                }
            }
            case REPEAT -> {
                requireOutsideRound(field, inRound);
                requireAnchor(field, next);
                walkScope(field.children, next, true);
            }
            case TIMES -> {
                requireOutsideRound(field, inRound);
                requireAnchor(field, next);
                requireCount(field, earlier);
                walkScope(field.children, next, true);
            }
            case GROUP -> {
                if (field.children.isEmpty() && !field.nestedRow) {
                    throw new IllegalArgumentException("empty group " + field.id + NEVER_SET);
                }
                if (field.children.isEmpty() && !isBit) {
                    throw new IllegalArgumentException("empty group" + ONLY_A_BIT);
                }
                if (field.nestedRow) {
                    walkScope(field.children, new int[] {0}, inRound);
                } else {
                    requireAnchor(field, next);
                    for (Field child : field.children) {
                        walk(child, earlier, next, false, inRound);
                    }
                }
            }
            case LIST, DICT -> walkScope(field.children, new int[] {0}, false);
            case U2 -> {
                for (Field slot : field.children) {
                    take(slot, earlier, next);
                }
            }
            case SIZED, BITS, PACKED -> {
                requireCount(field, earlier);
                take(field, earlier, next);
            }
            case BOOL -> {
                if (!isBit) {
                    throw new IllegalArgumentException("bool " + field.id + ONLY_A_BIT);
                }
                take(field, earlier, next);
            }
            default -> {
                if (Field.isValueBearing(field)) {
                    take(field, earlier, next);
                }
            }
        }
    }

    private static void requireAnchor(Field field, int[] next) {
        if (field.id != next[0]) {
            throw new IllegalArgumentException("field id " + field.id + " must be " + next[0]);
        }
    }

    private static void requireOutsideRound(Field field, boolean inRound) {
        if (inRound) {
            throw new IllegalArgumentException(field.kind.name().toLowerCase(Locale.ROOT) + " " + field.id + NESTED_ROUND);
        }
    }

    private static void requireCount(Field field, Set<Integer> earlier) {
        requireEarlier(field.countId, earlier,
                field.kind.name().toLowerCase(Locale.ROOT) + " " + field.id + " takes its count from field ");
    }

    private static void requireEarlier(int id, Set<Integer> earlier, String referrer) {
        if (!earlier.contains(id)) {
            throw new IllegalArgumentException(referrer + id + NOT_EARLIER);
        }
    }

    private static void take(Field field, Set<Integer> earlier, int[] next) {
        if (field.id != next[0]) {
            throw new IllegalArgumentException("field id " + field.id + " must be " + next[0]);
        }
        if (isCountSource(field)) {
            earlier.add(field.id);
        }
        next[0]++;
    }

    /** The kinds whose value a when or a count can read (C++ {@code is_count_source}); a u2 slot is a u8. */
    private static boolean isCountSource(Field field) {
        return switch (field.kind) {
            case U8, U16, U32, U64, I8, I16, I32, I64, BOOL -> true;
            default -> false;
        };
    }
}
