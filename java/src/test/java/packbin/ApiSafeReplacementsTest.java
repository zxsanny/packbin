package packbin;

import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

/**
 * AZ-2094: the Android API 26 replacements keep dict key order (unsigned UTF-8 byte order) and keep a
 * Field's or Scheme's child list an immutable copy.
 */
@SuppressWarnings({"unchecked", "rawtypes"})
final class ApiSafeReplacementsTest {
    private ApiSafeReplacementsTest() {}

    // Recorded from the build before the change: keys "", a, ab, b, z, then 0xc3 0xa9 and 0xc3 0xa9 0x61.
    private static final String UNSIGNED_ORDER_HEX =
            "01070000000100370100610100340200616201003501006201003301007a0100310200c3a90100320300c3a961010036";

    static void run() {
        dictKeysSortAsUnsignedBytes();
        fieldChildrenAreAnImmutableCopy();
        schemeFieldsAreAnImmutableCopy();
    }

    private static void dictKeysSortAsUnsignedBytes() {
        Scheme<Map> scheme = Maps.scheme(1, Packbin.dict(
                Access.get("m"), Access.set("m"), Packbin.utf8(0, Access.identity(), Access.ignore())));
        Map<String, Object> keys = new LinkedHashMap<>();
        keys.put("z", "1");
        keys.put("é", "2");
        keys.put("b", "3");
        keys.put("a", "4");
        keys.put("ab", "5");
        keys.put("éa", "6");
        keys.put("", "7");
        PackbinTest.expectEq("unsigned key order",
                UNSIGNED_ORDER_HEX, PackbinTest.toHex(BinaryPacker.pack(scheme, Maps.map("m", keys))));
    }

    private static void fieldChildrenAreAnImmutableCopy() {
        List<Field> slots = new ArrayList<>();
        slots.add(Packbin.u2Slot(0, Access.get("a"), Access.set("a")));
        slots.add(Packbin.u2Slot(1, Access.get("b"), Access.set("b")));
        Field field = Field.u2(slots);
        slots.add(Packbin.u2Slot(2, Access.get("c"), Access.set("c")));
        slots.remove(0);
        PackbinTest.expectEq("field children keep the original two", 2, field.children.size());
        expectUnsupported("field children add", () -> field.children.add(slots.get(0)));
        expectUnsupported("field children remove", () -> field.children.remove(0));

        Field[] array = {Packbin.u8(0, Access.get("a"), Access.set("a"))};
        Field group = Packbin.group(0, array);
        array[0] = null;
        PackbinTest.expectTrue("group child survives its source array changing", group.children.get(0) != null);
        expectUnsupported("group children clear", group.children::clear);
    }

    private static void schemeFieldsAreAnImmutableCopy() {
        Field[] array = {Packbin.u8(0, Access.get("a"), Access.set("a"))};
        Scheme<Map> scheme = new Scheme<>(1, (Class) Map.class, array);
        array[0] = null;
        PackbinTest.expectTrue("scheme field survives its source array changing", scheme.fields.get(0) != null);
        expectUnsupported("scheme fields add", () -> scheme.fields.add(scheme.fields.get(0)));
    }

    private static void expectUnsupported(String label, Runnable action) {
        try {
            action.run();
        } catch (UnsupportedOperationException ex) {
            return;
        }
        PackbinTest.fail(label + ": no UnsupportedOperationException");
    }
}
