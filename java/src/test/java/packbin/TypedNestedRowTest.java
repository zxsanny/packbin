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
        public List<Map<String, Object>> maps;
        public List<List<Item>> nested;
    }

    public static final class Mixed {
        public Integer k;
        public List<Item> items;
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
        az2235Ac1ListElementWithoutAFactoryIsRefused();
        az2235Ac2DictAndInnerContainers();
        az2235Ac3WhereverTheHoldingScopeIsTyped();
        az2235Ac4AFactoryBuilds();
        az2235Ac5MapSchemesAndUndecidableShapesAreUnchanged();
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

    private static final String LIST_NEEDS_FACTORY = "list element: nested group on a typed row needs a child factory";
    private static final String DICT_NEEDS_FACTORY = "dict element: nested group on a typed row needs a child factory";
    private static final Getter GET_ITEMS = Access.get((Holder h) -> h.items);
    private static final Setter SET_ITEMS = Access.set((Holder h, Object v) -> h.items = (List<Item>) v);
    private static final Getter GET_MAPS = Access.get((Holder h) -> h.maps);
    private static final Setter SET_MAPS = Access.set((Holder h, Object v) -> h.maps = (List<Map<String, Object>>) v);
    private static final Getter GET_BY_NAME = Access.get((Holder h) -> h.byName);
    private static final Setter SET_BY_NAME = Access.set((Holder h, Object v) -> h.byName = (Map<String, Item>) v);
    private static final Getter GET_NESTED = Access.get((Holder h) -> h.nested);
    private static final Setter SET_NESTED = Access.set((Holder h, Object v) -> h.nested = (List<List<Item>>) v);
    private static final Getter GET_MIXED_ITEMS = Access.get((Mixed m) -> m.items);
    private static final Setter SET_MIXED_ITEMS = Access.set((Mixed m, Object v) -> m.items = (List<Item>) v);

    private static Field mapV() {
        return Packbin.u8(0, Access.get("v"), Access.set("v"));
    }

    /** An element nested-row group, with the factory when {@code create} is not null. */
    private static Field elementGroup(Supplier<?> create, Field... fields) {
        return create == null
                ? Packbin.group(Access.identity(), Access.ignore(), fields)
                : Packbin.group(Access.identity(), Access.ignore(), create, fields);
    }

    private static Field itemsOf(Field element) {
        return Packbin.list(GET_ITEMS, SET_ITEMS, element);
    }

    private static Field mixedItemsOf(Field element) {
        return Packbin.list(GET_MIXED_ITEMS, SET_MIXED_ITEMS, element);
    }

    /** Unpacking {@code hex} throws the ClassCastException that a typed accessor gets from a HashMap row. */
    private static void expectUnpackClassCast(String label, Scheme<?> scheme, String hex) {
        try {
            BinaryPacker.unpack(PackbinTest.parseHex(hex), scheme.on(row -> {}));
        } catch (ClassCastException ex) {
            return;
        }
        PackbinTest.fail(label + ": unpack did not throw ClassCastException");
    }

    /** AZ-2235 AC-1 (S2): a list element group without a factory on a typed row is refused at construction. */
    private static void az2235Ac1ListElementWithoutAFactoryIsRefused() {
        Scheme<Holder>[] built = new Scheme[1];
        PackbinTest.expectThrows("AZ-2235 AC-1 list of element groups without a factory",
                () -> built[0] = new Scheme<>(1, Holder.class, itemsOf(elementGroup(null, itemV()))), LIST_NEEDS_FACTORY);
        PackbinTest.expectTrue("AZ-2235 AC-1 no scheme built", built[0] == null);
    }

    /** AZ-2235 AC-2 (S6, S7): a dict, and the element of an inner list or dict, name the container that holds it. */
    private static void az2235Ac2DictAndInnerContainers() {
        PackbinTest.expectThrows("AZ-2235 AC-2 dict of element groups without a factory", () -> new Scheme<>(1, Holder.class,
                Packbin.dict(GET_BY_NAME, SET_BY_NAME, elementGroup(null, itemV()))), DICT_NEEDS_FACTORY);
        PackbinTest.expectThrows("AZ-2235 AC-2 list of lists", () -> new Scheme<>(1, Holder.class,
                Packbin.list(GET_NESTED, SET_NESTED,
                        Packbin.list(Access.identity(), Access.ignore(), elementGroup(null, itemV())))),
                LIST_NEEDS_FACTORY);
        PackbinTest.expectThrows("AZ-2235 AC-2 list of dicts", () -> new Scheme<>(1, Holder.class,
                Packbin.list(GET_NESTED, SET_NESTED,
                        Packbin.dict(Access.identity(), Access.ignore(), elementGroup(null, itemV())))),
                DICT_NEEDS_FACTORY);
        PackbinTest.expectThrows("AZ-2235 AC-2 dict of lists", () -> new Scheme<>(1, Holder.class,
                Packbin.dict(GET_BY_NAME, SET_BY_NAME,
                        Packbin.list(Access.identity(), Access.ignore(), elementGroup(null, itemV())))),
                LIST_NEEDS_FACTORY);
    }

    /** AZ-2235 AC-3 (S10, S11 and the carriers of AZ-2101): the holding scope is typed whatever stands around it. */
    private static void az2235Ac3WhereverTheHoldingScopeIsTyped() {
        PackbinTest.expectThrows("AZ-2235 AC-3 a typed nested row with a factory", () -> new Scheme<>(1, Holder.class,
                Packbin.group(Access.identity(), Access.ignore(), Holder::new, itemsOf(elementGroup(null, itemV())))),
                LIST_NEEDS_FACTORY);
        PackbinTest.expectThrows("AZ-2235 AC-3 a repeat", () -> new Scheme<>(1, Holder.class,
                Packbin.repeat(0, itemsOf(elementGroup(null, itemV())))), LIST_NEEDS_FACTORY);
        Field k = Packbin.u8(0, Access.get((Mixed m) -> m.k), Access.set((Mixed m, Object v) -> m.k = ((Number) v).intValue()));
        PackbinTest.expectThrows("AZ-2235 AC-3 below a when", () -> new Scheme<>(1, Mixed.class, k,
                Packbin.when(1, Packbin.eq(0, 1), mixedItemsOf(elementGroup(null, itemV())))), LIST_NEEDS_FACTORY);
        PackbinTest.expectThrows("AZ-2235 AC-3 as a flags member", () -> new Scheme<>(1, Mixed.class,
                Packbin.flags(0, mixedItemsOf(elementGroup(null, itemV())))), LIST_NEEDS_FACTORY);
        Field m = Packbin.flagByte();
        PackbinTest.expectThrows("AZ-2235 AC-3 as the payload of a flag byte bit", () -> new Scheme<>(1, Mixed.class, m,
                m.bit(mixedItemsOf(elementGroup(null, itemV())))), LIST_NEEDS_FACTORY);
        PackbinTest.expectThrows("AZ-2235 AC-3 inside an anchored group", () -> new Scheme<>(1, Mixed.class,
                Packbin.group(0, mixedItemsOf(elementGroup(null, itemV())))), LIST_NEEDS_FACTORY);
    }

    /** AZ-2235 AC-4 (S1, S3, S3b): a factory builds, with typed rows and with Map rows; the old overload is refused. */
    private static void az2235Ac4AFactoryBuilds() {
        Scheme<Holder> typed = new Scheme<>(1, Holder.class, itemsOf(elementGroup(Item::new, itemV())));
        Holder row = new Holder();
        row.items = List.of(item(3));
        PackbinTest.expectEq("AZ-2235 AC-4 typed factory bytes", "01010003", PackbinTest.toHex(BinaryPacker.pack(typed, row)));
        Holder back = unpackOne("AZ-2235 AC-4 typed factory", typed, "01010003");
        PackbinTest.expectTrue("AZ-2235 AC-4 the element is an Item",
                back.items != null && back.items.size() == 1 && ((Object) back.items.get(0)) instanceof Item
                        && back.items.get(0).v == 3);

        Scheme<Holder> maps = new Scheme<>(1, Holder.class,
                Packbin.list(GET_MAPS, SET_MAPS, elementGroup(java.util.HashMap::new, mapV())));
        Holder mapRow = new Holder();
        mapRow.maps = List.of(Maps.map("v", 3));
        PackbinTest.expectEq("AZ-2235 AC-4 HashMap factory bytes", "01010003", PackbinTest.toHex(BinaryPacker.pack(maps, mapRow)));
        PackbinTest.expectEq("AZ-2235 AC-4 HashMap factory row", List.of(Maps.map("v", 3)),
                unpackOne("AZ-2235 AC-4 HashMap factory", maps, "01010003").maps);

        PackbinTest.expectThrows("AZ-2235 AC-4 the old overload with Map accessors on a List of Map", () -> new Scheme<>(1,
                Holder.class, Packbin.list(GET_MAPS, SET_MAPS, elementGroup(null, mapV()))), LIST_NEEDS_FACTORY);
        PackbinTest.expectTrue("AZ-2235 AC-4 holderScheme (list and dict with Item::new) builds", holderScheme() != null);
    }

    /** AZ-2235 AC-5 (S4, S5, S8, S12): Map schemes and the shapes construction cannot decide build as before. */
    private static void az2235Ac5MapSchemesAndUndecidableShapesAreUnchanged() {
        Scheme<Map> mapScheme = Maps.scheme(1, Packbin.list(Access.get("items"), Access.set("items"),
                elementGroup(null, itemV())));
        Item three = item(3);
        PackbinTest.expectEq("AZ-2235 AC-5 Map scheme with typed accessors packs", "01010003",
                PackbinTest.toHex(BinaryPacker.pack(mapScheme, Maps.map("items", List.of(three)))));
        expectUnpackClassCast("AZ-2235 AC-5 Map scheme with typed accessors", mapScheme, "01010003");

        Scheme<Map> hashMapScheme = new Scheme<>(1, (Class) java.util.HashMap.class,
                Packbin.list(Access.get("maps"), Access.set("maps"), elementGroup(null, mapV())));
        PackbinTest.expectEq("AZ-2235 AC-5 HashMap class with Map accessors", Maps.map("maps", List.of(Maps.map("v", 3))),
                unpackOne("AZ-2235 AC-5 HashMap class", hashMapScheme, "01010003"));

        Scheme<Holder> anchoredTyped = new Scheme<>(1, Holder.class, itemsOf(Packbin.group(0, itemV())));
        expectUnpackClassCast("AZ-2235 AC-5 anchored element, typed accessors", anchoredTyped, "01010003");
        Scheme<Holder> anchoredMap = new Scheme<>(1, Holder.class,
                Packbin.list(GET_MAPS, SET_MAPS, Packbin.group(0, mapV())));
        PackbinTest.expectEq("AZ-2235 AC-5 anchored element, Map accessors", List.of(Maps.map("v", 3)),
                unpackOne("AZ-2235 AC-5 anchored element", anchoredMap, "01010003").maps);

        Scheme<Holder> flagsTyped = new Scheme<>(1, Holder.class, itemsOf(Packbin.flags(0, itemV())));
        expectUnpackClassCast("AZ-2235 AC-5 flags element, typed accessors", flagsTyped, "0101000103");
        Scheme<Holder> flagsMap = new Scheme<>(1, Holder.class,
                Packbin.list(GET_MAPS, SET_MAPS, Packbin.flags(0, mapV())));
        PackbinTest.expectEq("AZ-2235 AC-5 flags element, Map accessors", List.of(Maps.map("v", 3)),
                unpackOne("AZ-2235 AC-5 flags element", flagsMap, "0101000103").maps);
    }
}
