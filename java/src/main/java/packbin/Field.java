package packbin;

import java.util.ArrayList;
import java.util.Collections;
import java.util.List;

public final class Field {
    enum Kind {
        U8, U16, U32, U64,
        I8, I16, I32, I64,
        F32, F64,
        BYTES,
        BOOL,
        FLAGS,
        FLAG_BYTE,
        FLAG_BIT,
        WHEN,
        REPEAT,
        GROUP,
        SIZED,
        U2,
        BITS,
        UTF8,
        LIST,
        DICT
    }

    final Kind kind;
    final int id;
    final Getter get;
    final Setter set;
    final boolean bigEndian;
    final int size;
    final List<Field> children;
    final Packbin.Eq condition;
    final FlagGroup group;
    final int bitIndex;
    final Field inner;
    final int countId;
    final List<Integer> slotIds;
    final boolean nestedRow;

    private Field(
            Kind kind,
            int id,
            Getter get,
            Setter set,
            boolean bigEndian,
            int size,
            List<Field> children,
            Packbin.Eq condition,
            FlagGroup group,
            int bitIndex,
            Field inner,
            int countId,
            List<Integer> slotIds,
            boolean nestedRow) {
        this.kind = kind;
        this.id = id;
        this.get = get;
        this.set = set;
        this.bigEndian = bigEndian;
        this.size = size;
        this.children = children == null ? List.of() : List.copyOf(children);
        this.condition = condition;
        this.group = group;
        this.bitIndex = bitIndex;
        this.inner = inner;
        this.countId = countId;
        this.slotIds = slotIds == null ? List.of() : List.copyOf(slotIds);
        this.nestedRow = nestedRow;
    }

    String label() {
        return Integer.toString(id);
    }

    static boolean isValueBearing(Field field) {
        return switch (field.kind) {
            case U8, U16, U32, U64, I8, I16, I32, I64, F32, F64,
                    BYTES, BOOL, SIZED, BITS, UTF8, U2 -> true;
            default -> false;
        };
    }

    static Field scalar(Kind kind, int id, Getter get, Setter set, int size) {
        return new Field(
                kind,
                id,
                get,
                set,
                false,
                size,
                null,
                null,
                null,
                0,
                null,
                -1,
                null,
                false);
    }

    static Field of(Kind kind, int id, Getter get, Setter set, int size, int countId) {
        return new Field(
                kind,
                id,
                get,
                set,
                false,
                size,
                null,
                null,
                null,
                0,
                null,
                countId,
                null,
                false);
    }

    static Field u2(List<Field> slots) {
        if (slots.isEmpty()) {
            throw new IllegalArgumentException("u2 needs at least one slot");
        }
        List<Integer> ids = new ArrayList<>(slots.size());
        for (Field slot : slots) {
            ids.add(slot.id);
        }
        Field first = slots.get(0);
        return new Field(
                Kind.U2,
                first.id,
                first.get,
                first.set,
                false,
                0,
                List.copyOf(slots),
                null,
                null,
                0,
                null,
                -1,
                ids,
                false);
    }

    static Field flags(Field[] fields) {
        FlagGroup group = new FlagGroup();
        List<Field> bits = new ArrayList<>(fields.length);
        for (Field field : fields) {
            bits.add(group.addBit(field));
        }
        return new Field(Kind.FLAGS, -1, null, null, false, 1, bits, null, group, 0, null, -1, null, false);
    }

    static Field flagByte() {
        FlagGroup group = new FlagGroup();
        return new Field(Kind.FLAG_BYTE, -1, null, null, false, 1, null, null, group, 0, null, -1, null, false);
    }

    static Field flagBit(FlagGroup group, int bitIndex, Field inner) {
        return new Field(
                Kind.FLAG_BIT,
                inner.id,
                inner.get,
                inner.set,
                false,
                0,
                null,
                null,
                group,
                bitIndex,
                inner,
                -1,
                null,
                false);
    }

    static Field when(Packbin.Eq condition, Field[] fields) {
        return new Field(Kind.WHEN, -1, null, null, false, 0, List.of(fields), condition, null, 0, null, -1, null, false);
    }

    static Field repeat(Field[] fields) {
        return new Field(Kind.REPEAT, -1, null, null, false, 0, List.of(fields), null, null, 0, null, -1, null, false);
    }

    static Field group(Getter get, Setter set, Field[] fields, boolean nested) {
        return new Field(
                Kind.GROUP,
                -1,
                get,
                set,
                false,
                0,
                List.of(fields),
                null,
                null,
                0,
                null,
                -1,
                null,
                nested);
    }

    static Field group(Field[] fields) {
        return new Field(Kind.GROUP, -1, null, null, false, 0, List.of(fields), null, null, 0, null, -1, null, false);
    }

    static Field list(Getter get, Setter set, Field element) {
        if (element.kind == Kind.REPEAT) {
            throw new IllegalArgumentException("repeat is not a list element");
        }
        return new Field(
                Kind.LIST,
                -1,
                get,
                set,
                false,
                0,
                List.of(element),
                null,
                null,
                0,
                null,
                -1,
                null,
                false);
    }

    static Field dict(Getter get, Setter set, Field element) {
        if (element.kind == Kind.REPEAT) {
            throw new IllegalArgumentException("repeat is not a dictionary element");
        }
        return new Field(
                Kind.DICT,
                -1,
                get,
                set,
                false,
                0,
                List.of(element),
                null,
                null,
                0,
                null,
                -1,
                null,
                false);
    }

    Field withBigEndian() {
        if (kind != Kind.U8 && kind != Kind.U16 && kind != Kind.U32 && kind != Kind.U64
                && kind != Kind.I8 && kind != Kind.I16 && kind != Kind.I32 && kind != Kind.I64
                && kind != Kind.F32 && kind != Kind.F64) {
            throw new IllegalArgumentException("be() expects a numeric field");
        }
        return new Field(
                kind, id, get, set, true, size, children, condition, group, bitIndex, inner, countId, slotIds, nestedRow);
    }

    public Field bit(Field field) {
        if (kind != Kind.FLAG_BYTE || group == null) {
            throw new IllegalStateException("bit() requires flagByte");
        }
        return group.addBit(field);
    }
}

final class FlagGroup {
    final List<Field> bitInners = new ArrayList<>();
    int unpacked;

    Field addBit(Field inner) {
        int index = bitInners.size();
        if (index >= 8) {
            throw new IllegalArgumentException("flags already has 8 bits");
        }
        bitInners.add(inner);
        return Field.flagBit(this, index, inner);
    }

    int compute(Object row) {
        int flags = 0;
        for (int i = 0; i < bitInners.size(); i++) {
            if (Walker.childOn(row, bitInners.get(i))) {
                flags |= 1 << i;
            }
        }
        return flags;
    }

    List<Field> bits() {
        return Collections.unmodifiableList(bitInners);
    }
}
