package packbin;

import static packbin.MemberCases.refused;
import static packbin.MemberCases.row;
import static packbin.MemberCases.u8;

import java.util.List;
import java.util.Map;

/**
 * AZ-2332 (owner decision 4, loop 19): one byte buffer for a bytes or sized name in a repeat or times round is
 * refused naming the member instead of being broadcast to every round; a list with one buffer per round packs as
 * before. A lone string for a utf8 name still goes to every round.
 */
@SuppressWarnings({"unchecked", "rawtypes"})
final class LoneBytesInRoundTest {
    private LoneBytesInRoundTest() {}

    private static final String LONE = "d: a lone byte buffer is not a list of rounds; give one buffer per round in a list";

    private static Field bytes(int id) {
        return Packbin.bytes(id, Access.get("d"), Access.set("d"), 2);
    }

    private static final Scheme<Map> TIMES_BYTES = Maps.scheme(1, u8(0, "n"), Packbin.times(1, 0, bytes(1)));

    private static final Scheme<Map> REPEAT_BYTES = Maps.scheme(1, Packbin.repeat(0, bytes(0)));

    private static final Scheme<Map> TIMES_SIZED = Maps.scheme(1, u8(0, "n"), Packbin.times(1, 0, u8(1, "len"),
            Packbin.sized(2, Access.get("d"), Access.set("d"), 1)));

    private static final Scheme<Map> TIMES_UTF8 = Maps.scheme(1, u8(0, "n"),
            Packbin.times(1, 0, Packbin.utf8(1, Access.get("t"), Access.set("t"))));

    static void run() {
        ac1LoneBufferIsRefused();
        ac2OneBufferPerRoundPacks();
    }

    private static byte[] b(int... values) {
        byte[] out = new byte[values.length];
        for (int i = 0; i < values.length; i++) {
            out[i] = (byte) values[i];
        }
        return out;
    }

    private static void ac1LoneBufferIsRefused() {
        refused("AZ-2332 AC-1 times bytes, 2 rounds", TIMES_BYTES, row("n", 2, "d", b(1, 2)), LONE);
        refused("AZ-2332 AC-1 times bytes, 1 round", TIMES_BYTES, row("n", 1, "d", b(1, 2)), LONE);
        refused("AZ-2332 AC-1 times bytes, count 0", TIMES_BYTES, row("n", 0, "d", b(1, 2)), LONE);
        refused("AZ-2332 AC-1 repeat bytes", REPEAT_BYTES, row("d", b(1, 2)), LONE);
        refused("AZ-2332 AC-1 hostile buffer of the wrong size", TIMES_BYTES, row("n", 2, "d", b(1)), LONE);
        refused("AZ-2332 AC-1 times sized", TIMES_SIZED, row("n", 2, "len", List.of(2, 2), "d", b(1, 2)), LONE);
        PackbinTest.expectEq("AZ-2332 lone string still goes to every round", "01020200686902006869",
                PackbinTest.toHex(BinaryPacker.pack(TIMES_UTF8, row("n", 2, "t", "hi"))));
    }

    private static void ac2OneBufferPerRoundPacks() {
        pack("AZ-2332 AC-2 times bytes", TIMES_BYTES, row("n", 2, "d", List.of(b(1, 2), b(3, 4))), "010201020304");
        pack("AZ-2332 AC-2 times bytes, 1 round", TIMES_BYTES, row("n", 1, "d", List.of(b(1, 2))), "01010102");
        pack("AZ-2332 AC-2 repeat bytes", REPEAT_BYTES, row("d", List.of(b(1, 2), b(3, 4))), "010102" + "0304");
        pack("AZ-2332 AC-2 times sized", TIMES_SIZED, row("n", 2, "len", List.of(2, 2), "d", List.of(b(1, 2), b(3, 4))),
                "0102" + "020102" + "020304");
        refused("AZ-2332 AC-2 hostile buffer of the wrong size in a list", TIMES_BYTES,
                row("n", 2, "d", List.of(b(1, 2), b(1))), "1: expected 2 bytes, got 1");
    }

    private static void pack(String label, Scheme<Map> scheme, Map<String, Object> row, String hex) {
        PackbinTest.expectEq(label, hex, PackbinTest.toHex(BinaryPacker.pack(scheme, row)));
    }
}
