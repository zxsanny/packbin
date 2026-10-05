package packbin;

import java.lang.reflect.Field;
import java.lang.reflect.Modifier;
import java.util.concurrent.atomic.AtomicInteger;
import java.util.Map;

/** AZ-2077: unpack keeps flag-byte state per call, so one shared scheme is safe on many threads. */
@SuppressWarnings({"unchecked", "rawtypes"})
final class FlagStateTest {
    private FlagStateTest() {}

    private static final int ROUNDS = 200_000;

    private static final Scheme<Map> SPLIT = splitAb();
    private static final Scheme<Map> COMBINED = combinedAb();

    static void run() throws InterruptedException {
        concurrentSplitForm();
        concurrentCombinedForm();
        schemeStateIsFinal();
        splitFormBytesAndRoundTrip();
        splitFormShortPacket();
        splitFormClearByte();
        repeatRoundKeepsItsOwnFlagByte();
    }

    private static Scheme<Map> splitAb() {
        packbin.Field fb = Packbin.flagByte();
        return Maps.scheme(1,
                fb,
                fb.bit(Packbin.u8(0, Access.get("a"), Access.set("a"))),
                fb.bit(Packbin.u8(1, Access.get("b"), Access.set("b"))));
    }

    private static Scheme<Map> combinedAb() {
        return Maps.scheme(1, Packbin.flags(0,
                Packbin.u8(0, Access.get("a"), Access.set("a")),
                Packbin.u8(1, Access.get("b"), Access.set("b"))));
    }

    private static void concurrentSplitForm() throws InterruptedException {
        expectNoWrongRows("AC-1 split form concurrent", SPLIT);
    }

    private static void concurrentCombinedForm() throws InterruptedException {
        expectNoWrongRows("AC-2 combined form concurrent", COMBINED);
    }

    /** Two threads, one packet each ({a: 7} and {b: 8}), every call must see only its own packet's field. */
    private static void expectNoWrongRows(String label, Scheme<Map> scheme) throws InterruptedException {
        byte[] onlyA = PackbinTest.parseHex("010107");
        byte[] onlyB = PackbinTest.parseHex("010208");
        AtomicInteger wrong = new AtomicInteger();
        AtomicInteger errors = new AtomicInteger();
        Thread first = new Thread(() -> hammer(scheme, onlyA, "a", 7, "b", wrong, errors));
        Thread second = new Thread(() -> hammer(scheme, onlyB, "b", 8, "a", wrong, errors));
        first.start();
        second.start();
        first.join();
        second.join();
        PackbinTest.expectEq(label + " wrong rows", 0, wrong.get());
        PackbinTest.expectEq(label + " errors", 0, errors.get());
    }

    private static void hammer(
            Scheme<Map> scheme, byte[] packet, String own, int value, String other,
            AtomicInteger wrong, AtomicInteger errors) {
        for (int i = 0; i < ROUNDS; i++) {
            Map[] got = new Map[1];
            Object err;
            try {
                err = BinaryPacker.unpack(packet, scheme.on(row -> got[0] = row));
            } catch (RuntimeException ex) {
                errors.incrementAndGet();
                continue;
            }
            if (err != null || got[0] == null) {
                errors.incrementAndGet();
            } else if (!Integer.valueOf(value).equals(got[0].get(own)) || got[0].containsKey(other)) {
                wrong.incrementAndGet();
            }
        }
    }

    private static void schemeStateIsFinal() {
        for (Class<?> type : new Class<?>[] {Scheme.class, packbin.Field.class, FlagGroup.class}) {
            for (Field member : type.getDeclaredFields()) {
                boolean mutable = !Modifier.isStatic(member.getModifiers()) && !Modifier.isFinal(member.getModifiers());
                PackbinTest.expectTrue("AC-3 " + type.getSimpleName() + "." + member.getName() + " is final", !mutable);
            }
        }
        int instanceFields = 0;
        for (Field member : FlagGroup.class.getDeclaredFields()) {
            if (!Modifier.isStatic(member.getModifiers())) {
                instanceFields++;
            }
        }
        PackbinTest.expectEq("AC-3 FlagGroup holds only its bit list", 1, instanceFields);
    }

    /** sid, flag byte, when(sid == 9) shape, then three bits; bytes as the TypeScript split-form reference. */
    private static Scheme<Map> splitMotion() {
        packbin.Field motion = Packbin.flagByte();
        return Maps.scheme(1,
                Packbin.u8(0, Access.get("sid"), Access.set("sid")),
                motion,
                Packbin.when(1, Packbin.eq(0, 9), Packbin.u8(1, Access.get("shape"), Access.set("shape"))),
                motion.bit(Packbin.u16(2, Access.get("heading"), Access.set("heading"))),
                motion.bit(Packbin.u8(3, Access.get("speed"), Access.set("speed"))),
                motion.bit(Packbin.i16(4, Access.get("altitude"), Access.set("altitude"))));
    }

    private static void splitFormBytesAndRoundTrip() {
        Scheme<Map> scheme = splitMotion();
        byte[] present = BinaryPacker.pack(scheme, Maps.map("sid", 9, "shape", 4, "heading", 90));
        PackbinTest.expectEq("AC-4 split form heading only", "010901045a00", PackbinTest.toHex(present));
        Map[] got = new Map[1];
        Object err = BinaryPacker.unpack(present, scheme.on(row -> got[0] = row));
        PackbinTest.expectTrue("AC-4 split form unpack ok", err == null);
        PackbinTest.expectEq("AC-4 split form row", Maps.map("sid", 9, "shape", 4, "heading", 90), got[0]);

        byte[] none = BinaryPacker.pack(scheme, Maps.map("sid", 1));
        PackbinTest.expectEq("AC-4 split form nothing present", "010100", PackbinTest.toHex(none));
        Map[] noneGot = new Map[1];
        Object noneErr = BinaryPacker.unpack(none, scheme.on(row -> noneGot[0] = row));
        PackbinTest.expectTrue("AC-4 split form clear byte ok", noneErr == null);
        PackbinTest.expectEq("AC-4 split form clear row", Maps.map("sid", 1), noneGot[0]);

        Map<String, Object> all = Maps.map("sid", 9, "shape", 4, "heading", 90, "speed", 10, "altitude", -2);
        byte[] full = BinaryPacker.pack(scheme, all);
        Map[] fullGot = new Map[1];
        Object fullErr = BinaryPacker.unpack(full, scheme.on(row -> fullGot[0] = row));
        PackbinTest.expectTrue("AC-4 split form all bits ok", fullErr == null);
        PackbinTest.expectEq("AC-4 split form all bits row", all, fullGot[0]);
    }

    private static void splitFormShortPacket() {
        Scheme<Map> scheme = splitMotion();
        HostileRun inside = HostileRun.of(scheme, "010901045a");
        PackbinTest.expectTrue("AC-4 short inside heading -> " + inside.kind(), inside.result instanceof Packbin.ShortPacket);
        PackbinTest.expectTrue("AC-4 short inside heading handler not called", !inside.handled);
        if (inside.result instanceof Packbin.ShortPacket packet) {
            PackbinTest.expectEq("AC-4 short field", "2", packet.field);
            PackbinTest.expectEq("AC-4 short needed", 2, packet.needed);
            PackbinTest.expectEq("AC-4 short left", 1, packet.left);
        }

        HostileRun noByte = HostileRun.of(scheme, "0109");
        PackbinTest.expectTrue("AC-4 short before flag byte -> " + noByte.kind(), noByte.result instanceof Packbin.ShortPacket);
        PackbinTest.expectTrue("AC-4 short before flag byte handler not called", !noByte.handled);
    }

    private static void splitFormClearByte() {
        Scheme<Map> scheme = splitMotion();
        HostileRun extra = HostileRun.of(scheme, "01010099");
        PackbinTest.expectTrue("AC-4 clear byte with leftover -> " + extra.kind(), extra.result instanceof Packbin.TrailingBytes);
        PackbinTest.expectTrue("AC-4 clear byte with leftover handler not called", !extra.handled);
    }

    private static void repeatRoundKeepsItsOwnFlagByte() {
        packbin.Field round = Packbin.flagByte();
        Scheme<Map> scheme = Maps.scheme(1, Packbin.repeat(0,
                round,
                round.bit(Packbin.u8(0, Access.get("a"), Access.set("a")))));
        Map[] got = new Map[1];
        Object err = BinaryPacker.unpack(PackbinTest.parseHex("010107000109"), scheme.on(row -> got[0] = row));
        PackbinTest.expectTrue("scope repeat rounds ok", err == null);
        // AZ-2089 F2: one entry per round; the round whose bit was clear holds null.
        PackbinTest.expectEq("scope repeat rounds use their own flag byte", java.util.Arrays.asList(7, null, 9), got[0].get("a"));
    }
}
