package packbin;

import java.util.HashMap;
import java.util.List;
import java.util.Map;

final class SchemeOrder {
    private SchemeOrder() {}

    static void validate(List<Field> fields) {
        Map<Integer, Field> scope = new HashMap<>();
        int[] next = {0};
        for (Field field : fields) {
            walk(field, scope, next);
        }
        resolve(fields, scope);
    }

    private static void walk(Field field, Map<Integer, Field> scope, int[] next) {
        switch (field.kind) {
            case WHEN, REPEAT, FLAGS -> {
                for (Field child : field.children) {
                    walk(child, scope, next);
                }
            }
            case FLAG_BIT -> walk(field.inner, scope, next);
            case FLAG_BYTE -> {}
            case GROUP -> {
                if (field.nestedRow) {
                    Map<Integer, Field> nested = new HashMap<>();
                    int[] nestedNext = {0};
                    for (Field child : field.children) {
                        walk(child, nested, nestedNext);
                    }
                    resolve(field.children, nested);
                } else {
                    for (Field child : field.children) {
                        walk(child, scope, next);
                    }
                }
            }
            case LIST, DICT -> {
                Map<Integer, Field> nested = new HashMap<>();
                int[] nestedNext = {0};
                walk(field.children.get(0), nested, nestedNext);
                resolve(field.children, nested);
            }
            case U2 -> {
                for (Field slot : field.children) {
                    take(slot.id, slot, scope, next);
                }
            }
            default -> {
                if (Field.isValueBearing(field)) {
                    take(field.id, field, scope, next);
                }
            }
        }
    }

    private static void take(int id, Field field, Map<Integer, Field> scope, int[] next) {
        if (id != next[0]) {
            throw new IllegalArgumentException("field id " + id + " must be " + next[0]);
        }
        if (scope.put(id, field) != null) {
            throw new IllegalArgumentException("duplicate field id " + id);
        }
        next[0]++;
    }

    private static void resolve(List<Field> fields, Map<Integer, Field> scope) {
        for (Field field : fields) {
            resolveField(field, scope);
        }
    }

    private static void resolveField(Field field, Map<Integer, Field> scope) {
        switch (field.kind) {
            case WHEN -> {
                if (!scope.containsKey(field.condition.fieldId)) {
                    throw new IllegalArgumentException(
                            "condition field id " + field.condition.fieldId + " is unknown");
                }
                for (Field child : field.children) {
                    resolveField(child, scope);
                }
            }
            case SIZED, BITS -> {
                if (!scope.containsKey(field.countId)) {
                    throw new IllegalArgumentException("count field id " + field.countId + " is unknown");
                }
            }
            case FLAGS, REPEAT -> {
                for (Field child : field.children) {
                    resolveField(child, scope);
                }
            }
            case FLAG_BIT -> resolveField(field.inner, scope);
            case GROUP -> {
                if (!field.nestedRow) {
                    for (Field child : field.children) {
                        resolveField(child, scope);
                    }
                }
            }
            default -> {}
        }
    }
}
