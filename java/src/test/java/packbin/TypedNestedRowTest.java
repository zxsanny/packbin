package packbin;

import java.util.List;
import java.util.Map;
import java.util.function.Supplier;

/**
 * AZ-2101: a nested row of a typed row is created by a caller-supplied factory, in a round and as a list or dict
 * element too, and the ids of a nested row never shadow those of the row around it. AC-3 (Map rows unchanged) is the
 * existing nested-row tests of PackbinFieldsTest, BoolPlacementTest and NestedRoundTest; AC-6 is the whole suite
 * with the golden fixtures.
 */
@SuppressWarnings({"unchecked", "rawtypes"})
final class TypedNestedRowTest {
    private TypedNestedRowTest() {}

    public static final class Inner {
        public Integer v;
    }

    public static final class Outer {
        public Inner inner;
        public Integer tail;
    }

    public static final class Preset {
        public Inner inner = new Inner();
    }

    public static final class Item {
        public Integer v;
    }

    public static final class Holder {
        public List<Item> items;
        public Map<String, Item> byName;
    }

    public static final class RoundRow {
        public List<Inner> g;
    }

    public static final class Leaf {
        public Integer v;
    }

    public static final class Mid {
        public Leaf leaf;
    }

    public static final class Deep {
        public Mid mid;
    }

    static void run() {
        ac1TypedNestedRowRoundTrips();
        ac2MissingFactoryFailsAtConstruction();
        factoryRulesBelowAFactoryGroup();
        factoryIsUsedOnlyWhenTheMemberIsNull();
        mapRowsMayUseAFactoryToo();
        ac4NestedIdsDoNotShadowParentIds();
        ac5RowTypedListAndDictElements();
        typedNestedRowInARound();
        typedEmptyNestedRowUnderAFlagBit();
        typedNestedRowUnderAFlagBitWithAnAbsentMember();
        mapNestedRowWithAbsentMemberWritesNoBit();
        nullFactory();
    }

    private static Field innerV() {
        return Packbin.u8(0, Access.get((Inner i) -> i.v), Access.set((Inner i, Object v) -> i.v = ((Number) v).intValue()));
    }

    private static Field itemV() {
        return Packbin.u8(0, Access.get((Item i) -> i.v), Access.set((Item i, Object v) -> i.v = ((Number) v).intValue()));
    }

    private static Field tail() {
        return Packbin.u8(0, Access.get((Outer o) -> o.tail), Access.set((Outer o, Object v) -> o.tail = ((Number) v).intValue()));
    }

    private static Getter innerOfOuter() {
        return Access.get((Outer o) -> o.inner);
    }

    private static Setter setInnerOfOuter() {
        return Access.set((Outer o, Object v) -> o.inner = (Inner) v);
    }

    private static Inner inner(int v) {
        Inner inner = new Inner();
        inner.v = v;
        return inner;
    }

    private static Item item(int v) {
        Item item = new Item();
        item.v = v;
        return item;
    }

    private static <T> T unpackOne(String label, Scheme<T> scheme, String hex) {
        Object[] got = new Object[1];
        Object err = BinaryPacker.unpack(PackbinTest.parseHex(hex), scheme.on(row -> got[0] = row));
        PackbinTest.expectTrue(label + " unpack ok (" + err + ")", err == null && got[0] != null);
        return (T) got[0];
    }

    private static Scheme<Outer> outerScheme(Supplier<?> create) {
        return new Scheme<>(1, Outer.class, Packbin.group(innerOfOuter(), setInnerOfOuter(), create, innerV()), tail());
    }

    private static void ac1TypedNestedRowRoundTrips() {
        int[] created = {0};
        Scheme<Outer> scheme = outerScheme(() -> {
            created[0]++;
            return new Inner();
        });
        Outer row = new Outer();
        row.inner = inner(3);
        row.tail = 4;
        byte[] bytes = BinaryPacker.pack(scheme, row);
        PackbinTest.expectEq("AC-1 bytes", "010304", PackbinTest.toHex(bytes));

        Outer back = unpackOne("AC-1", scheme, "010304");
        PackbinTest.expectEq("AC-1 inner is an Inner", Inner.class, back.inner == null ? null : back.inner.getClass());
        PackbinTest.expectEq("AC-1 inner.v", 3, back.inner == null ? null : back.inner.v);
        PackbinTest.expectEq("AC-1 tail", 4, back.tail);
        PackbinTest.expectEq("AC-1 the factory made the one child", 1, created[0]);
        PackbinTest.expectEq("AC-1 repack", "010304", PackbinTest.toHex(BinaryPacker.pack(scheme, back)));
    }

    private static void ac2MissingFactoryFailsAtConstruction() {
        String message = "nested group on a typed row needs a child factory";
        Scheme<Outer>[] built = new Scheme[1];
        PackbinTest.expectThrows("AC-2 the old overload on a typed row", () -> built[0] = new Scheme<>(1, Outer.class,
                Packbin.group(innerOfOuter(), setInnerOfOuter(), innerV()), tail()), message);
        PackbinTest.expectTrue("AC-2 no scheme built", built[0] == null);
        PackbinTest.expectThrows("AC-2 the old overload in a repeat of a typed row", () -> new Scheme<>(1, RoundRow.class,
                Packbin.repeat(0, Packbin.group(Access.get((RoundRow r) -> r.g), Access.set((RoundRow r, Object v) -> {}),
                        innerV()))), message);
        PackbinTest.expectThrows("AC-2 an empty nested row, even as a flag bit", () -> new Scheme<>(1, Outer.class,
                Packbin.flags(0, Packbin.group(innerOfOuter(), setInnerOfOuter()))), message);
    }

    /** A nested row below a nested row with a factory is typed too; below a Map row's nested row it is a Map row. */
    private static void factoryRulesBelowAFactoryGroup() {
        Field leafV = Packbin.u8(0, Access.get((Leaf l) -> l.v), Access.set((Leaf l, Object v) -> l.v = ((Number) v).intValue()));
        Getter getMid = Access.get((Deep d) -> d.mid);
        Setter setMid = Access.set((Deep d, Object v) -> d.mid = (Mid) v);
        Getter getLeaf = Access.get((Mid m) -> m.leaf);
        Setter setLeaf = Access.set((Mid m, Object v) -> m.leaf = (Leaf) v);

        Scheme<Deep> both = new Scheme<>(1, Deep.class,
                Packbin.group(getMid, setMid, Mid::new, Packbin.group(getLeaf, setLeaf, Leaf::new, leafV)));
        Deep deep = new Deep();
        deep.mid = new Mid();
        deep.mid.leaf = new Leaf();
        deep.mid.leaf.v = 5;
        PackbinTest.expectEq("two typed levels bytes", "0105", PackbinTest.toHex(BinaryPacker.pack(both, deep)));
        Deep back = unpackOne("two typed levels", both, "0105");
        PackbinTest.expectEq("two typed levels leaf.v", 5,
                back.mid == null || back.mid.leaf == null ? null : back.mid.leaf.v);

        PackbinTest.expectThrows("a nested row without a factory below one that has it", () -> new Scheme<>(1, Deep.class,
                Packbin.group(getMid, setMid, Mid::new, Packbin.group(getLeaf, setLeaf, leafV))),
                "nested group on a typed row needs a child factory");

        Scheme<Map> mapBelowMap = Maps.scheme(1, Packbin.group(Access.get("a"), Access.set("a"),
                Packbin.group(Access.get("b"), Access.set("b"), Packbin.u8(0, Access.get("v"), Access.set("v")))));
        PackbinTest.expectTrue("a Map row's nested rows build without factories", mapBelowMap != null);
    }

    private static void factoryIsUsedOnlyWhenTheMemberIsNull() {
        int[] created = {0};
        Scheme<Preset> preset = new Scheme<>(1, Preset.class, Packbin.group(
                Access.get((Preset p) -> p.inner), Access.set((Preset p, Object v) -> p.inner = (Inner) v),
                () -> {
                    created[0]++;
                    return new Inner();
                }, innerV()));
        Preset back = unpackOne("preset member", preset, "0109");
        PackbinTest.expectEq("preset member is filled", 9, back.inner.v);
        PackbinTest.expectEq("the factory is not called for a member the row already has", 0, created[0]);
    }

    private static void mapRowsMayUseAFactoryToo() {
        Scheme<Map> scheme = Maps.scheme(1, Packbin.group(Access.get("g"), Access.set("g"),
                java.util.LinkedHashMap::new, Packbin.u8(0, Access.get("v"), Access.set("v"))));
        Map<String, Object> row = Maps.map("g", Maps.map("v", 7));
        PackbinTest.expectEq("map row with a factory bytes", "0107", PackbinTest.toHex(BinaryPacker.pack(scheme, row)));
        Map back = unpackOne("map row with a factory", scheme, "0107");
        PackbinTest.expectEq("map row with a factory made its own map class", java.util.LinkedHashMap.class,
                back.get("g") == null ? null : back.get("g").getClass());
    }

    private static void ac4NestedIdsDoNotShadowParentIds() {
        Scheme<Map> scheme = Maps.scheme(1,
                Packbin.u8(0, Access.get("profile"), Access.set("profile")),
                Packbin.group(Access.get("g"), Access.set("g"), Packbin.u8(0, Access.get("inner"), Access.set("inner"))),
                Packbin.when(1, Packbin.eq(0, 1), Packbin.u8(1, Access.get("shape"), Access.set("shape"))));
        Map<String, Object> off = Maps.map("profile", 0, "g", Maps.map("inner", 1), "shape", 9);
        PackbinTest.expectEq("AC-4 profile 0 bytes", "010001", PackbinTest.toHex(BinaryPacker.pack(scheme, off)));
        Map offBack = unpackOne("AC-4 profile 0", scheme, "010001");
        PackbinTest.expectEq("AC-4 profile 0 row", Maps.map("profile", 0, "g", Maps.map("inner", 1)), offBack);
        PackbinTest.expectTrue("AC-4 profile 0 leaves shape null", !offBack.containsKey("shape"));

        Map<String, Object> on = Maps.map("profile", 1, "g", Maps.map("inner", 1), "shape", 9);
        PackbinTest.expectEq("AC-4 profile 1 bytes", "01010109", PackbinTest.toHex(BinaryPacker.pack(scheme, on)));
        PackbinTest.expectEq("AC-4 profile 1 row", on, unpackOne("AC-4 profile 1", scheme, "01010109"));

        Scheme<Map> reverse = Maps.scheme(1,
                Packbin.u8(0, Access.get("k"), Access.set("k")),
                Packbin.group(Access.get("g"), Access.set("g"), Packbin.u8(0, Access.get("v"), Access.set("v"))),
                Packbin.when(1, Packbin.eq(0, 1), Packbin.u8(1, Access.get("w"), Access.set("w"))));
        PackbinTest.expectEq("AC-4 k 1 with a nested v 2 writes w", "01010209",
                PackbinTest.toHex(BinaryPacker.pack(reverse, Maps.map("k", 1, "g", Maps.map("v", 2), "w", 9))));
        PackbinTest.expectEq("AC-4 k 2 with a nested v 1 drops w", "010201",
                PackbinTest.toHex(BinaryPacker.pack(reverse, Maps.map("k", 2, "g", Maps.map("v", 1), "w", 9))));

        Scheme<Map> inRound = Maps.scheme(1, Packbin.repeat(0,
                Packbin.u8(0, Access.get("k"), Access.set("k")),
                Packbin.group(Access.get("g"), Access.set("g"), Packbin.u8(0, Access.get("v"), Access.set("v"))),
                Packbin.when(1, Packbin.eq(0, 1), Packbin.u8(1, Access.get("w"), Access.set("w")))));
        Map<String, Object> rounds = Maps.map("k", List.of(1, 2), "g", List.of(Maps.map("v", 2), Maps.map("v", 1)),
                "w", java.util.Arrays.asList(9, null));
        PackbinTest.expectEq("AC-4 in a round: only the round that holds k = 1 writes w", "01" + "010209" + "0201",
                PackbinTest.toHex(BinaryPacker.pack(inRound, rounds)));
        Map roundsBack = unpackOne("AC-4 in a round", inRound, "01" + "010209" + "0201");
        PackbinTest.expectEq("AC-4 in a round row", rounds, roundsBack);
    }

    private static Scheme<Holder> holderScheme() {
        return new Scheme<>(1, Holder.class,
                Packbin.list(Access.get((Holder h) -> h.items), Access.set((Holder h, Object v) -> h.items = (List<Item>) v),
                        Packbin.group(Access.identity(), Access.ignore(), Item::new, itemV())),
                Packbin.dict(Access.get((Holder h) -> h.byName), Access.set((Holder h, Object v) -> h.byName = (Map<String, Item>) v),
                        Packbin.group(Access.identity(), Access.ignore(), Item::new, itemV())));
    }

    private static void ac5RowTypedListAndDictElements() {
        Scheme<Holder> scheme = holderScheme();
        Holder row = new Holder();
        row.items = List.of(item(3), item(4));
        row.byName = Map.of("a", item(6));
        String hex = "01" + "0200" + "03" + "04" + "0100" + "0100" + "61" + "06";
        PackbinTest.expectEq("AC-5 bytes", hex, PackbinTest.toHex(BinaryPacker.pack(scheme, row)));

        Holder back = unpackOne("AC-5", scheme, hex);
        PackbinTest.expectEq("AC-5 two items", 2, back.items == null ? null : back.items.size());
        if (back.items != null && back.items.size() == 2) {
            Object first = back.items.get(0);
            Object second = back.items.get(1);
            PackbinTest.expectTrue("AC-5 items are Item objects", first instanceof Item && second instanceof Item);
            PackbinTest.expectEq("AC-5 first v", 3, first instanceof Item a ? a.v : null);
            PackbinTest.expectEq("AC-5 second v", 4, second instanceof Item b ? b.v : null);
        }
        Object named = back.byName == null ? null : back.byName.get("a");
        PackbinTest.expectTrue("AC-5 dict value is an Item object", named instanceof Item);
        PackbinTest.expectEq("AC-5 dict value v", 6, named instanceof Item n ? n.v : null);
        PackbinTest.expectEq("AC-5 repack", hex, PackbinTest.toHex(BinaryPacker.pack(scheme, back)));
    }

    private static void typedNestedRowInARound() {
        Scheme<RoundRow> scheme = new Scheme<>(1, RoundRow.class, Packbin.repeat(0, Packbin.group(
                Access.get((RoundRow r) -> r.g), Access.set((RoundRow r, Object v) -> r.g = (List<Inner>) v),
                Inner::new, innerV())));
        RoundRow row = new RoundRow();
        row.g = List.of(inner(1), inner(2));
        PackbinTest.expectEq("round bytes", "010102", PackbinTest.toHex(BinaryPacker.pack(scheme, row)));
        RoundRow back = unpackOne("round", scheme, "010102");
        PackbinTest.expectEq("round has two rows", 2, back.g == null ? null : back.g.size());
        if (back.g != null && back.g.size() == 2) {
            Object first = back.g.get(0);
            Object second = back.g.get(1);
            PackbinTest.expectTrue("round rows are Inner objects", first instanceof Inner && second instanceof Inner);
            PackbinTest.expectEq("round first v", 1, first instanceof Inner a ? a.v : null);
            PackbinTest.expectEq("round second v", 2, second instanceof Inner b ? b.v : null);
        }
        PackbinTest.expectEq("round repack", "010102", PackbinTest.toHex(BinaryPacker.pack(scheme, back)));
    }

    /** AZ-2131 AC-2 for a typed row: the bit of an empty nested row follows whether its member is present. */
    private static void typedEmptyNestedRowUnderAFlagBit() {
        Scheme<Outer> combined = new Scheme<>(1, Outer.class,
                Packbin.flags(0, Packbin.group(innerOfOuter(), setInnerOfOuter(), Inner::new)));
        Field fb = Packbin.flagByte();
        Scheme<Outer> split = new Scheme<>(1, Outer.class,
                fb, fb.bit(Packbin.group(innerOfOuter(), setInnerOfOuter(), Inner::new)));
        for (Object[] form : new Object[][] {{"flags", combined}, {"flag byte", split}}) {
            String label = "typed empty nested row in " + form[0];
            Scheme<Outer> scheme = (Scheme<Outer>) form[1];
            Outer present = new Outer();
            present.inner = new Inner();
            PackbinTest.expectEq(label + " present", "0101", PackbinTest.toHex(BinaryPacker.pack(scheme, present)));
            PackbinTest.expectEq(label + " absent", "0100", PackbinTest.toHex(BinaryPacker.pack(scheme, new Outer())));
            Outer on = unpackOne(label + " 0101", scheme, "0101");
            PackbinTest.expectTrue(label + " 0101 makes the member (" + on.inner + ")", on.inner != null);
            Outer off = unpackOne(label + " 0100", scheme, "0100");
            PackbinTest.expectTrue(label + " 0100 leaves the member null", off.inner == null);
        }
    }

    /** The presence of a nested row is its member; its fields are never asked of the row around it (ClassCastException). */
    private static void typedNestedRowUnderAFlagBitWithAnAbsentMember() {
        Scheme<Outer> scheme = new Scheme<>(1, Outer.class,
                Packbin.flags(0, Packbin.group(innerOfOuter(), setInnerOfOuter(), Inner::new, innerV())));
        PackbinTest.expectEq("typed nested row, absent member", "0100", PackbinTest.toHex(BinaryPacker.pack(scheme, new Outer())));
        Outer row = new Outer();
        row.inner = inner(3);
        PackbinTest.expectEq("typed nested row, present member", "010103", PackbinTest.toHex(BinaryPacker.pack(scheme, row)));
        Outer back = unpackOne("typed nested row 010103", scheme, "010103");
        PackbinTest.expectEq("typed nested row unpacks v", 3, back.inner == null ? null : back.inner.v);
    }

    private static void mapNestedRowWithAbsentMemberWritesNoBit() {
        Scheme<Map> scheme = Maps.scheme(1, Packbin.flags(0, Packbin.group(Access.get("g"), Access.set("g"),
                Packbin.u8(0, Access.get("v"), Access.set("v")))));
        PackbinTest.expectEq("a value of the outer row named like a nested field leaves the bit clear", "0100",
                PackbinTest.toHex(BinaryPacker.pack(scheme, Maps.map("v", 5))));
        PackbinTest.expectEq("the member present sets the bit", "010105",
                PackbinTest.toHex(BinaryPacker.pack(scheme, Maps.map("g", Maps.map("v", 5)))));
    }

    private static void nullFactory() {
        boolean threw = false;
        try {
            Packbin.group(innerOfOuter(), setInnerOfOuter(), (Supplier<?>) null, innerV());
        } catch (NullPointerException ex) {
            threw = true;
            PackbinTest.expectEq("null factory message", "create", ex.getMessage());
        }
        PackbinTest.expectTrue("a null factory is refused when the group is built", threw);

        Scheme<Outer> returnsNull = outerScheme(() -> null);
        boolean refused = false;
        try {
            BinaryPacker.unpack(PackbinTest.parseHex("010304"), returnsNull.on(row -> {}));
        } catch (NullPointerException ex) {
            refused = true;
        }
        PackbinTest.expectTrue("a factory that returns null is a caller bug, not a silent drop", refused);
    }
}
