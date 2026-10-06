package packbin;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.HashSet;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Set;

final class SchemeOrder {
    private SchemeOrder() {}

    private static final String NOT_EARLIER = ", which is not an earlier integer or bool field in its scope";
    private static final String ONLY_A_BIT = " is allowed only as a bit of flags or a flagByte";
    private static final String NEVER_SET = " has no fields and no accessor, so its bit can never be set";
    private static final String NEEDS_FACTORY = "nested group on a typed row needs a child factory";

    /** {@code typedRow} is true when the scheme's row class is not a Map. */
    static void validate(List<Field> fields, boolean typedRow) {
        walkScope(fields, new int[] {0}, typedRow);
    }

    /**
     * Binds the split flag bits of a scheme (AZ-2135) and returns the fields rebuilt for it. A bit belongs to the
     * latest read of its flagByte earlier in the same container (top level, repeat or times round, list or dict
     * element); a byte read inside a when, a flags child or a nested row is visible only there. Its position is its
     * order among the bits of that read, so the flagByte handle itself holds no bit and may be a member of any
     * number of schemes.
     * Each read gets a {@link FlagGroup} of its own in the rebuilt fields.
     */
    static List<Field> bindFlagBits(List<Field> fields) {
        return bindAll(fields, new HashMap<>());
    }

    /** {@code visible} maps a flagByte handle to the group of its latest read that this point can see. */
    private static List<Field> bindAll(List<Field> fields, Map<FlagGroup, FlagGroup> visible) {
        List<Field> bound = new ArrayList<>(fields.size());
        for (Field field : fields) {
            bound.add(bind(field, visible));
        }
        return bound;
    }

    private static Field bind(Field field, Map<FlagGroup, FlagGroup> visible) {
        return switch (field.kind) {
            case FLAG_BYTE -> {
                FlagGroup read = new FlagGroup();
                visible.put(field.group, read);
                yield field.withGroup(read);
            }
            case FLAG_BIT -> {
                FlagGroup read = visible.get(field.group);
                if (read == null) {
                    throw new IllegalArgumentException(
                            "flag bit " + bitName(field.inner) + " has no flagByte before it in the same scope");
                }
                int index = read.reserve(field.inner);
                Field inner = bind(field.inner, new HashMap<>(visible));
                read.bitInners.set(index, inner);
                yield Field.flagBit(read, index, inner);
            }
            case FLAGS -> {
                Field[] members = new Field[field.children.size()];
                for (int i = 0; i < members.length; i++) {
                    members[i] = bind(field.children.get(i).inner, new HashMap<>(visible));
                }
                yield Field.flags(field.id, members);
            }
            case WHEN -> field.withChildren(bindAll(field.children, new HashMap<>(visible)));
            case GROUP -> field.withChildren(bindAll(field.children, field.nestedRow ? new HashMap<>(visible) : visible));
            case REPEAT, TIMES, LIST, DICT -> field.withChildren(bindAll(field.children, new HashMap<>()));
            default -> field;
        };
    }

    /** Fields carry no names, so a bit is named by its kind and, when it has one, its id (ids restart per scope). */
    private static String bitName(Field inner) {
        return inner.id >= 0 ? inner.kind + " " + inner.id : inner.kind.toString();
    }

    /**
     * One reference scope: the top level, a repeat or times round, a list or dict element, or a nested row.
     * A when condition or a borrowed count may name only an integer or bool field read earlier in the same scope
     * (C++ {@code find_ref}, {@code is_count_source}). Order ids continue through repeat and times rounds;
     * {@code next} carries them. A repeat or times inside a round is a group of its own (AZ-2127): its value
     * fields hold one list per outer round. {@code typed} is true when the row of this scope is not a Map: a
     * nested row in it needs a child factory (AZ-2101), as one below a nested row that has a factory does.
     */
    private static void walkScope(List<Field> fields, int[] next, boolean typed) {
        Set<Integer> earlier = new HashSet<>();
        for (Field field : fields) {
            walk(field, earlier, next, false, typed);
        }
    }

    /**
     * {@code earlier} holds the ids of the integer and bool fields read before this field in its scope. {@code isBit} is true only for
     * the direct payload of a flags bit or a flagByte bit: a bool or an empty group is a presence bit and
     * nothing else (C++ {@code check_shape}). An empty anchored group has no accessor, so its bit could never be
     * set: it is refused wherever it stands. An empty nested row sets its bit when its member is present.
     */
    private static void walk(Field field, Set<Integer> earlier, int[] next, boolean isBit, boolean typed) {
        switch (field.kind) {
            case FLAGS -> {
                requireAnchor(field, next);
                for (Field bit : field.children) {
                    walk(bit.inner, earlier, next, true, typed);
                }
            }
            case FLAG_BIT -> walk(field.inner, earlier, next, true, typed);
            case FLAG_BYTE -> {}
            case WHEN -> {
                requireAnchor(field, next);
                requireEarlier(field.condition.fieldId, earlier, "when " + field.id + " tests field ");
                for (Field child : field.children) {
                    walk(child, earlier, next, false, typed);
                }
            }
            case REPEAT -> {
                requireAnchor(field, next);
                walkScope(field.children, next, typed);
            }
            case TIMES -> {
                requireAnchor(field, next);
                requireCount(field, earlier);
                walkScope(field.children, next, typed);
            }
            case GROUP -> {
                if (field.children.isEmpty() && !field.nestedRow) {
                    throw new IllegalArgumentException("empty group " + field.id + NEVER_SET);
                }
                if (field.children.isEmpty() && !isBit) {
                    throw new IllegalArgumentException("empty group" + ONLY_A_BIT);
                }
                if (field.nestedRow) {
                    if (typed && field.create == null) {
                        throw new IllegalArgumentException(NEEDS_FACTORY);
                    }
                    walkScope(field.children, new int[] {0}, field.create != null);
                } else {
                    requireAnchor(field, next);
                    for (Field child : field.children) {
                        walk(child, earlier, next, false, typed);
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
