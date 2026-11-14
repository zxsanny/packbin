package packbin;

import java.util.List;
import java.util.Map;
import java.util.function.Supplier;

/**
 * AC-3: the Java chains of the four scheme-depth cases of fixtures/hostile/cases.txt (contract scheme-depth, AZ-4294),
 * replayed by HostileVectorTest. The chains are written by loops in SchemeDepthTest, innermost first. The group
 * cases use the Map-row form (a group without an anchor); the typed-row form packs the same bytes and is pinned by
 * SchemeDepthTest. Java writes all four cases.
 */
@SuppressWarnings({"unchecked", "rawtypes"})
final class HostileLoop126 {
    private HostileLoop126() {}

    /** The ids this file supplies; HostileVectorTest requires each to be present in cases.txt. */
    static final List<String> IDS = List.of(
            "construct_depth_when_257", "construct_depth_group_257", "pack_depth_when_256", "pack_depth_group_256");

    static Supplier<byte[]> packFor(String id) {
        return switch (id) {
            case "pack_depth_when_256" -> () -> BinaryPacker.pack(
                    SchemeDepthTest.whenScheme(SchemeDepthTest.LIMIT), Maps.map("a", 1, "b", 7));
            case "pack_depth_group_256" -> () -> BinaryPacker.pack(
                    SchemeDepthTest.groupScheme(SchemeDepthTest.LIMIT), SchemeDepthTest.groupRow(SchemeDepthTest.LIMIT));
            default -> null;
        };
    }

    static Supplier<Scheme<Map>> constructFor(String id) {
        return switch (id) {
            case "construct_depth_when_257" -> () -> SchemeDepthTest.whenScheme(SchemeDepthTest.LIMIT + 1);
            case "construct_depth_group_257" -> () -> SchemeDepthTest.groupScheme(SchemeDepthTest.LIMIT + 1);
            default -> null;
        };
    }
}
