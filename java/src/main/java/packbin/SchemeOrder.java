package packbin;

import java.nio.ByteBuffer;
import java.util.ArrayDeque;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.IdentityHashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;

final class SchemeOrder {
    private SchemeOrder() {}

    private static final String NOT_EARLIER = ", which is not an earlier integer or bool field in its scope";
    private static final String ONLY_A_BIT = " is allowed only as a bit of flags or a flagByte";
    private static final String NEVER_SET = " has no fields and no accessor, so its bit can never be set";
    private static final String NEEDS_FACTORY = "nested group on a typed row needs a child factory";
    private static final String READS_TO_END = "; a repeat reads to the end of the packet, so ";
    private static final String FOLLOWS = " follows it" + READS_TO_END + "nothing can follow it; use times";
    private static final String IN_ELEMENT = " is inside a list or dict element" + READS_TO_END
            + "another element cannot follow it; use times";
    private static final String IN_ROUND = " is inside a repeat or times round" + READS_TO_END
            + "another round cannot follow it; use times";

    /** The deepest nesting a scheme may have (contract scheme-depth). */
    static final int MAX_DEPTH = 256;

    /**
     * Refuses a scheme nested deeper than {@link #MAX_DEPTH} levels (contract scheme-depth). A when, flags, group,
     * nested row, repeat, times, list and dict count one level each; a flag bit and a scalar add none. Runs before
     * any walk that recurses, and itself uses a stack of fields, so a scheme of any depth costs no call stack: it
     * stops at the first field that is too deep. A field shared by two parents is measured again only when it is
     * reached deeper than before.
     */
    static void checkDepth(List<Field> fields) {
        ArrayDeque<Field> nodes = new ArrayDeque<>(fields);
        ArrayDeque<Integer> above = new ArrayDeque<>();
        for (int i = 0; i < fields.size(); i++) {
            above.push(0);
        }
        Map<Field, Integer> deepest = new IdentityHashMap<>();
        while (!nodes.isEmpty()) {
            Field field = nodes.pop();
            int outer = above.pop();
            Integer seen = deepest.get(field);
            if (seen != null && seen >= outer) {
                continue;
            }
            deepest.put(field, outer);
            int depth = switch (field.kind) {
                case WHEN, FLAGS, GROUP, REPEAT, TIMES, LIST, DICT -> outer + 1;
                default -> outer;
            };
            if (depth > MAX_DEPTH) {
                throw new IllegalArgumentException(
                        "scheme nested too deep: more than " + MAX_DEPTH + " levels; the limit is " + MAX_DEPTH);
            }
            for (Field child : field.children) {
                nodes.push(child);
                above.push(depth);
            }
            if (field.inner != null) {
                nodes.push(field.inner);
                above.push(depth);
            }
        }
    }

    /** {@code typedRow} is true when the scheme's row class is not a Map. */
    static void validate(List<Field> fields, boolean typedRow) {
        walkScope(fields, new int[] {0}, typedRow);
        checkRepeatLast(fields);
    }

    /** The repeat-last rule alone, for the tests that compare it with an older walk. */
    static void checkRepeatLast(List<Field> fields) {
        new RepeatLast().walk(fields, null, null);
    }

    /**
     * A repeat has no count on the wire: unpack reads its rounds to the end of the packet, so a repeat must be the
     * last thing a packet reads (contract repeat-last, AZ-4214). Refused here, once, when the scheme is built: a
     * field that can write a byte after a repeat, in the repeat's own place or after the when, flags, flag bit,
     * group or nested row that holds it; a repeat inside a list or dict element; a repeat inside a repeat or times
     * round. A times has a count and is not restricted. The walk follows the order pack writes the fields in.
     * The first writer of a field is worked out once ({@code firstWriters}) however many places above ask for it, so
     * the walk costs the size of the scheme whatever its shape (AZ-4257; a chain of nested whens was quadratic).
     */
    private static final class RepeatLast {
        /** The first writer of each field asked for; a field that writes nothing maps to null. */
        private final Map<Field, Field> firstWriters = new IdentityHashMap<>();

        /**
         * {@code open} is the repeat read before these fields, null when there is none; {@code inside} is the refusal
         * of a repeat that stands here, null outside every element and round. Returns the repeat open after the
         * fields.
         */
        Field walk(List<Field> fields, Field open, String inside) {
            for (Field field : fields) {
                open = walk(field, open, inside);
            }
            return open;
        }

        private Field walk(Field field, Field open, String inside) {
            Field follower = open == null ? null : firstWriter(field);
            if (follower != null) {
                throw new IllegalArgumentException("repeat " + open.id + ": " + kindAndId(follower) + FOLLOWS);
            }
            return switch (field.kind) {
                case REPEAT -> {
                    if (inside != null) {
                        throw new IllegalArgumentException("repeat " + field.id + inside);
                    }
                    walk(field.children, null, IN_ROUND);
                    // A repeat that reached here writes nothing (one that writes was refused above): the first
                    // repeat stays the one a later field follows.
                    yield open == null ? field : open;
                }
                case TIMES -> {
                    walk(field.children, null, IN_ROUND);
                    yield open;
                }
                case LIST, DICT -> {
                    walk(field.children, null, IN_ELEMENT);
                    yield open;
                }
                case WHEN, GROUP, FLAGS -> walk(field.children, open, inside);
                case FLAG_BIT -> walk(field.inner, open, inside);
                default -> open;
            };
        }

        /**
         * The first field of {@code field} that can write a byte for some row, null when none can. A bool is a bit
         * of a flag byte written earlier and a bytes of size 0 writes nothing; a when, group, nested row or flag bit
         * writes what it holds, and so does a repeat or times, which is named itself. Every other field writes: a
         * flags and a flag byte their byte, a list or dict its count.
         */
        private Field firstWriter(Field field) {
            if (firstWriters.containsKey(field)) {
                return firstWriters.get(field);
            }
            Field writer = switch (field.kind) {
                case BOOL -> null;
                case BYTES -> field.size > 0 ? field : null;
                case FLAG_BIT -> firstWriter(field.inner);
                case WHEN, GROUP -> firstWriter(field.children);
                case REPEAT, TIMES -> firstWriter(field.children) == null ? null : field;
                default -> field;
            };
            firstWriters.put(field, writer);
            return writer;
        }

        private Field firstWriter(List<Field> fields) {
            for (Field field : fields) {
                Field writer = firstWriter(field);
                if (writer != null) {
                    return writer;
                }
            }
            return null;
        }
    }

    /** The follower of a repeat, the kind in lower case as in the other messages of this file ({@code u8 1}). */
    private static String kindAndId(Field field) {
        String kind = field.kind == Field.Kind.FLAG_BYTE ? "flagByte" : field.kind.name().toLowerCase(Locale.ROOT);
        return named(kind, field);
    }

    /** Fields carry no names: one is named by a kind word and, when it has one, its id (ids restart per scope). */
    private static String named(String kind, Field field) {
        return field.id >= 0 ? kind + " " + field.id : kind;
    }

    /**
     * Binds the split flag bits of a scheme (AZ-2135) and returns the fields rebuilt for it. A bit belongs to the
     * latest read of its flagByte earlier in the same container (top level, repeat or times round, list or dict
     * element); a byte read inside a when or a flags child is visible only there. A nested row is a scope of its own
     * that starts with no byte visible: a byte read inside it is not visible after it, and a byte read outside it is
     * not visible inside it (AZ-2233). The rule is by scope, not by what the member is: it also holds when the member
     * is the row around itself ({@code group(identity(), ignore(), ...)}). Its position is its order among the bits
     * of that read, so the flagByte handle itself holds no bit and may be a member of any number of schemes.
     * Each read gets a {@link FlagGroup} of its own in the rebuilt fields.
     */
    static List<Field> bindFlagBits(List<Field> fields) {
        return bindAll(fields, new HashMap<>(), new HashMap<>());
    }

    /**
     * {@code visible} maps a flagByte handle to the group of its latest read that this point can see. {@code counts}
     * holds the integer and bool fields read so far in this reference scope, by id, as the construction checks see
     * them: a times takes the field its count names from it, so pack can read that count in the row.
     */
    private static List<Field> bindAll(
            List<Field> fields, Map<FlagGroup, FlagGroup> visible, Map<Integer, Field> counts) {
        List<Field> bound = new ArrayList<>(fields.size());
        for (Field field : fields) {
            bound.add(bind(field, visible, counts));
        }
        return bound;
    }

    private static Field bind(Field field, Map<FlagGroup, FlagGroup> visible, Map<Integer, Field> counts) {
        return switch (field.kind) {
            case FLAG_BYTE -> {
                FlagGroup read = new FlagGroup();
                visible.put(field.group, read);
                yield field.withGroup(read);
            }
            case FLAG_BIT -> {
                FlagGroup read = visible.get(field.group);
                if (read == null) {
                    // The kind keeps the case of its constant (U8 0): the documented text of this refusal (AZ-2135).
                    throw new IllegalArgumentException("flag bit " + named(field.inner.kind.toString(), field.inner)
                            + " has no flagByte before it in the same scope");
                }
                int index = read.reserve(field.inner);
                Field inner = bind(field.inner, new HashMap<>(visible), counts);
                read.bitInners.set(index, inner);
                yield Field.flagBit(read, index, inner);
            }
            case FLAGS -> {
                Field[] members = new Field[field.children.size()];
                for (int i = 0; i < members.length; i++) {
                    members[i] = bind(field.children.get(i).inner, new HashMap<>(visible), counts);
                }
                yield Field.flags(field.id, members);
            }
            case WHEN -> field.withChildren(bindAll(field.children, new HashMap<>(visible), counts));
            case GROUP -> field.nestedRow
                    ? field.withChildren(bindAll(field.children, new HashMap<>(), new HashMap<>()))
                    : field.withChildren(bindAll(field.children, visible, counts));
            case REPEAT, LIST, DICT -> field.withChildren(bindAll(field.children, new HashMap<>(), new HashMap<>()));
            case TIMES -> field.withChildren(
                    bindAll(field.children, new HashMap<>(), new HashMap<>()), counts.get(field.countId));
            case BITS, PACKED, SIZED -> field.withChildren(field.children, counts.get(field.countId));
            case U2 -> {
                for (Field slot : field.children) {
                    if (isCountSource(slot)) {
                        counts.put(slot.id, slot);
                    }
                }
                yield field;
            }
            default -> {
                if (isCountSource(field)) {
                    counts.put(field.id, field);
                }
                yield field;
            }
        };
    }

    /**
     * One reference scope: the top level, a repeat or times round, a list or dict element, or a nested row.
     * A when condition may name only an integer or bool field read earlier in the same scope, a bool only against
     * true; a borrowed count may name only an integer field (AZ-2126). Order ids continue through repeat and times rounds;
     * {@code next} carries them. A times inside a round is a group of its own (AZ-2127): its value fields hold
     * one list per outer round; a repeat inside a round is refused ({@code repeatLast}). {@code typed} is true when
     * the row of this scope is not a Map: a nested row in it needs a child factory (AZ-2101), as one below a nested
     * row that has a factory does.
     */
    private static void walkScope(List<Field> fields, int[] next, boolean typed) {
        Map<Integer, Field> earlier = new HashMap<>();
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
    private static void walk(Field field, Map<Integer, Field> earlier, int[] next, boolean isBit, boolean typed) {
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
                requireWhenSource(field, earlier);
                for (Field child : field.children) {
                    walk(child, earlier, next, false, typed);
                }
            }
            case REPEAT -> {
                requireAnchor(field, next);
                walkScope(field.children, next, typed);
                requireMember(field);
            }
            case TIMES -> {
                requireAnchor(field, next);
                requireCount(field, earlier);
                walkScope(field.children, next, typed);
                requireMember(field);
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
            case LIST, DICT -> {
                requireElementFactory(field, typed);
                walkScope(field.children, new int[] {0}, false);
            }
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

    /**
     * An element group without a factory unpacks into a HashMap, which a typed row's accessors cannot take: refused
     * where the list or dict is held by a typed row, also as the element of an inner list or dict (AZ-2235). An
     * anchored group, flags or u2 element has no factory overload, so it is left to the caller.
     */
    private static void requireElementFactory(Field container, boolean typed) {
        Field element = container.children.get(0);
        if (typed && element.kind == Field.Kind.GROUP && element.nestedRow && element.create == null) {
            throw new IllegalArgumentException(
                    container.kind.name().toLowerCase(Locale.ROOT) + " element: " + NEEDS_FACTORY);
        }
        if (element.kind == Field.Kind.LIST || element.kind == Field.Kind.DICT) {
            requireElementFactory(element, typed);
        }
    }

    /**
     * A round whose body holds no member charges no slot and writes no byte, so neither maxSlots nor maxBytes could
     * bound a count of 65 535 such rounds (F33). Refused here, once, wherever the repeat or times stands.
     */
    private static void requireMember(Field round) {
        if (!holdsMember(round.children)) {
            throw new IllegalArgumentException(round.kind.name().toLowerCase(Locale.ROOT) + " " + round.id
                    + ": the body holds no member; a round of it would charge no slot and write nothing");
        }
    }

    /**
     * Looking through when, anchored groups, flag bits and an inner times, a member is any field that is not a
     * container: a value field (a zero-width bytes included), a list, a dict, a u2, a nested row, a flag byte or a
     * flags (one without members writes its flag byte). An inner repeat counts as a member without a look: a
     * round refuses it ({@code repeatLast}), and {@code walk} has already checked that its own body holds a member.
     */
    private static boolean holdsMember(List<Field> body) {
        for (Field field : body) {
            boolean member = switch (field.kind) {
                case WHEN, TIMES -> holdsMember(field.children);
                case GROUP -> field.nestedRow || holdsMember(field.children);
                case FLAG_BIT -> holdsMember(java.util.Collections.singletonList(field.inner));
                default -> true;
            };
            if (member) {
                return true;
            }
        }
        return false;
    }

    private static void requireAnchor(Field field, int[] next) {
        if (field.id != next[0]) {
            throw new IllegalArgumentException("field id " + field.id + " must be " + next[0]);
        }
    }

    /** A count is read as a number, so it names an integer field; a bool is refused (AZ-2126). */
    private static void requireCount(Field field, Map<Integer, Field> earlier) {
        String referrer = field.kind.name().toLowerCase(Locale.ROOT) + " " + field.id + " takes its count from field "
                + field.countId;
        Field source = earlier.get(field.countId);
        if (source == null) {
            throw new IllegalArgumentException(referrer + ", which is not an earlier integer field in its scope");
        }
        if (source.kind == Field.Kind.BOOL) {
            throw new IllegalArgumentException(referrer + ", which is a bool; a count names an integer field");
        }
    }

    /**
     * A bool is true or clear on the wire and a clear bit is absent, so a when on a bool compares only with true. An
     * integer source is compared only with a value it could hold (AZ-2338): the value is checked as pack would check
     * it, so a string, a fraction, a boolean, NaN or a number past the range of the source never builds a when that
     * can not match.
     */
    private static void requireWhenSource(Field when, Map<Integer, Field> earlier) {
        int id = when.condition.fieldId;
        Field source = earlier.get(id);
        if (source == null) {
            throw new IllegalArgumentException("when " + when.id + " tests field " + id + NOT_EARLIER);
        }
        if (source.kind == Field.Kind.BOOL) {
            if (!Boolean.TRUE.equals(when.condition.value)) {
                throw new IllegalArgumentException("when " + when.id + " tests bool field " + id + " against "
                        + when.condition.value + "; a bool is compared only with true");
            }
            return;
        }
        try {
            ByteBuffer probe = ByteBuffer.allocate(8);
            Scalars.writeScalar(source, when.condition.value, probe);
            // A u2 slot is a u8 without a byte of its own (size 0) and holds 0..3.
            if (source.kind == Field.Kind.U8 && source.size == 0 && (probe.get(0) & 0xFF) > 3) {
                throw new IllegalArgumentException("expected 2-bit int");
            }
        } catch (IllegalArgumentException ex) {
            throw new IllegalArgumentException("when " + when.id + " tests field " + id + " against "
                    + when.condition.value + ", which that field can not hold (" + ex.getMessage() + ")", ex);
        }
    }

    private static void take(Field field, Map<Integer, Field> earlier, int[] next) {
        if (field.id != next[0]) {
            throw new IllegalArgumentException("field id " + field.id + " must be " + next[0]);
        }
        if (isCountSource(field)) {
            earlier.put(field.id, field);
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
