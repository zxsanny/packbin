package packbin;

import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.LinkedList;
import java.util.List;
import java.util.Map;
import java.util.TreeMap;

/**
 * AZ-4255 (owner decision D12 B): unpack hands a list field an {@code ArrayList} and a dict field a
 * {@code LinkedHashMap}. A setter that rejects it (a field declared {@code LinkedList} or {@code TreeMap}) gets the
 * package's own error naming the field, not a raw {@code ClassCastException}; a cast failure of anything else inside the
 * caller's setter is not hidden.
 */
@SuppressWarnings("unchecked")
final class CollectionTypeTest {
    private CollectionTypeTest() {}

    static void run() {
        ac1LinkedListOfValuesIsRefusedAtUnpack();
        ac2TreeMapOfValuesIsRefusedAtUnpack();
        ac3AnotherCastFailureIsNotHidden();
        ac4AcceptedTypesAreUnchanged();
    }

    static final class Row {
        public List<Integer> list;
        public LinkedList<Integer> linked;
        public Map<String, Integer> map;
        public TreeMap<String, Integer> tree;
    }

    private static Field u8() {
        return Packbin.u8(0, Access.identity(), Access.ignore());
    }

    private static Scheme<Row> linkedScheme() {
        return new Scheme<>(1, Row.class, Packbin.list(Access.get((Row r) -> r.linked),
                Access.set((Row r, Object v) -> r.linked = (LinkedList<Integer>) v), u8()));
    }

    private static Scheme<Row> treeScheme() {
        return new Scheme<>(1, Row.class, Packbin.dict(Access.get((Row r) -> r.tree),
                Access.set((Row r, Object v) -> r.tree = (TreeMap<String, Integer>) v), u8()));
    }

    private static final byte[] LIST_OF_TWO = PackbinTest.parseHex("0102000105");
    private static final byte[] DICT_OF_ONE = PackbinTest.parseHex("010100021061" + "07");

    private static void expectRefusedUnpack(String label, Scheme<Row> scheme, byte[] bytes, String message) {
        PackbinTest.expectThrows(label, () -> BinaryPacker.unpack(bytes, scheme.on(r -> {})), message);
    }

    private static void ac1LinkedListOfValuesIsRefusedAtUnpack() {
        // Arrange: a list of plain values in a LinkedList field (not only element rows).
        Scheme<Row> scheme = linkedScheme();
        Row row = new Row();
        row.linked = new LinkedList<>(List.of(1, 5));

        // Act: pack still works; unpack refuses.
        byte[] packed = BinaryPacker.pack(scheme, row);

        // Assert
        PackbinTest.expectEq("AZ-4255 AC-1 pack bytes unchanged", "0102000105", PackbinTest.toHex(packed));
        expectRefusedUnpack("AZ-4255 AC-1 linked list", scheme, packed,
                "list: the setter rejected an ArrayList that unpack creates; a list field must accept an ArrayList");
    }

    private static void ac2TreeMapOfValuesIsRefusedAtUnpack() {
        Scheme<Row> scheme = treeScheme();
        Row row = new Row();
        row.tree = new TreeMap<>(Map.of("a", 7));
        byte[] packed = BinaryPacker.pack(scheme, row);
        PackbinTest.expectEq("AZ-4255 AC-2 pack bytes unchanged", "01010002106107", PackbinTest.toHex(packed));
        expectRefusedUnpack("AZ-4255 AC-2 tree map", scheme, packed,
                "dict: the setter rejected a LinkedHashMap that unpack creates; a dict field must accept a LinkedHashMap");
    }

    private static void ac3AnotherCastFailureIsNotHidden() {
        // Arrange: a setter that fails a cast of something other than the collection unpack created.
        Scheme<Row> scheme = new Scheme<>(1, Row.class, Packbin.list(Access.get((Row r) -> r.list),
                Access.set((Row r, Object v) -> {
                    Object other = "text";
                    r.list = (List<Integer>) (Object) (Integer) other;
                }), u8()));

        // Act, Assert: still the caller's own ClassCastException.
        boolean raw = false;
        try {
            BinaryPacker.unpack(LIST_OF_TWO, scheme.on(r -> {}));
        } catch (ClassCastException ex) {
            raw = true;
        }
        PackbinTest.expectTrue("AZ-4255 AC-3 a cast failure of another object is not hidden", raw);
    }

    private static void ac4AcceptedTypesAreUnchanged() {
        // Arrange: List and Map fields accept what unpack creates.
        Scheme<Row> list = new Scheme<>(1, Row.class, Packbin.list(Access.get((Row r) -> r.list),
                Access.set((Row r, Object v) -> r.list = (List<Integer>) v), u8()));
        Scheme<Row> map = new Scheme<>(1, Row.class, Packbin.dict(Access.get((Row r) -> r.map),
                Access.set((Row r, Object v) -> r.map = (Map<String, Integer>) v), u8()));
        Row[] gotList = new Row[1];
        Row[] gotMap = new Row[1];

        // Act
        Object e1 = BinaryPacker.unpack(LIST_OF_TWO, list.on(r -> gotList[0] = r));
        Object e2 = BinaryPacker.unpack(DICT_OF_ONE, map.on(r -> gotMap[0] = r));

        // Assert
        PackbinTest.expectEq("AZ-4255 AC-4 list error", null, e1);
        PackbinTest.expectEq("AZ-4255 AC-4 list", "[1, 5]", String.valueOf(gotList[0].list));
        PackbinTest.expectEq("AZ-4255 AC-4 map error", null, e2);
        PackbinTest.expectEq("AZ-4255 AC-4 map", "{a=7}", String.valueOf(gotMap[0].map));
        PackbinTest.expectEq("AZ-4255 AC-4 list class", ArrayList.class, gotList[0].list.getClass());
        PackbinTest.expectEq("AZ-4255 AC-4 map class", LinkedHashMap.class, gotMap[0].map.getClass());
    }
}
