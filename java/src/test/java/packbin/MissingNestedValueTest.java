package packbin;

import java.util.Arrays;
import java.util.List;
import java.util.Map;
import java.util.TreeMap;

/**
 * AZ-2234 AC-1 to AC-5: pack throws instead of writing bytes that unpack reads differently. A nested row that is null
 * or absent outside flags, and a null element of a list or dict of nested-row groups, name what is missing.
 * AC-6 (flags and flag bits) is in FlagPresenceTest, AC-7 to AC-8 (u2 in a round) in RepeatRoundTest.
 */
@SuppressWarnings({"unchecked", "rawtypes"})
final class MissingNestedValueTest {
    private MissingNestedValueTest() {}

    private static final String MISSING_GROUP = "missing group";

    static void run() {
        ac1NullOrAbsentMemberThrows();
        ac1TypedMemberThrows();
        ac2UnderAWhenOnlyWhenItHolds();
        ac3EveryRoundBelowTheCountNeedsItsRow();
        ac4ARowReadByUnpackStillPacksBack();
        ac5ListElements();
        ac5DictElements();
        ac5TypedListElement();
        ac5OtherElementKindsKeepTheirMessages();
        sessionPackThrowsAndSendsNoFrame();
    }

    private static Field u8(int id, String name) {
        return Packbin.u8(id, Access.get(name), Access.set(name));
    }

    private static Field group(String member, Field... fields) {
        return Packbin.group(Access.get(member), Access.set(member), fields);
    }

    private static Field element(Field... fields) {
        return Packbin.group(Access.identity(), Access.ignore(), fields);
    }

    private static Field listOf(String member, Field element) {
        return Packbin.list(Access.get(member), Access.set(member), element);
    }

    private static Field dictOf(String member, Field element) {
        return Packbin.dict(Access.get(member), Access.set(member), element);
    }

    private static void expectThrows(String label, Scheme<Map> scheme, Map<String, Object> row, String message) {
        PackbinTest.expectThrows(label, () -> BinaryPacker.pack(scheme, row), message);
    }

    private static void expectPacks(String label, Scheme<Map> scheme, Map<String, Object> row, String hex) {
        try {
            PackbinTest.expectEq(label + " bytes", hex, PackbinTest.toHex(BinaryPacker.pack(scheme, row)));
        } catch (RuntimeException ex) {
            PackbinTest.fail(label + ": pack threw " + ex);
        }
    }

    private static Map unpackOk(String label, Scheme<Map> scheme, String hex) {
        Map[] got = new Map[1];
        Object err = BinaryPacker.unpack(PackbinTest.parseHex(hex), scheme.on(r -> got[0] = r));
        PackbinTest.expectTrue(label + " unpack ok (" + err + ")", err == null && got[0] != null);
        return got[0];
    }

    /** Pack, unpack the bytes, expect {@code row} back and the same bytes from packing it again. */
    private static void expectRoundTrip(String label, Scheme<Map> scheme, Map<String, Object> row, String hex) {
        expectPacks(label, scheme, row, hex);
        Map back = unpackOk(label, scheme, hex);
        PackbinTest.expectEq(label + " row", row, back);
        if (back != null) {
            expectPacks(label + " repack", scheme, back, hex);
        }
    }

    /** AC-1 (probes 1 and 2): a null member and an absent member are the same case, at any depth. */
    private static void ac1NullOrAbsentMemberThrows() {
        Scheme<Map> one = Maps.scheme(1, group("g", u8(0, "v")), u8(0, "tail"));
        expectThrows("AC-1 {g: null, tail: 7}", one, Maps.map("g", null, "tail", 7), MISSING_GROUP);
        expectThrows("AC-1 {tail: 7}", one, Maps.map("tail", 7), MISSING_GROUP);
        expectRoundTrip("AC-1 {g: {v: 3}, tail: 7}", one, Maps.map("g", Maps.map("v", 3), "tail", 7), "010307");

        Scheme<Map> twice = Maps.scheme(1, group("g1", group("g2", u8(0, "v")), u8(0, "w")));
        expectThrows("AC-1 nested twice, inner member absent", twice, Maps.map("g1", Maps.map("w", 2)), MISSING_GROUP);
        expectThrows("AC-1 nested twice, nothing", twice, Maps.map(), MISSING_GROUP);
        expectRoundTrip("AC-1 nested twice, both present", twice,
                Maps.map("g1", Maps.map("g2", Maps.map("v", 1), "w", 2)), "010102");
    }

    /** AC-1 typed row: the field of Outer is null; the present row packs and unpacks as before. */
    private static void ac1TypedMemberThrows() {
        Field v = Packbin.u8(0, Access.get((TypedNestedRowTest.Inner i) -> i.v),
                Access.set((TypedNestedRowTest.Inner i, Object x) -> i.v = ((Number) x).intValue()));
        Field tail = Packbin.u8(0, Access.get((TypedNestedRowTest.Outer o) -> o.tail),
                Access.set((TypedNestedRowTest.Outer o, Object x) -> o.tail = ((Number) x).intValue()));
        Scheme<TypedNestedRowTest.Outer> scheme = new Scheme<>(1, TypedNestedRowTest.Outer.class,
                Packbin.group(Access.get((TypedNestedRowTest.Outer o) -> o.inner),
                        Access.set((TypedNestedRowTest.Outer o, Object x) -> o.inner = (TypedNestedRowTest.Inner) x),
                        TypedNestedRowTest.Inner::new, v),
                tail);
        TypedNestedRowTest.Outer missing = new TypedNestedRowTest.Outer();
        missing.tail = 7;
        PackbinTest.expectThrows("AC-1 typed row, inner null", () -> BinaryPacker.pack(scheme, missing), MISSING_GROUP);

        TypedNestedRowTest.Outer present = new TypedNestedRowTest.Outer();
        present.inner = new TypedNestedRowTest.Inner();
        present.inner.v = 3;
        present.tail = 7;
        PackbinTest.expectEq("AC-1 typed row, inner present", "010307", PackbinTest.toHex(BinaryPacker.pack(scheme, present)));
        TypedNestedRowTest.Outer[] got = new TypedNestedRowTest.Outer[1];
        Object err = BinaryPacker.unpack(PackbinTest.parseHex("010307"), scheme.on(r -> got[0] = r));
        PackbinTest.expectTrue("AC-1 typed row unpacks (" + err + ")", err == null && got[0] != null
                && got[0].inner != null && got[0].inner.v == 3 && got[0].tail == 7);
    }

    /** AC-2 (probe 3): the member is needed only when the when holds. */
    private static void ac2UnderAWhenOnlyWhenItHolds() {
        Scheme<Map> scheme = Maps.scheme(1, u8(0, "k"),
                Packbin.when(1, Packbin.eq(0, 1), group("g", u8(0, "v"))));
        expectThrows("AC-2 when holds, member absent", scheme, Maps.map("k", 1), MISSING_GROUP);
        expectThrows("AC-2 when holds, member null", scheme, Maps.map("k", 1, "g", null), MISSING_GROUP);
        expectRoundTrip("AC-2 when does not hold", scheme, Maps.map("k", 2), "0102");
        expectRoundTrip("AC-2 when holds, member present", scheme, Maps.map("k", 1, "g", Maps.map("v", 4)), "010104");
    }

    /** AC-3 (probe 4): a round below the count with no row for it throws, for a repeat and for a times. */
    private static void ac3EveryRoundBelowTheCountNeedsItsRow() {
        Scheme<Map> repeat = Maps.scheme(1, Packbin.repeat(0, u8(0, "a"), group("g", u8(0, "v"))));
        expectThrows("AC-3 repeat, null item", repeat,
                Maps.map("a", List.of(1, 2), "g", Arrays.asList(Maps.map("v", 5), null)), MISSING_GROUP);
        expectThrows("AC-3 repeat, short list", repeat,
                Maps.map("a", List.of(1, 2), "g", List.of(Maps.map("v", 5))), MISSING_GROUP);
        expectThrows("AC-3 repeat, absent list", repeat, Maps.map("a", List.of(1, 2)), MISSING_GROUP);
        expectPacks("AC-3 repeat, nothing", repeat, Maps.map(), "01");
        expectRoundTrip("AC-3 repeat, every round has its row", repeat,
                Maps.map("a", List.of(1, 2), "g", List.of(Maps.map("v", 5), Maps.map("v", 6))), "0101050206");
        expectPacks("AC-3 repeat, a lone row is the row of every round", repeat,
                Maps.map("a", List.of(1), "g", Maps.map("v", 5)), "010105");

        Scheme<Map> times = Maps.scheme(1, u8(0, "n"), Packbin.times(1, 0, group("g", u8(0, "v"))));
        expectThrows("AC-3 times, null item", times,
                Maps.map("n", 2, "g", Arrays.asList(Maps.map("v", 5), null)), MISSING_GROUP);
        expectThrows("AC-3 times, short list", times,
                Maps.map("n", 2, "g", List.of(Maps.map("v", 5))), MISSING_GROUP);
        expectThrows("AC-3 times, absent list", times, Maps.map("n", 2), MISSING_GROUP);
        expectPacks("AC-3 times, no rounds", times, Maps.map("n", 0), "0100");
        expectRoundTrip("AC-3 times, every round has its row", times,
                Maps.map("n", 2, "g", List.of(Maps.map("v", 5), Maps.map("v", 6))), "01020506");
    }

    /** AC-4: unpack leaves a null entry only where a when skipped the row, and the row packs back. */
    private static void ac4ARowReadByUnpackStillPacksBack() {
        Scheme<Map> scheme = Maps.scheme(1, Packbin.repeat(0, u8(0, "k"),
                Packbin.when(1, Packbin.eq(0, 1), group("g", u8(0, "v")))));
        Map back = unpackOk("AC-4", scheme, "01010902");
        PackbinTest.expectEq("AC-4 row", Maps.map("k", List.of(1, 2), "g", Arrays.asList(Maps.map("v", 9), null)), back);
        if (back != null) {
            expectPacks("AC-4 repack", scheme, back, "01010902");
        }
    }

    /** AC-5 (probe 5): the first null element in list order is named by its index. */
    private static void ac5ListElements() {
        Scheme<Map> scheme = Maps.scheme(1, listOf("l", element(u8(0, "v"))));
        expectThrows("AC-5 list, null in the middle", scheme,
                Maps.map("l", Arrays.asList(Maps.map("v", 1), null, Maps.map("v", 2))), "missing list element 1");
        expectThrows("AC-5 list, only element null", scheme, Maps.map("l", Arrays.asList((Object) null)),
                "missing list element 0");
        expectThrows("AC-5 list, two nulls name the first", scheme,
                Maps.map("l", Arrays.asList(Maps.map("v", 1), null, null)), "missing list element 1");
        expectRoundTrip("AC-5 list, every element present", scheme,
                Maps.map("l", List.of(Maps.map("v", 1), Maps.map("v", 2))), "0102000102");
        expectRoundTrip("AC-5 list, empty", scheme, Maps.map("l", List.of()), "010000");
    }

    /** AC-5: a dict names the key; pack writes the keys sorted, so the first null in that order is named. */
    private static void ac5DictElements() {
        Scheme<Map> scheme = Maps.scheme(1, dictOf("d", element(u8(0, "v"))));
        expectThrows("AC-5 dict, null value", scheme,
                Maps.map("d", new TreeMap<>(Maps.map("a", Maps.map("v", 1), "b", null))), "missing dict element \"b\"");
        expectThrows("AC-5 dict, two nulls name the first sorted key", scheme,
                Maps.map("d", Maps.map("z", null, "c", null, "a", Maps.map("v", 1))), "missing dict element \"c\"");
        expectRoundTrip("AC-5 dict, every value present", scheme,
                Maps.map("d", Maps.map("a", Maps.map("v", 1))), "01010001006101");
    }

    private static void ac5TypedListElement() {
        Field v = Packbin.u8(0, Access.get((TypedNestedRowTest.Item i) -> i.v),
                Access.set((TypedNestedRowTest.Item i, Object x) -> i.v = ((Number) x).intValue()));
        Scheme<TypedNestedRowTest.Holder> scheme = new Scheme<>(1, TypedNestedRowTest.Holder.class,
                Packbin.list(Access.get((TypedNestedRowTest.Holder h) -> h.items),
                        Access.set((TypedNestedRowTest.Holder h, Object x) -> h.items = (List<TypedNestedRowTest.Item>) x),
                        Packbin.group(Access.identity(), Access.ignore(), TypedNestedRowTest.Item::new, v)));
        TypedNestedRowTest.Item one = new TypedNestedRowTest.Item();
        one.v = 1;
        TypedNestedRowTest.Holder row = new TypedNestedRowTest.Holder();
        row.items = Arrays.asList(one, null, one);
        PackbinTest.expectThrows("AC-5 typed list, null item", () -> BinaryPacker.pack(scheme, row),
                "missing list element 1");
        row.items = List.of(one, one);
        PackbinTest.expectEq("AC-5 typed list, every item present", "0102000101",
                PackbinTest.toHex(BinaryPacker.pack(scheme, row)));
    }

    /** AC-5: a null element of any other kind keeps the message it had (decision C15). */
    private static void ac5OtherElementKindsKeepTheirMessages() {
        expectThrows("AC-5 list of u8", Maps.scheme(1, listOf("l", u8(0, "x"))),
                Maps.map("l", Arrays.asList(1, null, 2)), "0: expected int, got null");
        expectThrows("AC-5 list of lists",
                Maps.scheme(1, listOf("l", Packbin.list(Access.identity(), Access.ignore(), u8(0, "x")))),
                Maps.map("l", Arrays.asList(List.of(1), null)), "list: expected list");
        expectThrows("AC-5 list of anchored groups",
                Maps.scheme(1, listOf("l", Packbin.group(0, u8(0, "x")))),
                Maps.map("l", Arrays.asList(Maps.map("x", 1), null)), "expected map");
        expectThrows("AC-5 list of flags",
                Maps.scheme(1, listOf("l", Packbin.flags(0, u8(0, "x")))),
                Maps.map("l", Arrays.asList(Maps.map("x", 1), null)), "expected map");
    }

    /** The blackbox row: a session refuses the row with no frame and its counter stays where it was. */
    private static void sessionPackThrowsAndSendsNoFrame() {
        byte[] seed = new byte[PackSession.SEED_SIZE];
        PackSession sender = PackSession.load(seed);
        PackSession reader = PackSession.load(seed);
        byte[] nonce = sender.start();
        PackbinTest.expectTrue("session opens", nonce != null && reader.join(nonce));
        Scheme<Map> scheme = Maps.scheme(1, group("g", u8(0, "v")), u8(0, "tail"));
        PackbinTest.expectThrows("session pack of a null member",
                () -> sender.pack(scheme, Maps.map("g", null, "tail", 7)), MISSING_GROUP);
        byte[] sealed = sender.pack(scheme, Maps.map("g", Maps.map("v", 3), "tail", 7));
        Map[] got = new Map[1];
        Object err = reader.unpack(sealed, scheme.on(r -> got[0] = r));
        PackbinTest.expectTrue("the next valid row is read by the peer (" + err + ")", err == null && got[0] != null);
        PackbinTest.expectEq("the next valid row", Maps.map("g", Maps.map("v", 3), "tail", 7), got[0]);
    }
}
