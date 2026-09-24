package packbin;

import java.util.Map;

public final class Packbin {
    private Packbin() {}

    public static Field u8(String name) {
        return Field.scalar(Field.Kind.U8, name, 1);
    }

    public static Field u16(String name) {
        return Field.scalar(Field.Kind.U16, name, 2);
    }

    public static Field u32(String name) {
        return Field.scalar(Field.Kind.U32, name, 4);
    }

    public static Field u64(String name) {
        return Field.scalar(Field.Kind.U64, name, 8);
    }

    public static Field i8(String name) {
        return Field.scalar(Field.Kind.I8, name, 1);
    }

    public static Field i16(String name) {
        return Field.scalar(Field.Kind.I16, name, 2);
    }

    public static Field i32(String name) {
        return Field.scalar(Field.Kind.I32, name, 4);
    }

    public static Field i64(String name) {
        return Field.scalar(Field.Kind.I64, name, 8);
    }

    public static Field f32(String name) {
        return Field.scalar(Field.Kind.F32, name, 4);
    }

    public static Field f64(String name) {
        return Field.scalar(Field.Kind.F64, name, 8);
    }

    public static Field bytes(String name, int n) {
        if (n < 0) {
            throw new IllegalArgumentException("bytes length must be >= 0");
        }
        return Field.bytes(name, n);
    }

    public static Field be(Field field) {
        return field.withBigEndian();
    }

    public static Field flags(String name, Field... fields) {
        return Field.flags(name, fields);
    }

    public static Field flagByte(String name) {
        return Field.flagByte(name);
    }

    public static Eq eq(String field, Object value) {
        return new Eq(field, value);
    }

    public static Field when(Eq condition, Field... fields) {
        return Field.when(condition, fields);
    }

    public static final class Eq {
        final String field;
        final Object value;

        Eq(String field, Object value) {
            this.field = field;
            this.value = value;
        }
    }

    public static Field repeat(Field... fields) {
        return Field.repeat(fields);
    }

    public static Field group(String name, Field... fields) {
        return Field.group(name, fields);
    }

    public static Field sized(String name, String countField) {
        return Field.sized(name, countField);
    }

    public static Field u2(String... names) {
        return Field.u2(names);
    }

    public static Field bits(String name, String countField) {
        return Field.bits(name, countField);
    }

    public static Field utf8(String name) {
        return Field.utf8(name);
    }

    public static Field list(String name, Field element) {
        return Field.list(name, element);
    }

    public static Field dict(String name, Field element) {
        return Field.dict(name, element);
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

    public static final class UnpackResult {
        public final boolean ok;
        public final Map<String, Object> value;
        public final Object error;

        private UnpackResult(boolean ok, Map<String, Object> value, Object error) {
            this.ok = ok;
            this.value = value;
            this.error = error;
        }

        static UnpackResult ok(Map<String, Object> value) {
            return new UnpackResult(true, Map.copyOf(value), null);
        }

        static UnpackResult fail(Object error) {
            return new UnpackResult(false, Map.of(), error);
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
    }
}
