package packbin;

import java.util.Arrays;
import java.util.Map;

/**
 * AZ-2135 G4, Java part: a split-form flag bit takes its position from field order among the bits of the flag byte
 * read it belongs to, as in Rust, so one handle may build any number of schemes and may be read more than once.
 */
@SuppressWarnings({"unchecked", "rawtypes"})
final class SplitBitOrderTest {
    private SplitBitOrderTest() {}

    static void run() {
        ac1HandleSharedByTwoSchemes();
        ac1BitCreatedLaterStandsEarlier();
        ac1FlagByteReadTwice();
        ac1HandleSharedByTwoFiveBitSchemes();
        ac1HandleReadAtTopLevelAndInARound();
        ac1BitsAcrossAWhenAndAFlagsMember();
        ac1NestedRowReadsStayInsideTheRow();
        ac1NestedRowInARound();
        ac1BitsAreCountedPerRead();
        ac3GoldenAndMotionUnchanged();
    }

    private static Field u8(int id, String name) {
        return Packbin.u8(id, Access.get(name), Access.set(name));
    }

    /** {@code [m, m.bit(u8 f0), ..., m.bit(u8 f<count-1>)]}, ids 0 to count - 1. */
    private static Scheme<Map> bitsOf(int typeNumber, Field m, int count) {
        Field[] fields = new Field[count + 1];
        fields[0] = m;
        for (int i = 0; i < count; i++) {
            fields[i + 1] = m.bit(u8(i, "f" + i));
        }
        return Maps.scheme(typeNumber, fields);
    }

    private static void expectPacks(String label, String hex, Scheme<Map> scheme, Map<String, Object> row) {
        PackbinTest.expectEq(label + " pack", hex, PackbinTest.toHex(BinaryPacker.pack(scheme, row)));
        Map[] got = new Map[1];
        Object err = BinaryPacker.unpack(PackbinTest.parseHex(hex), scheme.on(r -> got[0] = r));
        PackbinTest.expectTrue(label + " unpack ok", err == null);
        PackbinTest.expectEq(label + " unpack row", row, got[0]);
        if (got[0] != null) {
            PackbinTest.expectEq(label + " repack", hex, PackbinTest.toHex(BinaryPacker.pack(scheme, got[0])));
        }
    }

    /** One handle, two schemes {@code [m, m.bit(u8 x)]} (assessment12 G4 probe 1): the bit is bit 0 in each. */
    private static void ac1HandleSharedByTwoSchemes() {
        Field m = Packbin.flagByte();
        Scheme<Map> first = Maps.scheme(1, m, m.bit(u8(0, "x")));
        Scheme<Map> second = Maps.scheme(2, m, m.bit(u8(0, "x")));
        expectPacks("AC-1 shared handle, first scheme x=5", "010105", first, Maps.map("x", 5));
        expectPacks("AC-1 shared handle, second scheme x=5", "020105", second, Maps.map("x", 5));
        expectPacks("AC-1 shared handle, first scheme x absent", "0100", first, Maps.map());
        expectPacks("AC-1 shared handle, second scheme x absent", "0200", second, Maps.map());
    }

    /** {@code [m, early a, late b]} with {@code late} created first (probe 2): bits follow the scheme, not the calls. */
    private static void ac1BitCreatedLaterStandsEarlier() {
        Field m = Packbin.flagByte();
        Field late = m.bit(u8(1, "b"));
        Field early = m.bit(u8(0, "a"));
        Scheme<Map> scheme = Maps.scheme(1, m, early, late);
        expectPacks("AC-1 late bit only", "010209", scheme, Maps.map("b", 9));
        expectPacks("AC-1 early bit only", "010107", scheme, Maps.map("a", 7));
        expectPacks("AC-1 both bits", "01030709", scheme, Maps.map("a", 7, "b", 9));
    }

    /** {@code [m, m.bit(a), m, m.bit(b)]} (probe 3): each read of the byte holds the bits that follow it. */
    private static void ac1FlagByteReadTwice() {
        Field m = Packbin.flagByte();
        Scheme<Map> scheme = Maps.scheme(1, m, m.bit(u8(0, "a")), m, m.bit(u8(1, "b")));
        expectPacks("AC-1 second read only", "01000109", scheme, Maps.map("b", 9));
        expectPacks("AC-1 first read only", "01010700", scheme, Maps.map("a", 7));
        expectPacks("AC-1 both reads", "0101070109", scheme, Maps.map("a", 7, "b", 9));
        expectPacks("AC-1 neither read", "010000", scheme, Maps.map());
    }

    /** A handle shared by two schemes of five bits each builds both. */
    private static void ac1HandleSharedByTwoFiveBitSchemes() {
        Field m = Packbin.flagByte();
        Scheme<Map> first = bitsOf(1, m, 5);
        Scheme<Map> second = bitsOf(2, m, 5);
        expectPacks("AC-1 five bits, first scheme", "011f0102030405", first,
                Maps.map("f0", 1, "f1", 2, "f2", 3, "f3", 4, "f4", 5));
        expectPacks("AC-1 five bits, second scheme last bit", "021005", second, Maps.map("f4", 5));
    }

    /** The same handle read at the top level and in a round: the round starts its bits at 0. */
    private static void ac1HandleReadAtTopLevelAndInARound() {
        Field m = Packbin.flagByte();
        Scheme<Map> scheme = Maps.scheme(1,
                m, m.bit(u8(0, "x")),
                Packbin.repeat(1, m, m.bit(u8(1, "a"))));
        expectPacks("AC-1 top level and round", "0101040106", scheme, Maps.map("x", 4, "a", Arrays.asList(6)));
    }

    /** Bits count in field order across a when and a combined flags member that holds a bit of the same byte. */
    private static void ac1BitsAcrossAWhenAndAFlagsMember() {
        Field inWhen = Packbin.flagByte();
        Field w = inWhen.bit(u8(2, "w"));
        Field v = inWhen.bit(u8(1, "v"));
        Scheme<Map> bitWhen = Maps.scheme(1, u8(0, "k"), inWhen, Packbin.when(1, Packbin.eq(0, 1), v), w);
        expectPacks("AC-1 bit in a when, then a later bit: first", "01010105", bitWhen, Maps.map("k", 1, "v", 5));
        expectPacks("AC-1 bit in a when, then a later bit: both", "0101030506", bitWhen,
                Maps.map("k", 1, "v", 5, "w", 6));

        Field m = Packbin.flagByte();
        Scheme<Map> inFlags = Maps.scheme(1, m,
                Packbin.flags(0, m.bit(u8(0, "a")), u8(1, "b")), m.bit(u8(2, "c")));
        expectPacks("AC-1 flags member holding a bit, all present", "010303050607", inFlags,
                Maps.map("a", 5, "b", 6, "c", 7));
        expectPacks("AC-1 flags member holding a bit, only the later bit", "01020007", inFlags, Maps.map("c", 7));
    }

    /**
     * A flag byte read inside a nested row (an accessor group) is the row's own: it is not visible after the row, so
     * the bits of the row around it keep their own read. A byte read outside the row stays visible inside it, as for
     * a when.
     */
    private static void ac1NestedRowReadsStayInsideTheRow() {
        Field m = Packbin.flagByte();
        Scheme<Map> shared = Maps.scheme(1,
                m, m.bit(u8(0, "a")),
                Packbin.group(Access.get("g"), Access.set("g"), m, m.bit(u8(0, "x"))),
                m.bit(u8(1, "b")));
        expectPacks("AC-1 one handle in the row and around it", "010301010203", shared,
                Maps.map("a", 1, "g", Maps.map("x", 2), "b", 3));
        expectPacks("AC-1 one handle, only the outer later bit", "01020003", shared,
                Maps.map("g", Maps.map(), "b", 3));
        expectPacks("AC-1 one handle, only the nested bit", "01000102", shared, Maps.map("g", Maps.map("x", 2)));

        Field distinct = Packbin.flagByte();
        Field inner = Packbin.flagByte();
        Scheme<Map> apart = Maps.scheme(1,
                distinct, distinct.bit(u8(0, "a")),
                Packbin.group(Access.get("g"), Access.set("g"), inner, inner.bit(u8(0, "x"))),
                distinct.bit(u8(1, "b")));
        expectPacks("AC-1 distinct handles give the same bytes", "010301010203", apart,
                Maps.map("a", 1, "g", Maps.map("x", 2), "b", 3));

        PackbinTest.expectThrows("AC-1 a byte read inside a nested row is not visible after it", () -> {
            Field byteInRow = Packbin.flagByte();
            Maps.scheme(1, Packbin.group(Access.get("g"), Access.set("g"), byteInRow), byteInRow.bit(u8(0, "a")));
        }, "flag bit U8 0 has no flagByte before it in the same scope");

        Field outside = Packbin.flagByte();
        Scheme<Map> seenInside = Maps.scheme(1, outside,
                Packbin.group(Access.get("g"), Access.set("g"), outside.bit(u8(0, "x"))));
        PackbinTest.expectTrue("AC-1 a byte read outside a nested row stays visible inside it", seenInside != null);
    }

    /** The same rule in a round: the byte the nested row of a round reads is not the byte of the round. */
    private static void ac1NestedRowInARound() {
        Field r = Packbin.flagByte();
        Scheme<Map> scheme = Maps.scheme(1, Packbin.repeat(0,
                r, r.bit(u8(0, "a")),
                Packbin.group(Access.get("g"), Access.set("g"), r, r.bit(u8(0, "x"))),
                r.bit(u8(1, "b"))));
        Map<String, Object> row = Maps.map("a", Arrays.asList(1, 4),
                "g", Arrays.asList(Maps.map("x", 2), Maps.map("x", 5)), "b", Arrays.asList(3, 6));
        expectPacks("AC-1 nested row in a round, one handle", "01" + "0301010203" + "0304010506", scheme, row);
    }

    /** Eight bits are the limit of one read, not of a handle or of a scheme; the ninth bit of a read is refused. */
    private static void ac1BitsAreCountedPerRead() {
        Field shared = Packbin.flagByte();
        Scheme<Map> firstOfEight = bitsOf(1, shared, 8);
        Scheme<Map> secondOfEight = bitsOf(2, shared, 8);
        expectPacks("AC-1 eight bits, first scheme of a shared handle", "018007", firstOfEight, Maps.map("f7", 7));
        expectPacks("AC-1 eight bits, second scheme of a shared handle", "028007", secondOfEight, Maps.map("f7", 7));

        Field reread = Packbin.flagByte();
        Scheme<Map> twoReads = Maps.scheme(1,
                reread, reread.bit(u8(0, "a")), reread.bit(u8(1, "b")), reread.bit(u8(2, "c")),
                reread.bit(u8(3, "d")), reread.bit(u8(4, "e")),
                reread, reread.bit(u8(5, "f")), reread.bit(u8(6, "g")), reread.bit(u8(7, "h")),
                reread.bit(u8(8, "i")), reread.bit(u8(9, "j")));
        expectPacks("AC-1 five bits on each of two reads, none set", "010000", twoReads, Maps.map());
        expectPacks("AC-1 fifth bit of the first read and first bit of the second", "0110050106", twoReads,
                Maps.map("e", 5, "f", 6));

        PackbinTest.expectThrows("AC-1 ninth bit of one read", () -> bitsOf(1, Packbin.flagByte(), 9),
                "flags already has 8 bits");
    }

    /** Golden row (combined form) and the split motion example keep their bytes. */
    private static void ac3GoldenAndMotionUnchanged() {
        Scheme<Map> position = Maps.scheme(0x40,
                Packbin.u16(0, Access.get("sid"), Access.set("sid")),
                Packbin.i32(1, Access.get("lat"), Access.set("lat")),
                Packbin.i32(2, Access.get("lon"), Access.set("lon")),
                Packbin.u8(3, Access.get("profile"), Access.set("profile")),
                Packbin.flags(4,
                        Packbin.u16(4, Access.get("heading"), Access.set("heading")),
                        Packbin.u8(5, Access.get("speed"), Access.set("speed")),
                        Packbin.i16(6, Access.get("altitude"), Access.set("altitude"))));
        PackbinTest.expectEq("AC-3 golden row", "4001000065cd1d00a3e1110100", PackbinTest.toHex(BinaryPacker.pack(
                position, Maps.map("sid", 1, "lat", 500_000_000, "lon", 300_000_000, "profile", 1))));

        Field motion = Packbin.flagByte();
        Scheme<Map> split = Maps.scheme(1,
                u8(0, "sid"),
                motion,
                Packbin.when(1, Packbin.eq(0, 9), u8(1, "shape")),
                motion.bit(Packbin.u16(2, Access.get("heading"), Access.set("heading"))),
                motion.bit(u8(3, "speed")),
                motion.bit(Packbin.i16(4, Access.get("altitude"), Access.set("altitude"))));
        PackbinTest.expectEq("AC-3 motion heading only", "010901045a00", PackbinTest.toHex(BinaryPacker.pack(
                split, Maps.map("sid", 9, "shape", 4, "heading", 90))));
        PackbinTest.expectEq("AC-3 motion speed and altitude", "010906040affff", PackbinTest.toHex(
                BinaryPacker.pack(split, Maps.map("sid", 9, "shape", 4, "speed", 10, "altitude", -1))));
    }
}
