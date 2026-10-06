package packbin;

import java.util.Map;
import java.util.function.Supplier;

/**
 * AZ-2121, Java parts: the orphan flag-bit rule (a split bit needs its flag byte earlier in the same scope) holds for
 * a dict element (AC-2) and for a split bit held by a combined flags member (AC-4). The same-scope shapes still build.
 */
@SuppressWarnings({"unchecked", "rawtypes"})
final class FlagScopeContainerTest {
    private FlagScopeContainerTest() {}

    static void run() {
        ac2FlagByteOutsideADictElement();
        ac4CombinedFlagsMemberWithoutItsByte();
        sameScopeShapesStillBuild();
    }

    private static Field u8(int id, String name) {
        return Packbin.u8(id, Access.get(name), Access.set(name));
    }

    private static void expectRefused(String label, Supplier<Scheme<Map>> build, String named) {
        Scheme<Map>[] built = new Scheme[1];
        PackbinTest.expectThrows(label, () -> built[0] = build.get(),
                "flag bit " + named + " has no flagByte before it in the same scope");
        PackbinTest.expectTrue(label + ": no scheme built", built[0] == null);
    }

    private static void ac2FlagByteOutsideADictElement() {
        expectRefused("AC-2 byte outside the dict element holding the bit", () -> {
            Field fb = Packbin.flagByte();
            return Maps.scheme(1, fb, Packbin.dict(Access.get("m"), Access.set("m"),
                    fb.bit(Packbin.u8(0, Access.identity(), Access.ignore()))));
        }, "U8 0");

        expectRefused("AC-2 byte outside a dict element group holding the bit", () -> {
            Field fb = Packbin.flagByte();
            return Maps.scheme(1, fb, Packbin.dict(Access.get("m"), Access.set("m"),
                    Packbin.group(0, fb.bit(u8(0, "a")))));
        }, "U8 0");
    }

    private static void ac4CombinedFlagsMemberWithoutItsByte() {
        expectRefused("AC-4 combined flags holds a bit whose byte is missing", () -> {
            Field fb = Packbin.flagByte();
            return Maps.scheme(1, Packbin.flags(0, fb.bit(u8(0, "a"))));
        }, "U8 0");

        expectRefused("AC-4 combined flags holds a bit whose byte comes after it", () -> {
            Field fb = Packbin.flagByte();
            return Maps.scheme(1, Packbin.flags(0, fb.bit(u8(0, "a"))), fb);
        }, "U8 0");

        expectRefused("AC-4 second member of a combined flags", () -> {
            Field fb = Packbin.flagByte();
            return Maps.scheme(1, Packbin.flags(0, u8(0, "a"), fb.bit(u8(1, "b"))));
        }, "U8 1");
    }

    private static void sameScopeShapesStillBuild() {
        Field inElement = Packbin.flagByte();
        Scheme<Map> element = Maps.scheme(1, Packbin.dict(Access.get("m"), Access.set("m"),
                Packbin.group(0, inElement, inElement.bit(u8(0, "a")))));
        PackbinTest.expectTrue("AC-2 byte and bit inside one dict element group build", element != null);

        Field top = Packbin.flagByte();
        Scheme<Map> combined = Maps.scheme(1, top, Packbin.flags(0, top.bit(u8(0, "a"))));
        PackbinTest.expectTrue("AC-4 combined flags holding a bit of an earlier byte builds", combined != null);
    }
}
