package packbin;

import java.util.ArrayList;
import java.util.List;
import java.util.Map;

final class VarFields {
    private VarFields() {}

    static void packSized(Field field, Map<String, Object> values, ByteSink sink) {
        int count = requireCount(field.countName, values.get(field.countName));
        Object raw = values.get(field.name);
        if (!(raw instanceof byte[] bytes)) {
            throw new IllegalArgumentException(field.name + ": expected bytes");
        }
        if (bytes.length != count) {
            throw new IllegalArgumentException(
                    field.name + ": expected " + count + " bytes, got " + bytes.length);
        }
        sink.write(bytes);
    }

    static Object unpackSized(
            Field field,
            byte[] data,
            int[] offset,
            Map<String, Object> values,
            boolean asList) {
        int count = requireCount(field.countName, values.get(field.countName));
        int left = data.length - offset[0];
        if (left < count) {
            return new Packbin.ShortPacket(field.name, count, left);
        }
        byte[] raw = new byte[count];
        System.arraycopy(data, offset[0], raw, 0, count);
        offset[0] += count;
        Walker.store(values, field.name, raw, asList);
        return null;
    }

    static void packU2(Field field, Map<String, Object> values, ByteSink sink) {
        List<String> names = field.names;
        int nbytes = (names.size() + 3) / 4;
        byte[] raw = new byte[nbytes];
        for (int i = 0; i < names.size(); i++) {
            String name = names.get(i);
            int n = requireU2(name, values.get(name));
            raw[i / 4] |= (byte) (n << ((i % 4) * 2));
        }
        sink.write(raw);
    }

    static Object unpackU2(
            Field field,
            byte[] data,
            int[] offset,
            Map<String, Object> values,
            boolean asList) {
        List<String> names = field.names;
        int nbytes = (names.size() + 3) / 4;
        int left = data.length - offset[0];
        if (left < nbytes) {
            return new Packbin.ShortPacket(names.get(0), nbytes, left);
        }
        for (int i = 0; i < names.size(); i++) {
            int value = (data[offset[0] + i / 4] >> ((i % 4) * 2)) & 3;
            Walker.store(values, names.get(i), value, asList);
        }
        offset[0] += nbytes;
        return null;
    }

    static void packBits(Field field, Map<String, Object> values, ByteSink sink) {
        int count = requireCount(field.countName, values.get(field.countName));
        Object raw = values.get(field.name);
        if (!(raw instanceof List<?> bits) || bits.size() != count) {
            throw new IllegalArgumentException(field.name + ": expected " + count + " bits");
        }
        int nbytes = (count + 7) / 8;
        byte[] packed = new byte[nbytes];
        for (int i = 0; i < count; i++) {
            int bit = requireBit(field.name, bits.get(i));
            packed[i / 8] |= (byte) (bit << (i % 8));
        }
        sink.write(packed);
    }

    static Object unpackBits(
            Field field,
            byte[] data,
            int[] offset,
            Map<String, Object> values,
            boolean asList) {
        int count = requireCount(field.countName, values.get(field.countName));
        int nbytes = (count + 7) / 8;
        int left = data.length - offset[0];
        if (left < nbytes) {
            return new Packbin.ShortPacket(field.name, nbytes, left);
        }
        List<Integer> out = new ArrayList<>(count);
        for (int i = 0; i < count; i++) {
            out.add((data[offset[0] + i / 8] >> (i % 8)) & 1);
        }
        offset[0] += nbytes;
        Walker.store(values, field.name, out, asList);
        return null;
    }

    private static int requireCount(String name, Object value) {
        if (!(value instanceof Number) || value instanceof Float || value instanceof Double) {
            throw new IllegalStateException(name + ": count is missing");
        }
        return ((Number) value).intValue();
    }

    private static int requireU2(String name, Object value) {
        if (value instanceof Boolean
                || !(value instanceof Number)
                || value instanceof Float
                || value instanceof Double) {
            throw new IllegalArgumentException(name + ": expected 2-bit int");
        }
        int n = ((Number) value).intValue();
        if (n < 0 || n > 3) {
            throw new IllegalArgumentException(name + ": expected 2-bit int");
        }
        return n;
    }

    private static int requireBit(String name, Object value) {
        if (!(value instanceof Number) || value instanceof Float || value instanceof Double) {
            throw new IllegalArgumentException(name + ": expected 0 or 1");
        }
        int n = ((Number) value).intValue();
        if (n != 0 && n != 1) {
            throw new IllegalArgumentException(name + ": expected 0 or 1");
        }
        return n;
    }
}
