package packbin;

import java.util.List;
import java.util.Map;

/**
 * AZ-2235: the element scope of a list or dict is not typed. An anchored group or flags element has a HashMap row,
 * so a nested-row group inside it needs no factory even when the list is held by a typed row. The check of an element
 * group itself (TypedNestedRowTest) must not leak into the scope of an element that is not a nested-row group.
 */
@SuppressWarnings({"unchecked", "rawtypes"})
final class TypedElementScopeTest {
    private TypedElementScopeTest() {}

    static void run() {
        anchoredElementMayHoldAnUnfactoredNestedRow();
        flagsElementMayHoldAnUnfactoredNestedRow();
        dictAnchoredElementMayHoldAnUnfactoredNestedRow();
    }

    private static Field nestedRow() {
        return Packbin.group(Access.get("g"), Access.set("g"), Packbin.u8(0, Access.get("v"), Access.set("v")));
    }

    private static Getter getMaps() {
        return Access.get((TypedNestedRowTest.Holder h) -> h.maps);
    }

    private static Setter setMaps() {
        return Access.set((TypedNestedRowTest.Holder h, Object v) -> h.maps = (List<Map<String, Object>>) v);
    }

    private static void expectRoundTrip(String label, Scheme<TypedNestedRowTest.Holder> scheme, String hex) {
        TypedNestedRowTest.Holder[] got = new TypedNestedRowTest.Holder[1];
        Object err = BinaryPacker.unpack(PackbinTest.parseHex(hex), scheme.on(row -> got[0] = row));
        PackbinTest.expectTrue(label + " unpack ok (" + err + ")", err == null && got[0] != null);
        PackbinTest.expectEq(label + " row", List.of(Maps.map("g", Maps.map("v", 3))), got[0] == null ? null : got[0].maps);
        if (got[0] != null) {
            PackbinTest.expectEq(label + " repack", hex, PackbinTest.toHex(BinaryPacker.pack(scheme, got[0])));
        }
    }

    private static void anchoredElementMayHoldAnUnfactoredNestedRow() {
        Scheme<TypedNestedRowTest.Holder> scheme = new Scheme<>(1, TypedNestedRowTest.Holder.class,
                Packbin.list(getMaps(), setMaps(), Packbin.group(0, nestedRow())));
        expectRoundTrip("anchored element", scheme, "01" + "0100" + "03");
    }

    private static void flagsElementMayHoldAnUnfactoredNestedRow() {
        Scheme<TypedNestedRowTest.Holder> scheme = new Scheme<>(1, TypedNestedRowTest.Holder.class,
                Packbin.list(getMaps(), setMaps(), Packbin.flags(0, nestedRow())));
        expectRoundTrip("flags element", scheme, "01" + "0100" + "01" + "03");
    }

    /** A dict of anchored elements in a typed row: only the element scope matters, not the container kind. */
    private static void dictAnchoredElementMayHoldAnUnfactoredNestedRow() {
        Scheme<TypedNestedRowTest.Holder> scheme = new Scheme<>(1, TypedNestedRowTest.Holder.class,
                Packbin.dict(Access.get((TypedNestedRowTest.Holder h) -> h.byName),
                        Access.set((TypedNestedRowTest.Holder h, Object v) ->
                                h.byName = (Map<String, TypedNestedRowTest.Item>) v),
                        Packbin.group(0, nestedRow())));
        PackbinTest.expectTrue("dict anchored element builds", scheme != null);
    }
}
