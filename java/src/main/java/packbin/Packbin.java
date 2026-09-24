package packbin;

public final class Packbin {
    private Packbin() {}

    public static Field u8(int id, Getter get, Setter set) {
        return Field.scalar(Field.Kind.U8, id, get, set, 1);
    }

    public static Field u16(int id, Getter get, Setter set) {
        return Field.scalar(Field.Kind.U16, id, get, set, 2);
    }

    public static Field u32(int id, Getter get, Setter set) {
        return Field.scalar(Field.Kind.U32, id, get, set, 4);
    }

    public static Field u64(int id, Getter get, Setter set) {
        return Field.scalar(Field.Kind.U64, id, get, set, 8);
    }

    public static Field i8(int id, Getter get, Setter set) {
        return Field.scalar(Field.Kind.I8, id, get, set, 1);
    }

    public static Field i16(int id, Getter get, Setter set) {
        return Field.scalar(Field.Kind.I16, id, get, set, 2);
    }

    public static Field i32(int id, Getter get, Setter set) {
        return Field.scalar(Field.Kind.I32, id, get, set, 4);
    }

    public static Field i64(int id, Getter get, Setter set) {
        return Field.scalar(Field.Kind.I64, id, get, set, 8);
    }

    public static Field f32(int id, Getter get, Setter set) {
        return Field.scalar(Field.Kind.F32, id, get, set, 4);
    }

    public static Field f64(int id, Getter get, Setter set) {
        return Field.scalar(Field.Kind.F64, id, get, set, 8);
    }

    public static Field bytes(int id, Getter get, Setter set, int n) {
        if (n < 0) {
            throw new IllegalArgumentException("bytes length must be >= 0");
        }
        return Field.scalar(Field.Kind.BYTES, id, get, set, n);
    }

    public static Field boolField(int id, Getter get, Setter set) {
        return Field.scalar(Field.Kind.BOOL, id, get, set, 0);
    }

    public static Field be(Field field) {
        return field.withBigEndian();
    }

    public static Field flags(Field... fields) {
        return Field.flags(fields);
    }

    public static Field flagByte() {
        return Field.flagByte();
    }

    public static Eq eq(int fieldId, Object value) {
        return new Eq(fieldId, value);
    }

    public static Field when(Eq condition, Field... fields) {
        return Field.when(condition, fields);
    }

    public static final class Eq {
        final int fieldId;
        final Object value;

        Eq(int fieldId, Object value) {
            this.fieldId = fieldId;
            this.value = value;
        }
    }

    public static Field repeat(Field... fields) {
        return Field.repeat(fields);
    }

    public static Field group(Field... fields) {
        return Field.group(fields);
    }

    public static Field group(Getter get, Setter set, Field... fields) {
        return Field.group(get, set, fields, true);
    }

    public static Field sized(int id, Getter get, Setter set, int countId) {
        return Field.of(Field.Kind.SIZED, id, get, set, 0, countId);
    }

    public static Field u2(Field... slots) {
        return Field.u2(java.util.List.of(slots));
    }

    public static Field u2Slot(int id, Getter get, Setter set) {
        return Field.scalar(Field.Kind.U8, id, get, set, 0);
    }

    public static Field bits(int id, Getter get, Setter set, int countId) {
        return Field.of(Field.Kind.BITS, id, get, set, 0, countId);
    }

    public static Field utf8(int id, Getter get, Setter set) {
        return Field.scalar(Field.Kind.UTF8, id, get, set, 0);
    }

    public static Field list(Getter get, Setter set, Field element) {
        return Field.list(get, set, element);
    }

    public static Field dict(Getter get, Setter set, Field element) {
        return Field.dict(get, set, element);
    }

    public static final class ShortPacket {
        public final String field;
        public final int needed;
        public final int left;

        public ShortPacket(String field, int needed, int left) {
            this.field = field;
            this.needed = needed;
            this.left = left;
        }
    }

    public static final class TrailingBytes {
        public final int left;

        public TrailingBytes(int left) {
            this.left = left;
        }
    }

    public static final class TypeMismatch {
        public final int expected;
        public final int actual;

        public TypeMismatch(int expected, int actual) {
            this.expected = expected;
            this.actual = actual;
        }
    }

    public static final class Bound<T> {
        public final boolean ok;
        public final T value;
        public final Object error;

        private Bound(boolean ok, T value, Object error) {
            this.ok = ok;
            this.value = value;
            this.error = error;
        }

        static <T> Bound<T> ok(T value) {
            return new Bound<>(true, value, null);
        }

        static <T> Bound<T> fail(Object error) {
            return new Bound<>(false, null, error);
        }

        public String field() {
            return error instanceof ShortPacket s ? s.field : null;
        }

        public Integer needed() {
            return error instanceof ShortPacket s ? s.needed : null;
        }

        public Integer left() {
            if (error instanceof ShortPacket s) {
                return s.left;
            }
            if (error instanceof TrailingBytes t) {
                return t.left;
            }
            return null;
        }
    }
}
