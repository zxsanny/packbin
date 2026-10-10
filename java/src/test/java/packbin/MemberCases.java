package packbin;

import java.util.List;
import java.util.Map;

/** Shared checks of the AZ-2120 tests: one row against one pinned packet, in both directions. */
@SuppressWarnings({"unchecked", "rawtypes"})
final class MemberCases {
    private MemberCases() {}

    static Field u8(int id, String name) {
        return Packbin.u8(id, Access.get(name), Access.set(name));
    }

    static Field u16(int id, String name) {
        return Packbin.u16(id, Access.get(name), Access.set(name));
    }

    static Map<String, Object> row(Object... kv) {
        return Maps.map(kv);
    }

    static List<Integer> list(Integer... items) {
        return List.of(items);
    }

    /** Packs {@code row} to {@code hex}, and unpacks {@code hex} to {@code unpacked}. */
    static void packsAs(
            String label, Scheme<Map> scheme, Map<String, Object> row, String hex, Map<String, Object> unpacked) {
        PackbinTest.expectEq(label + " bytes", hex, PackbinTest.toHex(BinaryPacker.pack(scheme, row)));
        unpacks(label, scheme, hex, unpacked);
    }

    static void packs(String label, Scheme<Map> scheme, Map<String, Object> row, String hex) {
        packsAs(label, scheme, row, hex, row);
    }

    static void unpacks(String label, Scheme<Map> scheme, String hex, Map<String, Object> expected) {
        Map[] got = new Map[1];
        Object err = BinaryPacker.unpack(PackbinTest.parseHex(hex), scheme.on(r -> got[0] = r));
        PackbinTest.expectTrue(label + " unpack ok (" + err + ")", err == null && got[0] != null);
        PackbinTest.expectEq(label + " row", expected, got[0]);
    }

    /** Pack fails with exactly {@code message} and returns no bytes. */
    static void refused(String label, Scheme<Map> scheme, Map<String, Object> row, String message) {
        byte[][] wrote = {null};
        PackbinTest.expectThrows(label, () -> wrote[0] = BinaryPacker.pack(scheme, row), message);
        PackbinTest.expectTrue(label + ": no bytes returned", wrote[0] == null);
    }
}
