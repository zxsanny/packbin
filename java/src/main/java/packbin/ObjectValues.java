package packbin;

import java.lang.reflect.Field;
import java.lang.reflect.Method;
import java.lang.reflect.Modifier;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

final class ObjectValues {
    private ObjectValues() {}

    static Map<String, Object> read(Object value) {
        Map<String, Object> dict = new LinkedHashMap<>();
        if (value != null) {
            collect(value, dict);
        }
        return dict;
    }

    static Map<String, Object> asMap(Map<?, ?> map) {
        Map<String, Object> dict = new LinkedHashMap<>();
        for (Map.Entry<?, ?> entry : map.entrySet()) {
            if (entry.getKey() instanceof String key) {
                dict.put(key, entry.getValue());
            }
        }
        return dict;
    }

    static <T> T write(Class<T> type, Map<String, Object> values) {
        try {
            var ctor = type.getDeclaredConstructor();
            ctor.setAccessible(true);
            T target = ctor.newInstance();
            apply(target, values);
            return target;
        } catch (ReflectiveOperationException ex) {
            throw new IllegalStateException("Cannot create " + type.getName(), ex);
        }
    }

    private static void collect(Object value, Map<String, Object> dict) {
        for (Member member : members(value.getClass())) {
            Object raw = member.read(value);
            if (raw == null) {
                continue;
            }
            if (nested(member.type)) {
                collect(raw, dict);
            } else {
                dict.put(member.name, raw);
            }
        }
    }

    private static void apply(Object target, Map<String, Object> values) {
        for (Member member : members(target.getClass())) {
            if (nested(member.type)) {
                if (!containsAny(member.type, values)) {
                    continue;
                }
                Object child = write(member.type, values);
                member.write(target, child);
                continue;
            }
            if (!values.containsKey(member.name) || values.get(member.name) == null) {
                continue;
            }
            member.write(target, narrow(values.get(member.name), member.type));
        }
    }

    private static boolean containsAny(Class<?> type, Map<String, Object> values) {
        for (Member member : members(type)) {
            if (nested(member.type)) {
                if (containsAny(member.type, values)) {
                    return true;
                }
            } else if (values.containsKey(member.name) && values.get(member.name) != null) {
                return true;
            }
        }
        return false;
    }

    private static boolean nested(Class<?> type) {
        if (type.isPrimitive() || type.isArray() || type.isEnum()) {
            return false;
        }
        if (type == String.class || Number.class.isAssignableFrom(type) || type == Boolean.class) {
            return false;
        }
        if (Iterable.class.isAssignableFrom(type) || Map.class.isAssignableFrom(type)) {
            return false;
        }
        return !type.isInterface();
    }

    private static Object narrow(Object value, Class<?> type) {
        Class<?> boxed = box(type);
        if (boxed.isInstance(value)) {
            return value;
        }
        if (value instanceof Number number) {
            if (boxed == Byte.class) {
                return number.byteValue();
            }
            if (boxed == Short.class) {
                return number.shortValue();
            }
            if (boxed == Integer.class) {
                return number.intValue();
            }
            if (boxed == Long.class) {
                return number.longValue();
            }
            if (boxed == Float.class) {
                return number.floatValue();
            }
            if (boxed == Double.class) {
                return number.doubleValue();
            }
        }
        return value;
    }

    private static Class<?> box(Class<?> type) {
        if (type == byte.class) return Byte.class;
        if (type == short.class) return Short.class;
        if (type == int.class) return Integer.class;
        if (type == long.class) return Long.class;
        if (type == float.class) return Float.class;
        if (type == double.class) return Double.class;
        if (type == boolean.class) return Boolean.class;
        if (type == char.class) return Character.class;
        return type;
    }

    private static List<Member> members(Class<?> type) {
        List<Member> out = new ArrayList<>();
        List<String> names = new ArrayList<>();
        for (Field field : type.getFields()) {
            if (Modifier.isStatic(field.getModifiers())) {
                continue;
            }
            names.add(field.getName());
            out.add(new Member(field.getName(), field.getType(), field::get, field::set));
        }
        for (Method method : type.getMethods()) {
            if (method.getDeclaringClass() == Object.class || method.getParameterCount() != 0) {
                continue;
            }
            if (Modifier.isStatic(method.getModifiers())) {
                continue;
            }
            String name = beanName(method.getName());
            if (name == null || names.contains(name)) {
                continue;
            }
            Method setter = setter(type, name, method.getReturnType());
            if (setter == null) {
                continue;
            }
            names.add(name);
            out.add(new Member(name, method.getReturnType(), target -> method.invoke(target), (target, value) -> setter.invoke(target, value)));
        }
        return out;
    }

    private static String beanName(String method) {
        String rest;
        if (method.startsWith("get") && method.length() > 3) {
            rest = method.substring(3);
        } else if (method.startsWith("is") && method.length() > 2) {
            rest = method.substring(2);
        } else {
            return null;
        }
        if (rest.length() > 1 && Character.isUpperCase(rest.charAt(1))) {
            return rest;
        }
        return Character.toLowerCase(rest.charAt(0)) + rest.substring(1);
    }

    private static Method setter(Class<?> type, String name, Class<?> arg) {
        String method = "set" + Character.toUpperCase(name.charAt(0)) + name.substring(1);
        try {
            return type.getMethod(method, arg);
        } catch (NoSuchMethodException ex) {
            return null;
        }
    }

    @FunctionalInterface
    private interface Read {
        Object get(Object target) throws ReflectiveOperationException;
    }

    @FunctionalInterface
    private interface Write {
        void set(Object target, Object value) throws ReflectiveOperationException;
    }

    private static final class Member {
        final String name;
        final Class<?> type;
        final Read read;
        final Write write;

        Member(String name, Class<?> type, Read read, Write write) {
            this.name = name;
            this.type = type;
            this.read = read;
            this.write = write;
        }

        Object read(Object target) {
            try {
                return read.get(target);
            } catch (ReflectiveOperationException ex) {
                throw new IllegalStateException(name, ex);
            }
        }

        void write(Object target, Object value) {
            try {
                write.set(target, value);
            } catch (ReflectiveOperationException ex) {
                throw new IllegalStateException(name, ex);
            }
        }
    }
}
