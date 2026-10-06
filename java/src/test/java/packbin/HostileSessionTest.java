package packbin;

import java.util.Arrays;
import java.util.List;
import java.util.Map;

/**
 * AZ-2114: a session waiter that unpacks a hostile packet, padded as a session sends it, gets the error clear unpack
 * gives, within 1 s, and the next valid message of the session still unpacks. The packets are the zero-progress
 * repeat of the hostile vectors (AC-1, AC-2) and the zero-width list and dict elements of loop 11 (R2-G1).
 */
@SuppressWarnings({"unchecked", "rawtypes"})
final class HostileSessionTest {
    private HostileSessionTest() {}

    private static final byte[] NONCE = PackbinTest.parseHex("01000000000000000000000000000000");

    static void run() {
        ac1AndAc2ZeroProgressRepeat();
        zeroWidthListElements();
        zeroWidthDictValue();
    }

    private static byte[] seed() {
        byte[] bytes = new byte[PackSession.SEED_SIZE];
        for (int i = 0; i < bytes.length; i++) {
            bytes[i] = (byte) (i + 1);
        }
        return bytes;
    }

    /** One unpack on a daemon thread, so a hang shows as an unfinished run instead of stalling CI. */
    private static final class Run {
        Object result;
        Throwable thrown;
        boolean handled;
        boolean finished;
    }

    private interface Unpack {
        Object apply(Scheme.Handler<?> handler);
    }

    private static Run timed(Scheme<Map> scheme, Unpack unpack) {
        Run run = new Run();
        Thread worker = new Thread(() -> {
            try {
                run.result = unpack.apply(scheme.on(row -> run.handled = true));
            } catch (RuntimeException | Error ex) {
                run.thrown = ex;
            }
        });
        worker.setDaemon(true);
        worker.start();
        try {
            worker.join(HostileRun.LIMIT_MS);
        } catch (InterruptedException ex) {
            Thread.currentThread().interrupt();
            throw new IllegalStateException("interrupted while waiting for unpack", ex);
        }
        run.finished = !worker.isAlive();
        return run;
    }

    /** What an error value says, field by field, so two results compare by kind and content. */
    private static String describe(Object error) {
        if (error instanceof Packbin.ShortPacket s) {
            return "ShortPacket(" + s.field + "," + s.needed + "," + s.left + ")";
        }
        if (error instanceof Packbin.TrailingBytes t) {
            return "TrailingBytes(" + t.left + ")";
        }
        if (error instanceof Packbin.TypeMismatch m) {
            return "TypeMismatch(" + m.expected + "," + m.actual + ")";
        }
        return String.valueOf(error);
    }

    /** The packet as the opener sends it: its clear bytes XOR the pad of the opener's packet number {@code count}. */
    private static byte[] padded(byte[] clear, long count) {
        byte[] key = Arrays.copyOfRange(SessionPad.hkdfSha256(seed(), NONCE, 2 * PackSession.SEED_SIZE), 0, PackSession.SEED_SIZE);
        byte[] copy = Arrays.copyOf(clear, clear.length);
        SessionPad.xor(key, count, copy);
        return copy;
    }

    /**
     * The hostile packet is the first one of a fresh pair, so it carries packet number 0. The opener then packs one
     * valid message to move its counter past 0 and sends a second one, which the waiter must still unpack.
     */
    private static void expectSameErrorThenValid(String label, Scheme<Map> scheme, String clearHex, Map<String, Object> valid) {
        byte[] clear = PackbinTest.parseHex(clearHex);
        Run viaClear = timed(scheme, handler -> BinaryPacker.unpack(clear, handler));
        PackbinTest.expectTrue(label + " clear unpack is an error value (" + viaClear.thrown + ")",
                viaClear.finished && viaClear.thrown == null && viaClear.result != null && !viaClear.handled);

        PackSession opener = PackSession.load(seed());
        PackSession waiter = PackSession.load(seed());
        PackbinTest.expectTrue(label + " pair opens", opener != null && waiter != null
                && opener.start(NONCE) != null && waiter.join(NONCE));
        if (opener == null || waiter == null) {
            return;
        }
        byte[] hostile = padded(clear, 0);
        PackbinTest.expectTrue(label + " the padded bytes differ from the clear ones", !Arrays.equals(hostile, clear));

        Run viaSession = timed(scheme, handler -> waiter.unpack(hostile, handler));
        PackbinTest.expectTrue(label + " session unpack returns within " + HostileRun.LIMIT_MS + " ms", viaSession.finished);
        PackbinTest.expectTrue(label + " session unpack does not throw (" + viaSession.thrown + ")", viaSession.thrown == null);
        PackbinTest.expectTrue(label + " session unpack leaves the handler uncalled", !viaSession.handled);
        PackbinTest.expectEq(label + " same error as clear unpack", describe(viaClear.result), describe(viaSession.result));

        opener.pack(scheme, valid);
        byte[] next = opener.pack(scheme, valid);
        Map[] got = new Map[1];
        Object err = waiter.unpack(next, scheme.on(row -> got[0] = row));
        PackbinTest.expectTrue(label + " the next valid message unpacks (" + describe(err) + ")", err == null && got[0] != null);
        PackbinTest.expectEq(label + " the next valid message row", valid, got[0]);
    }

    private static Field u8(int id, String name) {
        return Packbin.u8(id, Access.get(name), Access.set(name));
    }

    /** AC-1 and AC-2. A round of the repeat reads nothing and `ff` is left over, so clear unpack says TrailingBytes. */
    private static void ac1AndAc2ZeroProgressRepeat() {
        Scheme<Map> scheme = Maps.scheme(1, u8(0, "mode"),
                Packbin.repeat(1, Packbin.bytes(1, Access.get("b"), Access.set("b"), 0)));
        expectSameErrorThenValid("AC-1 01 00 ff", scheme, "0100ff", Maps.map("mode", 0));
        PackbinTest.expectEq("AC-1 clear unpack of 01 00 ff", "TrailingBytes(1)",
                describe(clearResult(scheme, "0100ff")));
    }

    private static Object clearResult(Scheme<Map> scheme, String hex) {
        return BinaryPacker.unpack(PackbinTest.parseHex(hex), scheme.on(row -> {}));
    }

    private static void zeroWidthListElements() {
        Scheme<Map> scheme = Maps.scheme(1, Packbin.list(Access.get("xs"), Access.set("xs"),
                Packbin.list(Access.identity(), Access.ignore(), Packbin.bytes(0, Access.identity(), Access.ignore(), 0))));
        expectSameErrorThenValid("R2-G1 01 ff ff ff ff", scheme, "01ffffffff", Maps.map("xs", List.of()));
        PackbinTest.expectEq("R2-G1 clear unpack of 01 ff ff ff ff", "ShortPacket(,0,0)",
                describe(clearResult(scheme, "01ffffffff")));
    }

    private static void zeroWidthDictValue() {
        Scheme<Map> scheme = Maps.scheme(1, Packbin.dict(Access.get("m"), Access.set("m"),
                Packbin.bytes(0, Access.identity(), Access.ignore(), 0)));
        expectSameErrorThenValid("R2-G1 01 ff ff 01 00 61", scheme, "01ffff010061", Maps.map("m", Map.of()));
        PackbinTest.expectEq("R2-G1 clear unpack of 01 ff ff 01 00 61", "ShortPacket(,0,0)",
                describe(clearResult(scheme, "01ffff010061")));
    }
}
