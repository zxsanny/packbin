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
        DICT,
        TYPE_NUM
    }

    final Kind kind;
    final String name;
    final boolean bigEndian;
    final int size;
    final List<Field> children;
    final Packbin.Eq condition;
    final FlagGroup group;
    final int bitIndex;
    final Field inner;
    final String countName;
    final List<String> names;
    final int constant;

    private Field(
            Kind kind,
            String name,
            boolean bigEndian,
            int size,
            List<Field> children,
            Packbin.Eq condition,
            FlagGroup group,
            int bitIndex,
            Field inner,
            String countName,
            List<String> names,
            int constant) {
        this.kind = kind;
        this.name = name;
        this.bigEndian = bigEndian;
        this.size = size;
        this.children = children == null ? List.of() : List.copyOf(children);
        this.condition = condition;
        this.group = group;
        this.bitIndex = bitIndex;
        this.inner = inner;
        this.countName = countName;
        this.names = names == null ? List.of() : List.copyOf(names);
        this.constant = constant;
    }

    static Field scalar(Kind kind, String name, int size) {
        return new Field(kind, name, false, size, null, null, null, 0, null, null, null, 0);
    }

    static Field bytes(String name, int n) {
        return new Field(Kind.BYTES, name, false, n, null, null, null, 0, null, null, null, 0);
    }

    static Field typeNum(int value) {
        return new Field(Kind.TYPE_NUM, "", false, 1, null, null, null, 0, null, null, null, value);
    }

    static Field flags(String name, Field[] fields) {
        rejectNestedTypeNum(fields);
        FlagGroup group = new FlagGroup(name);
        List<Field> bits = new ArrayList<>(fields.length);
        for (Field field : fields) {
            bits.add(group.addBit(field));
        }
        return new Field(Kind.FLAGS, name, false, 1, bits, null, group, 0, null, null, null, 0);
    }

    static Field flagByte(String name) {
        FlagGroup group = new FlagGroup(name);
        return new Field(Kind.FLAG_BYTE, name, false, 1, null, null, group, 0, null, null, null, 0);
    }

    static Field flagBit(FlagGroup group, int bitIndex, Field inner) {
        return new Field(Kind.FLAG_BIT, inner.name, false, 0, null, null, group, bitIndex, inner, null, null, 0);
    }

    static Field when(Packbin.Eq condition, Field[] fields) {
        rejectNestedTypeNum(fields);
        return new Field(Kind.WHEN, condition.field, false, 0, List.of(fields), condition, null, 0, null, null, null, 0);
    }

    static Field repeat(Field[] fields) {
        rejectNestedTypeNum(fields);
        return new Field(Kind.REPEAT, "", false, 0, List.of(fields), null, null, 0, null, null, null, 0);
    }

    static Field group(String name, Field[] fields) {
        rejectNestedTypeNum(fields);
        return new Field(Kind.GROUP, name, false, 0, List.of(fields), null, null, 0, null, null, null, 0);
    }

    static Field sized(String name, String countField) {
        return new Field(Kind.SIZED, name, false, 0, null, null, null, 0, null, countField, null, 0);
    }

    static Field u2(String[] names) {
        if (names.length == 0) {
            throw new IllegalArgumentException("u2 needs at least one name");
        }
        return new Field(Kind.U2, names[0], false, 0, null, null, null, 0, null, null, List.of(names), 0);
    }

    static Field bits(String name, String countField) {
        return new Field(Kind.BITS, name, false, 0, null, null, null, 0, null, countField, null, 0);
    }

    static Field utf8(String name) {
        return new Field(Kind.UTF8, name, false, 0, null, null, null, 0, null, null, null, 0);
    }

    static Field list(String name, Field element) {
        if (element.kind == Kind.REPEAT) {
            throw new IllegalArgumentException("repeat is not a list element");
        }
        rejectNestedTypeNum(element);
        return new Field(Kind.LIST, name, false, 0, List.of(element), null, null, 0, null, null, null, 0);
    }

    static Field dict(String name, Field element) {
        if (element.kind == Kind.REPEAT) {
            throw new IllegalArgumentException("repeat is not a dictionary element");
        }
        rejectNestedTypeNum(element);
        return new Field(Kind.DICT, name, false, 0, List.of(element), null, null, 0, null, null, null, 0);
    }

    static void rejectNestedTypeNum(Field... fields) {
        for (Field field : fields) {
            if (field.kind == Kind.TYPE_NUM) {
                throw new IllegalArgumentException("type number cannot be nested");
            }
            rejectNestedTypeNum(field.children.toArray(Field[]::new));
            if (field.inner != null) {
                rejectNestedTypeNum(field.inner);
            }
        }
    }

    Field withBigEndian() {
        if (kind != Kind.U8 && kind != Kind.U16 && kind != Kind.U32 && kind != Kind.U64
                && kind != Kind.I8 && kind != Kind.I16 && kind != Kind.I32 && kind != Kind.I64
                && kind != Kind.F32 && kind != Kind.F64) {
            throw new IllegalArgumentException("be() expects a numeric field");
        }
        return new Field(kind, name, true, size, children, condition, group, bitIndex, inner, countName, names, constant);
    }

    public Field bit(Field field) {
        if (kind != Kind.FLAG_BYTE || group == null) {
            throw new IllegalStateException("bit() requires flagByte");
        }
        rejectNestedTypeNum(field);
        return group.addBit(field);
    }

    String fieldName() {
        if (kind == Kind.FLAG_BIT) {
            return inner.fieldName();
        }
        return name;
    }
}

final class FlagGroup {
    final String name;
    final List<Field> bitInners = new ArrayList<>();
    int unpacked;

    FlagGroup(String name) {
        this.name = name;
    }

    Field addBit(Field inner) {
        int index = bitInners.size();
        if (index >= 8) {
            throw new IllegalArgumentException("flags '" + name + "' already has 8 bits");
        }
        bitInners.add(inner);
        return Field.flagBit(this, index, inner);
    }

    int compute(java.util.Map<String, Object> values) {
        int flags = 0;
        for (int i = 0; i < bitInners.size(); i++) {
            Field inner = bitInners.get(i);
            boolean on = inner.kind == Field.Kind.GROUP
                    ? Walker.groupOn(values, inner)
                    : Walker.isPresent(values, inner.name);
            if (on) {
                flags |= 1 << i;
            }
        }
        return flags;
    }

    List<Field> bits() {
        return Collections.unmodifiableList(bitInners);
    }
}
